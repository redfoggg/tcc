# Relatório de dados

De onde vêm os CSVs (arquivos de valores separados por vírgula) de
`data/curated/` e o que cada um contém. As conversões e as hipóteses e
simplificações do modelo, com onde pesam e por quê, estão em
`docs/data_transformations.md`.

## Fontes da ANP

ANP é a Agência Nacional do Petróleo, Gás Natural e Biocombustíveis.

| Série | URL |
|---|---|
| Processamento de petróleo | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/pppd/processamento-petroleo-m3-1990-2025.csv` |
| Produção de gasolina A | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/pppd/producao-derivados-petroleo-por-refinaria-m3-1990-2025.csv` |
| Vendas de combustíveis | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/vdpb/vendas-derivados-petroleo-e-etanol/vendas-combustiveis-m3-1990-2025.csv` |
| Capacidade de refino (Anuário 2026, tabela 2.35) | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/publicacoes/anuario-estatistico/arquivos-anuario-estatistico-2026/secao-2/t2-35.xlsx` |

Os quatro arquivos foram baixados uma vez e filtrados para 2025. Os
brutos de processamento e de produção por refinaria ficam em
`data/original/`. `data/scripts/download_anp_sources.py` só baixa de
novo para lá, com as opções `--force` e `--only`. Ele não regenera os
CSVs curados. Outras cargas, o volume que a ANP separa do petróleo na
destilação, estão em `docs/other_charges.md`.

## Arquivos curados

| Arquivo | Uso |
|---|---|
| `anp_2025_demand_proxy_national_monthly.csv` | Demanda nacional de gasolina A, $D^{\text{base}}$ |
| `anp_2025_refinery_capacity_monthly.csv` | Capacidade de processamento $K^P$, petróleo, outras cargas e rendimento médio nacional |
| `anp_2025_gasoline_a_production_by_refinery_monthly.csv` | Gasolina A produzida por refinaria e mês. Base dos rendimentos sorteados e do Histórico |
| `anp_2025_derivative_yields_by_refinery_monthly.csv` | Variação histórica de rendimento por produto. Só documentação |
| `historical_2025_summary.json` | Painel Histórico 2025 |

O rendimento sorteado de cada refinaria é a gasolina A do mês dividida
pelo petróleo do mês. O plano não usa esse sorteio nem o CSV de
rendimentos derivados. `data/scripts/curate_other_charges.py` grava o
corte entre petróleo e outras cargas.

## Categorias dos dados

| Categoria | Exemplos |
|---|---|
| Observado | Processamento, produção de gasolina A e vendas de gasolina C |
| Derivado | Demanda de gasolina A e capacidades em m³ |
| Simulado | Rendimento diário de cada refinaria |
| Hipotético | Ajuste de demanda e taxa de falha dos comboios |

As colunas `*_provenance` registram a categoria de cada valor.
`Data.Repository` não revalida esse vocabulário.

## Fora de escopo

A LUBNOR, refinaria de lubrificantes e asfalto do Nordeste, não entra no
catálogo nem nos CSVs curados. Em 2025 a ANP registra 0 m³ de gasolina A
nela. A RNEST também não entra, por ser uma refinaria de diesel
(`docs/data_transformations.md`, Escopo). Os brutos em `data/original/`
ainda listam as duas, e o `Repository`
ignora qualquer código fora do catálogo.

`logistics_data.csv` e `logistics_data_only_gasoline_2025.csv` são preço
médio de distribuição e nenhum código os lê. Vendas por região não foram
curadas. A demanda nacional é dividida pela população do Censo 2022, como
descrito em `docs/data_transformations.md`.
