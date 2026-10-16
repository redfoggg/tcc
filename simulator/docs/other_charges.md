# Outras cargas

A coluna `OUTRAS CARGAS` de
`data/original/processamento-petroleo-m3-1990-2025.csv` é a carga da
destilação atmosférica que não é petróleo nacional nem importado. O
modelo reserva esse volume na capacidade da refinaria e o tira do
denominador do rendimento de gasolina A.

## Definição da ANP

A ANP (Agência Nacional do Petróleo, Gás Natural e Biocombustíveis)
separa a carga das unidades de destilação primária em três origens:

- Petróleo nacional: petróleo, condensado e C5+, a fração de
  hidrocarbonetos com cinco carbonos ou mais.
- Petróleo importado: petróleo e condensado.
- Outras cargas: resíduos de petróleo, resíduos de terminais e resíduos
  de derivados, reprocessados junto com o petróleo.

O CSV (arquivo de valores separados por vírgula) público não separa os
três tipos de resíduo. A produção de gasolina A também não vem por
matéria-prima.

Fontes:

- Metadados da tabela 2.30 do Anuário 2022, notas 1 a 3: `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/anuario-estatistico-2022/metadados/cap-2/anuario-abertos-metadados-tabela2-30.pdf`
- Metadados da tabela 2.28 do Anuário 2019, nota 2: `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/anuario-estatistico-2019/secao-2/anuario-2019-abertos-metadados-tabela2-28.pdf`
- Seção 2 do Anuário 2021: `https://www.gov.br/anp/pt-br/centrais-de-conteudo/publicacoes/anuario-estatistico/arquivos-anuario-estatistico-2021/textos/secao2-novo.pdf`
- Série aberta usada no projeto: `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/pppd/processamento-petroleo-m3-1990-2025.csv`
- Manual do i-SIMP (Sistema de Informações de Movimentação de Produtos da ANP), operação 1022008, que soma petróleo e outras cargas na destilação primária sem abrir a composição: `https://csa.anp.gov.br/downloads/manuais-isimp/MANUAL-DO-I-SIMP-REFINO.pdf`

## Conferência

O Anuário 2021 registra 45,8 mil barris por dia de outras cargas em
2020, ou 2,6% da carga do parque. O CSV do repositório soma 2.664.832 m³
nessa categoria em 2020. Com o fator da ANP de 0,158987 m³ por barril e
366 dias, isso dá 45.796 barris por dia, ou 2,59%.

Nas 12 refinarias do catálogo, em 2025, outras cargas são 2,11% da carga
atmosférica, 2,38 milhões de m³. O peso muda por planta: a REAM fica
perto de 22%, REFAP e RNEST perto de 6%, e REPLAN, REPAR e REVAP perto de
1% ou abaixo.

## FUT do trabalho

O indicador do modelo é o FUT (fator de utilização total) da Petrobras:
toda a carga das unidades de destilação, com petróleo, C5+, resíduos e
reprocessamentos, inclusive de terminais, dividida pela capacidade de
referência. A definição está no Relatório de Produção e Vendas da
Petrobras. Somar as três origens da ANP dá esse numerador. O
`utilized_throughput_m3` curado já fazia essa soma, então o FUT
histórico de 82,12% nas 12 refinarias já estava certo. O FUE (fator de
utilização efetivo) da ANP, carga efetiva sobre capacidade nominal no
painel regulatório, é outro dado.

## Uso no modelo

$O_{i,d}$ são as outras cargas observadas da refinaria $i$ no mês,
divididas pelos dias do mês, em m³ por dia. $K^P_{i,d}$ é a capacidade
nominal de processamento no dia. O rendimento sorteado usa só petróleo:

$$
R_{i,\text{mês}} = \frac{\text{gasolina A}}{\text{petróleo nacional} + \text{petróleo importado}}
$$

O petróleo da campanha, $P_{i,d}$, ocupa o que sobra da capacidade:

$$
\max\!\left(\rho^{\min}_{i,d} K^P_{i,d} - O_{i,d},\ 0\right) \le P_{i,d} \le K^P_{i,d} - O_{i,d}
$$

$\rho^{\min}_{i,d}$ é o piso de FUT da planta no dia, explicado em
`docs/model_specification.md`. O FUT fica

$$
\text{FUT}_{i,d} = 100 \times \frac{P_{i,d} + O_{i,d}}{K^P_{i,d}}
$$

O Histórico usa a mesma razão de somas, com a carga observada no
numerador. `data/scripts/curate_other_charges.py` grava o corte em
`anp_2025_refinery_capacity_monthly.csv` e os volumes em
`historical_2025_summary.json`.
