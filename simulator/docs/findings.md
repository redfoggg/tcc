# Conclusões contra o Histórico 2025

Este documento registra quais comparações com o Histórico 2025 os
dados do estudo sustentam e quais não sustentam. Não é o texto do TCC
(trabalho de conclusão de curso). Ele guarda as linhas de argumento e a
evidência de cada uma, para o autor escrever as conclusões no TCC.

Todos os números vêm da bateria `data/studies/20261021T045244Z`, com
semente `865221133`, 11 refinarias e o plano com a previsão do ano.
Eles estão em `analysis/report.md` e nos CSVs de `analysis/`. Rodar a
bateria de novo com a mesma semente reproduz os números. Com outra
semente, eles mudam um pouco. A ordem de grandeza dessa mudança é a
largura do IC 95% (intervalo de confiança de 95% da média): na
referência, a cobertura efetiva fica entre 98,47% e 99,28%, uma faixa
de 0,81 p.p. (pontos percentuais). Mm³ são milhões de m³.

## Premissas que enquadram a leitura

Os detalhes estão em `docs/data_transformations.md`, seção Hipóteses e
simplificações, itens 11 a 15. As que mais pesam na comparação:

- **A referência não é uma calibração de 2025.** Ela é a produção
  planejada sem desastres: as 11 plantas no ar o ano inteiro, com o
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
- **O planejador conhece a demanda do ano.** Ele forma estoque antes
  dos meses em que a demanda passa do teto do parque, como dezembro.
  Paradas, rendimento sorteado e falhas de comboio ficam fora da
  previsão.
- **A demanda de cada região segue a população** do Censo 2022, com o
  Centro-Oeste somado ao Sudeste.

## Linhas que os dados sustentam

### 1. Capacidade e utilização

O parque tinha capacidade para atender a demanda de 2025, no limite.
Com as 11 plantas disponíveis, o FUT entre 94% e 100% e o estoque
formado antes de dezembro, a referência produz praticamente a demanda:
o saldo do ano é −0,16 Mm³, com desvio padrão de 0,13 Mm³, então não dá
para dizer que sobra nem que falta. Em 2025, a produção do mesmo escopo
ficou 5,19 Mm³ abaixo da demanda.

| Indicador | Histórico 2025 | Referência |
|---|---|---|
| Produção (Mm³) | 28,25 | 33,28 ± 0,13 |
| Demanda (Mm³) | 33,44 | 33,44 |
| Saldo (Mm³) | −5,19 | −0,16 ± 0,13 |
| FUT (%) | 82,8 | 98,3 ± 0,4 |
| Cobertura efetiva (%) | 75,77 a 84,47 | 98,87 ± 0,57 |

Frase de exemplo: "Com as refinarias disponíveis o ano inteiro e
operando entre 94% e 100% da capacidade, o parque produziria 33,28 Mm³
de gasolina A, praticamente a demanda de 33,44 Mm³, contra 28,25 Mm³
efetivamente produzidos em 2025 pelas mesmas refinarias."

### 2. O FUT histórico explica a maior parte da diferença

Quando o modelo trava o teto de FUT em 82%, perto dos 82,8% de 2025, a
produção e a cobertura caem para perto dos valores históricos. A
execução de teto 82% do cenário `mobilidade_fut` usa os mesmos
rendimentos e taxas de falha da execução de mesmo número da
referência.

| Indicador | Histórico 2025 | Modelo com teto de 82% |
|---|---|---|
| Produção (Mm³) | 28,25 | 27,78 |
| Cobertura efetiva (%) | 75,77 a 84,47 | 82,86 |

A produção do modelo fica 0,47 Mm³ abaixo da histórica, cerca de 1,7%.
A cobertura efetiva fica dentro do intervalo histórico.

Isso funciona como validação do modelo: com a utilização de 2025, ele
chega perto do volume de 2025. A ressalva é que o modelo trava todas as
plantas no mesmo teto, e em 2025 algumas pararam e outras rodaram alto.
REPAR e RECAP rodaram a 94,7% e 91,6% em 2025 e têm os maiores
rendimentos do parque (0,344 e 0,358, contra 0,267 de média). Travá-las
em 82% tira gasolina que o histórico teve. Já a REAM quase não refinou
em 2025 (3,9%), e no modelo ela roda a 82%. O total fica próximo, mas a
divisão por refinaria não bate.

Frase de exemplo: "Ao limitar a utilização do parque a 82%, valor
próximo ao observado em 2025, o modelo produz 27,78 Mm³, a 1,7% da
produção real das mesmas refinarias, o que indica que a diferença entre
o potencial e o realizado se explica em sua maior parte pela
utilização."

### 3. Valor marginal do FUT

Cada ponto de teto entre 80% e 94% acrescenta cerca de 0,34 Mm³ de
produção: (31,82 − 27,02) / 14. De 94% para 98%, a produção sobe 1,36
Mm³, também cerca de 0,34 Mm³ por ponto. Com teto de 98%, o FUT do ano
fica em 97,7%, porque o plano só sobe acima do piso quando a previsão
pede estoque.

| Teto (%) | FUT anual (%) | Produção (Mm³) | Cobertura efetiva (%) |
|---|---|---|---|
| 80 | 80,0 | 27,02 | 80,68 |
| 82 | 82,0 | 27,78 | 82,86 |
| 86 | 86,0 | 29,30 | 87,29 |
| 90 | 90,0 | 30,53 | 90,97 |
| 94 | 94,0 | 31,82 | 94,59 |
| 96 | 96,0 | 32,62 | 97,03 |
| 98 | 97,7 | 33,18 | 98,31 |

A tabela completa, com os dez tetos, está em
`analysis/scenario_ceiling.csv`. Cada linha é uma única execução, então
não tem IC.

Frase de exemplo: "Entre 80% e 98% de utilização, cada ponto percentual
equivale a cerca de 0,34 Mm³ de gasolina A por ano."

### 4. Dependência regional

Norte e Nordeste dependem de outras regiões. A autossuficiência é a
produção das refinarias da região dividida pela demanda dela. Na
referência, ela sobe, mas continua bem abaixo de 100%, e é a chegada de
comboios que leva a cobertura efetiva para perto de 100%.

| Região | Autossuficiência histórica (%) | Autossuficiência na referência (%) | Cobertura efetiva na referência (%) |
|---|---|---|---|
| Norte | 11,9 | 24,0 ± 0,2 | 96,9 ± 2,5 |
| Nordeste | 37,9 | 60,7 ± 0,4 | 96,9 ± 2,7 |

No cenário `falha_alta_remessa`, a taxa de falha de cada rota fica
entre 41% e 100%. Quase nada chega, e a cobertura efetiva de cada
região fica perto da autossuficiência dela.

| Região | Autossuficiência (%) | Cobertura efetiva (%) |
|---|---|---|
| Norte | 24,8 ± 0,0 | 24,9 ± 0,1 |
| Nordeste | 60,7 ± 0,4 | 60,8 ± 0,5 |

Como a logística do modelo é só por caminhão, mais difícil que a real,
a cobertura alta da referência é um limite inferior do que o
planejamento entregaria.

Frase de exemplo: "Mesmo com todas as refinarias do Norte e do
Nordeste operando, as duas regiões produzem menos do que consomem, e a
cobertura delas depende do transporte vindo do Sul e do Sudeste."

### 5. Robustez do planejamento

A cobertura efetiva de cada cenário de choque, comparada com o
intervalo histórico de 75,77% a 84,47%. O maior valor, 84,47%, é a
cobertura nacional de 2025 e o maior valor possível da efetiva.

| Cenário | Cobertura efetiva (%) | IC 95% |
|---|---|---|
| falha_alta_remessa | 83,02 ± 0,12 | 82,93 a 83,10 |
| rendimento_minimo | 83,21 ± 0,07 | 83,16 a 83,26 |
| choque_demanda | 88,02 ± 0,21 | 87,87 a 88,17 |
| manutencao_escalonada | 90,92 ± 0,66 | 90,45 a 91,39 |
| paradas_produtivas | 92,69 ± 0,74 | 92,16 a 93,22 |
| demanda_mensal | 93,87 ± 1,35 | 92,90 a 94,84 |
| rotas_bloqueadas | 98,23 ± 0,66 | 97,75 a 98,70 |

Dois cenários ficam abaixo de 84,47%, dentro do intervalo histórico:
`falha_alta_remessa`, em que quase nenhum comboio chega, e
`rendimento_minimo`, que fixa em todos os dias o menor rendimento
mensal de cada refinaria. Os outros choques ficam acima do maior valor
possível de 2025. O `mobilidade_fut` fica fora desta tabela porque a
média dele mistura tetos diferentes (linha 3).

`rotas_bloqueadas` tira 0,64 p.p. da cobertura efetiva, com asterisco
(p = 0,03). O efeito é pequeno no ano porque o bloqueio dura 2 meses e
o comboio segue para o próximo destino, mas existe.

Frase de exemplo: "Mesmo sob choques de demanda, paradas de refinarias
e bloqueio de rotas, o parque planejado atende uma parcela da demanda
maior que a atendida em 2025. Só ficam no nível histórico os cenários
em que o transporte quase para ou todas as refinarias rendem o mínimo
do ano."

### 6. Argumento combinado com o contexto do TCC

O modelo mostra que a capacidade física existia: o parque podia
produzir praticamente toda a gasolina A de 2025 (linhas 1 e 2). O
porquê de não ter produzido vem de fora do modelo. O TCC traz o
contexto: antes das privatizações, a Petrobras refinava toda a gasolina
A no Brasil, e depois das privatizações e do início da PPI (paridade
de preços internacionais) o país passou a importar gasolina A.

Os dois lados têm fontes diferentes. O "podia" vem da simulação. O
"por que não fez", e qualquer afirmação sobre custo ou preço, tem que
se apoiar nas fontes do autor, não nos resultados da simulação, que
não tem preço nem custo.

Frase de exemplo: "A simulação indica que o parque nacional tinha
capacidade física para atender praticamente toda a demanda de 2025. A
diferença entre essa capacidade e a produção observada coincide com o
período posterior à adoção da PPI, quando a importação passou a cobrir
parte da demanda (fonte)."

## O que os dados não sustentam

- **Decisão econômica ou custo.** O modelo não tem preço, custo nem
  importação. Ele não diz se produzir era mais barato que importar.
- **Que o parque sobraria.** O saldo da referência, −0,16 ± 0,13 Mm³,
  fica no limite. A afirmação segura é que o parque chegaria
  praticamente à demanda, não que a superaria.
- **A cobertura efetiva exata de 2025.** Ela é o intervalo de 75,77% a
  84,47%, porque não há dado de transporte entre regiões. Compare os
  cenários com o intervalo, não com um ponto dele.
- **A média anual de `mobilidade_fut`.** Ela mistura dez tetos
  diferentes. Use a tabela por teto (linha 3).
- **A divisão da produção por refinaria em 2025.** O teto uniforme
  reproduz o total, não quem produziu quanto (linha 2).
- **A rede logística real.** Os cenários logísticos medem a rede só de
  caminhões. Com dutos e cabotagem, bloquear uma rodovia tenderia a
  pesar menos, e falhas de comboio também.

## Cuidados de leitura estatística

A explicação completa está em `docs/methodology.md`, seção Como ler a
estatística.

- **Significativo não é importante.** O asterisco diz que a diferença
  provavelmente não é ruído, não que ela é grande. Cite sempre o Δ ao
  lado do asterisco. O −0,64 p.p. de `rotas_bloqueadas` é um exemplo.
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
