"use client";
import { useEffect, useState } from "react";
import axios from "axios";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  Legend,
  CartesianGrid
} from "recharts";

interface DadoGrafico {
  data: string;
  IPCA_real: number | null;
  IPCA_previsto: number | null;
}

interface HistoricoItem {
  data: string;
  IPCA: number;
}

interface PrevisaoItem {
  data: string;
  IPCA_previsto?: number;
}

interface Metricas {
  RMSE: number;
  MAE: number;
  MAPE_real: number;
  R2: number;
}

interface Interpretacoes {
  RMSE: string;
  MAE: string;
  MAPE_real: string;
  R2: string;
}

export default function SimulacaoForm() {
  const [selic, setSelic] = useState<string>("0");
  const [pib, setPib] = useState<string>("0");
  const [cambio, setCambio] = useState<string>("0");
  const [horizonte, setHorizonte] = useState<number>(12);
  const [dadosGrafico, setDadosGrafico] = useState<DadoGrafico[]>([]);
  const [metricas, setMetricas] = useState<Metricas>({
    RMSE: 0,
    MAE: 0,
    MAPE_real: 0,
    R2: 0
  });
  const [interpretacoes, setInterpretacoes] = useState<Interpretacoes | null>(null);


const fetchEconomia = async () => {
  try {
    const res = await axios.get("/api/economia");
    setSelic(res.data.selic.toString());
    setPib(res.data.pib.toString());
    setCambio(res.data.cambio.toString());
  } catch (error) {
    console.error("Erro ao buscar dados econômicos:", error);
  }
};


  useEffect(() => {
    fetchEconomia();
  }, []);

  const limparCampos = () => {
    fetchEconomia();
    setHorizonte(12);
    setDadosGrafico([]);
    setMetricas({ RMSE: 0, MAE: 0, MAPE_real: 0, R2: 0 });
    setInterpretacoes(null);
  };

  const enviarDados = async () => {
    const payload = { SELIC: selic, PIB: pib, CAMBIO: cambio, horizonte };

    try {
      const res = await axios.post("http://localhost:8000/simulacao", payload);
      const response = res.data;

      setMetricas(response.metricas);
      setInterpretacoes(response.interpretacoes);

      const historico: HistoricoItem[] = (response.historico || []).map((h: HistoricoItem) => ({
        data: h.data,
        IPCA: Number(h.IPCA)
      }));

      const previsao: PrevisaoItem[] = (response.previsao || []).map((p: PrevisaoItem) => ({
        data: p.data,
        IPCA_previsto: p.IPCA_previsto !== undefined ? Number(p.IPCA_previsto) : undefined
      }));

      // Últimos 6 meses reais
      const ultimosHistorico = historico.slice(-6).map(h => ({
        data: h.data,
        IPCA_real: h.IPCA,
        IPCA_previsto: null
      }));

      // Previsão futura
      const dadosPrevistos = previsao.map(p => ({
        data: p.data,
        IPCA_real: null,
        IPCA_previsto: p.IPCA_previsto ?? null
      }));

      const combinedData: DadoGrafico[] = [...ultimosHistorico, ...dadosPrevistos];
      setDadosGrafico(combinedData);
    } catch (error) {
      console.error("Erro ao enviar dados:", error);
    }
  };

  return (
    <>
      <h1 className="bg-blue-800 font-bold text-white p-4 rounded-lg text-4xl text-center">
        Sistema de Simulação do IPCA
      </h1>

      <fieldset className="border p-5 rounded-lg shadow-xl shadow-blue-200 flex flex-wrap gap-5 mt-2 items-center">
        <legend className="font-bold">Simulação do IPCA</legend>

        <div>
          <label>Taxa de Juros (%): </label>
          <input
            type="number"
            value={selic}
            onChange={(e) => setSelic(e.target.value)}
            className="bg-blue-100 border rounded w-20 text-center"
          />
        </div>

        <div>
          <label>PIB (%): </label>
          <input
            type="number"
            value={pib}
            onChange={(e) => setPib(e.target.value)}
            className="bg-blue-100 border rounded w-20 text-center"
          />
        </div>

        <div>
          <label>Câmbio (R$): </label>
          <input
            type="number"
            value={cambio}
            onChange={(e) => setCambio(e.target.value)}
            className="bg-blue-100 border rounded w-20 text-center"
          />
        </div>

        <div>
          <label>Horizonte (meses): </label>
          <input
            type="number"
            value={horizonte}
            onChange={(e) => setHorizonte(Number(e.target.value))}
            className="bg-blue-100 border rounded w-20 text-center"
          />
        </div>

        <div className="flex gap-2 ml-auto">
          <button
            type="button"
            onClick={limparCampos}
            className="bg-blue-500 text-white py-2 px-4 rounded cursor-pointer"
          >
            Resetar
          </button>
          <button
            type="button"
            onClick={enviarDados}
            className="bg-blue-500 text-white py-2 px-4 rounded cursor-pointer"
          >
            Simular
          </button>
        </div>
      </fieldset>

      {dadosGrafico.length > 0 && (
        <div className="mt-28 flex gap-12 ">
          {/* Gráfico */}
          <div className="flex-1">
            <LineChart width={1500} height={500} data={dadosGrafico}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis
                dataKey="data"
                tickFormatter={(date) =>
                  new Date(date).toLocaleDateString("pt-BR", {
                    month: "2-digit",
                    year: "2-digit"
                  })
                }
              />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line
                type="monotone"
                dataKey="IPCA_real"
                stroke="#1f77b4"
                dot={false}
                name="IPCA Real"
                strokeWidth={3}
              />
              <Line
                type="monotone"
                dataKey="IPCA_previsto"
                stroke="#2ca02c"
                dot={false}
                name="IPCA Previsto"
                strokeWidth={4}
                connectNulls
              />
            </LineChart>

            {/* Métricas e interpretações */}
            <div className="mt-4 w-full flex flex-col items-center bg-gray-100 p-4 rounded h-32">
              <div className="flex justify-center gap-10">
                <div>RMSE: {metricas.RMSE}</div>
                <div>MAE: {metricas.MAE}</div>
                {/* <div>MAPE: {metricas.MAPE_real}%</div> */}
                <div>R²: {metricas.R2}</div>
              </div>

              {interpretacoes && (
                <div className="mt-4 text-sm text-gray-700 text-justify max-w-4xl">
                  <p><strong>RMSE:</strong> {interpretacoes.RMSE}</p>
                  <p><strong>MAE:</strong> {interpretacoes.MAE}</p>
                  {/* <p><strong>MAPE:</strong> {interpretacoes.MAPE_real}</p> */}
                  <p><strong>R²:</strong> {interpretacoes.R2}</p>
                </div>
              )}
            </div>
          </div>

          {/* Tabela de projeções */}
          <div className="flex-1 overflow-y-auto h-[600px]">
            <table className="w-80 border-collapse border border-gray-300 text-center">
              <thead className="bg-gray-200">
                <tr>
                  <th className="border border-gray-300 p-2">Data</th>
                  <th className="border border-gray-300 p-2">IPCA Previsto</th>
                </tr>
              </thead>
              <tbody>
                {dadosGrafico
                  .filter((d) => d.IPCA_previsto !== null)
                  .map((item, index) => (
                    <tr key={index}>
                      <td className="border border-gray-300 p-2">
                        {new Date(item.data).toLocaleDateString("pt-BR", {
                          month: "short",
                          year: "numeric"
                        })}
                      </td>
                      <td className="border border-gray-300 p-2">
                        {item.IPCA_previsto?.toFixed(2)}
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </>
  );
}
