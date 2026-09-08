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
| `anp_2025_demand_proxy_national_monthly.csv` | `D_t^{base}` |
| `anp_2025_refinery_capacity_monthly.csv` | `K^G`, `K^P` e piso |
| `anp_2025_gasoline_a_production_by_refinery_monthly.csv` | Evidência e Histórico |
| `anp_2025_derivative_yields_by_refinery_monthly.csv` | Calibração do intervalo de `R` |
| `historical_2025_summary.json` | Painel Histórico 2025 |

O planejamento não lê o CSV de rendimentos derivados. `R_{i,t}` é sorteado
em tempo de execução.

## Categorias

- Observado: processamento, produção de gasolina A e vendas de gasolina C
- Derivado: proxy de demanda, capacidades em m³ e piso mínimo de 2025
- Simulado: `R_{i,t}`
- Hipotético: estoque inicial, ajuste de demanda e piso do usuário

Colunas `*_provenance` viajam com os CSVs. O `Repository` não revalida esse
vocabulário.

## Fora de escopo

`logistics_data.csv` e `logistics_data_only_gasoline_2025.csv` são preço
médio de distribuição. Nenhum código os lê. Vendas regionais e totais
nacionais de capacidade ou rendimento não foram curados.
