# Especificação do modelo

O Planejado 2025 resolve um problema por dia, nos 365 dias do ano. Cada
problema é um LP (programação linear), resolvido pelo HiGHS, um solver
de código aberto. O plano é central: uma única chamada
decide quanto petróleo cada refinaria no ar processa. Depois, o
rendimento sorteado transforma esse petróleo em gasolina A. Os comboios
levam a sobra das regiões que refinam mais do que consomem para as que
refinam menos. O resultado do dia volta como dado para o plano do dia
seguinte. O Histórico 2025 não usa este modelo.

Gasolina A é a gasolina sem etanol, como sai da refinaria. Fontes dos
dados: `docs/data_report.md`. Conversões: `docs/data_transformations.md`.
Código: `docs/model_runtime.md`.

## Índices e conjuntos

| Símbolo | Significado |
|---|---|
| $d$ | Dia de 2025, de 1º de janeiro a 31 de dezembro |
| $i$ | Refinaria |
| $F$ | As 11 refinarias do catálogo |
| $F_d$ | Refinarias no ar no dia $d$: o cenário as mantém e o processo delas responde |
| $r$ | Região de demanda: Norte, Nordeste, Sudeste ou Sul |
| $F_{r,d}$ | Refinarias de $F_d$ que ficam na região $r$ |

| Região | Refinarias | População (Censo 2022 do IBGE) | Fatia $s_r$ |
|---|---|---:|---:|
| Norte | REAM | 17.354.884 | 8,55% |
| Nordeste | REFMAT, RPCC | 54.658.515 | 26,91% |
| Sudeste | RECAP, REDUC, REGAP, REPLAN, REVAP, RPBC | 101.129.651 | 49,80% |
| Sul | REFAP, REPAR | 29.937.706 | 14,74% |

IBGE é o Instituto Brasileiro de Geografia e Estatística. O Sudeste soma
84.840.113 habitantes do próprio Sudeste e 16.289.538 do Centro-Oeste,
que não tem refinaria no catálogo. O total é 203.080.756. Os nomes de
cada sigla de refinaria estão em `docs/refinery_distances.md`. A LUBNOR,
refinaria de lubrificantes do Nordeste, fica de fora porque não produz
gasolina A. A RNEST fica de fora porque é uma refinaria de diesel
(`docs/data_transformations.md`, Escopo).

No Planejado, $F_d = F$ em todos os dias, salvo planta derrubada no
painel. A hipótese é que as paradas do histórico, como a de manutenção
da REVAP, não fazem parte do plano. O efeito de tirar plantas
do ar é estudado nos cenários de parada de `docs/methodology.md`.

## Dados de cada dia

Os valores mensais curados são divididos pelos dias do mês.

| Símbolo | Significado | Unidade |
|---|---|---|
| $D^{\text{base}}_d$ | Demanda curada de gasolina A do país | m³ |
| $a$ | Ajuste de demanda escolhido no painel ou no cenário | % |
| $K^P_{i,d}$ | Capacidade nominal de processamento (placa) da refinaria | m³ |
| $O_{i,d}$ | Outras cargas observadas, que já ocupam parte da placa | m³ |
| $R_{i,d}$ | Rendimento sorteado: gasolina A por m³ de petróleo | adimensional |
| $R^{\text{BR}}$ | Rendimento médio do parque nacional, 0,2685 | adimensional |
| $\rho^{\text{base}}_{i,d}$ | FUT aceitável da planta: 0,94 no padrão ou o degrau da rampa | fração da placa |

Outras cargas são resíduos reprocessados na destilação junto com o
petróleo. Elas estão explicadas em `docs/other_charges.md`. FUT é o
fator de utilização total: a fração da placa que a destilação ocupa.

## Demanda

$$
D_d = D^{\text{base}}_d \left(1 + \frac{a}{100}\right)
\qquad
D_{r,d} = s_r \, D_d
$$

$D_d$ é a demanda do país no dia e $D_{r,d}$ é a parte da região $r$. A
fatia $s_r$ é a população da região dividida pela do país. No cenário de
demanda mensal, $a$ muda a cada mês.

## Rendimento

$R_{i,d}$ é sorteado, com reposição, entre os rendimentos mensais
válidos da própria refinaria em 2025. Válido quer dizer que houve
petróleo processado e que a gasolina A não passou do petróleo. Sorteio
igual a 0, ou lista vazia, vira $R^{\text{BR}}$. A hipótese é que o zero
foi decisão de mercado, não limite técnico. A REAM não tem mês válido,
porque depois da privatização deixou de refinar, e usa $R^{\text{BR}}$
todo dia. As hipóteses, onde pesam e por quê estão em
`docs/data_transformations.md`, seção Hipóteses e simplificações.

O plano não conhece $R_{i,d}$. Ele usa o rendimento de planejamento
$\bar R_d$:

$$
\bar R_1 = R^{\text{BR}}
\qquad
\bar R_d = \frac{\sum_{t<d} \sum_i x_{i,t}}{\sum_{t<d} \sum_i P_{i,t}}
\quad (d > 1)
$$

O numerador é a gasolina realizada até a véspera, e o denominador é o
petróleo processado até a véspera. $R^{\text{BR}}$ é a média simples dos
12 valores mensais da ANP (Agência Nacional do Petróleo, Gás Natural e
Biocombustíveis): em cada mês, gasolina A de todas as refinarias do país
dividida pelo petróleo delas.

## Faixa de cada planta

O plano decide $P_{i,d}$, o petróleo que a refinaria processa no dia,
sem contar as outras cargas. Ele fica entre o piso $L_{i,d}$ e o teto
$C_{i,d}$:

$$
C_{i,d} = \max\!\left(K^P_{i,d} - O_{i,d},\ 0\right)
\qquad
L_{i,d} = \min\!\left(\max\!\left(\rho^{\min}_{i,d} K^P_{i,d} - O_{i,d},\ 0\right),\ C_{i,d}\right)
$$

O teto deixa a destilação em 100% da placa. O piso deixa a destilação em
$\rho^{\min}_{i,d}$ da placa. As duas contas descontam $O_{i,d}$, porque
as outras cargas já ocupam a torre.

O piso do dia é

$$
\rho^{\min}_{i,d} = \min\!\left(1,\ \rho^{\text{base}}_{i,d} + \frac{Q_{i,d-1}}{\bar R_d \, K^P_{i,d}}\right)
$$

$Q_{i,d-1}$ é a dívida da planta: quanto ela já rendeu de gasolina abaixo
do próprio plano. Dividir por $\bar R_d K^P_{i,d}$ converte esse volume em
fração da placa. A dívida muda assim:

$$
Q_{i,d} = \max\!\left(0,\ Q_{i,d-1} + P_{i,d} \bar R_d - x_{i,d}\right),
\qquad Q_{i,0} = 0
$$

$P_{i,d} \bar R_d$ é a gasolina que o plano esperava, e $x_{i,d}$ é a que
saiu. Dia ruim aumenta a dívida e sobe o piso no dia seguinte. Dia bom
reduz a dívida.

$\rho^{\text{base}}_{i,d}$ vale 0,94 para quem está no ar. No cenário de
mobilidade de FUT, o teto vai de 0,80 a 0,98, e o piso desce junto quando
o teto fica abaixo de 0,94. Planta que volta de uma parada
entra numa rampa: o degrau começa em 0,40 e sobe 0,01 em cada dia em que
o déficit do país, $U_d$, fica em até 1 m³. Quando chega ao FUT aceitável,
a rampa acaba. O plano pode subir a planta até o teto, que é 100% fora do
cenário de mobilidade de FUT.

## Plano do dia

Variáveis, todas em m³ de petróleo:

| Símbolo | Significado |
|---|---|
| $P_{i,d} \ge 0$ | Petróleo processado pela refinaria $i$ |
| $u_{r,d} \ge 0$ | Falta da região $r$ |
| $E_{r,d} \ge 0$ | Sobra da região $r$ |
| $u_d \ge 0$ | Falta do país |
| $E_d \ge 0$ | Sobra do país |

Dados que o plano recebe, em m³ de gasolina:

| Símbolo | Significado |
|---|---|
| $A_{r,d}$, $A_d$ | Gasolina que chegou de comboio hoje, na região e no país |
| $S_{r,d}$, $S_d$ | Tanque de abertura: gasolina que sobrou de ontem, na região e no país |
| $U_{d-1}$ | Déficit realizado ontem, definido em Execução do dia |

Função objetivo:

$$
\min \ \sum_r u_{r,d} + u_d + 10^{-4}\left(\sum_r E_{r,d} + E_d\right) + 10^{-4} \sum_{i \in F_d,\ C_{i,d} > 0} \frac{P_{i,d}}{C_{i,d}}
$$

- Cada m³ de falta, regional ou nacional, custa 1. É o termo que manda.
- Cada m³ de sobra custa $10^{-4}$. Sobrar é aceito, mas o plano evita
  produzir sem motivo.
- O último termo soma a fração do teto que cada planta usa, com peso
  $10^{-4}$. Sem falta para cobrir, ele deixa a planta no piso. Entre
  duas plantas, sobe primeiro a de teto maior, porque cada m³ dela pesa
  menos nesse termo.

Restrições:

$$
L_{i,d} \le P_{i,d} \le C_{i,d}
$$

$$
\sum_{i \in F_{r,d}} P_{i,d} + u_{r,d} + \frac{A_{r,d} + S_{r,d}}{\bar R_d} - E_{r,d} = \frac{D_{r,d}}{\bar R_d}
\quad \text{para cada região } r
$$

$$
\sum_{i \in F_d} P_{i,d} + u_d + \frac{A_d}{\bar R_d} - E_d = \frac{\max\!\left(D_d + U_{d-1} - S_d,\ 0\right)}{\bar R_d}
$$

A primeira mantém cada planta na própria faixa. A segunda fecha cada
região com a refinação dela, a falta, o que chegou e o tanque dela. A
terceira fecha o país. O alvo nacional soma a falta de ontem e desconta o
tanque, então sobra de um mês reduz o que o mês seguinte precisa
refinar. Dividir por $\bar R_d$ converte gasolina em petróleo. Quando uma
região curta já está no teto, só a restrição nacional ainda tem falta, e
o plano sobe as plantas das outras regiões.

## Execução do dia

A ordem é:

1. As cargas que chegam hoje entram no tanque de destino ($A_{r,d}$).
2. O plano decide $P_{i,d}$.
3. Cada planta produz $x_{i,d} = P_{i,d} R_{i,d}$, que entra no tanque
   dela. Na região, $X_{r,d} = \sum_{i \in F_{r,d}} x_{i,d}$.
4. Saem os comboios. $B_{r,d}$ é o volume que saiu da região, contando
   o que se perde na estrada.
5. Cada região fecha o dia:

$$
u^{\text{exe}}_{r,d} = \max\!\left(D_{r,d} - (S_{r,d} + X_{r,d} + A_{r,d} - B_{r,d}),\ 0\right)
$$

$$
E^{\text{exe}}_{r,d} = \max\!\left(X_{r,d} + A_{r,d} - B_{r,d} - D_{r,d},\ 0\right)
$$

$$
S_{r,d+1} = \max\!\left(S_{r,d} + X_{r,d} + A_{r,d} - B_{r,d} - D_{r,d},\ 0\right)
$$

$u^{\text{exe}}$ é a demanda que a região não teve como cobrir hoje.
$E^{\text{exe}}$ é o quanto a gasolina nova do dia passou da demanda.
$S_{r,d+1}$ é o tanque que fica para amanhã: a demanda da região é tirada
do tanque das plantas dela, na proporção do que cada uma guarda.

6. O dia passa para o seguinte o déficit $U_d = \sum_r u^{\text{exe}}_{r,d}$,
   o rendimento $\bar R_{d+1}$, a dívida $Q_{i,d}$ de cada planta e o
   degrau da rampa.

## Comboios

O pedido e a oferta de cada região usam o tanque depois do passo 3:

$$
N_{r,d} = D_{r,d} - X_{r,d} \quad \text{se } X_{r,d} < D_{r,d}
$$

$$
V_{r,d} = S_{r,d} + X_{r,d} - D_{r,d} \quad \text{se } X_{r,d} \ge D_{r,d} \text{ e o resultado é positivo}
$$

$N_{r,d}$ é o pedido: a demanda que a refinação da região não cobre. O
pedido não conta o tanque nem as chegadas de hoje, porque esses já cobrem
o dia de hoje. A carga cobre o dia em que chegar. Assim cada dia envia a
falta de um dia, e a estrada mantém um fluxo contínuo. $V_{r,d}$ é a
oferta: o que a região tem acima da própria demanda. A gasolina que
chegou hoje não sai de novo.

O pedido é dividido entre as plantas da região pela placa $K^P$. A oferta
é dividida pelo tanque de cada planta. A maior oferta atende o maior
pedido, e assim por diante. Cada comboio leva até 30 m³. O resto vira um
comboio a mais se tiver pelo menos 20 m³. Um volume entre 20 e 30 m³ sai
num comboio só, e um volume abaixo de 20 m³ não sai. Exemplo: 50 m³
saem em dois comboios, de 30 e de 20 m³.

O prazo de viagem é

$$
\tau = \max\!\left(\left\lceil \frac{k}{60 \times 24} \right\rceil,\ 1\right) \text{ dias}
$$

$k$ é a distância de rodovia do par em km, 60 é a velocidade do
caminhão em km/h e 24 converte horas em dias. O teto $\lceil\cdot\rceil$
arredonda para cima. As distâncias estão em `docs/refinery_distances.md`.

Na saída, cada comboio passa por um sorteio de falha com probabilidade
$\varphi/100$. $\varphi$ é um inteiro de 0 a 100. Vale primeiro a taxa
da rota, que é o par de refinarias sem direção. Sem ela, vale a taxa da
refinaria de destino, que é o que o painel envia. Sem nenhuma das duas,
$\varphi = 1$. A carga que falha se perde: não volta para a origem, não
chega ao destino e entra nas perdas no transporte. Origem e destino são
avisados.

Três perdas seguidas na mesma rota, da origem até aquele destino, fazem
a origem esperar 10 dias antes de mandar outra carga por ela. Uma carga
que sai sem falha zera a contagem. Um cenário também pode fechar
estradas em certos dias, nos dois sentidos. Em rota pausada ou estrada
fechada, a origem tenta a próxima planta com pedido. Se ninguém pode
receber, o volume fica na origem. Nada disso conta como perda. Cargas
ainda na estrada em 31 de dezembro saem da conta.

## FUT

$$
\text{FUT}_{i,d} = 100 \times \frac{P_{i,d} + O_{i,d}}{K^P_{i,d}}
\qquad
\text{FUT}_{\text{período}} = 100 \times \frac{\sum_{d} \sum_{i} \left(P_{i,d} + O_{i,d}\right)}{\sum_{d} \sum_{i} K^P_{i,d}}
$$

O FUT de uma planta fica entre $\rho^{\min}_{i,d}$ e 100%. O FUT do dia,
do mês e do ano é a razão das somas do período, nunca a média dos FUT
individuais. O Histórico usa a mesma razão, com a carga observada:
petróleo nacional, que inclui o condensado C5+ (hidrocarbonetos com cinco
carbonos ou mais), petróleo importado e outras cargas, sempre nas 12
refinarias. Esse é o FUT da Petrobras. O FUE (fator de utilização
efetivo) publicado pela ANP é outro indicador.

## Indicadores do painel

| Indicador | Conta |
|---|---|
| Produção fornecida | $\sum_d \sum_i x_{i,d}$ |
| Demanda-alvo | $\sum_d D_d$ |
| Saldo assinado | Produção fornecida menos demanda-alvo |
| Perdas no transporte | $\Lambda$, a soma das cargas perdidas no ano |
| Demanda atendida | $\min\!\left(\sum_d D_d,\ \sum_d \sum_i x_{i,d} - \Lambda\right)$ |
| Déficit | Demanda-alvo menos demanda atendida |
| Excedente | $\max\!\left(\sum_d \sum_i x_{i,d} - \Lambda - \sum_d D_d,\ 0\right)$ |
| Cobertura nacional | Demanda atendida dividida pela demanda-alvo |
| Cobertura efetiva | $\sum_r M_r$ dividido pela demanda-alvo |
| Chegadas | $\sum_d A_d$ |
| Estoque nas plantas | Tanque de todas as plantas no fim de 31 de dezembro |

As duas coberturas olham o ano inteiro, não cada dia. A nacional
pergunta se a gasolina refinada no país, menos a que se perdeu na
estrada, cobriu a demanda do país. Ela não vê onde a gasolina ficou: se
os comboios não saem, quase nada se perde e ela fica perto de 100%. A
efetiva pergunta quanto da demanda de cada região foi servido:

$$
M_r = \min\!\left(\sum_d D_{r,d},\ \sum_d \left(X_{r,d} + A_{r,d} - B_{r,d}\right)\right)
$$

$M_r$ é a demanda atendida da região $r$ no ano: o menor entre a
demanda dela e a gasolina que ela teve, que é a refinada nela mais a que
chegou de comboio menos a que saiu. Gasolina parada no tanque de uma
região não cobre a demanda de outra. A tabela por região mostra, no ano,
a demanda $\sum_d D_{r,d}$, a produção $\sum_d X_{r,d}$, a atendida
$M_r$, o tanque no fim do ano e a cobertura da região, $M_r$ sobre a
demanda dela. A tabela mensal soma os dias: produção, demanda, saldo e
FUT.

O CSV de cada execução grava o fechamento diário: `day_deficit_m3` é
$U_d$ e `day_excess_m3` é $\sum_r E^{\text{exe}}_{r,d}$. CSV é um arquivo
de texto com valores separados por vírgula.
