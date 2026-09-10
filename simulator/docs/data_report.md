# Relatório de dados

Como os CSVs em `data/curated/` foram obtidos e o que cada um contém.
Conversões e limitações: `docs/data_transformations.md`.

## Fontes ANP

| Série | URL |
|---|---|
| Processamento de petróleo | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/pppd/processamento-petroleo-m3-1990-2025.csv` |
| Produção de gasolina A | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/pppd/producao-derivados-petroleo-por-refinaria-m3-1990-2025.csv` |
| Vendas de combustíveis | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/vdpb/vendas-derivados-petroleo-e-etanol/vendas-combustiveis-m3-1990-2025.csv` |
| Capacidade de refino (Anuário 2026, t2-35) | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/publicacoes/anuario-estatistico/arquivos-anuario-estatistico-2026/secao-2/t2-35.xlsx` |

Os quatro arquivos foram baixados uma vez e filtrados para 2025. Os brutos
não são versionados. `data/scripts/download_anp_sources.py` só baixa de novo
para `data/original/`. Não regenera os CSVs curados. Flags: `--force` e
`--only`.

## Arquivos curados

| Arquivo | Uso |
|---|---|
| `anp_2025_demand_proxy_national_monthly.csv` | $D_t^{\text{base}}$ |
| `anp_2025_refinery_capacity_monthly.csv` | $K^P$ no Planejado. $K^G$ curada não é lida como teto |
| `anp_2025_gasoline_a_production_by_refinery_monthly.csv` | Evidência e Histórico |
| `anp_2025_derivative_yields_by_refinery_monthly.csv` | Calibração do intervalo de $R$ |
| `historical_2025_summary.json` | Painel Histórico 2025 |

O planejamento não lê o CSV de rendimentos derivados. O sorteio diário
usa os rendimentos mensais válidos de cada refinaria, da produção de
gasolina A e do processamento observado.

## Categorias

- Observado: processamento, produção de gasolina A e vendas de gasolina C
- Derivado: proxy de demanda e capacidades em m³
- Simulado: $R_{i,d}$
- Hipotético: estoque inicial e ajuste de demanda

Colunas `*_provenance` viajam com os CSVs. O `Repository` não revalida esse
vocabulário.

## Fora de escopo

LUBNOR não entra no catálogo nem nos CSVs curados do modelo. É refinaria
de lubrificantes e asfalto. Em 2025 a ANP registra 0 m³ de gasolina A.
O Histórico e o Planejado usam as outras 12 plantas do catálogo. Os
brutos da ANP em `data/original/` ainda listam a planta. O
`Repository` também ignora qualquer código fora do catálogo.

`logistics_data.csv` e `logistics_data_only_gasoline_2025.csv` são preço
médio de distribuição. Nenhum código os lê. Vendas regionais e totais
nacionais de capacidade ou rendimento não foram curados.
