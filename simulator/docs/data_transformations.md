# Transformações e escopo dos dados

Fórmulas aplicadas sobre as fontes de `docs/data_report.md`. O índice
$t$ é o mês de 2025 e $i$ é a refinaria. Os valores diários do modelo são
o valor do mês dividido pelos dias do mês.

## Demanda

A ANP (Agência Nacional do Petróleo, Gás Natural e Biocombustíveis)
publica vendas de gasolina C, que é gasolina A misturada com etanol
anidro. O modelo usa o equivalente em gasolina A:

$$
D^{\text{base}}_t = V^C_t \, (1 - e_t)
$$

$V^C_t$ são as vendas nacionais de gasolina C no mês, em m³. $e_t$ é a
fração obrigatória de etanol anidro na mistura: 0,27 até julho de 2025
(Resolução 16/2021 do CNPE, o Conselho Nacional de Política Energética)
e 0,30 a partir de agosto (Resolução CNPE 9/2025). A série da ANP não
separa gasolina comum e premium, e a fração da comum vale para o total.
Proveniência: `derived_assumption_not_observed`.

A série é nacional. Vendas por região não foram guardadas. A demanda do
dia é dividida pela população do Censo Demográfico 2022 do IBGE
(Instituto Brasileiro de Geografia e Estatística): Norte 17.354.884,
Nordeste 54.658.515, Sul 29.937.706 e Sudeste 84.840.113. O Centro-Oeste,
16.289.538, entra no Sudeste porque não tem refinaria no catálogo. As
fatias estão em `docs/model_specification.md`.

## Capacidade

A ANP publica a capacidade nominal de 31 de dezembro de 2025, em barris
por dia. O mesmo valor vale para todos os meses:

$$
K^P_{i,t} = c_i \times n_t \times 0{,}158987
$$

$c_i$ é a capacidade nominal da refinaria em barris por dia, $n_t$ é o
número de dias do mês e 0,158987 é o fator da ANP de barril para m³.
$K^P_{i,t}$ é a capacidade de processamento do mês, em m³.

O CSV também traz uma capacidade teórica de gasolina A,
$K^G_{i,t} = K^P_{i,t} \times R^{\text{BR}}_t$, com $R^{\text{BR}}_t$
definido abaixo, e uma coluna de piso observado. Nenhuma das duas entra
no Planejado. Lá o teto de petróleo é $K^P$ menos as outras cargas, como
descrito em `docs/model_specification.md`.

## Rendimento

O rendimento mensal de cada refinaria é

$$
R_{i,t} = \frac{G_{i,t}}{\text{PN}_{i,t} + \text{PI}_{i,t}}
$$

$G_{i,t}$ é a gasolina A produzida no mês, $\text{PN}_{i,t}$ o petróleo
nacional e $\text{PI}_{i,t}$ o petróleo importado processados, todos em
m³. Outras cargas ficam fora do denominador. A produção publicada não é
alterada. Um mês é válido se houve petróleo processado e se
$R_{i,t} \le 1$. O dia sorteia, com reposição, um dos meses válidos da
própria refinaria.

$R^{\text{BR}}_t$ é a mesma razão para todas as refinarias do país
juntas, no mês $t$. Fica na coluna `national_avg_gasoline_a_yield_used`.
A média simples dos 12 meses, $R^{\text{BR}} = 0{,}2685$, é o rendimento
de planejamento do primeiro dia e substitui um sorteio igual a 0. As
hipóteses por trás dessa troca estão em Hipóteses e simplificações. Só nas 12
refinarias do catálogo, a razão do ano é 0,2566 sobre o petróleo e
0,2512 sobre a carga total, com outras cargas. O CSV de rendimentos
derivados só documenta a variação mensal por produto e não entra no
sorteio.

## Histórico 2025

`historical_2025_summary.json` traz, por mês e no ano, a gasolina A
produzida, a demanda, o saldo (produção menos demanda), o petróleo e as
outras cargas. Não há estoque. O FUT (fator de utilização total) é

$$
\text{FUT} = 100 \times \frac{\sum_i \left(\text{PN}_{i,t} + \text{PI}_{i,t} + O_{i,t}\right)}{\sum_i K^P_{i,t}}
$$

$O_{i,t}$ são as outras cargas. As somas correm nas 12 refinarias, no
mês ou no ano. É o FUT da Petrobras: toda a carga da destilação dividida
pela capacidade de referência. O FUE (fator de utilização efetivo) que a
ANP publica é outro indicador. Detalhes em `docs/other_charges.md`. A
REPAR em fevereiro de 2025 fica com FUT individual de 100,2535%: 954.411
m³ processados contra 951.998,117 m³ de capacidade.

## Escopo

O catálogo, em `lib/gasoline_simulator/data/catalog.ex`, tem RNEST,
REFMAT, RECAP, REDUC, REFAP, REGAP, REPAR, RPBC, REPLAN, REVAP, REAM e
RPCC. A Clara Camarão usa o código `RPCC`, não o rótulo `RECAP` de
`estudo_tcc.typ`. A LUBNOR, em Fortaleza, produz lubrificantes, parafina
e asfalto, e não registra gasolina A em 2025. Incluí-la só somaria
petróleo ao FUT sem gasolina possível. Também ficam fora DAX OIL,
MANGUINHOS, PARANÁ XISTO, RIOGRANDENSE, SSOIL e UNIVEN.

## Hipóteses e simplificações

Cada item diz o que o modelo assume, onde isso pesa e por quê. Os
números são do histórico de 2025.

### 1. Rendimento zero vira a média nacional

**O quê.** Um mês válido com gasolina A igual a 0 entra no sorteio como
$R^{\text{BR}} = 0{,}2685$.

**Onde.** RNEST, com 5 dos 11 meses válidos em zero (agosto a dezembro,
rodando entre 82% e 87% da capacidade), e RPCC, com 8 dos 12 meses em
zero. Nos meses em que produziram gasolina, a RNEST rendeu de 0,001 a
0,055 e a RPCC de 0,002 a 0,006.

**Por quê.** A hipótese é que o zero foi decisão de mercado, a escolha de
outro produto, e não incapacidade da planta. O modelo pergunta o que
aconteceria se elas produzissem gasolina como o parque nacional.

**Efeito.** O rendimento esperado no sorteio fica em 0,131 na RNEST e em
0,180 na RPCC, bem acima de qualquer mês observado delas. Com o piso de
94%, o modelo tira cerca de 0,78 milhão de m³ de gasolina A da RNEST e 0,44
milhão da RPCC no ano, contra 22 mil e 2,5 mil m³ no histórico. Cerca
de 1,2 milhão de m³ da produção do Nordeste no Planejado vem dessa
hipótese.

### 2. A REAM refina com o rendimento nacional

**O quê.** Todo dia da REAM usa $R^{\text{BR}}$.

**Onde.** Em 2025 a REAM não processou petróleo em 7 meses e registrou
gasolina A em 5 meses sem carga nenhuma na destilação. No ano foram
81.833 m³ de petróleo, 23.350 m³ de outras cargas e 341.136 m³ de
gasolina A, mais de três vezes a carga inteira. Nenhum mês dela é
válido.

**Por quê.** A REAM produzia gasolina A refinando petróleo. Depois da
privatização, deixou de refinar, e a gasolina registrada em 2025 não vem
da destilação. O modelo trata a REAM como a refinaria que ela é
fisicamente, com o rendimento médio do país, o que é razoável para uma
planta que já refinou gasolina.

**Efeito.** A REAM processa cerca de 2,5 milhões de m³ de petróleo no
ano, contra 82 mil no histórico, e rende cerca de 0,67 milhão de m³ de
gasolina A com o piso de 94%.

### 3. Todas as plantas ficam disponíveis o ano inteiro

**O quê.** No Planejado e na referência, toda refinaria fica no ar nos
365 dias, entre o piso de 94% e o teto de 100%.

**Onde.** O histórico tem paradas: a REAM sem petróleo em 7 meses, a
RNEST em fevereiro (0% da capacidade) e a REVAP em outubro e novembro
(34,2% e 0,1%). As da RNEST e da REVAP têm perfil de manutenção: a
destilação para e as outras unidades seguem processando estoque.

**Por quê.** O Planejado mede o que o parque entrega com as plantas
disponíveis. O efeito de paradas de manutenção é estudado à parte, nos
cenários `paradas_produtivas` e `manutencao_escalonada` de
`docs/methodology.md`.

**Efeito.** Com todas no ar e acima de 94%, o FUT (fator de utilização
total) do Planejado fica perto de 97%, contra 82,12% no Histórico.

### 4. Meses de operação parcial continuam no sorteio

**O quê.** Um mês só sai do sorteio sem petróleo processado ou com
rendimento acima de 1. Mês com a destilação rodando pouco continua.

**Onde.** REVAP em outubro (34,2% da capacidade, rendimento 0,385) e em
dezembro (87,3%, 0,275), e RNEST em janeiro (21,5%, 0,055) e em março
(40,5%, 0,003). Saem do sorteio a REVAP em novembro, com rendimento de
240 porque a destilação quase parou, e a RNEST em fevereiro, sem
petróleo.

**Por quê.** A regra usa só o que o dado mensal mostra, sem um corte de
operação mínima.

**Efeito.** Perto de uma parada, as unidades seguintes processam estoque
e o rendimento do mês sobe. Na REVAP, a média do sorteio passa de 0,230,
sem outubro, para 0,244.

### 5. Outras cargas não entram no rendimento

**O quê.** O rendimento divide a gasolina A só pelo petróleo. As outras
cargas ocupam capacidade e entram no FUT, mas não viram gasolina no
modelo.

**Onde.** Em todas as plantas. As outras cargas são até cerca de 6% da
carga, exceto na REAM, com 22%.

**Por quê.** O plano decide só o petróleo, e a gasolina realizada é o
petróleo vezes o rendimento. Calibrar o rendimento com o mesmo
denominador mantém a conta coerente. A ANP não separa a gasolina por
matéria-prima.

**Efeito.** Pequeno. Incluir as outras cargas mudaria o rendimento do
ano em no máximo 0,02, na REFAP (0,301 contra 0,281). Na REAM nenhum dos
dois denominadores explica a produção.

### 6. Uma capacidade para o ano inteiro

**O quê.** A capacidade nominal de 31 de dezembro de 2025 vale em todos
os meses.

**Onde.** Em todas as plantas. Em fevereiro a REPAR processou 100,25%
dessa capacidade, sinal de que ao menos um mês teve capacidade maior.

**Por quê.** A ANP publica a capacidade como um retrato anual.

**Efeito.** Mudanças de capacidade durante o ano não aparecem, e o teto
de 100% impede reproduzir aquele mês da REPAR.

### 7. Demanda regional pela população

**O quê.** A demanda do país é dividida entre as regiões pela população
do Censo 2022. O Centro-Oeste entra no Sudeste.

**Onde.** Em todo o modelo. É o que define quanto cada região pede.

**Por quê.** As vendas por região não foram curadas, e o Centro-Oeste
não tem refinaria no catálogo.

**Efeito.** Consumo per capita diferente entre regiões não aparece.

### 8. A mesma mistura de etanol para toda a gasolina

**O quê.** A fração de etanol da gasolina comum vale também para a
premium.

**Por quê.** A série da ANP não separa os dois tipos.

**Efeito.** A demanda de gasolina A muda um pouco se a premium tiver
outra fração.

### 9. O dia é a média do mês

**O quê.** Demanda, capacidade e outras cargas do mês são divididos
igualmente pelos dias. Todo dia de um mesmo mês tem o mesmo valor. O
petróleo de cada dia não vem do dado mensal: é decidido pelo plano. O
rendimento também não segue essa regra: é sorteado a cada dia entre os
meses válidos da refinaria.

**Por quê.** Os dados da ANP são mensais. Do lado da produção, a
aproximação é boa: a refinaria opera em regime contínuo, 24 horas por
dia e sete dias por semana, e só para em manutenção ou incidente.

**Efeito.** A simplificação pesa na demanda. As vendas variam com o dia
da semana, feriados e fim do mês, e na prática os tanques de refinarias
e distribuidoras absorvem essa variação. No modelo, a demanda muda só na
virada do mês: de 89.852 m³ por dia em novembro para 104.757 m³ por dia
em 1º de dezembro. Uma parada curta, de poucos dias, aparece só como uma
carga mensal menor.

### 10. A demanda é dado externo

**O quê.** A demanda vem das vendas observadas em 2025 e não reage à
produção.

**Por quê.** O trabalho estuda a alocação da produção, não a formação
de preços.

**Efeito.** As vendas foram observadas no regime de preços de 2025.
Outro regime mudaria a demanda.

### 11. Toda remessa vai de caminhão

**O quê.** O prazo de cada comboio é a rodovia a 60 km/h, sem paradas
de descanso, com no mínimo 1 dia.

**Onde.** Todas as rotas. A REAM, em Manaus, recebe e envia por estrada
em 3 a 4 dias. As coordenadas de REAM, RECAP e RPCC vêm do OpenStreetMap
porque a Wikipédia não as publica.

**Por quê.** A escolha é deliberada. O modelo deixa de fora os dutos e a
cabotagem, e isso torna a logística mais difícil do que na realidade,
porque o duto é mais eficiente que o caminhão. Uma regra única de
transporte vale entre todas as refinarias.

**Efeito.** Os resultados de cobertura são um limite inferior
conservador. Se o sistema planejado cobre a demanda só com caminhões,
tende a cobrir tão bem ou melhor com dutos e cabotagem. Os cenários de
logística, `falha_alta_remessa` e `rotas_bloqueadas`, medem a
sensibilidade de uma rede só de caminhões, e não da rede real. Com o
duto como alternativa, bloquear uma estrada tenderia a pesar menos. Na
prática, produto de Manaus costuma seguir de navio ou balsa, e o prazo
real da REAM pode ser outro. Detalhes em `docs/refinery_distances.md`.

### 12. O modelo não tem preço, custo nem importação

**O quê.** O plano decide só quantidades físicas. Não há custo de
refino, preço de combustível nem opção de importar. A parte da demanda
que 2025 cobriu com importação e estoque fica fora do modelo.

**Por quê.** O estudo pergunta o que o parque de refino instalado
poderia produzir fisicamente. O argumento econômico vem de fora do
modelo, no TCC. Antes das privatizações, a Petrobras refinava no Brasil
toda a gasolina A. Depois das privatizações e do início da política de
paridade de preços internacionais (PPI), o Brasil passou a importar
gasolina A. O trabalho defende que o custo não justifica essas
importações.

**Efeito.** O modelo mostra se a capacidade existia, não se usá-la
sairia mais barato. Afirmações sobre custo devem se apoiar nas fontes
do trabalho, não nos resultados da simulação.

### 13. A referência é produção planejada, não 2025 recalibrado

**O quê.** No cenário `referencia`, as 12 plantas ficam no ar o ano
inteiro, com planejamento central, sem paradas nem outros choques, e
com o FUT entre o piso de 94% e o teto de 100%.

**Por quê.** O cenário mede o potencial do parque instalado sob
planejamento. O Histórico 2025 é o que aconteceu sob a dinâmica de
mercado. A distância entre os dois é um resultado do estudo, não um
erro de calibração.

**Efeito.** Na bateria `20261018T043254Z`, a referência produz 33,60
milhões de m³, contra 28,27 milhões em 2025, com FUT de 97,1% contra
82,1%. Os itens 1 e 2, rendimento zero como média nacional e REAM com o
rendimento nacional, seguem a mesma premissa.

### 14. O plano é um problema de programação linear

**O quê.** Cada dia é um problema de programação linear (LP), resolvido
pelo HiGHS. Não há variável inteira. O solver não liga nem desliga
planta. Quais plantas ficam no ar é decisão do cenário.

**Por quê.** Uma versão anterior tinha uma variável binária de "planta
ligada", fixada em 1 para toda planta no ar. Ela não mudava o valor
ótimo, mas fazia o solver tratar o problema como programação linear
inteira mista (MILP). Ela foi removida.

**Efeito.** O valor ótimo é o mesmo. Em dias com déficit, várias
alocações empatam no ótimo, e o LP pode desempatar de outro jeito que o
MILP. Numa comparação da bateria inteira com a mesma semente, isso
mudou pouco 16 das 90 execuções, no máximo 0,01 desvio padrão nas
médias dos cenários, sem mudar nenhum marcador de significância. Se um
dia o solver precisar decidir ligar ou desligar plantas, por exemplo
com um custo fixo de operação, a variável binária volta a ser
necessária.
