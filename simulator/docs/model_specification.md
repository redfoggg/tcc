# Especificação do modelo

O Planejado 2025 resolve um MILP por dia. Não há estoque nacional. Planta
que produziu acima do plano envia a sobra para a que ficou abaixo. Esse
volume só entra na demanda no dia em que chega. O prazo mínimo é
1 dia. O painel agrega os 365 dias em mês e ano. O Histórico 2025 não
é uma execução do modelo. Fontes e conversões: `docs/data_report.md` e
`docs/data_transformations.md`. Contrato de software:
`docs/model_runtime.md`.

## Conjuntos

- $T$: os 365 dias de 2025
- $F$: 12 refinarias de `estudo_tcc.typ` (REAM, RECAP, REDUC, REFAP,
  REFMAT, REGAP, REPAR, REPLAN, REVAP, RNEST, RPBC, RPCC). LUBNOR fica de
  fora: é planta de lubrificantes e asfalto e não produz gasolina A.
- Cada $i \in F$ é um GenServer. O dia $d$ usa só $F_d$: plantas que o
  cenário manteve e que respondem. Processo ausente, ou chamada que cai,
  tira $i$ de $F_d$. Recuperação devolve $i$ nos dias seguintes. O MILP
  realoca $D_d$ em $F_d$.

## Símbolos

| Símbolo | Significado | Unidade |
|---|---|---|
| $R_{i,d}$ | Rendimento simulado de gasolina A sobre petróleo | meses válidos de $i$ em 2025 |
| $\rho_{i,d}$ | Teto de utilização de $i$ no dia $d$. Não é o FUT realizado | adimensional, $[0{,}40,\ 1]$ |
| $K^G_{i,d}$ | Coluna curada teórica. Não entra no Planejado | m³/dia |
| $K^P_{i,d}$ | Capacidade bruta de processamento | m³/dia |
| $O_{i,d}$ | Outras cargas observadas, já na torre | m³/dia |
| $L_{i,d}$ | Piso de petróleo da campanha | m³/dia |
| $D_d$ | Proxy de demanda de gasolina A, já ajustado | m³ |
| $x_{i,d}$ | Gasolina realizada, $P_{i,d} R_{i,d}$ | m³ |
| $y_{i,d}$ | Ativação | $\{0, 1\}$ |
| $u_d$ | Déficit | m³ |
| $A_d$ | Gasolina que chegou de uma remessa no dia $d$ | m³ |
| $E_d$ | Excedente do dia, retido na planta ou embarcado | m³ |
| $P_{i,d}$ | Petróleo da campanha decidido pelo plano | m³/dia |

A demanda e as capacidades diárias são o valor mensal curado dividido pelos
dias daquele mês. $R_{i,d}$ é sorteado por refinaria-dia, com reposição,
entre os rendimentos mensais válidos daquela planta em 2025. O HiGHS não
vê esse sorteio. O denominador é petróleo nacional mais importado. Outras
cargas ficam de fora. Válido: petróleo $> 0$ e A/petróleo $\le 1$. Se o
valor sorteado (ou a lista) é $0$, usa-se a média nacional de gasolina A
da ANP. Zero no histórico é decisão de mercado, não teto técnico.

$$
R_{i,d} =
\begin{cases}
R^{\text{BR}} & \text{se o sorteio é } 0 \\
R_{i,\text{mês}} & \text{caso contrário}
\end{cases}
$$

$\rho_{i,d}$ é a fração máxima de $K^P_{i,d}$ que a torre de $i$ pode
ocupar no dia $d$. $O_{i,d}$ é o volume observado de outras cargas do mês,
repartido pelos dias. Esse volume já ocupa a placa. A campanha de
petróleo fica com o restante:

$$
P_{i,d} \le \rho_{i,d}\, K^P_{i,d} - O_{i,d}
$$

O FUT da torre, $(P_{i,d}+O_{i,d})/K^P_{i,d}$, fica entre o piso da planta
e $1$. Dentro do dia, o piso e $O_{i,d}$ são dados. O teto de petróleo da
campanha é

$$
C_{i,d} = \max(K^P_{i,d} - O_{i,d},\ 0)
$$

O piso de cada planta é o FUT aceitável da simulação. O padrão é
$0{,}94$. O cenário de mobilidade usa $0{,}92$, $0{,}93$ ou $0{,}94$.
O teto do planejamento é $100\%$. Planta religada tem piso na rampa,
$\rho = 0{,}40$, subindo $1$ p.p. por dia até o FUT aceitável.

A nameplate $K^P$ é o máximo físico. O piso de petróleo que o
planejamento recebe é

$$
L_{i,d} = \max(\rho^{\min}_{i,d}\, K^P_{i,d} - O_{i,d},\ 0)
$$

e o teto é a mesma conta com $\rho = 1$. O rendimento sorteado não entra
nessas duas contas.

## Otimização diária

Não há orçamento global de petróleo. O HiGHS faz um planejamento para o
país e devolve a cada planta o petróleo da campanha. Para mirar a demanda
de gasolina, converte $D_d$ e $A_d$ por um rendimento de planejamento.
No dia 1 esse rendimento é a média nacional $R^{\text{BR}}$. Depois de
cada dia ele vira a gasolina realizada até ali dividida pelo petróleo
processado até ali. Não usa o $R_{i,d}$ do dia.

Toda refinaria em $F_d$ fica ligada: $y_{i,d} = 1$. Planta derrubada no
painel sai de $F_d$ e não entra no dia. Não há saldo nacional carregado
de um dia para o outro.

A função é

$$
\min \; u_d + 10^{-4} E_d + 10^{-4} \sum_{i \in F_d \,:\, C_{i,d} > 0} \frac{P_{i,d}}{C_{i,d}}
$$

Dentro do solver, $u_d$ e $E_d$ estão em petróleo, com a demanda já
dividida por $R^{\text{BR}}$. $u_d$ tem peso $1$ por m³. $E_d$ tem peso
$10^{-4}$. O terceiro termo reparte o petróleo que falta entre as plantas.

## Restrições

$$
0 \le P_{i,d} \le y_{i,d} \, C_{i,d}
$$

$$
P_{i,d} \ge y_{i,d} \, L_{i,d}
$$

$$
L_{i,d} \le C_{i,d}
$$

Dentro do HiGHS o balanço é em petróleo, com $D_d$ e $A_d$ divididos pelo
rendimento de planejamento daquele dia. Depois da execução o balanço do
dia é em gasolina:

$$
A_d + \sum_i P_{i,d} R_{i,d} + u_d - D_d - E_d = 0
$$

$$
P_{i,d} + O_{i,d} \le \rho_{i,d}\, K^P_{i,d}
$$

$$
u_d \ge 0, \quad E_d \ge 0, \quad A_d \ge 0, \quad y_{i,d} = 1
$$

$A_d$ é a soma do que as plantas presentes receberam naquele dia. $E_d$ não
passa para o dia seguinte como saldo do país.

## Remessa

O prazo de cada comboio é o tempo de caminhão da estrada. A conta é o
teto de quilômetros / 60 / 24, com mínimo de 1 dia. Não há remessa no
mesmo dia. A volta usa o mesmo prazo. Se a origem tenta outra planta, o
prazo passa a ser o daquele par. Os quilômetros estão em
`Refineries.Distances`.

A remessa cobre a falta de uma planta contra o próprio plano. A falta é
$P_{i,d} R^{\text{plano}} - x_{i,d}$, quando é maior que zero. A sobra de
quem realizou mais que o plano, também maior que zero, vai primeiro para
a maior falta. Se essa sobra cobre a falta, o restante vai para a próxima
falta. Cada comboio leva no máximo 30 m³ e só sai com pelo menos 20 m³.
Uma sobra de 50 m³ vira dois comboios, de 30 m³ e de 20 m³. O que sobra
abaixo de 20 m³ fica na origem. A origem abre um processo para cada
comboio. A carga fica nesse processo,
não na planta. No dia da chegada o destino cobra o processo e o volume
entra na demanda, como $A_d$. Quem cumpriu o plano não recebe. Se ninguém
ficou abaixo, não há remessa. Se ninguém ficou acima, não há quem envie.
O Runner não guarda a rota. Carga que cairia depois de 31/12 não volta
nesse ano. Se ninguém recebe, a sobra fica na origem.

Um cenário pode fechar uma estrada num dia. A opção é `closed_roads`,
uma função que devolve os pares fechados naquele dia. O par vale nos dois
sentidos. Comboio que usaria essa estrada não sai e a origem tenta a
próxima planta com falta. Pular a estrada fechada não conta como perda.
O painel não escolhe esses pares. O cenário de rotas bloqueadas fecha
três pares por dois meses civis. Nos outros dias a função devolve lista
vazia.

Cada entrega passa por um sorteio no momento em que vai sair. A taxa da
rota vem primeiro. A rota é o par sem direção. A chave pode ser a tupla
ordenada, como `{"RECAP", "REPLAN"}`, ou o texto `RECAP|REPLAN`, com os
identificadores em ordem. Se essa chave não está no mapa, vale a
porcentagem da refinaria de destino, que é o que o painel envia. Chave
ausente vale 0. O valor fica entre 0 e 100. 0 não muda a
remessa. 100 faz a entrega falhar. O sorteio de cada entrega é
independente. Se falha, o processo não fica a caminho como se fosse
chegar. A carga é perdida: origem e destino recebem o aviso, o volume
não volta para a origem e não entra na demanda. Três perdas seguidas
na rota da origem até aquele destino fazem a origem esperar 10 dias
antes de iniciar outra entrega nessa rota. Uma entrega que sai zera
essa contagem. Na pausa, a origem tenta a próxima planta com falta. Pular
a rota pausada não conta como perda. Se ninguém recebe, a sobra fica na
origem e isso também não conta como perda. Quem não configura a
porcentagem no painel usa 1. Na bateria, a referência sorteia de 1 a 5
em cada rota e a falha alta sorteia de 41 a 100. Os outros cenários usam 1.

Se o processo da entrega cai por outro motivo, ele deixa de responder.
A origem e o destino recebem o aviso. A carga é perdida do mesmo jeito.

O estoque de uma planta, no fim do dia, é a gasolina produzida até ali
menos o volume que saiu em entrega já iniciada. O saldo passa para o dia
seguinte. Quem nunca enviou fica com estoque igual à produção. Carga que
ninguém recebeu continua na planta. Carga perdida não volta para o estoque.
A soma desses estoques não reproduz o antigo estoque nacional. Gasolina
em trânsito não entra nessa soma. O CSV da simulação grava `stock_m3`
por refinaria e dia, e `plant_stock_m3` no fim do período.

Se o processo não responde, a refinaria conta como ausente naquele dia.
Carga que estava só nesse processo some com ele.

## FUT

$P_{i,d}$ é o petróleo que o plano mandou processar. A torre ainda carrega
$O_{i,d}$. A gasolina que sai é $P_{i,d} R_{i,d}$.

$$
\text{FUT}_{\text{Total}, d} = 100 \times \frac{\sum_i (P_{i,d}+O_{i,d})}{\sum_i K^P_{i,d}}
$$

$$
\text{FUT}_{\text{Total}, \text{mês}} = 100 \times \frac{\sum_{d \in \text{mês}} \sum_i (P_{i,d}+O_{i,d})}{\sum_{d \in \text{mês}} \sum_i K^P_{i,d}}
$$

$$
\text{FUT}_{\text{Total}, \text{ano}} = 100 \times \frac{\sum_d \sum_i (P_{i,d}+O_{i,d})}{\sum_d \sum_i K^P_{i,d}}
$$

O Histórico usa a mesma razão de somas. O numerador é toda a carga de
destilação, no sentido do FUT da Petrobras: petróleo nacional (inclui
C5+), petróleo importado e outras cargas. Sempre sobre as 12 refinarias.
O FUE publicado pela ANP é outro indicador. FUT individual é diagnóstico.
Planta ligada fica em $[0{,}40,\ \rho_{i,d}]$. Definição e fontes:
`docs/other_charges.md`.

## Controles

$D_d = D_d^{\text{base}} (1 + a/100)$. O prazo da remessa é o tempo de
caminhão de cada par, o teto de (rodovia / 60 / 24), com mínimo $1$. A
conta que gerou esses quilômetros está em `docs/refinery_distances.md`.
