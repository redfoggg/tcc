# Outras cargas

A coluna `OUTRAS CARGAS` de `data/original/processamento-petroleo-m3-1990-2025.csv`
é a carga da destilação atmosférica que não é petróleo nacional nem
importado. O modelo reserva esse volume na placa e tira ele do
denominador do rendimento de gasolina A.

## Definição da ANP

No anuário, a carga processada nas unidades de destilação primária separa
três origens: petróleo nacional, petróleo importado e outras cargas.
Petróleo nacional inclui petróleo, condensado e C5+. Petróleo importado
inclui petróleo e condensado. Outras cargas incluem resíduos de petróleo,
resíduos de terminais e resíduos de derivados reprocessados na destilação
atmosférica junto com petróleo e condensado.

Fontes:

- Metadados da tabela 2.30 do Anuário 2022, notas 1 a 3: `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/anuario-estatistico-2022/metadados/cap-2/anuario-abertos-metadados-tabela2-30.pdf`
- Metadados da tabela 2.28 do Anuário 2019, nota 2: `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/anuario-estatistico-2019/secao-2/anuario-2019-abertos-metadados-tabela2-28.pdf`
- Seção 2 do Anuário 2021: `https://www.gov.br/anp/pt-br/centrais-de-conteudo/publicacoes/anuario-estatistico/arquivos-anuario-estatistico-2021/textos/secao2-novo.pdf`
- Série aberta usada no projeto: `https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/arquivos/pppd/processamento-petroleo-m3-1990-2025.csv`
- Manual do i-SIMP, operação 1022008 (soma de petróleo e outras cargas na destilação primária, sem abrir a composição): `https://csa.anp.gov.br/downloads/manuais-isimp/MANUAL-DO-I-SIMP-REFINO.pdf`

O CSV público não separa resíduo de petróleo, resíduo de terminal e
resíduo de derivado. A produção de gasolina A também não vem por
matéria-prima.

## Conferência de 2020

O Anuário 2021 registra 45,8 mil barris/dia de outras cargas em 2020
(2,6% da carga do parque). O CSV do repositório soma 2.664.832 m³ nessa
categoria. Com o fator ANP de 0,158987 m³/barril e 366 dias, o volume vira
45.796 barris/dia (2,59%).

Nas 12 refinarias do catálogo, em 2025, outras cargas são 2,11% da carga
atmosférica (2,38 milhões de m³). O peso muda por planta. REAM fica perto
de 22%. REFAP e RNEST ficam perto de 6%. REPLAN, REPAR e REVAP ficam perto
de 1% ou abaixo.

## FUT do trabalho

O indicador do modelo é o fator de utilização total da Petrobras: o
percentual de uso do parque em relação à carga de referência, com toda a
carga das unidades de destilação (petróleo, C5+, resíduos,
reprocessamentos, inclusive de terminais). A nota está no Relatório de
Produção e Vendas da Petrobras.

A série da ANP é a observação dessa carga, não o indicador a reproduzir.
Petróleo nacional já traz C5+. Outras cargas trazem resíduos, resíduos de
terminais e resíduos de derivados. Somar as três matérias-primas é o
numerador do FUT da Petrobras. O `utilized_throughput_m3` curado já fazia
essa soma, então o FUT histórico de 82,12% nas 12 refinarias já estava
certo. O FUE da ANP, carga efetiva sobre capacidade nominal no painel
regulatório, continua outro dado.

## Uso no modelo

$O_{i,d}$ é o volume observado de outras cargas da refinaria no mês,
dividido pelos dias do mês. $K^P$ continua a placa nominal. O rendimento
sorteado usa só petróleo:

$$
R_{i,\text{mês}} = \frac{\text{gasolina A}}{\text{petróleo nacional}+\text{importado}}
$$

A campanha de gasolina ocupa o que sobra da placa:

$$
P_{i,d} \le \rho_{i,d} K^P_{i,d} - O_{i,d}
$$

$$
P_{i,d} \ge \max(0{,}40\, K^P_{i,d} - O_{i,d},\ 0)
$$

$$
\text{FUT} = 100 \times \frac{P + O}{K^P}
$$

O histórico usa a mesma razão de somas, com a carga atmosférica observada
(petróleo mais outras cargas) no numerador. `data/scripts/curate_other_charges.py`
grava o corte em `anp_2025_refinery_capacity_monthly.csv` e os volumes em
`historical_2025_summary.json`.
