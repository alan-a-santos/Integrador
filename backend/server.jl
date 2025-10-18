using HTTP, JSON3, Random
include("modelo.jl")
include("simulacao.jl")
using .Simulacao

Random.seed!(1234)

# host = "127.0.0.1"
host = "0.0.0.0"
port = 8000

const CORS_HEADERS = [
    ("Access-Control-Allow-Origin", "*"),
    ("Access-Control-Allow-Headers", "Content-Type, xAuthorization"),
    ("Access-Control-Allow-Methods", "GET, POST, OPTIONS"),
    ("Content-Type", "application/json")
]

function handler(req::HTTP.Request)
    method = HTTP.method(req)
    body_str = String(req.body)
    println(body_str)
    
    if method == "OPTIONS"
        return HTTP.Response(200, CORS_HEADERS, "")

    elseif method == "GET" && req.target == "/teste"
        return HTTP.Response(200, CORS_HEADERS, "Servidor OK")

    elseif method == "POST" && req.target == "/simulacao"
    dados = JSON3.read(body_str, Dict{String, Any})

    resultado_json = Simulacao.rodar_simulacao(dados)

    # Converte o JSON (string) em Dict
    resultado = JSON3.read(resultado_json, Dict{String, Any})

    metricas = resultado["metricas"]
    historicoData = resultado["historico"]
    previsaoData = resultado["previsao"]

    resposta = Dict(
        "metricas" => metricas,
        "interpretacoes" => Dict(
            "RMSE" => "Raiz do Erro Quadrático Médio — quanto menor, melhor o ajuste do modelo às observações.",
            "MAE" => "Erro Absoluto Médio — indica o erro médio das previsões em relação aos valores reais.",
            "MAPE_real" => "Erro Percentual Médio Absoluto — mostra o erro percentual médio. Valores abaixo de 10% indicam excelente precisão.",
            "R2" => "Coeficiente de Determinação — mede o quanto da variação dos dados reais é explicada pelo modelo (1 é perfeito)."
        ),
        "historico" => historicoData,
        "previsao" => previsaoData
    )

    return HTTP.Response(200, CORS_HEADERS, JSON3.write(resposta))

    else
        return HTTP.Response(404, CORS_HEADERS, "Not Found")
    end
end

println("Servidor rodando em http://$host:$port")
HTTP.serve(handler, host, port)

