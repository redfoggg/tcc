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
transformações descritas abaixo. Os dados brutos originais não são
versionados neste repositório, e este repositório não inclui o código de
processamento: `data/curated/anp_2025_*` é entrada acadêmica estática e
versionada, não o resultado de um pipeline reproduzível. Atualizá-la para um
ano futuro exige repetir manualmente esse processo a partir das fontes acima.

O script `data/scripts/download_anp_sources.py` permite baixar novamente os
quatro arquivos brutos originais a partir das fontes da ANP listadas acima,
salvando-os em `data/original/` (`python3 data/scripts/download_anp_sources.py`).
Ele não realiza nenhum processamento; apenas reproduz a etapa de aquisição
descrita nesta seção. A flag `--force` re-baixa um arquivo mesmo que ele já
exista no destino, e `--only <nome>` restringe o download a uma única fonte
(`processamento`, `producao_gasolina_a`, `vendas_combustiveis` ou
`capacidade_refino`).

## Valores observados, derivados e hipotéticos

Cada linha curada carrega um valor de `provenance` (ou `*_provenance` por
coluna) que declara exatamente como foi obtido. Três categorias amplas:

- **Observado**: retirado diretamente de um arquivo de origem da ANP, sem
  modificação além de filtragem que preserva unidades (`observed`,
  `observed_positive_yield`). Cobre o processamento bruto mensal de petróleo,
  a produção de gasolina A por refinaria e as vendas de gasolina C.
- **Derivado**: calculado a partir de dados observados usando uma conversão
  ou uma premissa externa, portanto nunca é, ele mesmo, um valor reportado
  pela ANP. Cobre o proxy de demanda e a capacidade de refino em metros
  cúbicos e a capacidade teórica de gasolina A (veja as transformações
  abaixo). O piso operacional é um caso especial: é derivado como o mínimo
  entre vários valores de produção mensal diretamente observados de uma
  refinaria, portanto é uma estatística calculada, não um valor publicado
  diretamente pela ANP.
- **Simulado**: o rendimento de gasolina A por refinaria-mês (`R_{i,t}`) não
  é observado nem derivado de nenhum CSV curado. É sorteado em tempo de
  execução, uma vez por execução anual do Planejado 2025, de uma distribuição
  uniforme calibrada a partir dos dados observados (veja a seção abaixo).
- **Hipotético**: valores que existem apenas dentro de uma execução anual
  planejada disparada pelo painel (estoque inicial customizado, ajuste de
  demanda ou substituição do piso operacional, aplicados a toda a execução de
  janeiro a dezembro). Esses valores nunca sobrescrevem nem se misturam com o
  artefato Histórico 2025.

## Transformações de dados

### Rendimento simulado `R_{i,t}`

O modelo planejado não usa mais um rendimento de referência fixo derivado da
razão anual observada de cada refinaria. Em vez disso, para cada execução do
Planejado 2025, o painel sorteia um rendimento simulado de gasolina A
independente para cada refinaria e cada mês:

```
R_{i,t} ~ Uniforme(0.20, 0.25)
```

O intervalo `[0.20, 0.25]` é calibrado a partir dos dados agregados
observados no Brasil, hoje diretamente sustentado pelos dados de 2025 deste
repositório. A razão nacional ponderada de gasolina A por petróleo
processado em 2025, somando as 13 refinarias do escopo fixo
(`sum_i sum_t gasolina_a_m3_{i,t} / sum_i sum_t petroleo_processado_m3_{i,t}`,
somando todos os 156 pares refinaria-mês presentes nos CSVs curados, sem
nenhuma exclusão), fica em `0,250164`, ou seja, centralmente dentro do
intervalo escolhido, não perto do topo. Essa mesma soma sobre as 13
refinarias é próxima, mas não idêntica, da razão nacional ponderada de
`0,248352` usada anteriormente neste repositório como
`NATIONAL_FALLBACK` (ver `anp_2025_reference_yields_by_refinery.csv`, hoje
removido). A pequena diferença entre `0,250164` e `0,248352` vem
inteiramente do escopo do denominador: `0,250164` soma as 13 refinarias do
escopo fixo, incluindo a LUBNOR e a REAM, enquanto `0,248352` somava apenas
as 11 refinarias com razão local válida, excluindo a LUBNOR (que não teve
produção observada de gasolina A em 2025) e a REAM (cuja razão local
ultrapassa 1 porque vários meses reportam `total_processado_m3 = 0` junto
com produção positiva de gasolina A, um problema conhecido de qualidade de
dado). Os dois números são legítimos para o respectivo escopo que descrevem
e ambos são consistentes com a calibração de `[0.20, 0.25]`, não uma
evidência contra ela. As razões mensais observadas por refinaria individual
(antes descritas em
`data/curated/anp_2025_derivative_yields_by_refinery_monthly.csv`) variam
muito mais entre refinarias, algumas bem abaixo e algumas acima de
`[0.20, 0.25]`, refletindo diferenças de escopo, mix de produto e qualidade
do dado mensal por refinaria. `[0.20, 0.25]` foi escolhido como uma faixa
plausível em torno do patamar agregado nacional, não como o intervalo exato
de mínimo e máximo observado por refinaria em cada mês.

A distribuição uniforme dentro desse intervalo é uma premissa de modelagem,
não uma distribuição de probabilidade oficial por refinaria: nenhuma
distribuição de probabilidade do rendimento de gasolina A por refinaria é
publicada pela ANP ou por qualquer fonte oficial consultada. `R_{i,t}` é,
portanto, um rendimento simulado de gasolina A para fins de simulação,
sorteado independentemente para cada par refinaria-mês, não um máximo de
engenharia comprovado observado daquela refinaria.

O sorteio acontece uma única vez por execução anual, ao construir a
execução (`GasolineSimulator.Scenarios.YieldSampling.draw/1`), e o mesmo
valor sorteado é reutilizado em ambas as etapas do solver e em toda a
renderização de resultado e exportação daquela execução. Uma nova execução
sorteia novos valores de forma independente, portanto tende a produzir
alocações e FUT diferentes da execução anterior. Não há controle de semente,
reprodutibilidade nem gerenciamento determinístico de cenário.

`data/curated/anp_2025_derivative_yields_by_refinery_monthly.csv` permanece
como evidência histórica do rendimento observado de gasolina A por
refinaria-mês em 2025, usada apenas para calibrar o intervalo acima. Ela não
alimenta o planejamento e nenhum valor dela é lido em tempo de execução pelo
código deste repositório.

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
não corrigida por este modelo: quando o rendimento simulado `R_{i,t}`
sorteado para uma refinaria em um mês fica abaixo da média nacional fixada
nessa fórmula, a capacidade teórica de gasolina A daquela refinaria naquele
mês tende a ficar subestimada em relação ao processamento de petróleo
implícito pela alocação planejada, o que pode produzir um FUT Total
agregado acima de 100% no modelo planejado. Veja `docs/model_specification.md`
para a discussão desse efeito sobre o FUT.

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
  nacional em vez do rendimento simulado sorteado para aquele mês. Essa
  limitação pode fazer o FUT Total planejado ultrapassar 100%, como descrito
  acima.
- O piso operacional é a menor produção mensal observada de gasolina A de uma
  refinaria ao longo de 2025. Ele não distingue uma taxa mínima de operação
  genuína de um mês afetado por uma parada ou evento de manutenção não
  relacionado.
- O escopo de refinarias é fixo à lista do `estudo_tcc.typ`. Refinarias
  independentes fora dessa lista são excluídas do modelo mesmo que apareçam
  na série bruta da ANP.
- O rendimento simulado `R_{i,t}` é sorteado de uma distribuição uniforme
  em `[0.20, 0.25]`, calibrada a partir do agregado nacional, e não reflete a
  razão local individual observada de cada refinaria, que varia bem mais
  entre refinarias como LUBNOR e REAM.
- `data/curated/anp_2025_*` é entrada acadêmica estática para 2025.
  `data/scripts/download_anp_sources.py` automatiza apenas o download dos
  quatro arquivos brutos originais; não há automação da regeneração dos CSVs
  curados a partir desses arquivos neste repositório.
