# Análise da bateria `20261021T045244Z`

Semente `865221133`. Rodar a bateria com a mesma semente reproduz estes números.

Cada cenário tem 10 execuções. Média ± desvio padrão (dp) resume as execuções. IC 95% é o intervalo de confiança de 95% da média, pela distribuição t de Student. Mm³ são milhões de m³ e p.p. são pontos percentuais.

## Resultado anual por cenário

Média ± desvio padrão das execuções. A cobertura nacional compara a produção do ano, menos as perdas no transporte, com a demanda do país. A cobertura efetiva soma o que cada região teve no ano (refinação própria e chegadas, menos o que enviou), até a demanda dela, e divide pela demanda do país. Gasolina parada numa região não cobre outra.

| Cenário | Execuções | Cobertura nacional (%) | Cobertura efetiva (%) | IC 95% da efetiva | Déficit nacional (Mm³) | Produção (Mm³) | FUT (%) | Perdas (Mm³) |
|---|---|---|---|---|---|---|---|---|
| rendimento_minimo | 10 | 83,24 ± 0,07 | 83,21 ± 0,07 | 83,16 a 83,26 | 5,60 ± 0,02 | 27,91 ± 0,00 | 100,0 ± 0,0 | 0,074 ± 0,025 |
| paradas_produtivas | 10 | 92,76 ± 0,74 | 92,69 ± 0,74 | 92,16 a 93,22 | 2,42 ± 0,25 | 31,17 ± 0,24 | 98,7 ± 0,3 | 0,147 ± 0,022 |
| referencia | 10 | 99,01 ± 0,41 | 98,87 ± 0,57 | 98,47 a 99,28 | 0,33 ± 0,14 | 33,28 ± 0,13 | 98,3 ± 0,4 | 0,169 ± 0,019 |
| choque_demanda | 10 | 88,04 ± 0,21 | 88,02 ± 0,21 | 87,87 a 88,17 | 4,60 ± 0,08 | 33,96 ± 0,09 | 100,0 ± 0,0 | 0,099 ± 0,022 |
| demanda_mensal | 10 | 93,91 ± 1,35 | 93,87 ± 1,35 | 92,90 a 94,84 | 2,20 ± 0,52 | 33,96 ± 0,09 | 100,0 ± 0,0 | 0,145 ± 0,023 |
| manutencao_escalonada | 10 | 90,98 ± 0,67 | 90,92 ± 0,66 | 90,45 a 91,39 | 3,02 ± 0,23 | 30,55 ± 0,23 | 99,0 ± 0,6 | 0,121 ± 0,017 |
| falha_alta_remessa | 10 | 98,50 ± 0,30 | 83,02 ± 0,12 | 82,93 a 83,10 | 0,50 ± 0,10 | 32,95 ± 0,10 | 97,5 ± 0,1 | 0,013 ± 0,002 |
| rotas_bloqueadas | 10 | 98,50 ± 0,47 | 98,23 ± 0,66 | 97,75 a 98,70 | 0,50 ± 0,16 | 33,11 ± 0,16 | 97,8 ± 0,4 | 0,165 ± 0,018 |
| mobilidade_fut | 10 | 89,84 ± 6,05 | 89,78 ± 5,99 | 85,50 a 94,06 | 3,40 ± 2,02 | 30,15 ± 2,07 | 89,0 ± 6,0 | 0,105 ± 0,054 |

## Efeito contra a referência

Δ é a média do cenário menos a média da referência. O asterisco marca p < 0,05 no teste t de Welch, que compara médias com variâncias diferentes. O valor p e o intervalo de 95% da diferença estão em `scenario_vs_reference.csv`.

| Cenário | Δ cobertura nacional (p.p.) | Δ cobertura efetiva (p.p.) | Δ déficit nacional (Mm³) | Δ produção (Mm³) | Δ FUT (p.p.) |
|---|---|---|---|---|---|
| rendimento_minimo | -15,77 * | -15,66 * | 5,27 * | -5,37 * | 1,7 * |
| paradas_produtivas | -6,25 * | -6,18 * | 2,09 * | -2,11 * | 0,4 * |
| choque_demanda | -10,97 * | -10,85 * | 4,27 * | 0,68 * | 1,7 * |
| demanda_mensal | -5,10 * | -5,00 * | 1,87 * | 0,68 * | 1,7 * |
| manutencao_escalonada | -8,03 * | -7,95 * | 2,69 * | -2,73 * | 0,8 * |
| falha_alta_remessa | -0,51 * | -15,85 * | 0,17 * | -0,33 * | -0,8 * |
| rotas_bloqueadas | -0,51 * | -0,64 * | 0,17 * | -0,17 * | -0,4 * |
| mobilidade_fut | -9,17 * | -9,09 * | 3,07 * | -3,13 * | -9,3 * |

## Referência contra o Histórico 2025

Saldo é produção menos demanda.

| Indicador | Histórico | Referência |
|---|---|---|
| Produção (Mm³) | 28,25 | 33,28 ± 0,13 |
| Demanda (Mm³) | 33,44 | 33,44 ± 0,00 |
| Saldo (Mm³) | -5,19 | -0,16 ± 0,13 |
| FUT (%) | 82,8 | 98,3 ± 0,4 |

## Cobertura do Histórico 2025 com as mesmas simplificações

A demanda de cada região é a fatia populacional da demanda do país, pelo Censo 2022, com o Centro-Oeste somado ao Sudeste, como no modelo. A cobertura nacional do Histórico é a produção observada sobre a demanda, sem perdas, porque o Histórico não tem comboios. A parte que faltou foi coberta por importação e estoque, que ficam fora do modelo.

A cobertura efetiva do Histórico é um intervalo, e não um valor único, porque a ANP informa quanto cada refinaria produziu, mas não quanta gasolina foi levada de uma região para outra. Na simulação, cada comboio é registrado, então a cobertura efetiva sai exata. O menor valor supõe que nenhuma região mandou gasolina para outra, e a sobra do Sul e do Sudeste ficou parada. O maior supõe que toda a sobra chegou onde faltava, e por isso é igual à cobertura nacional. O valor real de 2025 está entre os dois. Esse intervalo não é um intervalo de confiança: ele não vem da variação dos sorteios, e sim da falta de dado sobre o transporte, então não diminui com mais execuções.

| Indicador | Histórico | Referência |
|---|---|---|
| Cobertura nacional (%) | 84,47 | 99,01 ± 0,41 |
| Cobertura efetiva (%) | 75,77 a 84,47 | 98,87 ± 0,57 |

Autossuficiência é a produção das refinarias da região dividida pela demanda dela. A cobertura efetiva da referência inclui as chegadas de comboio.

| Região | Produção histórica (Mm³) | Demanda (Mm³) | Autossuficiência histórica (%) | Autossuficiência na referência (%) | Cobertura efetiva na referência (%) |
|---|---|---|---|---|---|
| Norte | 0,34 | 2,86 | 11,9 | 24,0 ± 0,2 | 96,9 ± 2,5 |
| Nordeste | 3,42 | 9,00 | 37,9 | 60,7 ± 0,4 | 96,9 ± 2,7 |
| Sudeste | 17,74 | 16,65 | 106,5 | 117,2 ± 0,4 | 100,0 ± 0,1 |
| Sul | 6,76 | 4,93 | 137,0 | 154,4 ± 1,4 | 100,0 ± 0,0 |

## Fechamento diário

A falta do dia é a soma do que cada região não cobriu naquele dia, com tanque, produção e chegadas. Ela mede quando a gasolina não estava na região certa, mesmo que o ano feche coberto.

| Cenário | Dias com falta | Maior falta diária (m³) | Falta no percentil 95 (m³) | Maior sequência (dias) | Falta diária somada (Mm³) |
|---|---|---|---|---|---|
| rendimento_minimo | 365 ± 0 | 28.663 ± 584 | 28.304 ± 58 | 365 ± 0 | 5,615 ± 0,025 |
| paradas_produtivas | 193 ± 17 | 32.007 ± 4.188 | 26.659 ± 3.772 | 98 ± 13 | 2,447 ± 0,244 |
| referencia | 108 ± 18 | 15.980 ± 1.977 | 6.562 ± 2.329 | 12 ± 7 | 0,393 ± 0,197 |
| choque_demanda | 365 ± 1 | 34.435 ± 1.183 | 26.561 ± 1.267 | 329 ± 77 | 4,608 ± 0,081 |
| demanda_mensal | 271 ± 58 | 27.511 ± 4.829 | 20.166 ± 4.077 | 112 ± 50 | 2,215 ± 0,520 |
| manutencao_escalonada | 328 ± 20 | 27.873 ± 1.446 | 20.035 ± 2.573 | 132 ± 43 | 3,037 ± 0,219 |
| falha_alta_remessa | 365 ± 0 | 24.317 ± 129 | 20.473 ± 266 | 365 ± 0 | 5,679 ± 0,040 |
| rotas_bloqueadas | 123 ± 26 | 16.245 ± 1.610 | 8.652 ± 1.997 | 22 ± 9 | 0,625 ± 0,228 |
| mobilidade_fut | 312 ± 91 | 28.222 ± 5.868 | 21.023 ± 6.138 | 215 ± 146 | 3,420 ± 1,998 |

## Mobilidade do FUT por teto

Cada execução de `mobilidade_fut` tem um teto de FUT, então as execuções não são repetições e a média da tabela anual mistura tetos diferentes. Aqui cada linha é uma execução. Δ é a cobertura efetiva da execução menos a da execução de mesmo número da referência, que tem teto de 100% e as mesmas taxas de falha.

| Teto (%) | FUT (%) | Produção (Mm³) | Cobertura efetiva (%) | Δ cobertura efetiva (p.p.) | Déficit nacional (Mm³) | Dias com falta | Falta diária somada (Mm³) |
|---|---|---|---|---|---|---|---|
| 80 | 80,0 | 27,02 | 80,68 | -18,48 | 6,46 | 365 | 6,461 |
| 82 | 82,0 | 27,78 | 82,86 | -16,35 | 5,73 | 365 | 5,733 |
| 84 | 84,0 | 28,34 | 84,62 | -14,71 | 5,14 | 365 | 5,144 |
| 86 | 86,0 | 29,30 | 87,29 | -11,88 | 4,25 | 365 | 4,252 |
| 88 | 88,0 | 29,80 | 88,84 | -10,08 | 3,72 | 364 | 3,732 |
| 90 | 90,0 | 30,53 | 90,97 | -8,21 | 3,01 | 356 | 3,021 |
| 92 | 92,0 | 31,13 | 92,64 | -6,35 | 2,45 | 347 | 2,462 |
| 94 | 94,0 | 31,82 | 94,59 | -3,07 | 1,80 | 282 | 1,810 |
| 96 | 96,0 | 32,62 | 97,03 | -2,08 | 0,98 | 209 | 0,993 |
| 98 | 97,7 | 33,18 | 98,31 | 0,29 | 0,45 | 99 | 0,593 |

## FUT mensal (%)

Média das execuções. FUT é a carga da destilação sobre a capacidade.

| Mês | rendimento_minimo | paradas_produtivas | referencia | choque_demanda | demanda_mensal | manutencao_escalonada | falha_alta_remessa | rotas_bloqueadas | mobilidade_fut |
|---|---|---|---|---|---|---|---|---|---|
| 2025-01 | 99,8 | 97,6 | 97,6 | 100,0 | 100,0 | 99,2 | 97,5 | 97,6 | 88,9 |
| 2025-02 | 100,0 | 97,7 | 97,7 | 100,0 | 100,0 | 97,2 | 97,6 | 97,7 | 89,0 |
| 2025-03 | 100,0 | 97,6 | 97,7 | 100,0 | 100,0 | 95,4 | 97,4 | 97,6 | 89,0 |
| 2025-04 | 100,0 | 97,6 | 97,4 | 100,0 | 100,0 | 98,9 | 97,3 | 97,4 | 88,9 |
| 2025-05 | 100,0 | 98,2 | 97,4 | 100,0 | 100,0 | 98,6 | 97,4 | 97,4 | 88,9 |
| 2025-06 | 100,0 | 98,4 | 97,6 | 100,0 | 100,0 | 99,6 | 97,4 | 97,4 | 89,0 |
| 2025-07 | 100,0 | 98,3 | 98,0 | 100,0 | 100,0 | 100,0 | 97,4 | 97,3 | 89,0 |
| 2025-08 | 100,0 | 99,7 | 98,6 | 100,0 | 100,0 | 99,9 | 97,4 | 97,5 | 89,0 |
| 2025-09 | 100,0 | 99,9 | 99,0 | 100,0 | 100,0 | 100,0 | 97,5 | 98,0 | 89,0 |
| 2025-10 | 100,0 | 100,0 | 99,7 | 100,0 | 100,0 | 100,0 | 97,4 | 98,5 | 89,0 |
| 2025-11 | 100,0 | 100,0 | 99,4 | 100,0 | 100,0 | 100,0 | 97,5 | 99,1 | 89,0 |
| 2025-12 | 100,0 | 99,9 | 99,2 | 100,0 | 100,0 | 100,0 | 97,6 | 98,4 | 88,9 |

## Cobertura efetiva por região (%)

Quanto da demanda de cada região foi servido no ano, com a refinação dela e as chegadas de comboio. Média ± desvio padrão das execuções.

| Cenário | Norte | Nordeste | Sudeste | Sul |
|---|---|---|---|---|
| rendimento_minimo | 28,8 ± 2,5 | 69,0 ± 1,0 | 95,2 ± 0,0 | 100,0 ± 0,0 |
| paradas_produtivas | 78,5 ± 4,2 | 85,3 ± 4,2 | 97,6 ± 3,1 | 97,9 ± 2,8 |
| referencia | 96,9 ± 2,5 | 96,9 ± 2,7 | 100,0 ± 0,1 | 100,0 ± 0,0 |
| choque_demanda | 33,7 ± 3,2 | 79,2 ± 1,0 | 98,6 ± 0,1 | 100,0 ± 0,0 |
| demanda_mensal | 66,3 ± 11,0 | 89,0 ± 2,0 | 99,4 ± 0,3 | 100,0 ± 0,0 |
| manutencao_escalonada | 51,5 ± 3,6 | 88,3 ± 1,1 | 97,5 ± 0,5 | 96,3 ± 1,3 |
| falha_alta_remessa | 24,9 ± 0,1 | 60,8 ± 0,5 | 100,0 ± 0,0 | 100,0 ± 0,0 |
| rotas_bloqueadas | 97,8 ± 4,8 | 94,3 ± 3,3 | 99,9 ± 0,1 | 100,0 ± 0,0 |
| mobilidade_fut | 49,4 ± 27,6 | 81,3 ± 10,8 | 98,3 ± 1,9 | 100,0 ± 0,0 |

## Autossuficiência por região (%)

Produção das refinarias da região dividida pela demanda da região, antes dos comboios. Abaixo de 100% a região depende de outras.

| Cenário | Norte | Nordeste | Sudeste | Sul |
|---|---|---|---|---|
| rendimento_minimo | 24,8 ± 0,0 | 44,5 ± 0,0 | 95,3 ± 0,0 | 148,7 ± 0,0 |
| paradas_produtivas | 24,3 ± 0,2 | 52,3 ± 7,5 | 111,0 ± 5,5 | 147,7 ± 11,8 |
| referencia | 24,0 ± 0,2 | 60,7 ± 0,4 | 117,2 ± 0,4 | 154,4 ± 1,4 |
| choque_demanda | 21,6 ± 0,0 | 52,8 ± 0,4 | 103,7 ± 0,3 | 139,8 ± 0,2 |
| demanda_mensal | 23,0 ± 0,3 | 56,4 ± 0,7 | 110,8 ± 1,7 | 149,3 ± 2,2 |
| manutencao_escalonada | 22,3 ± 0,7 | 55,6 ± 0,3 | 107,3 ± 1,4 | 142,8 ± 4,0 |
| falha_alta_remessa | 24,8 ± 0,0 | 60,7 ± 0,4 | 116,1 ± 0,5 | 150,9 ± 0,3 |
| rotas_bloqueadas | 23,7 ± 0,3 | 60,7 ± 0,4 | 116,7 ± 0,6 | 152,7 ± 1,5 |
| mobilidade_fut | 22,0 ± 1,5 | 53,9 ± 3,7 | 106,0 ± 7,3 | 142,5 ± 9,8 |

## Refinarias na referência

Dias no teto conta os dias com FUT de pelo menos 99,5%.

| Refinaria | Produção (Mm³) | Participação (%) | FUT (%) | Dias no teto | Dias fora do modelo |
|---|---|---|---|---|---|
| REAM | 0,686 ± 0,007 | 2,1 ± 0,0 | 96,9 ± 0,9 | 172,3 ± 56,7 | 0,0 ± 0,0 |
| RECAP | 1,259 ± 0,012 | 3,8 ± 0,0 | 96,2 ± 0,9 | 132,7 ± 52,8 | 0,0 ± 0,0 |
| REDUC | 2,758 ± 0,023 | 8,3 ± 0,1 | 100,0 ± 0,0 | 364,0 ± 0,0 | 0,0 ± 0,0 |
| REFAP | 3,530 ± 0,037 | 10,6 ± 0,1 | 96,2 ± 0,9 | 130,5 ± 51,9 | 0,0 ± 0,0 |
| REFMAT | 5,003 ± 0,036 | 15,0 ± 0,1 | 100,0 ± 0,0 | 364,9 ± 0,3 | 0,0 ± 0,0 |
| REGAP | 2,514 ± 0,023 | 7,6 ± 0,1 | 96,6 ± 0,7 | 138,4 ± 47,6 | 0,0 ± 0,0 |
| REPAR | 4,083 ± 0,036 | 12,3 ± 0,1 | 96,1 ± 0,9 | 128,8 ± 51,5 | 0,0 ± 0,0 |
| REPLAN | 6,599 ± 0,028 | 19,8 ± 0,1 | 98,3 ± 0,3 | 246,3 ± 21,6 | 0,0 ± 0,0 |
| REVAP | 3,557 ± 0,040 | 10,7 ± 0,1 | 100,0 ± 0,0 | 362,7 ± 1,5 | 0,0 ± 0,0 |
| RPBC | 2,832 ± 0,023 | 8,5 ± 0,1 | 97,1 ± 0,6 | 173,5 ± 39,2 | 0,0 ± 0,0 |
| RPCC | 0,460 ± 0,013 | 1,4 ± 0,0 | 100,0 ± 0,1 | 363,7 ± 3,1 | 0,0 ± 0,0 |

