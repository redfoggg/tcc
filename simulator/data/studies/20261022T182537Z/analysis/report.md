# Análise da bateria `20261022T182537Z`

Semente `657716052`. Rodar a bateria com a mesma semente reproduz estes números.

Cada cenário tem 100 execuções. Média ± desvio padrão (dp) resume as execuções. IC 95% é o intervalo de confiança de 95% da média, pela distribuição t de Student. Amostras constantes ficam sem inferência. Mm³ são milhões de m³ e p.p. são pontos percentuais.

## Resultado anual por cenário

Média ± desvio padrão das execuções. A cobertura nacional compara a produção do ano, menos as perdas no transporte, com a demanda do país. A cobertura efetiva soma o que cada região teve no ano (refinação própria e chegadas, menos o que enviou), até a demanda dela, e divide pela demanda do país. Gasolina parada numa região não cobre outra. A linha mobilidade_fut é apenas descritiva: mistura tetos e não recebe IC agregado.

| Cenário | Execuções | Cobertura nacional (%) | Cobertura efetiva (%) | IC 95% da efetiva | Déficit nacional (Mm³) | Produção (Mm³) | FUT (%) | Perdas (Mm³) |
|---|---|---|---|---|---|---|---|---|
| rendimento_minimo | 100 | 83,26 ± 0,07 | 83,23 ± 0,07 | 83,21 a 83,24 | 5,60 ± 0,02 | 27,91 ± 0,00 | 100,0 ± 0,0 | 0,068 ± 0,024 |
| paradas_produtivas | 100 | 92,38 ± 1,02 | 92,32 ± 1,02 | 92,12 a 92,52 | 2,55 ± 0,34 | 31,03 ± 0,35 | 98,8 ± 0,4 | 0,131 ± 0,029 |
| referencia | 100 | 99,16 ± 0,24 | 99,08 ± 0,28 | 99,03 a 99,14 | 0,28 ± 0,08 | 33,32 ± 0,07 | 98,4 ± 0,3 | 0,157 ± 0,032 |
| choque_demanda | 100 | 88,07 ± 0,21 | 88,05 ± 0,21 | 88,00 a 88,09 | 4,59 ± 0,08 | 33,97 ± 0,08 | 100,0 ± 0,0 | 0,092 ± 0,022 |
| demanda_mensal | 100 | 94,58 ± 1,30 | 94,54 ± 1,30 | 94,28 a 94,80 | 1,95 ± 0,49 | 33,97 ± 0,08 | 100,0 ± 0,0 | 0,135 ± 0,028 |
| manutencao_escalonada | 100 | 91,14 ± 0,55 | 91,09 ± 0,54 | 90,98 a 91,20 | 2,96 ± 0,18 | 30,60 ± 0,19 | 99,2 ± 0,5 | 0,115 ± 0,021 |
| falha_alta_remessa | 100 | 98,52 ± 0,25 | 83,06 ± 0,16 | 83,02 a 83,09 | 0,50 ± 0,08 | 32,96 ± 0,08 | 97,5 ± 0,1 | 0,013 ± 0,003 |
| rotas_bloqueadas | 100 | 98,92 ± 0,31 | 98,79 ± 0,41 | 98,70 a 98,87 | 0,36 ± 0,10 | 33,24 ± 0,10 | 98,1 ± 0,3 | 0,155 ± 0,032 |
| mobilidade_fut | 100 | 89,89 ± 5,81 | 89,86 ± 5,80 | — | 3,38 ± 1,94 | 30,16 ± 1,98 | 89,0 ± 5,7 | 0,097 ± 0,043 |

## Efeito contra a referência

Δ é a média das diferenças entre execuções de mesmo número e semente. Cada teto de FUT é comparado apenas com suas execuções correspondentes da referência. O teste principal é t pareado bilateral, sem seleção de método pelo diagnóstico de normalidade.

O asterisco marca p ajustado por Holm < 0,05 numa família única de 221 comparações planejadas (todas as 13 medidas, incluindo cada teto). NI indica inferência não estimável, inclusive diferenças constantes; nesses casos o p fica vazio. O asterisco não mede importância prática.

Os valores p brutos e ajustados, o IC 95% e os diagnósticos das diferenças estão em `scenario_vs_reference.csv`.

| Cenário / teto | Δ cobertura nacional (p.p.) | Δ cobertura efetiva (p.p.) | Δ déficit nacional (Mm³) | Δ produção (Mm³) | Δ FUT (p.p.) |
|---|---|---|---|---|---|
| rendimento_minimo | -15,90 * | -15,85 * | 5,32 * | -5,41 * | 1,6 * |
| paradas_produtivas | -6,78 * | -6,76 * | 2,27 * | -2,29 * | 0,4 * |
| choque_demanda | -11,09 * | -11,03 * | 4,31 * | 0,64 * | 1,6 * |
| demanda_mensal | -4,58 * | -4,54 * | 1,67 * | 0,64 * | 1,6 * |
| manutencao_escalonada | -8,02 * | -7,99 * | 2,68 * | -2,72 * | 0,8 * |
| falha_alta_remessa | -0,65 * | -16,03 * | 0,22 * | -0,36 * | -0,9 * |
| rotas_bloqueadas | -0,24 * | -0,30 * | 0,08 * | -0,08 * | -0,2 * |
| mobilidade_fut — teto 80% | -18,33 * | -18,27 * | 6,13 * | -6,24 * | -18,3 * |
| mobilidade_fut — teto 82% | -16,51 * | -16,46 * | 5,52 * | -5,63 * | -16,5 * |
| mobilidade_fut — teto 84% | -14,40 * | -14,35 * | 4,82 * | -4,91 * | -14,4 * |
| mobilidade_fut — teto 86% | -12,20 * | -12,15 * | 4,08 * | -4,17 * | -12,3 * |
| mobilidade_fut — teto 88% | -10,13 * | -10,08 * | 3,39 * | -3,46 * | -10,3 * |
| mobilidade_fut — teto 90% | -8,10 * | -8,00 * | 2,71 * | -2,76 * | -8,2 * |
| mobilidade_fut — teto 92% | -6,25 * | -6,21 * | 2,09 * | -2,13 * | -6,4 * |
| mobilidade_fut — teto 94% | -4,20 * | -4,16 * | 1,40 * | -1,43 * | -4,4 * |
| mobilidade_fut — teto 96% | -2,19 * | -2,15 * | 0,73 * | -0,74 * | -2,4 * |
| mobilidade_fut — teto 98% | -0,38 * | -0,41 | 0,13 * | -0,13 * | -0,6 * |

## Diagnósticos da cobertura efetiva

A tabela examina as diferenças pareadas, que são a amostra do teste. Os diagnósticos de cada cenário e teto estão em `statistical_diagnostics.csv`. Nenhuma execução é removida.

Alertas: small_sample = menos de 30 pares; strong_skew = distribuição muito assimétrica; shapiro_p_below_0.05 = distribuição longe da normal; tukey_outliers = pontos muito afastados; boundary_mass = observações no limite da medida.

| Cenário / teto | Pares | Δ (p.p.) | IC 95% | p Holm | Alertas |
|---|---|---|---|---|---|
| rendimento_minimo | 100 | -15,85 | -15,91 a -15,80 | 1.65e-174 | shapiro_p_below_0.05;strong_skew;tukey_outliers |
| paradas_produtivas | 100 | -6,76 | -6,97 a -6,55 | 2.17e-80 | shapiro_p_below_0.05 |
| choque_demanda | 100 | -11,03 | -11,11 a -10,96 | 2.1e-147 | shapiro_p_below_0.05;tukey_outliers |
| demanda_mensal | 100 | -4,54 | -4,81 a -4,28 | 3.32e-54 | tukey_outliers |
| manutencao_escalonada | 100 | -7,99 | -8,11 a -7,87 | 4.9e-110 | tukey_outliers |
| falha_alta_remessa | 100 | -16,03 | -16,09 a -15,96 | 9.34e-165 | shapiro_p_below_0.05;strong_skew;tukey_outliers |
| rotas_bloqueadas | 100 | -0,30 | -0,38 a -0,21 | 3.32e-08 | shapiro_p_below_0.05;strong_skew;tukey_outliers |
| mobilidade_fut — teto 80% | 10 | -18,27 | -18,56 a -17,98 | 3.11e-14 | small_sample;strong_skew;tukey_outliers |
| mobilidade_fut — teto 82% | 10 | -16,46 | -16,65 a -16,27 | 2.16e-15 | small_sample |
| mobilidade_fut — teto 84% | 10 | -14,35 | -14,60 a -14,11 | 5.51e-14 | small_sample;tukey_outliers |
| mobilidade_fut — teto 86% | 10 | -12,15 | -12,37 a -11,93 | 7.73e-14 | small_sample;tukey_outliers |
| mobilidade_fut — teto 88% | 10 | -10,08 | -10,22 a -9,95 | 6e-15 | small_sample |
| mobilidade_fut — teto 90% | 10 | -8,00 | -8,39 a -7,61 | 4.82e-10 | small_sample;shapiro_p_below_0.05;strong_skew;tukey_outliers |
| mobilidade_fut — teto 92% | 10 | -6,21 | -6,42 a -5,99 | 2.39e-11 | small_sample |
| mobilidade_fut — teto 94% | 10 | -4,16 | -4,41 a -3,90 | 3.54e-09 | small_sample;tukey_outliers |
| mobilidade_fut — teto 96% | 10 | -2,15 | -2,47 a -1,84 | 6.49e-06 | small_sample;shapiro_p_below_0.05;strong_skew;tukey_outliers |
| mobilidade_fut — teto 98% | 10 | -0,41 | -0,63 a -0,20 | 0.0905 | small_sample;tukey_outliers |


Das 221 comparações planejadas, 32 ficam sem inferência porque a diferença é constante.

## Referência contra o Histórico 2025

Saldo é produção menos demanda.

| Indicador | Histórico | Referência |
|---|---|---|
| Produção (Mm³) | 28,25 | 33,32 ± 0,07 |
| Demanda (Mm³) | 33,44 | 33,44 ± 0,00 |
| Saldo (Mm³) | -5,19 | -0,12 ± 0,07 |
| FUT (%) | 82,8 | 98,4 ± 0,3 |

## Cobertura do Histórico 2025 com as mesmas simplificações

A demanda de cada região é a fatia populacional da demanda do país, pelo Censo 2022, com o Centro-Oeste somado ao Sudeste, como no modelo. A cobertura nacional do Histórico é a produção observada sobre a demanda, sem perdas, porque o Histórico não tem comboios. A parte que faltou foi coberta por importação e estoque, que ficam fora do modelo.

A cobertura efetiva do Histórico é um intervalo, e não um valor único, porque a ANP informa quanto cada refinaria produziu, mas não quanta gasolina foi levada de uma região para outra. Na simulação, cada comboio é registrado, então a cobertura efetiva sai exata. O menor valor supõe que nenhuma região mandou gasolina para outra, e a sobra do Sul e do Sudeste ficou parada. O maior supõe que toda a sobra chegou onde faltava, e por isso é igual à cobertura nacional. O valor real de 2025 está entre os dois. Esse intervalo não é um intervalo de confiança: ele não vem da variação dos sorteios, e sim da falta de dado sobre o transporte, então não diminui com mais execuções.

| Indicador | Histórico | Referência |
|---|---|---|
| Cobertura nacional (%) | 84,47 | 99,16 ± 0,24 |
| Cobertura efetiva (%) | 75,77 a 84,47 | 99,08 ± 0,28 |

Autossuficiência é a produção das refinarias da região dividida pela demanda dela. A cobertura efetiva da referência inclui as chegadas de comboio.

| Região | Produção histórica (Mm³) | Demanda (Mm³) | Autossuficiência histórica (%) | Autossuficiência na referência (%) | Cobertura efetiva na referência (%) |
|---|---|---|---|---|---|
| Norte | 0,34 | 2,86 | 11,9 | 24,0 ± 0,2 | 96,4 ± 3,1 |
| Nordeste | 3,42 | 9,00 | 37,9 | 60,8 ± 0,6 | 97,8 ± 1,6 |
| Sudeste | 17,74 | 16,65 | 106,5 | 117,2 ± 0,3 | 100,0 ± 0,0 |
| Sul | 6,76 | 4,93 | 137,0 | 154,9 ± 1,1 | 100,0 ± 0,0 |

## Fechamento diário

A falta do dia é a soma do que cada região não cobriu naquele dia, com tanque, produção e chegadas. Ela mede quando a gasolina não estava na região certa, mesmo que o ano feche coberto.

| Cenário | Dias com falta | Maior falta diária (m³) | Falta no percentil 95 (m³) | Maior sequência (dias) | Falta diária somada (Mm³) |
|---|---|---|---|---|---|
| rendimento_minimo | 365 ± 0 | 28.730 ± 675 | 28.290 ± 47 | 365 ± 0 | 5,609 ± 0,024 |
| paradas_produtivas | 189 ± 20 | 34.335 ± 5.928 | 28.475 ± 5.422 | 101 ± 12 | 2,575 ± 0,342 |
| referencia | 97 ± 17 | 16.647 ± 1.541 | 5.960 ± 1.768 | 10 ± 4 | 0,326 ± 0,106 |
| choque_demanda | 364 ± 1 | 34.812 ± 1.652 | 26.247 ± 896 | 322 ± 62 | 4,597 ± 0,083 |
| demanda_mensal | 257 ± 43 | 26.524 ± 5.189 | 18.751 ± 3.921 | 81 ± 34 | 1,960 ± 0,490 |
| manutencao_escalonada | 332 ± 15 | 29.102 ± 3.061 | 20.722 ± 3.171 | 142 ± 51 | 2,979 ± 0,182 |
| falha_alta_remessa | 365 ± 0 | 24.198 ± 425 | 20.353 ± 353 | 365 ± 0 | 5,667 ± 0,055 |
| rotas_bloqueadas | 113 ± 25 | 16.795 ± 1.391 | 7.051 ± 1.810 | 22 ± 17 | 0,440 ± 0,153 |
| mobilidade_fut | 315 ± 84 | 28.316 ± 5.586 | 20.603 ± 6.614 | 208 ± 143 | 3,393 ± 1,937 |

## Mobilidade do FUT por teto

Em `mobilidade_fut`, cada bloco de execuções seguidas tem o mesmo teto de FUT, e a média da tabela anual mistura tetos diferentes. Aqui cada linha junta as execuções de um teto. Média ± desvio padrão. Δ é a cobertura efetiva da execução menos a da execução de mesmo número da referência, que tem teto de 100% e os mesmos rendimentos e taxas de falha. O IC 95% de cada linha está em `scenario_ceiling.csv`.

| Teto (%) | Execuções | FUT (%) | Produção (Mm³) | Cobertura efetiva (%) | Δ cobertura efetiva (p.p.) | Déficit nacional (Mm³) | Dias com falta | Falta diária somada (Mm³) |
|---|---|---|---|---|---|---|---|---|
| 80 | 10 | 80,0 ± 0,0 | 27,08 ± 0,06 | 80,83 ± 0,18 | -18,27 ± 0,41 | 6,40 ± 0,06 | 365 ± 0 | 6,410 ± 0,059 |
| 82 | 10 | 82,0 ± 0,0 | 27,72 ± 0,08 | 82,68 ± 0,25 | -16,46 ± 0,27 | 5,79 ± 0,08 | 365 ± 0 | 5,794 ± 0,085 |
| 84 | 10 | 84,0 ± 0,0 | 28,43 ± 0,06 | 84,81 ± 0,18 | -14,35 ± 0,34 | 5,07 ± 0,06 | 365 ± 0 | 5,079 ± 0,059 |
| 86 | 10 | 86,0 ± 0,0 | 29,13 ± 0,04 | 86,88 ± 0,14 | -12,15 ± 0,30 | 4,38 ± 0,05 | 365 ± 0 | 4,387 ± 0,047 |
| 88 | 10 | 88,0 ± 0,0 | 29,88 ± 0,05 | 89,01 ± 0,17 | -10,08 ± 0,19 | 3,66 ± 0,06 | 363 ± 1 | 3,674 ± 0,057 |
| 90 | 10 | 90,0 ± 0,0 | 30,52 ± 0,08 | 90,93 ± 0,26 | -8,00 ± 0,55 | 3,02 ± 0,09 | 359 ± 2 | 3,032 ± 0,088 |
| 92 | 10 | 92,0 ± 0,0 | 31,19 ± 0,08 | 92,91 ± 0,25 | -6,21 ± 0,30 | 2,36 ± 0,08 | 348 ± 5 | 2,371 ± 0,084 |
| 94 | 10 | 94,0 ± 0,0 | 31,88 ± 0,07 | 94,89 ± 0,23 | -4,16 ± 0,36 | 1,70 ± 0,08 | 304 ± 6 | 1,710 ± 0,077 |
| 96 | 10 | 96,0 ± 0,0 | 32,57 ± 0,09 | 96,86 ± 0,22 | -2,15 ± 0,44 | 1,04 ± 0,07 | 196 ± 24 | 1,051 ± 0,075 |
| 98 | 10 | 97,8 ± 0,2 | 33,21 ± 0,08 | 98,77 ± 0,39 | -0,41 ± 0,30 | 0,38 ± 0,09 | 117 ± 16 | 0,421 ± 0,137 |

## FUT mensal (%)

Média das execuções. FUT é a carga da destilação sobre a capacidade.

| Mês | rendimento_minimo | paradas_produtivas | referencia | choque_demanda | demanda_mensal | manutencao_escalonada | falha_alta_remessa | rotas_bloqueadas | mobilidade_fut |
|---|---|---|---|---|---|---|---|---|---|
| 2025-01 | 99,8 | 97,9 | 97,7 | 100,0 | 100,0 | 99,3 | 97,6 | 97,7 | 88,9 |
| 2025-02 | 100,0 | 98,0 | 97,4 | 100,0 | 100,0 | 97,9 | 97,4 | 97,4 | 89,0 |
| 2025-03 | 100,0 | 98,2 | 97,4 | 100,0 | 100,0 | 97,5 | 97,5 | 97,4 | 89,0 |
| 2025-04 | 100,0 | 98,2 | 97,5 | 100,0 | 100,0 | 98,6 | 97,4 | 97,5 | 89,0 |
| 2025-05 | 100,0 | 97,8 | 97,5 | 100,0 | 100,0 | 98,6 | 97,4 | 97,5 | 89,0 |
| 2025-06 | 100,0 | 98,5 | 97,9 | 100,0 | 100,0 | 99,2 | 97,4 | 97,8 | 89,0 |
| 2025-07 | 100,0 | 99,1 | 98,3 | 100,0 | 100,0 | 99,6 | 97,4 | 98,1 | 89,0 |
| 2025-08 | 100,0 | 99,4 | 98,9 | 100,0 | 100,0 | 99,8 | 97,4 | 98,5 | 89,0 |
| 2025-09 | 100,0 | 99,7 | 99,3 | 100,0 | 100,0 | 100,0 | 97,5 | 98,9 | 89,0 |
| 2025-10 | 100,0 | 99,8 | 99,5 | 100,0 | 100,0 | 100,0 | 97,5 | 99,1 | 89,0 |
| 2025-11 | 100,0 | 99,8 | 99,6 | 100,0 | 100,0 | 100,0 | 97,5 | 99,1 | 89,0 |
| 2025-12 | 100,0 | 99,7 | 99,3 | 100,0 | 100,0 | 100,0 | 97,5 | 98,8 | 89,0 |

## Cobertura efetiva por região (%)

Quanto da demanda de cada região foi servido no ano, com a refinação dela e as chegadas de comboio. Média ± desvio padrão das execuções.

| Cenário | Norte | Nordeste | Sudeste | Sul |
|---|---|---|---|---|
| rendimento_minimo | 28,0 ± 3,0 | 69,3 ± 1,2 | 95,3 ± 0,0 | 100,0 ± 0,0 |
| paradas_produtivas | 77,5 ± 4,2 | 86,6 ± 4,3 | 96,5 ± 3,0 | 97,4 ± 2,6 |
| referencia | 96,4 ± 3,1 | 97,8 ± 1,6 | 100,0 ± 0,0 | 100,0 ± 0,0 |
| choque_demanda | 33,0 ± 2,6 | 79,5 ± 1,0 | 98,6 ± 0,1 | 100,0 ± 0,0 |
| demanda_mensal | 69,5 ± 8,6 | 90,3 ± 2,4 | 99,5 ± 0,3 | 100,0 ± 0,0 |
| manutencao_escalonada | 51,4 ± 4,2 | 88,7 ± 1,2 | 97,4 ± 0,6 | 97,1 ± 1,1 |
| falha_alta_remessa | 24,9 ± 0,1 | 60,9 ± 0,6 | 100,0 ± 0,0 | 100,0 ± 0,0 |
| rotas_bloqueadas | 94,5 ± 5,5 | 97,3 ± 2,4 | 100,0 ± 0,0 | 100,0 ± 0,0 |
| mobilidade_fut | 48,7 ± 25,4 | 81,8 ± 10,8 | 98,3 ± 1,8 | 100,0 ± 0,0 |

## Autossuficiência por região (%)

Produção das refinarias da região dividida pela demanda da região, antes dos comboios. Abaixo de 100% a região depende de outras.

| Cenário | Norte | Nordeste | Sudeste | Sul |
|---|---|---|---|---|
| rendimento_minimo | 24,8 ± 0,0 | 44,5 ± 0,0 | 95,3 ± 0,0 | 148,7 ± 0,0 |
| paradas_produtivas | 24,4 ± 0,2 | 54,2 ± 7,0 | 109,6 ± 4,9 | 146,0 ± 10,9 |
| referencia | 24,0 ± 0,2 | 60,8 ± 0,6 | 117,2 ± 0,3 | 154,9 ± 1,1 |
| choque_demanda | 21,6 ± 0,0 | 52,9 ± 0,5 | 103,6 ± 0,3 | 139,9 ± 0,3 |
| demanda_mensal | 23,2 ± 0,3 | 56,9 ± 0,9 | 111,4 ± 1,6 | 150,4 ± 2,1 |
| manutencao_escalonada | 22,4 ± 0,7 | 55,3 ± 1,2 | 107,4 ± 1,2 | 143,8 ± 3,1 |
| falha_alta_remessa | 24,8 ± 0,0 | 60,8 ± 0,6 | 116,1 ± 0,3 | 151,1 ± 0,4 |
| rotas_bloqueadas | 24,0 ± 0,2 | 60,8 ± 0,6 | 117,0 ± 0,3 | 154,0 ± 1,3 |
| mobilidade_fut | 22,0 ± 1,4 | 54,0 ± 3,6 | 105,9 ± 6,9 | 142,6 ± 9,4 |

## Refinarias na referência

Dias no teto conta os dias com FUT de pelo menos 99,5%.

| Refinaria | Produção (Mm³) | Participação (%) | FUT (%) | Dias no teto | Dias fora do modelo |
|---|---|---|---|---|---|
| REAM | 0,687 ± 0,005 | 2,1 ± 0,0 | 97,0 ± 0,8 | 179,3 ± 46,6 | 0,0 ± 0,0 |
| RECAP | 1,265 ± 0,010 | 3,8 ± 0,0 | 96,4 ± 0,7 | 144,9 ± 40,0 | 0,0 ± 0,0 |
| REDUC | 2,751 ± 0,020 | 8,3 ± 0,1 | 100,0 ± 0,0 | 364,0 ± 0,0 | 0,0 ± 0,0 |
| REFAP | 3,541 ± 0,029 | 10,6 ± 0,1 | 96,4 ± 0,7 | 142,4 ± 39,5 | 0,0 ± 0,0 |
| REFMAT | 5,009 ± 0,051 | 15,0 ± 0,2 | 100,0 ± 0,0 | 364,9 ± 0,4 | 0,0 ± 0,0 |
| REGAP | 2,516 ± 0,017 | 7,6 ± 0,0 | 96,7 ± 0,6 | 149,1 ± 38,2 | 0,0 ± 0,0 |
| REPAR | 4,094 ± 0,028 | 12,3 ± 0,1 | 96,3 ± 0,7 | 140,6 ± 39,4 | 0,0 ± 0,0 |
| REPLAN | 6,604 ± 0,022 | 19,8 ± 0,1 | 98,5 ± 0,3 | 254,7 ± 22,1 | 0,0 ± 0,0 |
| REVAP | 3,546 ± 0,038 | 10,6 ± 0,1 | 100,0 ± 0,0 | 363,4 ± 1,0 | 0,0 ± 0,0 |
| RPBC | 2,841 ± 0,016 | 8,5 ± 0,0 | 97,2 ± 0,5 | 181,3 ± 34,0 | 0,0 ± 0,0 |
| RPCC | 0,466 ± 0,016 | 1,4 ± 0,0 | 100,0 ± 0,0 | 364,6 ± 1,1 | 0,0 ± 0,0 |

