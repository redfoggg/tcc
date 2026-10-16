# Análise da bateria `20261016T054238Z`

Cada cenário tem 10 execuções. Média ± desvio padrão (dp) resume as execuções. IC 95% é o intervalo de confiança de 95% da média, pela distribuição t de Student. Mm³ são milhões de m³ e p.p. são pontos percentuais.

## Resultado anual por cenário

Média ± desvio padrão das execuções. A cobertura nacional compara a produção do ano, menos as perdas no transporte, com a demanda do país. A cobertura efetiva soma o que cada região teve no ano (refinação própria e chegadas, menos o que enviou), até a demanda dela, e divide pela demanda do país. Gasolina parada numa região não cobre outra.

| Cenário | Execuções | Cobertura nacional (%) | Cobertura efetiva (%) | IC 95% da efetiva | Déficit nacional (Mm³) | Produção (Mm³) | FUT (%) | Perdas (Mm³) |
|---|---|---|---|---|---|---|---|---|
| rendimento_minimo | 10 | 83,31 ± 0,09 | 83,28 ± 0,09 | 83,21 a 83,34 | 5,58 ± 0,03 | 27,92 ± 0,00 | 100,0 ± 0,0 | 0,060 ± 0,030 |
| paradas_produtivas | 10 | 92,85 ± 1,64 | 92,77 ± 1,64 | 91,60 a 93,95 | 2,39 ± 0,55 | 31,17 ± 0,56 | 96,8 ± 1,1 | 0,118 ± 0,026 |
| referencia | 10 | 99,91 ± 0,16 | 99,40 ± 0,10 | 99,33 a 99,46 | 0,03 ± 0,05 | 33,64 ± 0,14 | 97,2 ± 0,1 | 0,148 ± 0,024 |
| choque_demanda | 10 | 89,97 ± 0,16 | 89,94 ± 0,16 | 89,83 a 90,06 | 3,86 ± 0,06 | 34,70 ± 0,06 | 99,7 ± 0,0 | 0,091 ± 0,018 |
| demanda_mensal | 10 | 94,83 ± 1,00 | 94,79 ± 0,98 | 94,09 a 95,49 | 1,85 ± 0,38 | 34,04 ± 0,11 | 98,2 ± 0,3 | 0,120 ± 0,015 |
| manutencao_escalonada | 10 | 91,34 ± 0,50 | 91,29 ± 0,49 | 90,94 a 91,64 | 2,90 ± 0,17 | 30,64 ± 0,16 | 96,6 ± 0,5 | 0,098 ± 0,014 |
| falha_alta_remessa | 10 | 100,00 ± 0,00 | 85,54 ± 0,18 | 85,41 a 85,68 | 0,00 ± 0,00 | 33,70 ± 0,10 | 97,2 ± 0,0 | 0,016 ± 0,004 |
| rotas_bloqueadas | 10 | 99,96 ± 0,10 | 99,39 ± 0,08 | 99,33 a 99,45 | 0,01 ± 0,03 | 33,68 ± 0,10 | 97,2 ± 0,1 | 0,150 ± 0,023 |
| campanha_estavel | 10 | 98,82 ± 1,58 | 98,38 ± 1,31 | 97,44 a 99,31 | 0,39 ± 0,53 | 33,88 ± 1,30 | 96,7 ± 0,6 | 0,123 ± 0,035 |
| mobilidade_fut | 10 | 100,00 ± 0,00 | 99,37 ± 0,29 | 99,17 a 99,58 | 0,00 ± 0,00 | 36,58 ± 0,53 | 95,4 ± 1,2 | 0,077 ± 0,011 |

## Efeito contra a referência

Δ é a média do cenário menos a média da referência. O asterisco marca p < 0,05 no teste t de Welch, que compara médias com variâncias diferentes. O valor p e o intervalo de 95% da diferença estão em `scenario_vs_reference.csv`.

| Cenário | Δ cobertura nacional (p.p.) | Δ cobertura efetiva (p.p.) | Δ déficit nacional (Mm³) | Δ produção (Mm³) | Δ FUT (p.p.) |
|---|---|---|---|---|---|
| rendimento_minimo | -16,60 * | -16,12 * | 5,55 * | -5,72 * | 2,8 * |
| paradas_produtivas | -7,06 * | -6,62 * | 2,36 * | -2,47 * | -0,4 |
| choque_demanda | -9,93 * | -9,45 * | 3,83 * | 1,05 * | 2,6 * |
| demanda_mensal | -5,07 * | -4,61 * | 1,82 * | 0,39 * | 1,0 * |
| manutencao_escalonada | -8,57 * | -8,11 * | 2,87 * | -3,00 * | -0,5 * |
| falha_alta_remessa | 0,09 | -13,85 * | -0,03 | 0,05 | 0,1 * |
| rotas_bloqueadas | 0,05 | -0,01 | -0,02 | 0,03 | 0,0 |
| campanha_estavel | -1,08 | -1,02 * | 0,36 | 0,24 | -0,5 * |
| mobilidade_fut | 0,09 | -0,02 | -0,03 | 2,94 * | -1,7 * |

## Referência contra o Histórico 2025

Saldo é produção menos demanda.

| Indicador | Histórico | Referência |
|---|---|---|
| Produção (Mm³) | 28,27 | 33,64 ± 0,14 |
| Demanda (Mm³) | 33,44 | 33,44 ± 0,00 |
| Saldo (Mm³) | -5,17 | 0,20 ± 0,14 |
| FUT (%) | 82,1 | 97,2 ± 0,1 |

## Cobertura do Histórico 2025 com as mesmas simplificações

A demanda de cada região é a fatia populacional da demanda do país, pelo Censo 2022, com o Centro-Oeste somado ao Sudeste, como no modelo. A cobertura nacional do Histórico é a produção observada sobre a demanda, sem perdas, porque o Histórico não tem comboios. A parte que faltou foi coberta por importação e estoque, que ficam fora do modelo. Os dados não dizem quanta gasolina passou de uma região para outra, então a cobertura efetiva do Histórico é um intervalo. O menor valor supõe que nenhuma região mandou gasolina para outra. O maior supõe que toda a sobra chegou onde faltava, e por isso é igual à cobertura nacional.

| Indicador | Histórico | Referência |
|---|---|---|
| Cobertura nacional (%) | 84,54 | 99,91 ± 0,16 |
| Cobertura efetiva (%) | 75,84 a 84,54 | 99,40 ± 0,10 |

Autossuficiência é a produção das refinarias da região dividida pela demanda dela. A cobertura efetiva da referência inclui as chegadas de comboio.

| Região | Produção histórica (Mm³) | Demanda (Mm³) | Autossuficiência histórica (%) | Autossuficiência na referência (%) | Cobertura efetiva na referência (%) |
|---|---|---|---|---|---|
| Norte | 0,34 | 2,86 | 11,9 | 23,6 ± 0,1 | 96,2 ± 2,3 |
| Nordeste | 3,44 | 9,00 | 38,2 | 70,1 ± 1,0 | 99,0 ± 0,8 |
| Sudeste | 17,74 | 16,65 | 106,5 | 115,3 ± 0,3 | 100,0 ± 0,0 |
| Sul | 6,76 | 4,93 | 137,0 | 151,0 ± 0,4 | 100,0 ± 0,0 |

## Fechamento diário

A falta do dia é a soma do que cada região não cobriu naquele dia, com tanque, produção e chegadas. Ela mede quando a gasolina não estava na região certa, mesmo que o ano feche coberto.

| Cenário | Dias com falta | Maior falta diária (m³) | Falta no percentil 95 (m³) | Maior sequência (dias) | Falta diária somada (Mm³) |
|---|---|---|---|---|---|
| rendimento_minimo | 365 ± 0 | 28.567 ± 517 | 28.255 ± 51 | 365 ± 0 | 5,593 ± 0,029 |
| paradas_produtivas | 236 ± 47 | 30.756 ± 5.229 | 23.741 ± 3.431 | 106 ± 16 | 2,418 ± 0,550 |
| referencia | 96 ± 8 | 16.417 ± 2.223 | 4.469 ± 1.345 | 9 ± 5 | 0,229 ± 0,037 |
| choque_demanda | 362 ± 2 | 33.126 ± 1.584 | 23.577 ± 1.098 | 201 ± 90 | 3,869 ± 0,062 |
| demanda_mensal | 265 ± 33 | 27.780 ± 6.796 | 17.684 ± 3.586 | 68 ± 26 | 1,867 ± 0,375 |
| manutencao_escalonada | 345 ± 13 | 28.869 ± 5.698 | 20.149 ± 4.651 | 136 ± 49 | 2,914 ± 0,163 |
| falha_alta_remessa | 365 ± 0 | 23.926 ± 462 | 19.150 ± 354 | 365 ± 0 | 4,835 ± 0,061 |
| rotas_bloqueadas | 90 ± 15 | 15.078 ± 2.167 | 4.792 ± 1.123 | 11 ± 12 | 0,234 ± 0,037 |
| campanha_estavel | 187 ± 104 | 11.204 ± 3.651 | 6.931 ± 4.418 | 51 ± 53 | 0,549 ± 0,433 |
| mobilidade_fut | 104 ± 21 | 6.395 ± 541 | 3.371 ± 2.100 | 14 ± 6 | 0,211 ± 0,099 |

## FUT mensal (%)

Média das execuções. FUT é a carga da destilação sobre a capacidade.

| Mês | rendimento_minimo | paradas_produtivas | referencia | choque_demanda | demanda_mensal | manutencao_escalonada | falha_alta_remessa | rotas_bloqueadas | campanha_estavel | mobilidade_fut |
|---|---|---|---|---|---|---|---|---|---|---|
| 2025-01 | 99,9 | 97,8 | 97,2 | 99,8 | 98,1 | 98,2 | 97,3 | 97,2 | 96,6 | 95,1 |
| 2025-02 | 100,0 | 98,2 | 97,1 | 99,6 | 97,9 | 97,3 | 97,2 | 97,1 | 96,6 | 95,4 |
| 2025-03 | 100,0 | 98,4 | 97,1 | 98,8 | 97,5 | 96,0 | 97,2 | 97,1 | 96,6 | 95,3 |
| 2025-04 | 100,0 | 97,6 | 97,1 | 100,0 | 98,3 | 98,5 | 97,2 | 97,1 | 96,5 | 95,5 |
| 2025-05 | 100,0 | 96,1 | 97,1 | 99,8 | 97,7 | 96,1 | 97,2 | 97,2 | 96,5 | 95,4 |
| 2025-06 | 100,0 | 95,7 | 97,2 | 99,9 | 97,6 | 96,5 | 97,2 | 97,2 | 96,5 | 95,4 |
| 2025-07 | 100,0 | 96,6 | 97,1 | 100,0 | 98,7 | 98,2 | 97,2 | 97,2 | 96,5 | 95,5 |
| 2025-08 | 100,0 | 95,0 | 97,2 | 99,0 | 97,4 | 93,8 | 97,3 | 97,1 | 96,5 | 95,4 |
| 2025-09 | 100,0 | 95,7 | 97,1 | 99,9 | 98,2 | 98,4 | 97,3 | 97,2 | 96,5 | 95,5 |
| 2025-10 | 100,0 | 96,7 | 97,2 | 100,0 | 98,9 | 95,8 | 97,3 | 97,2 | 96,8 | 95,6 |
| 2025-11 | 100,0 | 96,0 | 97,1 | 99,7 | 97,7 | 92,4 | 97,2 | 97,2 | 96,5 | 95,4 |
| 2025-12 | 100,0 | 99,3 | 97,2 | 100,0 | 99,8 | 99,8 | 97,2 | 97,2 | 97,9 | 95,5 |

## Cobertura efetiva por região (%)

Quanto da demanda de cada região foi servido no ano, com a refinação dela e as chegadas de comboio. Média ± desvio padrão das execuções.

| Cenário | Norte | Nordeste | Sudeste | Sul |
|---|---|---|---|---|
| rendimento_minimo | 27,6 ± 2,9 | 69,6 ± 1,2 | 95,2 ± 0,0 | 100,0 ± 0,0 |
| paradas_produtivas | 73,3 ± 5,2 | 86,0 ± 2,0 | 98,4 ± 2,3 | 97,3 ± 2,5 |
| referencia | 96,2 ± 2,3 | 99,0 ± 0,8 | 100,0 ± 0,0 | 100,0 ± 0,0 |
| choque_demanda | 54,5 ± 1,3 | 79,6 ± 0,5 | 98,7 ± 0,1 | 100,0 ± 0,0 |
| demanda_mensal | 75,9 ± 3,8 | 89,4 ± 2,2 | 99,4 ± 0,3 | 100,0 ± 0,0 |
| manutencao_escalonada | 62,8 ± 3,3 | 86,2 ± 0,7 | 97,2 ± 0,7 | 97,1 ± 0,8 |
| falha_alta_remessa | 24,9 ± 0,1 | 70,1 ± 0,7 | 100,0 ± 0,0 | 100,0 ± 0,0 |
| rotas_bloqueadas | 95,9 ± 2,8 | 99,0 ± 0,9 | 100,0 ± 0,0 | 100,0 ± 0,0 |
| campanha_estavel | 90,0 ± 5,5 | 97,2 ± 3,6 | 100,0 ± 0,1 | 100,0 ± 0,0 |
| mobilidade_fut | 92,7 ± 3,4 | 100,0 ± 0,0 | 100,0 ± 0,0 | 100,0 ± 0,0 |

## Autossuficiência por região (%)

Produção das refinarias da região dividida pela demanda da região, antes dos comboios. Abaixo de 100% a região depende de outras.

| Cenário | Norte | Nordeste | Sudeste | Sul |
|---|---|---|---|---|
| rendimento_minimo | 24,8 ± 0,0 | 44,6 ± 0,0 | 95,3 ± 0,0 | 148,7 ± 0,0 |
| paradas_produtivas | 24,2 ± 0,2 | 60,0 ± 6,8 | 110,0 ± 7,2 | 137,1 ± 14,7 |
| referencia | 23,6 ± 0,1 | 70,1 ± 1,0 | 115,3 ± 0,3 | 151,0 ± 0,4 |
| choque_demanda | 21,6 ± 0,0 | 60,6 ± 0,5 | 103,5 ± 0,2 | 139,1 ± 0,3 |
| demanda_mensal | 22,7 ± 0,2 | 65,4 ± 1,1 | 109,1 ± 1,2 | 144,6 ± 1,0 |
| manutencao_escalonada | 22,5 ± 0,1 | 63,6 ± 0,8 | 104,5 ± 1,3 | 139,5 ± 3,4 |
| falha_alta_remessa | 24,8 ± 0,0 | 70,1 ± 0,7 | 115,5 ± 0,3 | 151,1 ± 0,5 |
| rotas_bloqueadas | 23,6 ± 0,1 | 70,1 ± 0,5 | 115,6 ± 0,5 | 150,9 ± 0,4 |
| campanha_estavel | 24,3 ± 0,6 | 74,8 ± 14,9 | 113,9 ± 4,9 | 151,8 ± 7,9 |
| mobilidade_fut | 24,8 ± 0,0 | 97,0 ± 2,0 | 119,8 ± 0,8 | 145,7 ± 5,1 |

## Refinarias na referência

Dias no teto conta os dias com FUT de pelo menos 99,5%.

| Refinaria | Produção (Mm³) | Participação (%) | FUT (%) | Dias no teto | Dias fora do modelo |
|---|---|---|---|---|---|
| REAM | 0,675 ± 0,003 | 2,0 ± 0,0 | 95,2 ± 0,4 | 73,8 ± 21,4 | 0,0 ± 0,0 |
| RECAP | 1,232 ± 0,003 | 3,7 ± 0,0 | 94,0 ± 0,0 | 1,5 ± 0,7 | 0,0 ± 0,0 |
| REDUC | 2,749 ± 0,027 | 8,2 ± 0,1 | 100,0 ± 0,0 | 364,0 ± 0,0 | 0,0 ± 0,0 |
| REFAP | 3,450 ± 0,019 | 10,3 ± 0,0 | 94,0 ± 0,0 | 1,5 ± 0,7 | 0,0 ± 0,0 |
| REFMAT | 5,010 ± 0,057 | 14,9 ± 0,1 | 100,0 ± 0,0 | 364,4 ± 1,1 | 0,0 ± 0,0 |
| REGAP | 2,451 ± 0,006 | 7,3 ± 0,0 | 94,2 ± 0,0 | 2,0 ± 0,9 | 0,0 ± 0,0 |
| REPAR | 3,995 ± 0,006 | 11,9 ± 0,0 | 94,0 ± 0,0 | 1,5 ± 0,7 | 0,0 ± 0,0 |
| REPLAN | 6,454 ± 0,025 | 19,2 ± 0,1 | 96,2 ± 0,3 | 104,2 ± 16,3 | 0,0 ± 0,0 |
| REVAP | 3,548 ± 0,023 | 10,5 ± 0,1 | 100,0 ± 0,0 | 362,7 ± 1,2 | 0,0 ± 0,0 |
| RNEST | 0,839 ± 0,054 | 2,5 ± 0,2 | 100,0 ± 0,0 | 364,8 ± 0,4 | 0,0 ± 0,0 |
| RPBC | 2,776 ± 0,010 | 8,3 ± 0,0 | 94,9 ± 0,2 | 42,5 ± 9,4 | 0,0 ± 0,0 |
| RPCC | 0,464 ± 0,016 | 1,4 ± 0,0 | 100,0 ± 0,0 | 364,8 ± 0,4 | 0,0 ± 0,0 |

