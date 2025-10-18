module Simulacao

using ..Modelo
using DataFrames
using JSON3
using Statistics
using Plots
using Dates

export rodar_simulacao, plotar_real_vs_previsto

function rodar_simulacao(dados::Dict{String, Any})
    horizonte = get(dados, "horizonte", 6)

    # --- 1️⃣ Rodar previsão ---
    forecast = Modelo.prever_ipca_futuro_sensivel(dados; n_steps=horizonte)

    # --- 2️⃣ Histórico real (últimos 12 meses, por exemplo) ---
    n_historico = 12
    historico = Modelo.df[end-n_historico+1:end, [:data, :IPCA]]

    # --- 3️⃣ Datas futuras ---
    ult_data = last(Modelo.df.data)
    datas_futuras = [ult_data + Month(i) for i in 1:horizonte]
    df_forecast = DataFrame(data=datas_futuras, IPCA_previsto=forecast)

    # --- 4️⃣ Métricas do modelo ---
    metricas = Modelo.avaliar_modelo(Modelo.model, Modelo.dtest, Modelo.y_test)
    metricas = Dict(k => round(v, digits=3) for (k, v) in metricas)
    # metricas = Dict(
    #     "RMSE" => 0.1699,
    #     "MAE" => 0.1334,
    #     "MAPE_normalizado" => 257.54,
    #     "MAPE_real" => 7.8,
    #     "R2" => 0.9755
    # )

    # --- 5️⃣ Montar resposta JSON ---
    resposta = Dict(
        "historico" => [Dict("data" => string(h.data), "IPCA" => h.IPCA) for h in eachrow(historico)],
        "previsao"  => [Dict("data" => string(p.data), "IPCA_previsto" => p.IPCA_previsto) for p in eachrow(df_forecast)],
        "metricas"  => metricas
    )

    return JSON3.write(resposta)
end


# 🔹 Função opcional para gerar gráfico no backend (uso interno)
# function plotar_real_vs_previsto()
#     ipca_real = Modelo.df[:, [:data, :IPCA]]
#     entrada = Dict(
#         "CAMBIO" => last(Modelo.df.CAMBIO),
#         "PIB" => last(Modelo.df.PIB),
#         "SELIC" => last(Modelo.df.SELIC),
#         "horizonte" => 6
#     )
#     previsoes = Modelo.prever_ipca_futuro_sensivel(entrada; n_steps=6)
#     ult_data = last(ipca_real.data)
#     datas_futuras = [ult_data + Month(i) for i in 1:length(previsoes)]
#     df_prev = DataFrame(data=datas_futuras, IPCA_previsto=previsoes)

#     plot(ipca_real.data, ipca_real.IPCA, label="IPCA Real", lw=2)
#     plot!(df_prev.data, df_prev.IPCA_previsto, label="IPCA Previsto", lw=2, ls=:dash, color=:red)
#     xlabel!("Data")
#     ylabel!("IPCA (%)")
#     title!("Comparação: IPCA Real x IPCA Previsto")
#     grid!(true)
# end

end
