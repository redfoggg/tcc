# Análise da bateria `20261018T043254Z`

Semente `612777692`. Rodar a bateria com a mesma semente reproduz estes números.

Cada cenário tem 10 execuções. Média ± desvio padrão (dp) resume as execuções. IC 95% é o intervalo de confiança de 95% da média, pela distribuição t de Student. Mm³ são milhões de m³ e p.p. são pontos percentuais.

## Resultado anual por cenário

Média ± desvio padrão das execuções. A cobertura nacional compara a produção do ano, menos as perdas no transporte, com a demanda do país. A cobertura efetiva soma o que cada região teve no ano (refinação própria e chegadas, menos o que enviou), até a demanda dela, e divide pela demanda do país. Gasolina parada numa região não cobre outra.

| Cenário | Execuções | Cobertura nacional (%) | Cobertura efetiva (%) | IC 95% da efetiva | Déficit nacional (Mm³) | Produção (Mm³) | FUT (%) | Perdas (Mm³) |
|---|---|---|---|---|---|---|---|---|
| rendimento_minimo | 10 | 83,26 ± 0,07 | 83,23 ± 0,07 | 83,18 a 83,28 | 5,60 ± 0,02 | 27,92 ± 0,00 | 100,0 ± 0,0 | 0,075 ± 0,025 |
| paradas_produtivas | 10 | 93,34 ± 1,35 | 93,27 ± 1,35 | 92,31 a 94,23 | 2,23 ± 0,45 | 31,33 ± 0,45 | 96,9 ± 0,6 | 0,118 ± 0,027 |
| referencia | 10 | 99,93 ± 0,12 | 99,37 ± 0,10 | 99,30 a 99,44 | 0,02 ± 0,04 | 33,60 ± 0,06 | 97,1 ± 0,0 | 0,155 ± 0,027 |
| choque_demanda | 10 | 89,85 ± 0,16 | 89,82 ± 0,16 | 89,70 a 89,94 | 3,90 ± 0,06 | 34,66 ± 0,05 | 99,7 ± 0,1 | 0,098 ± 0,019 |
| demanda_mensal | 10 | 94,35 ± 0,91 | 94,30 ± 0,90 | 93,66 a 94,95 | 2,04 ± 0,35 | 34,07 ± 0,10 | 98,3 ± 0,2 | 0,125 ± 0,019 |
| manutencao_escalonada | 10 | 91,41 ± 0,49 | 91,36 ± 0,49 | 91,01 a 91,71 | 2,87 ± 0,16 | 30,68 ± 0,17 | 96,7 ± 0,5 | 0,104 ± 0,018 |
| falha_alta_remessa | 10 | 100,00 ± 0,00 | 85,41 ± 0,09 | 85,34 a 85,47 | 0,00 ± 0,00 | 33,63 ± 0,06 | 97,2 ± 0,0 | 0,016 ± 0,002 |
| rotas_bloqueadas | 10 | 99,94 ± 0,11 | 99,27 ± 0,28 | 99,07 a 99,47 | 0,02 ± 0,04 | 33,60 ± 0,06 | 97,1 ± 0,1 | 0,156 ± 0,026 |
| mobilidade_fut | 10 | 91,70 ± 5,86 | 91,66 ± 5,85 | 87,48 a 95,84 | 2,78 ± 1,96 | 30,77 ± 2,00 | 88,7 ± 5,7 | 0,103 ± 0,040 |

## Efeito contra a referência

Δ é a média do cenário menos a média da referência. O asterisco marca p < 0,05 no teste t de Welch, que compara médias com variâncias diferentes. O valor p e o intervalo de 95% da diferença estão em `scenario_vs_reference.csv`.

| Cenário | Δ cobertura nacional (p.p.) | Δ cobertura efetiva (p.p.) | Δ déficit nacional (Mm³) | Δ produção (Mm³) | Δ FUT (p.p.) |
|---|---|---|---|---|---|
| rendimento_minimo | -16,66 * | -16,14 * | 5,57 * | -5,67 * | 2,9 * |
| paradas_produtivas | -6,59 * | -6,10 * | 2,20 * | -2,26 * | -0,3 |
| choque_demanda | -10,08 * | -9,54 * | 3,88 * | 1,06 * | 2,6 * |
| demanda_mensal | -5,58 * | -5,06 * | 2,01 * | 0,48 * | 1,2 * |
| manutencao_escalonada | -8,52 * | -8,01 * | 2,85 * | -2,92 * | -0,4 * |
| falha_alta_remessa | 0,07 | -13,96 * | -0,02 | 0,03 | 0,1 * |
| rotas_bloqueadas | 0,01 | -0,09 | -0,00 | 0,00 | 0,0 |
| mobilidade_fut | -8,23 * | -7,71 * | 2,75 * | -2,83 * | -8,4 * |

## Referência contra o Histórico 2025

Saldo é produção menos demanda.

| Indicador | Histórico | Referência |
|---|---|---|
| Produção (Mm³) | 28,27 | 33,60 ± 0,06 |
| Demanda (Mm³) | 33,44 | 33,44 ± 0,00 |
| Saldo (Mm³) | -5,17 | 0,15 ± 0,06 |
| FUT (%) | 82,1 | 97,1 ± 0,0 |

## Cobertura do Histórico 2025 com as mesmas simplificações

A demanda de cada região é a fatia populacional da demanda do país, pelo Censo 2022, com o Centro-Oeste somado ao Sudeste, como no modelo. A cobertura nacional do Histórico é a produção observada sobre a demanda, sem perdas, porque o Histórico não tem comboios. A parte que faltou foi coberta por importação e estoque, que ficam fora do modelo.

A cobertura efetiva do Histórico é um intervalo, e não um valor único, porque a ANP informa quanto cada refinaria produziu, mas não quanta gasolina foi levada de uma região para outra. Na simulação, cada comboio é registrado, então a cobertura efetiva sai exata. O menor valor supõe que nenhuma região mandou gasolina para outra, e a sobra do Sul e do Sudeste ficou parada. O maior supõe que toda a sobra chegou onde faltava, e por isso é igual à cobertura nacional. O valor real de 2025 está entre os dois. Esse intervalo não é um intervalo de confiança: ele não vem da variação dos sorteios, e sim da falta de dado sobre o transporte, então não diminui com mais execuções.

| Indicador | Histórico | Referência |
|---|---|---|
| Cobertura nacional (%) | 84,54 | 99,93 ± 0,12 |
| Cobertura efetiva (%) | 75,84 a 84,54 | 99,37 ± 0,10 |

Autossuficiência é a produção das refinarias da região dividida pela demanda dela. A cobertura efetiva da referência inclui as chegadas de comboio.

| Região | Produção histórica (Mm³) | Demanda (Mm³) | Autossuficiência histórica (%) | Autossuficiência na referência (%) | Cobertura efetiva na referência (%) |
|---|---|---|---|---|---|
| Norte | 0,34 | 2,86 | 11,9 | 23,5 ± 0,1 | 97,3 ± 2,0 |
| Nordeste | 3,44 | 9,00 | 38,2 | 69,5 ± 0,3 | 98,5 ± 0,8 |
| Sudeste | 17,74 | 16,65 | 106,5 | 115,4 ± 0,3 | 100,0 ± 0,0 |
| Sul | 6,76 | 4,93 | 137,0 | 151,0 ± 0,4 | 100,0 ± 0,0 |

## Fechamento diário

A falta do dia é a soma do que cada região não cobriu naquele dia, com tanque, produção e chegadas. Ela mede quando a gasolina não estava na região certa, mesmo que o ano feche coberto.

| Cenário | Dias com falta | Maior falta diária (m³) | Falta no percentil 95 (m³) | Maior sequência (dias) | Falta diária somada (Mm³) |
|---|---|---|---|---|---|
| rendimento_minimo | 365 ± 0 | 28.580 ± 373 | 28.274 ± 52 | 365 ± 0 | 5,608 ± 0,025 |
| paradas_produtivas | 232 ± 43 | 28.946 ± 5.159 | 22.916 ± 4.513 | 101 ± 13 | 2,251 ± 0,450 |
| referencia | 86 ± 9 | 15.061 ± 1.434 | 4.461 ± 1.082 | 8 ± 3 | 0,237 ± 0,040 |
| choque_demanda | 362 ± 1 | 34.012 ± 1.750 | 24.074 ± 743 | 200 ± 84 | 3,914 ± 0,063 |
| demanda_mensal | 289 ± 29 | 25.695 ± 5.202 | 17.267 ± 2.980 | 68 ± 21 | 2,053 ± 0,342 |
| manutencao_escalonada | 338 ± 22 | 28.343 ± 3.459 | 19.748 ± 2.964 | 124 ± 32 | 2,890 ± 0,163 |
| falha_alta_remessa | 365 ± 0 | 23.655 ± 786 | 19.041 ± 280 | 365 ± 0 | 4,881 ± 0,029 |
| rotas_bloqueadas | 113 ± 33 | 15.061 ± 1.434 | 5.601 ± 501 | 18 ± 19 | 0,300 ± 0,103 |
| mobilidade_fut | 278 ± 114 | 27.183 ± 7.279 | 18.600 ± 6.686 | 154 ± 153 | 2,789 ± 1,955 |

## Mobilidade do FUT por teto

Cada execução de `mobilidade_fut` tem um teto de FUT, então as execuções não são repetições e a média da tabela anual mistura tetos diferentes. Aqui cada linha é uma execução. Δ é a cobertura efetiva da execução menos a da execução de mesmo número da referência, que tem teto de 100% e as mesmas taxas de falha.

| Teto (%) | FUT (%) | Produção (Mm³) | Cobertura efetiva (%) | Δ cobertura efetiva (p.p.) | Déficit nacional (Mm³) | Dias com falta | Falta diária somada (Mm³) |
|---|---|---|---|---|---|---|---|
| 80 | 80,0 | 27,61 | 82,37 | -16,92 | 5,89 | 365 | 5,897 |
| 82 | 82,0 | 28,41 | 84,79 | -14,71 | 5,08 | 365 | 5,087 |
| 84 | 84,0 | 29,07 | 86,65 | -12,58 | 4,46 | 365 | 4,464 |
| 86 | 86,0 | 29,89 | 89,09 | -10,18 | 3,64 | 362 | 3,649 |
| 88 | 88,0 | 30,51 | 90,91 | -8,41 | 3,03 | 357 | 3,039 |
| 90 | 90,0 | 31,31 | 93,32 | -6,08 | 2,22 | 317 | 2,234 |
| 92 | 92,0 | 31,96 | 95,13 | -4,25 | 1,62 | 276 | 1,628 |
| 94 | 94,0 | 32,59 | 97,06 | -2,47 | 0,97 | 196 | 0,982 |
| 96 | 95,1 | 33,03 | 98,18 | -1,13 | 0,59 | 89 | 0,608 |
| 98 | 96,2 | 33,32 | 99,10 | -0,33 | 0,27 | 86 | 0,302 |

## FUT mensal (%)

Média das execuções. FUT é a carga da destilação sobre a capacidade.

| Mês | rendimento_minimo | paradas_produtivas | referencia | choque_demanda | demanda_mensal | manutencao_escalonada | falha_alta_remessa | rotas_bloqueadas | mobilidade_fut |
|---|---|---|---|---|---|---|---|---|---|
| 2025-01 | 99,9 | 97,1 | 97,1 | 99,8 | 98,2 | 98,5 | 97,1 | 97,1 | 88,7 |
| 2025-02 | 100,0 | 97,6 | 97,2 | 99,6 | 97,5 | 96,0 | 97,2 | 97,2 | 88,7 |
| 2025-03 | 100,0 | 97,8 | 97,0 | 98,8 | 97,4 | 96,0 | 97,1 | 97,0 | 88,7 |
| 2025-04 | 100,0 | 98,1 | 97,0 | 100,0 | 98,1 | 97,8 | 97,1 | 97,0 | 88,7 |
| 2025-05 | 100,0 | 97,4 | 97,1 | 99,8 | 98,5 | 95,4 | 97,2 | 97,1 | 88,7 |
| 2025-06 | 100,0 | 96,8 | 97,2 | 99,9 | 98,2 | 95,8 | 97,3 | 97,2 | 88,7 |
| 2025-07 | 100,0 | 95,9 | 97,2 | 100,0 | 98,6 | 96,3 | 97,3 | 97,2 | 88,7 |
| 2025-08 | 100,0 | 95,4 | 97,1 | 99,0 | 97,7 | 94,6 | 97,2 | 97,1 | 88,7 |
| 2025-09 | 100,0 | 96,2 | 97,2 | 100,0 | 98,7 | 97,4 | 97,3 | 97,2 | 88,7 |
| 2025-10 | 100,0 | 96,6 | 97,2 | 100,0 | 98,8 | 98,2 | 97,3 | 97,2 | 88,7 |
| 2025-11 | 100,0 | 95,1 | 97,2 | 99,8 | 98,0 | 95,9 | 97,3 | 97,2 | 88,7 |
| 2025-12 | 100,0 | 99,7 | 97,2 | 100,0 | 99,8 | 100,0 | 97,3 | 97,2 | 88,8 |

## Cobertura efetiva por região (%)

Quanto da demanda de cada região foi servido no ano, com a refinação dela e as chegadas de comboio. Média ± desvio padrão das execuções.

| Cenário | Norte | Nordeste | Sudeste | Sul |
|---|---|---|---|---|
| rendimento_minimo | 28,7 ± 3,4 | 69,1 ± 1,3 | 95,2 ± 0,0 | 100,0 ± 0,0 |
| paradas_produtivas | 74,9 ± 4,2 | 86,3 ± 3,3 | 99,3 ± 1,4 | 96,5 ± 1,7 |
| referencia | 97,3 ± 2,0 | 98,5 ± 0,8 | 100,0 ± 0,0 | 100,0 ± 0,0 |
| choque_demanda | 55,0 ± 1,1 | 79,1 ± 0,5 | 98,5 ± 0,1 | 100,0 ± 0,0 |
| demanda_mensal | 75,2 ± 3,3 | 87,6 ± 2,1 | 99,5 ± 0,3 | 100,0 ± 0,0 |
| manutencao_escalonada | 63,7 ± 3,2 | 86,0 ± 0,7 | 97,2 ± 0,5 | 97,6 ± 0,9 |
| falha_alta_remessa | 24,9 ± 0,1 | 69,6 ± 0,3 | 100,0 ± 0,0 | 100,0 ± 0,0 |
| rotas_bloqueadas | 94,0 ± 4,6 | 99,2 ± 0,9 | 100,0 ± 0,0 | 100,0 ± 0,0 |
| mobilidade_fut | 65,3 ± 23,5 | 83,3 ± 11,0 | 98,2 ± 1,9 | 100,0 ± 0,0 |

## Autossuficiência por região (%)

Produção das refinarias da região dividida pela demanda da região, antes dos comboios. Abaixo de 100% a região depende de outras.

| Cenário | Norte | Nordeste | Sudeste | Sul |
|---|---|---|---|---|
| rendimento_minimo | 24,8 ± 0,0 | 44,6 ± 0,0 | 95,3 ± 0,0 | 148,7 ± 0,0 |
| paradas_produtivas | 24,1 ± 0,2 | 62,4 ± 7,3 | 112,1 ± 4,5 | 128,8 ± 9,1 |
| referencia | 23,5 ± 0,1 | 69,5 ± 0,3 | 115,4 ± 0,3 | 151,0 ± 0,4 |
| choque_demanda | 21,5 ± 0,0 | 60,5 ± 0,3 | 103,4 ± 0,2 | 139,1 ± 0,4 |
| demanda_mensal | 22,6 ± 0,2 | 64,6 ± 0,8 | 108,7 ± 1,0 | 144,1 ± 1,3 |
| manutencao_escalonada | 22,4 ± 0,3 | 63,6 ± 0,6 | 105,0 ± 1,1 | 138,5 ± 4,2 |
| falha_alta_remessa | 24,8 ± 0,0 | 69,5 ± 0,3 | 115,4 ± 0,3 | 151,0 ± 0,4 |
| rotas_bloqueadas | 23,7 ± 0,2 | 69,5 ± 0,3 | 115,4 ± 0,3 | 151,0 ± 0,4 |
| mobilidade_fut | 21,9 ± 1,3 | 61,7 ± 4,4 | 105,7 ± 6,9 | 141,8 ± 8,5 |

## Refinarias na referência

Dias no teto conta os dias com FUT de pelo menos 99,5%.

| Refinaria | Produção (Mm³) | Participação (%) | FUT (%) | Dias no teto | Dias fora do modelo |
|---|---|---|---|---|---|
| REAM | 0,673 ± 0,003 | 2,0 ± 0,0 | 94,9 ± 0,4 | 55,7 ± 24,1 | 0,0 ± 0,0 |
| RECAP | 1,234 ± 0,006 | 3,7 ± 0,0 | 94,0 ± 0,0 | 1,7 ± 0,7 | 0,0 ± 0,0 |
| REDUC | 2,750 ± 0,019 | 8,2 ± 0,1 | 100,0 ± 0,0 | 364,0 ± 0,0 | 0,0 ± 0,0 |
| REFAP | 3,449 ± 0,014 | 10,3 ± 0,0 | 94,0 ± 0,0 | 1,7 ± 0,7 | 0,0 ± 0,0 |
| REFMAT | 4,969 ± 0,038 | 14,8 ± 0,1 | 100,0 ± 0,0 | 365,0 ± 0,0 | 0,0 ± 0,0 |
| REGAP | 2,450 ± 0,007 | 7,3 ± 0,0 | 94,2 ± 0,1 | 2,6 ± 2,7 | 0,0 ± 0,0 |
| REPAR | 3,997 ± 0,009 | 11,9 ± 0,0 | 94,0 ± 0,0 | 1,7 ± 0,7 | 0,0 ± 0,0 |
| REPLAN | 6,453 ± 0,021 | 19,2 ± 0,0 | 96,1 ± 0,2 | 102,8 ± 15,1 | 0,0 ± 0,0 |
| REVAP | 3,558 ± 0,036 | 10,6 ± 0,1 | 100,0 ± 0,0 | 362,1 ± 2,5 | 0,0 ± 0,0 |
| RNEST | 0,822 ± 0,022 | 2,4 ± 0,1 | 100,0 ± 0,0 | 365,0 ± 0,0 | 0,0 ± 0,0 |
| RPBC | 2,772 ± 0,006 | 8,3 ± 0,0 | 94,9 ± 0,2 | 44,8 ± 8,2 | 0,0 ± 0,0 |
| RPCC | 0,469 ± 0,013 | 1,4 ± 0,0 | 100,0 ± 0,0 | 364,7 ± 0,7 | 0,0 ± 0,0 |

