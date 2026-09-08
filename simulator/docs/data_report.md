# Relatório de dados

Este relatório explica os dados por trás do modelo de alocação de gasolina A:
de onde vêm, como os CSVs curados em `data/curated/` foram construídos, quais
valores são diretamente observados, derivados ou hipotéticos, e o que está
explicitamente fora de escopo. Veja `docs/model_specification.md` para como o
modelo consome esses dados.

## Fontes oficiais da ANP

Todos os dados curados de 2025 remontam a quatro arquivos públicos publicados
pela ANP (Agência Nacional do Petróleo, Gás Natural e Biocombustíveis):

| Série | URL de origem |
|---|---|
| Processamento de petróleo (mensal, 1990-2025) | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/pppd/processamento-petroleo-m3-1990-2025.csv` |
| Produção de gasolina A por refinaria (mensal, 1990-2025) | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/pppd/producao-derivados-petroleo-por-refinaria-m3-1990-2025.csv` |
| Vendas de combustíveis (mensal, 1990-2025) | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/vdpb/vendas-derivados-petroleo-e-etanol/vendas-combustiveis-m3-1990-2025.csv` |
| Capacidade de refino (Anuário Estatístico 2026, Seção 2, Tabela 2.35) | `https://www.gov.br/anp/pt-br/centrais-de-conteudo/publicacoes/anuario-estatistico/arquivos-anuario-estatistico-2026/secao-2/t2-35.xlsx` |

## Método de aquisição

Esses quatro arquivos foram baixados uma única vez e processados nos CSVs
curados hoje versionados em `data/curated/`. Esse processamento filtrou linhas
para 2025, converteu unidades, calculou razões de rendimento e aplicou as
transformações descritas abaixo. Este repositório não inclui o código de
download ou processamento: `data/curated/anp_2025_*` é entrada acadêmica
estática e versionada, não o resultado de um pipeline reproduzível.
Atualizá-la para um ano futuro exige repetir manualmente esse processo a
partir das fontes acima.

## Valores observados, derivados e hipotéticos

Cada linha curada carrega um valor de `provenance` (ou `*_provenance` por
coluna) que declara exatamente como foi obtido. Três categorias amplas:

- **Observado**: retirado diretamente de um arquivo de origem da ANP, sem
  modificação além de filtragem que preserva unidades (`observed`,
  `observed_positive_yield`). Cobre o processamento bruto mensal de petróleo,
  a produção de gasolina A por refinaria e as vendas de gasolina C.
- **Derivado**: calculado a partir de dados observados usando uma conversão
  ou uma premissa externa, portanto nunca é, ele mesmo, um valor reportado
  pela ANP. Cobre o proxy de demanda, a capacidade de refino em metros
  cúbicos, a capacidade teórica de gasolina A e o rendimento de referência
  anual por refinaria (veja as transformações abaixo). O piso operacional é
  um caso especial: é derivado como o mínimo entre vários valores de produção
  mensal diretamente observados de uma refinaria, portanto é uma estatística
  calculada, não um valor publicado diretamente pela ANP.
- **Hipotético**: valores que existem apenas dentro de uma execução anual
  planejada disparada pelo painel (estoque inicial customizado, ajuste de
  demanda ou substituição do piso operacional, aplicados a toda a execução de
  janeiro a dezembro). Esses valores nunca sobrescrevem nem se misturam com o
  artefato Histórico 2025.

## Transformações de dados

### Rendimento de referência fixo por refinaria

O modelo planejado usa um único rendimento de referência anual por
refinaria, fixo para os doze meses de 2025, em vez de uma previsão móvel
mensal. Ele é calculado como a razão ponderada entre a soma anual observada
de produção de gasolina A e a soma anual observada de processamento de
petróleo daquela refinaria:

```
raw_ratio_i = sum_t gasolina_a_m3_{i,t} / sum_t petroleo_processado_m3_{i,t}
```

Essa razão local só é aceita como rendimento de referência (`valid_local_ratio
= true`) quando é finita, o denominador é positivo e `0 < raw_ratio_i <= 1`.
Quando a razão local não é válida, a refinaria recebe o fallback nacional
ponderado, calculado apenas a partir das refinarias cuja razão local é
válida:

```
fallback_nacional = sum_i (sum_t gasolina_a_m3_{i,t}) / sum_i (sum_t petroleo_processado_m3_{i,t})
```

somando apenas sobre as refinarias `i` com razão local válida. Duas
refinarias do escopo fixo usam o fallback nacional em 2025: LUBNOR, que não
teve produção de gasolina A observada em nenhum mês do ano
(`national_weighted_fallback_zero_local_ratio`), e REAM, cuja razão local
observada excede 1
(`national_weighted_fallback_local_ratio_exceeds_unit_interval`). O resultado
completo, incluindo os totais observados, a razão bruta, a validade da razão
local, o rendimento de referência selecionado e a proveniência de cada
refinaria, está em
`data/curated/anp_2025_reference_yields_by_refinery.csv`. A linha
`NATIONAL_FALLBACK` nesse arquivo documenta os totais agregados usados para
calcular o fallback.

Diferente do modelo anterior, o rendimento de referência não varia mês a mês
e não depende de nenhum histórico observado de meses anteriores dentro do
ano corrente: é um único valor fixo por refinaria, usado apenas para converter
a alocação planejada de gasolina A em processamento de petróleo implícito.
`data/curated/anp_2025_derivative_yields_by_refinery_monthly.csv` permanece
como evidência de origem mensal, mas não alimenta mais o planejamento.

### Proxy de demanda de gasolina C para gasolina A

As refinarias produzem gasolina A. O sinal de demanda na série de vendas da
ANP é gasolina C, o produto varejista misturado com etanol. O proxy de
demanda curado converte um no outro:

```
gasolina_a_equivalent_m3 = gasolina_c_sales_m3 * (1 - ethanol_anidro_fraction_assumed)
```

`ethanol_anidro_fraction_assumed` é a fração de mistura de etanol anidro
determinada pelo CNPE para a gasolina C comum: 0,27 até 2025-07 (Resolução
CNPE 16/2021, em vigor desde 2021-03), e 0,30 a partir de 2025-08 (Resolução
CNPE 9/2025, publicada no DOU em 2025-07-02, com vigência a partir de
2025-08-01). A gasolina Premium manteve uma mistura fixa de 25% durante todo
o ano e não é modelada separadamente, porque a série de vendas da ANP reporta
um único total "GASOLINA C" sem separação entre comum e premium. Aplicar a
fração da gasolina comum ao total inteiro é uma simplificação explícita e
documentada, por isso essa coluna é marcada como
`derived_assumption_not_observed` em vez de `observed`.

### Capacidade nominal para capacidade mensal de gasolina A

A planilha de capacidade de refino reporta uma única capacidade nominal
anual em barris por dia, referente a 2025-12-31, aplicada uniformemente a
todos os meses:

```
capacity_m3_month = nameplate_capacity_bbl_day * days_in_month * 0.158987
capacity_gasoline_a_m3_month = capacity_m3_month * national_avg_gasoline_a_yield_used
```

`0.158987` é o fator de conversão de barril para metro cúbico que a própria
ANP usa em suas publicações estatísticas. `national_avg_gasoline_a_yield_used`
é a razão de rendimento média nacional de gasolina A, não o rendimento
próprio observado daquela refinaria, portanto `capacity_gasoline_a_m3_month`
é uma estimativa teórica (`derived_theoretical_not_observed`) que pode
super ou subestimar a capacidade real de gasolina A de uma refinaria
específica. Essa é uma limitação conhecida e documentada dos dados curados,
não corrigida por este modelo: refinarias cujo rendimento de referência
próprio é bem maior que a média nacional (por exemplo RECAP e REPAR) têm sua
capacidade teórica de gasolina A subestimada por essa fórmula, o que pode
produzir um FUT Total agregado acima de 100% no modelo planejado. Veja
`docs/model_specification.md` para a discussão desse efeito sobre o FUT.

## Campos de proveniência

Os CSVs curados retêm valores de proveniência para exibição e exportação.
`GasolineSimulator.Data.Repository` confia nessas entradas estáticas e não
valida um vocabulário de proveniência em tempo de execução.

## Artefato de exibição do Histórico 2025

`data/curated/historical_2025_summary.json` é um artefato estático pronto
para exibição, pré-computado uma única vez a partir dos CSVs curados de 2025.
O Elixir em tempo de execução apenas o lê e decodifica. Ele não recalcula
totais, saldos ou FUT.

Cada linha mensal e os totais anuais contêm a produção observada de gasolina
A fornecida, o alvo estimado de demanda equivalente de gasolina A e o saldo
assinado `produção fornecida - alvo de demanda`. Saldo positivo significa
superávit e saldo negativo significa déficit. Estoque e déficit históricos
não são estimados.

O FUT Total histórico é uma razão de somas, nunca uma média aritmética das
razões individuais:

```
FUT_Total_t = 100 * sum_i processamento_observado_{i,t} / sum_i capacidade_bruta_{i,t}
FUT_Total_ano = 100 * sum_t sum_i processamento_observado_{i,t} / sum_t sum_i capacidade_bruta_{i,t}
```

somando sobre as 13 refinarias do escopo fixo, incluindo aquelas com
processamento nulo naquele mês. O FUT individual por refinaria continua
disponível apenas como diagnóstico, calculado como
`100 * processamento_observado_{i,t} / capacidade_bruta_{i,t}`, e pode
superar 100% quando o processamento observado excede a conversão de
capacidade daquele mês.

## Escopo de refinarias

O catálogo de refinarias (`lib/gasoline_simulator/catalog.ex`) e cada linha
curada por refinaria são restritos às refinarias explicitamente listadas no
`estudo_tcc.typ` da raiz do repositório, que é entrada de leitura e nunca é
modificado por este repositório:

RNEST, REFMAT (Mataripe, aliases RLAM e CEBV), RECAP, REDUC, REFAP, REGAP,
REPAR, RPBC, REPLAN, REVAP, LUBNOR, REAM (Manaus, alias REMAN) e RPCC
(Refinaria Clara Camarão).

O `estudo_tcc.typ` rotula Clara Camarão com o código "RECAP", mas esse código
já identifica a Refinaria de Capuava. O código ANP próprio de Clara Camarão é
`RPCC`, portanto o catálogo e os dados curados usam `RPCC` para essa
instalação em vez do código do texto de origem ou de qualquer rebatismo
comercial posterior.

Refinarias independentes presentes na série bruta da ANP mas fora da lista do
`estudo_tcc.typ` são excluídas de toda linha curada por refinaria: DAX OIL,
MANGUINHOS, PARANÁ XISTO, RIOGRANDENSE, SSOIL e UNIVEN.
`anp_2025_demand_proxy_national_monthly.csv` é a entrada de demanda mensal do
modelo. Agregados nacionais órfãos de produção e processamento não são
mantidos em `data/curated/`.

## Conjuntos de dados excluídos

- Os arquivos `logistics_data.csv` e `logistics_data_only_gasoline_2025.csv`
  na raiz são séries de preço médio de distribuição de combustíveis da ANP
  (`PREÇO MÉDIO DE DISTRIBUIÇÃO`), apesar do nome dos arquivos. Nunca são
  lidos por nenhum código deste repositório nem usados como entrada do
  modelo.
- Séries da ANP não necessárias pelo modelo não foram curadas em
  `data/curated/`: vendas de gasolina C por região, capacidade de refino como
  total nacional ou como um único instantâneo anual, e rendimentos de
  derivados como total nacional.

## Limitações conhecidas

- As vendas de gasolina C são um único total nacional, sem separação entre
  comum e premium. A fração de mistura obrigatória para o grau comum é
  aplicada uniformemente ao total inteiro, e essa fração é a determinação
  regulatória em vigor a cada mês, não uma razão de mistura observada
  efetivamente pelos distribuidores.
- A capacidade de refino é um único instantâneo nominal (2025-12-31) aplicado
  a todos os meses de 2025, portanto mudanças de capacidade dentro do ano não
  são capturadas, e `capacity_gasoline_a_m3_month` usa um rendimento médio
  nacional em vez do rendimento próprio de cada refinaria. Essa limitação
  pode fazer o FUT Total planejado ultrapassar 100%, como descrito acima.
- O piso operacional é a menor produção mensal observada de gasolina A de uma
  refinaria ao longo de 2025. Ele não distingue uma taxa mínima de operação
  genuína de um mês afetado por uma parada ou evento de manutenção não
  relacionado.
- O escopo de refinarias é fixo à lista do `estudo_tcc.typ`. Refinarias
  independentes fora dessa lista são excluídas do modelo mesmo que apareçam
  na série bruta da ANP.
- O rendimento de referência de LUBNOR e REAM vem do fallback nacional
  ponderado, não de uma razão local própria válida, pelas razões descritas
  acima.
- `data/curated/anp_2025_*` é entrada acadêmica estática para 2025. Não há
  automação de download ou regeneração neste repositório.
