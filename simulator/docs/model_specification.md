# Especificação do modelo

O Planejado 2025 resolve um MILP por dia e transporta só o estoque. O
painel agrega os 365 dias em mês e ano. O Histórico 2025 não é uma
execução do modelo. Fontes e conversões: `docs/data_report.md` e
`docs/data_transformations.md`. Contrato de software:
`docs/model_runtime.md`.

## Conjuntos

- $T$: os 365 dias de 2025
- $F$: 12 refinarias de `estudo_tcc.typ` (REAM, RECAP, REDUC, REFAP,
  REFMAT, REGAP, REPAR, REPLAN, REVAP, RNEST, RPBC, RPCC). LUBNOR fica de
  fora: é planta de lubrificantes e asfalto e não produz gasolina A.
- Cada $i \in F$ é um GenServer. O dia $d$ usa só $F_d$, as plantas cujo
  processo está no ar. Queda tira $i$ de $F_d$. Recuperação devolve $i$
  nos dias seguintes. O MILP realoca $D_d$ em $F_d$.

## Símbolos

| Símbolo | Significado | Unidade |
|---|---|---|
| $R_{i,d}$ | Rendimento simulado de gasolina A | meses válidos de $i$ em 2025 |
| $K^G_{i,d}$ | Coluna curada teórica. Não entra no Planejado | m³/dia |
| $K^P_{i,d}$ | Capacidade bruta de processamento | m³ petróleo/dia |
| $L_{i,d}$ | Piso técnico se ativa: $0{,}40\, R_{i,d} K^P_{i,d}$ | m³/dia |
| $D_d$ | Proxy de demanda de gasolina A, já ajustado | m³ |
| $x_{i,d}$ | Alocação planejada | m³ |
| $y_{i,d}$ | Ativação | $\{0, 1\}$ |
| $u_d$ | Déficit | m³ |
| $S_d$ | Estoque final nacional | m³ |
| $P_d$ | Processamento implícito do dia | m³ petróleo |

A demanda e as capacidades diárias são o valor mensal curado dividido pelos
dias daquele mês. $R_{i,d}$ é sorteado por refinaria-dia, com reposição,
entre os rendimentos mensais válidos daquela planta em 2025. Válido: petróleo
processado $> 0$ e A/petróleo $\le 1$. Se o valor sorteado (ou a lista) é $0$,
usa-se a média nacional de gasolina A da ANP. Zero no histórico é decisão de
mercado, não teto técnico.

$$
R_{i,d} =
\begin{cases}
R^{\text{BR}} & \text{se o sorteio é } 0 \\
R_{i,\text{mês}} & \text{caso contrário}
\end{cases}
$$

A produção efetiva é

$$
C_{i,d} = \rho_{i,d}\, R_{i,d} K^P_{i,d}
$$

$\rho$ começa em $1$ (fase aberta) para planta que já está no ar no primeiro
dia. Ao alcançar FUT $\ge 99\%$, a planta só desce: $99\%,\ 98\%,\ \ldots$
até $90\%$. Não sobe no meio da descida. Ao chegar em $90\%$, trava. O
tempo da trava é o excesso do ciclo acima de $90\%$,
$\sum \max(\mathrm{FUT}-0{,}90,\ 0)$, cobrado a $1$ p.p. por dia. Assim a
média do ciclo fica perto de $90\%$ ou abaixo. Depois a fase aberta volta.

Planta religada (processo de volta depois de uma queda) não abre em
$100\%$. Entra em rampa: $\rho = 0{,}40$ e sobe $1$ p.p. por dia até
$1$. Só então volta à fase aberta.

A nameplate $K^P$ é o máximo físico. Se $y_{i,d} = 1$, o FUT não fica
abaixo de 40%:

$$
L_{i,d} = \min(C_{i,d},\ 0{,}40\, R_{i,d} K^P_{i,d})
$$

## Otimização diária

Não há orçamento global de petróleo. Cada refinaria tem o próprio teto
$\rho_{i,d} K^P_{i,d}$: sobe até 100%, desce sem retorno até 90%, depois
trava pelo desvio da média acima de 90%.

Etapa 1: minimizar $u_d$. Pode usar 100% de FUT para atender demanda. Etapa
2: fixar $u_d$ no ótimo da etapa 1 com tolerância $10^{-6}$ m³ e minimizar
$\sum_i x_{i,d} / C_{i,d}$. O FUT alto é o penalizador. Estoque final não
entra na função objetivo. Se a demanda cabe abaixo do teto do dia, o FUT
cai. Planta ligada fica em $[0{,}40,\ \rho_{i,d}]$.

## Restrições

$$
0 \le x_{i,d} \le y_{i,d} \, C_{i,d}
$$

$$
x_{i,d} \ge y_{i,d} \, L_{i,d}
$$

$$
L_{i,d} \le C_{i,d}
$$

$$
S_{d-1} + \sum_i x_{i,d} + u_d - D_d - S_d = 0
$$

$$
P_{i,d} \le \rho_{i,d}\, K^P_{i,d}
$$

$$
u_d \ge 0, \quad S_d \ge 0, \quad y_{i,d} \in \{0, 1\}
$$

$S_0$ vem do painel. Para o dia seguinte, $S_{d-1}$ é o estoque resolvido
do dia anterior.

## FUT

Processamento planejado: $P_{i,d} = x_{i,d} / R_{i,d}$.

$$
\text{FUT}_{\text{Total}, d} = 100 \times \frac{\sum_i P_{i,d}}{\sum_i K^P_{i,d}}
$$

$$
\text{FUT}_{\text{Total}, \text{mês}} = 100 \times \frac{\sum_{d \in \text{mês}} \sum_i P_{i,d}}{\sum_{d \in \text{mês}} \sum_i K^P_{i,d}}
$$

$$
\text{FUT}_{\text{Total}, \text{ano}} = 100 \times \frac{\sum_d \sum_i P_{i,d}}{\sum_d \sum_i K^P_{i,d}}
$$

O Histórico usa o mesmo formato com processamento observado. Sempre razão de
somas sobre as 12 refinarias. FUT individual é diagnóstico. Planta ligada
fica em $[0{,}40,\ \rho_{i,d}]$.

## Controles

$D_d = D_d^{\text{base}} (1 + a/100)$. $S_0$ é o estoque inicial do painel.
