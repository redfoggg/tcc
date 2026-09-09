# Especificação do modelo

O Planejado 2025 resolve um MILP por dia e transporta só o estoque. O
painel agrega os 365 dias em mês e ano. O Histórico 2025 não é uma
execução do modelo. Fontes e conversões: `docs/data_report.md` e
`docs/data_transformations.md`. Contrato de software:
`docs/model_runtime.md`.

## Conjuntos

- $T$: os 365 dias de 2025
- $F$: 13 refinarias de `estudo_tcc.typ` (LUBNOR, REAM, RECAP, REDUC, REFAP,
  REFMAT, REGAP, REPAR, REPLAN, REVAP, RNEST, RPBC, RPCC)
- Toda $i \in F$ entra em todo $d \in T$.

## Símbolos

| Símbolo | Significado | Unidade |
|---|---|---|
| $R_{i,d}$ | Rendimento simulado de gasolina A | $[0{,}20,\ \hat R_i]$ |
| $K^G_{i,d}$ | Capacidade teórica curada de gasolina A | m³/dia |
| $K^P_{i,d}$ | Capacidade bruta de processamento | m³ petróleo/dia |
| $L_{i,d}$ | Piso técnico se ativa: $0{,}40\, R_{i,d} K^P_{i,d}$ | m³/dia |
| $D_d$ | Proxy de demanda de gasolina A, já ajustado | m³ |
| $x_{i,d}$ | Alocação planejada | m³ |
| $y_{i,d}$ | Ativação | $\{0, 1\}$ |
| $u_d$ | Déficit | m³ |
| $S_d$ | Estoque final nacional | m³ |
| $P_d$ | Processamento implícito do dia | m³ petróleo |

A demanda e as capacidades diárias são o valor mensal curado dividido pelos
dias daquele mês. $R_{i,d}$ é sorteado uma vez por execução anual, de forma
independente. O piso é $0{,}20$. O teto $\hat R_i$ é o rendimento observado
da refinaria em 2025, $\sum$ gasolina A / $\sum$ petróleo processado. Se
esse valor falta, não é positivo ou passa de $0{,}40$, o teto cai para
$0{,}20$.

$$
R_{i,d} \sim \text{Uniforme}(0{,}20,\ \hat R_i)
$$

A produção efetiva é

$$
C_{i,d} = \min(K^G_{i,d},\ R_{i,d} \cdot K^P_{i,d})
$$

Se $y_{i,d} = 1$, o FUT individual não fica abaixo de 40%:

$$
L_{i,d} = \min(C_{i,d},\ 0{,}40\, R_{i,d} K^P_{i,d})
$$

## Otimização diária

O ano tem orçamento $P_{\max} = 0{,}90 \cdot \sum_d \sum_i K^P_{i,d}$. O
dia $d$ reserva para o futuro a fatia de $P_{\max}$ proporcional ao petróleo
que a demanda restante pediria no rendimento sorteado, e pode usar o
restante até $\sum_i K^P_{i,d}$. $P_d = \sum_i x_{i,d} / R_{i,d}$.

$$
\bar R_d = \frac{\sum_i R_{i,d} K^P_{i,d}}{\sum_i K^P_{i,d}}
$$

Etapa 1: minimizar $u_d$ com $P_d$ limitado a esse teto. Etapa 2: fixar
$u_d$ no ótimo da etapa 1 com tolerância $10^{-6}$ m³ e minimizar $P_d$.

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

$P_d \le \min\bigl(\sum_i K^P_{i,d},\ \text{restante} - P_{\max} \frac{\sum_{s > d} D_s / \bar R_s}{\sum_s D_s / \bar R_s}\bigr)$

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
somas sobre as 13 refinarias, inclusive inativas. FUT individual é só
diagnóstico.

## Controles

$D_d = D_d^{\text{base}} (1 + a/100)$. $S_0$ é o estoque inicial do painel.
