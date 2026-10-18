# Conclusões contra o Histórico 2025

Este documento registra quais comparações com o Histórico 2025 os
dados do estudo sustentam e quais não sustentam. Não é o texto do TCC
(trabalho de conclusão de curso). Ele guarda as linhas de argumento e a
evidência de cada uma, para o autor escrever as conclusões no TCC.

Todos os números vêm da bateria `data/studies/20261018T043254Z`, com
semente `612777692`, e estão em `analysis/report.md` e nos CSVs de
`analysis/`. Rodar a bateria de novo com a mesma semente reproduz os
números. Com outra semente, eles mudam um pouco. A ordem de grandeza
dessa mudança é a largura do IC 95% (intervalo de confiança de 95% da
média): na referência, a cobertura efetiva fica entre 99,30% e 99,44%,
uma faixa de 0,14 p.p. (pontos percentuais). Mm³ são milhões de m³.

## Premissas que enquadram a leitura

Os detalhes estão em `docs/data_transformations.md`, seção Hipóteses e
simplificações, itens 11 a 14. As que mais pesam na comparação:

- **A referência não é uma calibração de 2025.** Ela é a produção
  planejada sem desastres: as 12 plantas no ar o ano inteiro, com o
  rendimento sorteado do histórico e FUT (fator de utilização total)
  entre 94% e 100%. A pergunta é o que o parque podia entregar, não o
  que entregou.
- **O modelo não tem preço, custo nem importação.** Isso é de
  propósito. Ele mede capacidade física, e a falta é o que sobra sem
  cobertura.
- **Toda remessa vai de caminhão.** Isso também é de propósito. A rede
  real tem dutos e cabotagem, que levam mais volume com menos perda.
  Por isso a logística do modelo é mais difícil que a real, e as
  coberturas são um limite inferior.
- **A demanda de cada região segue a população** do Censo 2022, com o
  Centro-Oeste somado ao Sudeste.

## Linhas que os dados sustentam

### 1. Capacidade e utilização

O parque tinha capacidade para atender a demanda de 2025. Com as
plantas disponíveis e o FUT entre 94% e 100%, a referência produz mais
do que a demanda. Em 2025, a produção ficou 5,17 Mm³ abaixo dela.

| Indicador | Histórico 2025 | Referência |
|---|---|---|
| Produção (Mm³) | 28,27 | 33,60 ± 0,06 |
| Demanda (Mm³) | 33,44 | 33,44 |
| Saldo (Mm³) | −5,17 | +0,15 ± 0,06 |
| FUT (%) | 82,1 | 97,1 ± 0,0 |

Frase de exemplo: "Com as refinarias disponíveis o ano inteiro e
operando entre 94% e 100% da capacidade, o parque produziria 33,60 Mm³
de gasolina A, acima da demanda de 33,44 Mm³, contra 28,27 Mm³
efetivamente produzidos em 2025."

### 2. O FUT histórico explica quase toda a diferença

Quando o modelo trava o teto de FUT em 82%, perto dos 82,1% de 2025, a
produção e a cobertura caem para perto dos valores históricos. A
execução de teto 82% do cenário `mobilidade_fut` usa os mesmos
rendimentos e taxas de falha da execução de mesmo número da
referência.

| Indicador | Histórico 2025 | Modelo com teto de 82% |
|---|---|---|
| Produção (Mm³) | 28,27 | 28,41 |
| Cobertura efetiva (%) | 75,84 a 84,54 | 84,79 |

A produção do modelo fica 0,14 Mm³ acima da histórica, cerca de 0,5%.
A cobertura efetiva fica 0,25 p.p. acima da cobertura nacional
histórica de 84,54%, que é o maior valor possível da efetiva em 2025.

Isso funciona também como validação do modelo: com a utilização de
2025, ele reproduz o volume de 2025. A ressalva é que o modelo trava
todas as plantas no mesmo teto, e em 2025 algumas pararam e outras
rodaram alto. O total bate, mas a divisão por refinaria não.

Frase de exemplo: "Ao limitar a utilização do parque a 82%, valor
observado em 2025, o modelo produz 28,41 Mm³, a 0,5% da produção real,
o que indica que a diferença entre o potencial e o realizado se explica
quase toda pela utilização."

### 3. Valor marginal do FUT

Cada ponto de teto entre 80% e 94% acrescenta cerca de 0,36 Mm³ de
produção: (32,59 − 27,61) / 14. Acima de 94%, o ganho cai, porque o
FUT anual fica abaixo do teto: com teto de 98%, o FUT do ano é 96,2%.
De 94% para 98%, a produção sobe 0,73 Mm³, cerca de 0,18 Mm³ por ponto.

| Teto (%) | FUT anual (%) | Produção (Mm³) | Cobertura efetiva (%) |
|---|---|---|---|
| 80 | 80,0 | 27,61 | 82,37 |
| 82 | 82,0 | 28,41 | 84,79 |
| 86 | 86,0 | 29,89 | 89,09 |
| 90 | 90,0 | 31,31 | 93,32 |
| 94 | 94,0 | 32,59 | 97,06 |
| 96 | 95,1 | 33,03 | 98,18 |
| 98 | 96,2 | 33,32 | 99,10 |

A tabela completa, com os dez tetos, está em
`analysis/scenario_ceiling.csv`. Cada linha é uma única execução, então
não tem IC.

Frase de exemplo: "Entre 80% e 94% de utilização, cada ponto percentual
equivale a cerca de 0,36 Mm³ de gasolina A por ano."

### 4. Dependência regional

Norte e Nordeste dependem de outras regiões. A autossuficiência é a
produção das refinarias da região dividida pela demanda dela. Na
referência, ela sobe, mas continua abaixo de 100%, e é a chegada de
comboios que leva a cobertura efetiva para perto de 100%.

| Região | Autossuficiência histórica (%) | Autossuficiência na referência (%) | Cobertura efetiva na referência (%) |
|---|---|---|---|
| Norte | 11,9 | 23,5 ± 0,1 | 97,3 ± 2,0 |
| Nordeste | 38,2 | 69,5 ± 0,3 | 98,5 ± 0,8 |

No cenário `falha_alta_remessa`, a taxa de falha de cada rota fica
entre 41% e 100%. Quase nada chega, e a cobertura efetiva de cada
região fica igual à autossuficiência dela.

| Região | Autossuficiência (%) | Cobertura efetiva (%) |
|---|---|---|
| Norte | 24,8 ± 0,0 | 24,9 ± 0,1 |
| Nordeste | 69,5 ± 0,3 | 69,6 ± 0,3 |

Como a logística do modelo é só por caminhão, mais difícil que a real,
a cobertura alta da referência é um limite inferior do que o
planejamento entregaria.

Frase de exemplo: "Mesmo com todas as refinarias do Norte e do
Nordeste operando, as duas regiões produzem menos do que consomem, e a
cobertura delas depende do transporte vindo do Sul e do Sudeste."

### 5. Robustez do planejamento

A cobertura efetiva de cada cenário de choque, comparada com a
cobertura nacional histórica de 84,54%, que é o maior valor possível da
efetiva em 2025.

| Cenário | Cobertura efetiva (%) | IC 95% |
|---|---|---|
| rendimento_minimo | 83,23 ± 0,07 | 83,18 a 83,28 |
| falha_alta_remessa | 85,41 ± 0,09 | 85,34 a 85,47 |
| choque_demanda | 89,82 ± 0,16 | 89,70 a 89,94 |
| manutencao_escalonada | 91,36 ± 0,49 | 91,01 a 91,71 |
| paradas_produtivas | 93,27 ± 1,35 | 92,31 a 94,23 |
| demanda_mensal | 94,30 ± 0,90 | 93,66 a 94,95 |
| rotas_bloqueadas | 99,27 ± 0,28 | 99,07 a 99,47 |

Só `rendimento_minimo` fica abaixo de 84,54%, e mesmo assim dentro do
intervalo histórico de 75,84% a 84,54%. Ele fixa em todos os dias o
menor rendimento mensal de cada refinaria. `falha_alta_remessa` fica
0,87 p.p. acima. Os outros choques ficam bem acima. O
`mobilidade_fut` fica fora desta tabela porque a média dele mistura
tetos diferentes (linha 3).

Frase de exemplo: "Mesmo sob choques de demanda, paradas de refinarias
e falhas de transporte, o parque planejado atende uma parcela da
demanda igual ou maior que a atendida em 2025, com exceção do cenário
em que todas as refinarias rendem o mínimo do ano."

### 6. Argumento combinado com o contexto do TCC

O modelo mostra que a capacidade física existia: o parque podia
produzir a gasolina A de 2025 (linhas 1 e 2). O porquê de não ter
produzido vem de fora do modelo. O TCC traz o contexto: antes das
privatizações, a Petrobras refinava toda a gasolina A no Brasil, e
depois das privatizações e do início da PPI (paridade de preços
internacionais) o país passou a importar gasolina A.

Os dois lados têm fontes diferentes. O "podia" vem da simulação. O
"por que não fez", e qualquer afirmação sobre custo ou preço, tem que
se apoiar nas fontes do autor, não nos resultados da simulação, que
não tem preço nem custo.

Frase de exemplo: "A simulação indica que o parque nacional tinha
capacidade física para atender a demanda de 2025. A diferença entre essa
capacidade e a produção observada coincide com o período posterior à
adoção da PPI, quando a importação passou a cobrir parte da demanda
(fonte)."

## O que os dados não sustentam

- **Decisão econômica ou custo.** O modelo não tem preço, custo nem
  importação. Ele não diz se produzir era mais barato que importar.
- **A cobertura efetiva exata de 2025.** Ela é o intervalo de 75,84% a
  84,54%, porque não há dado de transporte entre regiões. Compare os
  cenários com o intervalo, não com um ponto dele.
- **Efeito de `rotas_bloqueadas`.** Nesta bateria, a cobertura efetiva
  cai 0,09 p.p., sem asterisco (p = 0,34). Numa bateria de teste com
  outra semente, caiu 0,28 p.p., com asterisco. O efeito está no nível
  do ruído.
- **A média anual de `mobilidade_fut`.** Ela mistura dez tetos
  diferentes. Use a tabela por teto (linha 3).
- **A rede logística real.** Os cenários logísticos medem a rede só de
  caminhões. Com dutos e cabotagem, bloquear uma rodovia tenderia a
  pesar menos, e falhas de comboio também.

## Cuidados de leitura estatística

A explicação completa está em `docs/methodology.md`, seção Como ler a
estatística.

- **Significativo não é importante.** O asterisco diz que a diferença
  provavelmente não é ruído, não que ela é grande. Cite sempre o Δ ao
  lado do asterisco.
- **Muitos testes sem correção.** `analysis/scenario_vs_reference.csv`
  tem 104 testes (8 cenários × 13 medidas), e o `report.md` mostra só 5
  medidas por cenário. Todos usam o limite de 5% sem correção para
  comparações múltiplas. Mesmo sem efeito real, uns 5 dos 104 ganhariam
  asterisco por acaso, e resultados com p perto de 0,05 pedem cautela.
- **As execuções não são independentes da referência.** O teste de
  Welch trata cenário e referência como amostras independentes, mas a
  execução $n$ de cada cenário compartilha rendimento e taxas de falha
  com a execução $n$ da referência. Isso deixa o teste conservador: um
  teste pareado acharia diferenças com mais facilidade.
