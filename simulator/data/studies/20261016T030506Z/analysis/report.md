# Análise da bateria `20261016T030506Z`

Cada cenário tem até 10 execuções. Média ± desvio padrão (dp) resume as execuções. IC 95% é o intervalo de confiança de 95% da média, pela distribuição t de Student. Mm³ são milhões de m³ e p.p. são pontos percentuais.

## Resultado anual por cenário

Média ± desvio padrão das execuções.

| Cenário | Execuções ok | Cobertura (%) | IC 95% da cobertura | Déficit (Mm³) | Produção (Mm³) | FUT (%) | Perdas (Mm³) | Execuções com 100% |
|---|---|---|---|---|---|---|---|---|
| rendimento_minimo | 10/10 | 83,42 ± 0,00 | 83,42 a 83,42 | 5,55 ± 0,00 | 27,92 ± 0,00 | 100,0 ± 0,0 | 0,024 ± 0,001 | 0/10 |
| paradas_produtivas | 10/10 | 93,50 ± 1,79 | 92,22 a 94,78 | 2,17 ± 0,60 | 31,31 ± 0,60 | 97,0 ± 0,9 | 0,036 ± 0,006 | 0/10 |
| referencia | 10/10 | 99,97 ± 0,05 | 99,94 a 100,01 | 0,01 ± 0,02 | 33,64 ± 0,10 | 97,2 ± 0,0 | 0,146 ± 0,017 | 5/10 |
| choque_demanda | 10/10 | 90,09 ± 0,19 | 89,95 a 90,23 | 3,81 ± 0,07 | 34,68 ± 0,07 | 99,7 ± 0,1 | 0,032 ± 0,001 | 0/10 |
| demanda_mensal | 10/10 | 95,08 ± 0,67 | 94,60 a 95,56 | 1,76 ± 0,26 | 34,04 ± 0,12 | 98,1 ± 0,2 | 0,041 ± 0,002 | 0/10 |
| manutencao_escalonada | 10/10 | 91,75 ± 0,59 | 91,33 a 92,17 | 2,76 ± 0,20 | 30,72 ± 0,20 | 96,7 ± 0,5 | 0,034 ± 0,002 | 0/10 |
| falha_alta_remessa | 10/10 | 100,00 ± 0,00 | 100,00 a 100,00 | 0,00 ± 0,00 | 33,67 ± 0,14 | 97,3 ± 0,1 | 0,017 ± 0,005 | 10/10 |
| rotas_bloqueadas | 10/10 | 100,00 ± 0,00 | 100,00 a 100,00 | 0,00 ± 0,00 | 33,64 ± 0,10 | 97,2 ± 0,0 | 0,049 ± 0,001 | 10/10 |
| campanha_estavel | 10/10 | 97,51 ± 2,52 | 95,71 a 99,31 | 0,83 ± 0,84 | 33,23 ± 1,62 | 97,0 ± 0,6 | 0,045 ± 0,006 | 4/10 |
| mobilidade_fut | 10/10 | 96,14 ± 1,28 | 95,23 a 97,06 | 1,29 ± 0,43 | 32,20 ± 0,43 | 95,1 ± 1,0 | 0,043 ± 0,004 | 0/10 |

## Efeito contra a referência

Δ é a média do cenário menos a média da referência. O asterisco marca diferença cujo intervalo de confiança de 95% (teste de Welch) não inclui zero.

| Cenário | Δ cobertura (p.p.) | Δ déficit (Mm³) | Δ produção (Mm³) | Δ FUT (p.p.) |
|---|---|---|---|---|
| rendimento_minimo | -16,55 * | 5,54 * | -5,72 * | 2,8 * |
| paradas_produtivas | -6,47 * | 2,16 * | -2,34 * | -0,2 |
| choque_demanda | -9,88 * | 3,80 * | 1,04 * | 2,5 * |
| demanda_mensal | -4,89 * | 1,75 * | 0,40 * | 1,0 * |
| manutencao_escalonada | -8,22 * | 2,75 * | -2,92 * | -0,5 * |
| falha_alta_remessa | 0,03 | -0,01 | 0,02 | 0,1 * |
| rotas_bloqueadas | 0,03 | -0,01 | -0,01 | 0,0 |
| campanha_estavel | -2,46 * | 0,82 * | -0,41 | -0,2 |
| mobilidade_fut | -3,83 * | 1,28 * | -1,45 * | -2,1 * |

## Referência contra o Histórico 2025

Saldo é produção menos demanda.

| Indicador | Histórico | Referência |
|---|---|---|
| Produção (Mm³) | 28,27 | 33,64 ± 0,10 |
| Demanda (Mm³) | 33,44 | 33,44 ± 0,00 |
| Saldo (Mm³) | -5,17 | 0,20 ± 0,10 |
| FUT (%) | 82,1 | 97,2 ± 0,0 |

## Fechamento diário

A falta do dia é a soma do que cada região não cobriu naquele dia, com tanque, produção e chegadas. Ela mede quando a gasolina não estava na região certa, mesmo que o ano feche coberto.

| Cenário | Dias com falta | Maior falta diária (m³) | Falta no percentil 95 (m³) | Maior sequência (dias) | Falta diária somada (Mm³) |
|---|---|---|---|---|---|
| rendimento_minimo | 365 ± 0 | 28.299 ± 25 | 28.195 ± 7 | 365 ± 0 | 5,558 ± 0,001 |
| paradas_produtivas | 201 ± 50 | 31.767 ± 5.126 | 23.989 ± 5.122 | 112 ± 26 | 2,202 ± 0,592 |
| referencia | 91 ± 20 | 16.303 ± 1.424 | 4.242 ± 1.411 | 10 ± 4 | 0,235 ± 0,043 |
| choque_demanda | 361 ± 2 | 34.895 ± 1.781 | 24.262 ± 1.087 | 163 ± 30 | 3,823 ± 0,074 |
| demanda_mensal | 259 ± 33 | 26.349 ± 4.821 | 16.826 ± 3.012 | 69 ± 26 | 1,779 ± 0,256 |
| manutencao_escalonada | 334 ± 22 | 29.100 ± 4.579 | 18.870 ± 2.610 | 118 ± 27 | 2,779 ± 0,192 |
| falha_alta_remessa | 365 ± 0 | 23.634 ± 746 | 18.921 ± 320 | 365 ± 0 | 4,813 ± 0,089 |
| rotas_bloqueadas | 80 ± 21 | 14.616 ± 1.523 | 2.697 ± 1.851 | 11 ± 15 | 0,146 ± 0,056 |
| campanha_estavel | 236 ± 122 | 13.523 ± 2.225 | 8.765 ± 6.614 | 138 ± 146 | 0,890 ± 0,797 |
| mobilidade_fut | 323 ± 61 | 14.237 ± 0 | 11.007 ± 12 | 205 ± 87 | 1,310 ± 0,428 |

## FUT mensal (%)

Média das execuções. FUT é a carga da destilação sobre a capacidade.

| Mês | rendimento_minimo | paradas_produtivas | referencia | choque_demanda | demanda_mensal | manutencao_escalonada | falha_alta_remessa | rotas_bloqueadas | campanha_estavel | mobilidade_fut |
|---|---|---|---|---|---|---|---|---|---|---|
| 2025-01 | 99,9 | 97,5 | 97,2 | 99,6 | 98,1 | 98,7 | 97,3 | 97,2 | 96,7 | 94,5 |
| 2025-02 | 100,0 | 97,7 | 97,2 | 99,3 | 98,0 | 97,3 | 97,3 | 97,2 | 96,6 | 94,1 |
| 2025-03 | 100,0 | 97,9 | 97,1 | 98,8 | 97,3 | 93,9 | 97,3 | 97,2 | 96,6 | 94,1 |
| 2025-04 | 100,0 | 97,7 | 97,1 | 100,0 | 97,6 | 97,4 | 97,3 | 97,2 | 97,0 | 95,1 |
| 2025-05 | 100,0 | 97,1 | 97,1 | 99,7 | 97,7 | 94,3 | 97,3 | 97,1 | 96,6 | 94,2 |
| 2025-06 | 100,0 | 96,6 | 97,3 | 99,7 | 97,7 | 98,1 | 97,3 | 97,2 | 96,7 | 94,3 |
| 2025-07 | 100,0 | 96,9 | 97,1 | 100,0 | 98,0 | 95,8 | 97,2 | 97,2 | 97,0 | 95,1 |
| 2025-08 | 100,0 | 95,7 | 97,1 | 99,1 | 98,0 | 93,4 | 97,2 | 97,1 | 96,6 | 94,1 |
| 2025-09 | 100,0 | 96,8 | 97,2 | 100,0 | 98,3 | 98,5 | 97,2 | 97,1 | 97,0 | 95,0 |
| 2025-10 | 100,0 | 96,2 | 97,1 | 100,0 | 99,0 | 98,1 | 97,2 | 97,1 | 97,6 | 96,2 |
| 2025-11 | 100,0 | 95,5 | 97,1 | 99,9 | 97,8 | 96,6 | 97,2 | 97,2 | 96,6 | 94,2 |
| 2025-12 | 100,0 | 99,5 | 97,3 | 100,0 | 99,8 | 99,9 | 97,3 | 97,2 | 98,6 | 100,0 |

## Autossuficiência por região (%)

Produção das refinarias da região dividida pela demanda da região, antes dos comboios. Abaixo de 100% a região depende de outras.

| Cenário | Norte | Nordeste | Sudeste | Sul |
|---|---|---|---|---|
| rendimento_minimo | 24,8 ± 0,0 | 44,6 ± 0,0 | 95,3 ± 0,0 | 148,7 ± 0,0 |
| paradas_produtivas | 24,1 ± 0,2 | 64,7 ± 7,1 | 108,4 ± 4,5 | 136,7 ± 11,7 |
| referencia | 23,6 ± 0,1 | 70,2 ± 0,9 | 115,3 ± 0,2 | 151,0 ± 0,2 |
| choque_demanda | 21,5 ± 0,0 | 60,9 ± 0,6 | 103,3 ± 0,3 | 138,9 ± 0,3 |
| demanda_mensal | 22,7 ± 0,2 | 65,4 ± 0,8 | 109,2 ± 0,9 | 144,4 ± 1,0 |
| manutencao_escalonada | 22,3 ± 0,4 | 64,0 ± 0,7 | 104,8 ± 1,3 | 139,2 ± 3,3 |
| falha_alta_remessa | 24,8 ± 0,0 | 70,3 ± 1,0 | 115,3 ± 0,4 | 150,8 ± 0,3 |
| rotas_bloqueadas | 23,6 ± 0,1 | 70,0 ± 0,6 | 115,3 ± 0,5 | 151,1 ± 0,2 |
| campanha_estavel | 24,4 ± 0,5 | 65,1 ± 8,4 | 115,8 ± 7,8 | 150,0 ± 5,8 |
| mobilidade_fut | 24,4 ± 0,3 | 62,5 ± 0,1 | 113,2 ± 1,7 | 142,5 ± 3,1 |

## Refinarias na referência

Dias no teto conta os dias com FUT de pelo menos 99,5%.

| Refinaria | Produção (Mm³) | Participação (%) | FUT (%) | Dias no teto | Dias fora do modelo |
|---|---|---|---|---|---|
| REAM | 0,674 ± 0,004 | 2,0 ± 0,0 | 95,1 ± 0,5 | 64,3 ± 30,5 | 0,0 ± 0,0 |
| RECAP | 1,233 ± 0,006 | 3,7 ± 0,0 | 94,0 ± 0,0 | 1,7 ± 0,9 | 0,0 ± 0,0 |
| REDUC | 2,755 ± 0,014 | 8,2 ± 0,1 | 100,0 ± 0,0 | 364,0 ± 0,0 | 0,0 ± 0,0 |
| REFAP | 3,453 ± 0,007 | 10,3 ± 0,0 | 94,0 ± 0,0 | 1,7 ± 0,9 | 0,0 ± 0,0 |
| REFMAT | 5,010 ± 0,056 | 14,9 ± 0,1 | 100,0 ± 0,0 | 364,6 ± 1,0 | 0,0 ± 0,0 |
| REGAP | 2,454 ± 0,006 | 7,3 ± 0,0 | 94,3 ± 0,1 | 2,7 ± 1,3 | 0,0 ± 0,0 |
| REPAR | 3,994 ± 0,010 | 11,9 ± 0,0 | 94,0 ± 0,0 | 1,7 ± 0,9 | 0,0 ± 0,0 |
| REPLAN | 6,463 ± 0,021 | 19,2 ± 0,1 | 96,2 ± 0,3 | 109,6 ± 16,8 | 0,0 ± 0,0 |
| REVAP | 3,535 ± 0,031 | 10,5 ± 0,1 | 100,0 ± 0,0 | 363,1 ± 1,9 | 0,0 ± 0,0 |
| RNEST | 0,842 ± 0,049 | 2,5 ± 0,1 | 100,0 ± 0,0 | 364,9 ± 0,3 | 0,0 ± 0,0 |
| RPBC | 2,769 ± 0,012 | 8,2 ± 0,0 | 94,9 ± 0,2 | 45,7 ± 10,6 | 0,0 ± 0,0 |
| RPCC | 0,463 ± 0,022 | 1,4 ± 0,1 | 100,0 ± 0,0 | 364,8 ± 0,6 | 0,0 ± 0,0 |

