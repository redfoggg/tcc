# Conclusões contra o Histórico 2025

Este documento registra quais comparações com o Histórico 2025 os
dados do estudo sustentam e quais não sustentam. Não é o texto do TCC
(trabalho de conclusão de curso). Ele guarda as linhas de argumento e a
evidência de cada uma, para o autor escrever as conclusões no TCC.

Todos os números vêm da bateria `data/studies/20261022T182537Z`, com
semente `657716052`, 11 refinarias, 100 execuções por cenário e o plano
com a previsão do ano.
Eles estão em `analysis/report.md` e nos CSVs de `analysis/`. Rodar a
bateria de novo com a mesma semente reproduz os números. Com outra
semente, eles mudam um pouco. A ordem de grandeza dessa mudança é a
largura do IC 95% (intervalo de confiança de 95% da média): na
referência, a cobertura efetiva fica entre 99,03% e 99,14%, uma faixa
de 0,11 p.p. (pontos percentuais). Mm³ são milhões de m³.

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

O parque tinha capacidade para atender praticamente toda a demanda de
2025. Com as 11 plantas disponíveis, o FUT entre 94% e 100% e o estoque
formado antes de dezembro, a referência produz 33,32 Mm³, 0,12 Mm³
abaixo da demanda, cerca de 0,4%. Com 100 execuções, esse saldo
negativo é pequeno, mas não é ruído. Em 2025, a produção do mesmo
escopo ficou 5,19 Mm³ abaixo da demanda.

| Indicador | Histórico 2025 | Referência |
|---|---|---|
| Produção (Mm³) | 28,25 | 33,32 ± 0,07 |
| Demanda (Mm³) | 33,44 | 33,44 |
| Saldo (Mm³) | −5,19 | −0,12 ± 0,07 |
| FUT (%) | 82,8 | 98,4 ± 0,3 |
| Cobertura efetiva (%) | 75,77 a 84,47 | 99,08 ± 0,28 |

Frase de exemplo: "Com as refinarias disponíveis o ano inteiro e
operando entre 94% e 100% da capacidade, o parque produziria 33,32 Mm³
de gasolina A, 99,6% da demanda de 33,44 Mm³, contra 28,25 Mm³
efetivamente produzidos em 2025 pelas mesmas refinarias."

### 2. O FUT histórico explica a maior parte da diferença

Quando o modelo trava o teto de FUT em 82%, perto dos 82,8% de 2025, a
produção e a cobertura caem para perto dos valores históricos. As 10
execuções de teto 82% do cenário `mobilidade_fut` usam os mesmos
rendimentos e taxas de falha das execuções de mesmo número da
referência.

| Indicador | Histórico 2025 | Modelo com teto de 82% |
|---|---|---|
| Produção (Mm³) | 28,25 | 27,72 ± 0,08 |
| Cobertura efetiva (%) | 75,77 a 84,47 | 82,68 ± 0,25 |

A produção do modelo fica 0,53 Mm³ abaixo da histórica, cerca de 1,9%.
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
próximo ao observado em 2025, o modelo produz 27,72 Mm³, a 1,9% da
produção real das mesmas refinarias, o que indica que a diferença entre
o potencial e o realizado se explica em sua maior parte pela
utilização."

### 3. Valor marginal do FUT

Cada ponto de teto entre 80% e 94% acrescenta cerca de 0,34 Mm³ de
produção: (31,88 − 27,08) / 14. De 94% para 98%, a produção sobe 1,33
Mm³, cerca de 0,33 Mm³ por ponto. Com teto de 98%, o FUT do ano fica em
97,8%, porque o plano só sobe acima do piso quando a previsão
pede estoque.

| Teto (%) | FUT anual (%) | Produção (Mm³) | Cobertura efetiva (%) |
|---|---|---|---|
| 80 | 80,0 | 27,08 ± 0,06 | 80,83 ± 0,18 |
| 82 | 82,0 | 27,72 ± 0,08 | 82,68 ± 0,25 |
| 86 | 86,0 | 29,13 ± 0,04 | 86,88 ± 0,14 |
| 90 | 90,0 | 30,52 ± 0,08 | 90,93 ± 0,26 |
| 94 | 94,0 | 31,88 ± 0,07 | 94,89 ± 0,23 |
| 96 | 96,0 | 32,57 ± 0,09 | 96,86 ± 0,22 |
| 98 | 97,8 ± 0,2 | 33,21 ± 0,08 | 98,77 ± 0,39 |

Cada linha junta as 10 execuções de um teto. A tabela completa, com os
dez tetos e o IC 95% de cada um, está em `analysis/scenario_ceiling.csv`.

Frase de exemplo: "Entre 80% e 98% de utilização, cada ponto percentual
equivale a cerca de 0,34 Mm³ de gasolina A por ano."

### 4. Dependência regional

Norte e Nordeste dependem de outras regiões. A autossuficiência é a
produção das refinarias da região dividida pela demanda dela. Na
referência, ela sobe, mas continua bem abaixo de 100%, e é a chegada de
comboios que leva a cobertura efetiva para perto de 100%.

| Região | Autossuficiência histórica (%) | Autossuficiência na referência (%) | Cobertura efetiva na referência (%) |
|---|---|---|---|
| Norte | 11,9 | 24,0 ± 0,2 | 96,4 ± 3,1 |
| Nordeste | 37,9 | 60,8 ± 0,6 | 97,8 ± 1,6 |

No cenário `falha_alta_remessa`, a taxa de falha de cada rota fica
entre 41% e 100%. Quase nada chega, e a cobertura efetiva de cada
região fica perto da autossuficiência dela.

| Região | Autossuficiência (%) | Cobertura efetiva (%) |
|---|---|---|
| Norte | 24,8 ± 0,0 | 24,9 ± 0,1 |
| Nordeste | 60,8 ± 0,6 | 60,9 ± 0,6 |

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
| falha_alta_remessa | 83,06 ± 0,16 | 83,02 a 83,09 |
| rendimento_minimo | 83,23 ± 0,07 | 83,21 a 83,24 |
| choque_demanda | 88,05 ± 0,21 | 88,00 a 88,09 |
| manutencao_escalonada | 91,09 ± 0,54 | 90,98 a 91,20 |
| paradas_produtivas | 92,32 ± 1,02 | 92,12 a 92,52 |
| demanda_mensal | 94,54 ± 1,30 | 94,28 a 94,80 |
| rotas_bloqueadas | 98,79 ± 0,41 | 98,70 a 98,87 |

Dois cenários ficam abaixo de 84,47%, dentro do intervalo histórico:
`falha_alta_remessa`, em que quase nenhum comboio chega, e
`rendimento_minimo`, que fixa em todos os dias o menor rendimento
mensal de cada refinaria. Os outros choques ficam acima do maior valor
possível de 2025. O `mobilidade_fut` fica fora desta tabela porque a
média dele mistura tetos diferentes (linha 3).

`rotas_bloqueadas` tira 0,30 p.p. da cobertura efetiva, com asterisco
(p corrigido menor que 0,001). O efeito é pequeno no ano porque o
bloqueio dura 2 meses e o comboio segue para o próximo destino, mas
existe.

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
- **Que o parque sobraria.** O saldo da referência é −0,12 ± 0,07 Mm³.
  A afirmação segura é que o parque chegaria a cerca de 99,6% da
  demanda, não que a superaria.
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

- **Comparação par a par.** Cada cenário é comparado com a execução de
  mesmo número da referência, que usa os mesmos sorteios. O teste é o t
  pareado.
- **Correção para muitas comparações.** O relatório faz 221 comparações
  (7 cenários e 10 tetos, cada um com 13 medidas). O asterisco só
  aparece quando o p corrigido por Holm fica abaixo de 0,05.
- **Significativo não é importante.** O asterisco diz que a diferença
  provavelmente não é sorte, não que ela é grande. Com 100 execuções,
  quase todo efeito ganha asterisco: `rotas_bloqueadas` tira só 0,30
  p.p. da cobertura efetiva e ainda assim tem asterisco. Cite sempre o
  Δ ao lado do asterisco.
- **Sem asterisco não é igual.** No teto de 98% de `mobilidade_fut`, a
  cobertura efetiva cai 0,41 p.p. Com só 10 execuções por teto e a
  correção para 221 comparações, o p corrigido fica em cerca de 0,09, e
  a diferença fica sem asterisco. Isso não mostra que o teto de 98% é
  igual à referência.
- **Diferenças constantes ficam sem p.** Das 221 comparações, 32 dão a
  mesma diferença em todos os pares, e o relatório marca NI em vez de
  inventar um p.
- **Mais execuções não corrigem o modelo.** A média fica mais precisa,
  mas as premissas continuam as mesmas.
