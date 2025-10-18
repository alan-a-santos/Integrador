module Modelo

using HTTP, JSON3, DataFrames, Dates, Statistics, ShiftedArrays, MLJBase, XGBoost, Interpolations, Plots, Distributions

export df, model, colnames, treinar_modelo_sensivel, avaliar_modelo, mostrar_importancia, prever_ipca_futuro_sensivel

# ============================================================
# 1️⃣ Função para consultar séries do BCB
# ============================================================
function consultar_dados(codigo)
    final = Dates.format(Date(year(today()), month(today()), 1), "dd/mm/yyyy")
    inicial = Dates.format(Date(year(today()) - 25, month(today()), 1), "dd/mm/yyyy")
    url = "https://api.bcb.gov.br/dados/serie/bcdata.sgs.$(codigo)/dados?formato=json&dataInicial=$(inicial)&dataFinal=$(final)"
    resp = HTTP.get(url)
    body_str = String(resp.body)
    if !startswith(body_str, "[")
        error("Erro ao consultar série $codigo")
    end
    return DataFrame(JSON3.read(body_str))
end

# ============================================================
# 2️⃣ Carregar e preparar dados
# ============================================================
function carregar_dados()
    CAMBIO = consultar_dados(20360)
    IPCA   = consultar_dados(13522)
    PIB_tri = consultar_dados(24363)
    SELIC  = consultar_dados(4390)

    for df_tmp in [CAMBIO, IPCA, PIB_tri, SELIC]
        df_tmp.data = Date.(df_tmp.data, dateformat"dd/mm/yyyy")
    end

    # Interpolar PIB trimestral para mensal
    function interpolar_pib_mensal(df_tri::DataFrame)
        sort!(df_tri, :data)
        x = 1:size(df_tri,1)
        y = parse.(Float64, replace.(df_tri.valor, "," => "."))
        itp = LinearInterpolation(x, y, extrapolation_bc=Line())
        datas_mensais = collect(minimum(df_tri.data):Month(1):maximum(df_tri.data))
        n_meses = length(datas_mensais)
        x_mensal = range(1, stop=size(df_tri,1), length=n_meses)
        pib_mensal = itp.(x_mensal)
        return DataFrame(data=datas_mensais, PIB=pib_mensal)
    end

    PIB = interpolar_pib_mensal(PIB_tri)

    rename!(CAMBIO, :valor => :CAMBIO)
    rename!(IPCA, :valor => :IPCA)
    rename!(SELIC, :valor => :SELIC)

    for df_tmp in [CAMBIO, IPCA, SELIC]
        df_tmp[!, names(df_tmp, String)] = parse.(Float64, replace.(df_tmp[!, names(df_tmp, String)], "," => "."))
    end

    df = reduce((x,y) -> innerjoin(x, y, on=:data), [IPCA, CAMBIO, PIB, SELIC])

    # Variações percentuais
    df.CAMBIO = (df.CAMBIO .- ShiftedArrays.lag(df.CAMBIO)) ./ ShiftedArrays.lag(df.CAMBIO) .* 100
    df.PIB    = (df.PIB .- ShiftedArrays.lag(df.PIB)) ./ ShiftedArrays.lag(df.PIB) .* 100

    # Z-score
    for c in [:IPCA, :CAMBIO, :PIB, :SELIC]
        μ, σ = mean(skipmissing(df[!, c])), std(skipmissing(df[!, c]))
        df[!, Symbol(c, "_z")] = (df[!, c] .- μ) ./ σ
    end

    # Criar lags do IPCA
    for lags in [1,3,6,12]
        df[!, Symbol("IPCA_$lags")] = [fill(missing, lags); df.IPCA_z[1:end-lags]]
    end
    dropmissing!(df)
    return df
end

const df = carregar_dados()

# ============================================================
# 3️⃣ Enriquecer dados (diferenças + interações)
# ============================================================
function enriquecer_dados!(df)
    df[!, :CAMBIO_diff] = df.CAMBIO .- ShiftedArrays.lag(df.CAMBIO)
    df[!, :SELIC_diff]  = df.SELIC .- ShiftedArrays.lag(df.SELIC)
    df[!, :PIB_diff]    = df.PIB .- ShiftedArrays.lag(df.PIB)

    
    df[!, :CAMBIO_SELIC] = df.CAMBIO_z .* df.SELIC_z
    df[!, :PIB_CAMBIO]   = df.PIB_z .* df.CAMBIO_z

    dropmissing!(df)
    return df
end

enriquecer_dados!(df)

# ============================================================
# 4️⃣ Treinar modelo XGBoost sensível
# ============================================================
function treinar_modelo_sensivel(df)
    X = DataFrames.select(df, [:CAMBIO_z, :PIB_z, :SELIC_z,
                    :CAMBIO_diff, :SELIC_diff, :PIB_diff,
                    :CAMBIO_SELIC, :PIB_CAMBIO,
                    :IPCA_1])
    y = df.IPCA_z
    colnames = names(X)

    train, test = partition(eachindex(y), 0.8, shuffle=true)
    X_train = Matrix(X[train, :])
    X_test  = Matrix(X[test, :])
    y_train = y[train]
    y_test  = y[test]

    dtrain = DMatrix(X_train, label=y_train)
    dtest  = DMatrix(X_test, label=y_test)

    params = Dict(
        "objective" => "reg:squarederror",
        "eta" => 0.1,  #0,05
        "max_depth" => 4, #4
        "subsample" => 0.7, #0,9
        "colsample_bytree" => 0.7, #0,9
        "lambda" => 1.0, #2
        "alpha" => 0.5, #1
        "eval_metric" => "rmse"
    )

    model = xgboost(dtrain, num_round=400, params=params)
    return model, dtest, y_test, colnames
end

const model, dtest, y_test, colnames = treinar_modelo_sensivel(df)

# ============================================================
# 5️⃣ Avaliar modelo
# ============================================================
function avaliar_modelo(model, dtest, y_test)
    y_pred = XGBoost.predict(model, dtest)
    mse  = mean((y_test .- y_pred).^2)
    rmse = sqrt(mse)
    mae  = mean(abs.(y_test .- y_pred))
    r2   = 1 - sum((y_test .- y_pred).^2) / sum((y_test .- mean(y_test)).^2)

    # println("📊 Métricas do Modelo:")
    # println("RMSE = ", round(rmse, digits=3))
    # println("MAE  = ", round(mae, digits=3))
    # println("R²   = ", round(r2, digits=3))
    return Dict("RMSE"=>rmse, "MAE"=>mae, "R2"=>r2)
end

avaliar_modelo(model, dtest, y_test)

# ============================================================
# 6️⃣ Mostrar importância das features
# ============================================================
function mostrar_importancia(model, colnames)
    importance = XGBoost.importance(model)
    sorted_importance = sort(collect(importance), by = x -> -(x[2] isa AbstractVector ? x[2][1] : x[2]))
    println("\n📌 Importância das Features:")
    for (feature_idx, score) in sorted_importance
        idx = feature_idx
        nome = colnames[idx]
        valor = score isa AbstractVector ? score[1] : score
        println(rpad(nome, 15), " => ", round(valor, digits=4))
    end
end

mostrar_importancia(model, colnames)

# ============================================================
# 7️⃣ Previsão futura com variação realista
# ============================================================
function prever_ipca_futuro_sensivel(user_input; n_steps=12, variabilidade=0.2)
    preds_z = Float64[]
    lags = [last(df.IPCA_1)]
    cambio = parse(Float64, user_input["CAMBIO"])
    pib    = parse(Float64, user_input["PIB"])
    selic  = parse(Float64, user_input["SELIC"])

    IPCA_mean = mean(skipmissing(df.IPCA))
    IPCA_std  = std(skipmissing(df.IPCA))

    for t in 1:n_steps
        cambio_z = (cambio - mean(skipmissing(df.CAMBIO))) / std(skipmissing(df.CAMBIO))
        pib_z    = (pib - mean(skipmissing(df.PIB))) / std(skipmissing(df.PIB))
        selic_z  = (selic - mean(skipmissing(df.SELIC))) / std(skipmissing(df.SELIC))

        cambio_diff = 0.0
        pib_diff    = 0.0
        selic_diff  = 0.0
        CAMBIO_SELIC = cambio_z * selic_z
        PIB_CAMBIO   = pib_z * cambio_z

        X_step = [cambio_z, pib_z, selic_z,
                  cambio_diff, selic_diff, pib_diff,
                  CAMBIO_SELIC, PIB_CAMBIO,
                  lags...] |> x -> reshape(x, 1, :)

        y_pred_z = XGBoost.predict(model, DMatrix(X_step))[1]
        ruido = rand(Normal(0, variabilidade * abs(y_pred_z)))
        y_pred_z += ruido

        push!(preds_z, y_pred_z)
        lags = [y_pred_z]
    end

    return preds_z .* IPCA_std .+ IPCA_mean
end

end # module

