import type { NextApiRequest, NextApiResponse } from "next";
import axios from "axios";

type EconomicoResponse = {
  selic: number;
  pib: number;
  cambio: number;
};

// Função para pegar o último valor de uma série do SGS
const getUltimoValor = async (codigo: number): Promise<number> => {
  try {
    const response = await axios.get(
      `https://api.bcb.gov.br/dados/serie/bcdata.sgs.${codigo}/dados/ultimos/1?formato=json`
    );
    const data = response.data;
    if (!data || data.length === 0) return 0;
    const valorStr = data[0].valor ?? "0";
    return parseFloat(valorStr.replace(",", ".")) || 0;
  } catch (e) {
    console.error(`Erro ao buscar série ${codigo}:`, e);
    return 0;
  }
};

// Função para calcular PIB acumulado 12 meses (%) usando IBC-BR (24363)
const getPib12Meses = async (): Promise<number> => {
  try {
    const response = await axios.get(
      `https://api.bcb.gov.br/dados/serie/bcdata.sgs.24363/dados?formato=json`
    );
    const data = response.data;
    if (!data || data.length < 13) return 0;

    // Último valor
    const ultimo = parseFloat(data[data.length - 1].valor.replace(",", ".")) || 0;
    const dozeMesesAtras = parseFloat(data[data.length - 13].valor.replace(",", ".")) || 0;

    if (dozeMesesAtras === 0) return 0;

    const pib12 = ((ultimo - dozeMesesAtras) / dozeMesesAtras) * 100;
    return parseFloat(pib12.toFixed(2));
  } catch (e) {
    console.error("Erro ao calcular PIB 12 meses:", e);
    return 0;
  }
};

export default async function economia(
  req: NextApiRequest,
  res: NextApiResponse<EconomicoResponse>
) {
  try {
    const [selic, pib, cambio] = await Promise.all([
      getUltimoValor(432),    // Selic
      getPib12Meses(),        // PIB 12 meses
      getUltimoValor(1),  // Dólar PTAX venda
    ]);

    res.status(200).json({
      selic: parseFloat(selic.toFixed(2)),
      pib,
      cambio: parseFloat(cambio.toFixed(2)),
    });
  } catch (error) {
    console.error("Erro ao buscar dados econômicos:", error);
    res.status(500).json({ selic: 0, pib: 0, cambio: 0 });
  }
}
