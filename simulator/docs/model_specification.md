# Especificação do modelo

O Planejado 2025 resolve um MILP por mês e transporta só o estoque. O
Histórico 2025 não é uma execução do modelo. Fontes e conversões:
`docs/data_report.md` e `docs/data_transformations.md`. Contrato de software:
`docs/model_runtime.md`.

## Conjuntos

- $T = \{1, \ldots, 12\}$: meses de 2025
- $F$: 13 refinarias de `estudo_tcc.typ` (LUBNOR, REAM, RECAP, REDUC, REFAP,
  REFMAT, REGAP, REPAR, REPLAN, REVAP, RNEST, RPBC, RPCC)
- Toda $i \in F$ entra em todo $t$.

## Símbolos

| Símbolo | Significado | Unidade |
|---|---|---|
| $R_{i,t}$ | Rendimento simulado de gasolina A | $[0{,}20,\ \hat R_i]$ |
| $K^G_{i,t}$ | Capacidade teórica curada de gasolina A | m³/mês |
| $K^P_{i,t}$ | Capacidade bruta de processamento | m³ petróleo/mês |
| $L_{i,t}$ | Piso técnico se ativa: $0{,}40\, R_{i,t} K^P_{i,t}$ | m³/mês |
| $D_t$ | Proxy de demanda de gasolina A, já ajustado | m³ |
| $x_{i,t}$ | Alocação planejada | m³ |
| $y_{i,t}$ | Ativação | $\{0, 1\}$ |
| $u_t$ | Déficit | m³ |
| $S_t$ | Estoque final nacional | m³ |
| $P_t$ | Processamento implícito do mês | m³ petróleo |

$R_{i,t}$ é sorteado uma vez por execução anual, de forma independente.
O piso é $0{,}20$. O teto $\hat R_i$ é o rendimento observado da refinaria
em 2025, $\sum$ gasolina A / $\sum$ petróleo processado. Se esse valor
falta, não é positivo ou passa de $0{,}40$, o teto cai para $0{,}20$.

$$
R_{i,t} \sim \text{Uniforme}(0{,}20,\ \hat R_i)
$$

A produção efetiva é

$$
C_{i,t} = \min(K^G_{i,t},\ R_{i,t} \cdot K^P_{i,t})
$$

Se $y_{i,t} = 1$, o FUT individual não fica abaixo de 40%:

$$
L_{i,t} = \min(C_{i,t},\ 0{,}40\, R_{i,t} K^P_{i,t})
$$

## Otimização mensal

O ano tem orçamento $P_{\max} = 0{,}90 \cdot \sum_t \sum_i K^P_{i,t}$. O
mês $t$ reserva para o futuro a fatia de $P_{\max}$ proporcional ao petróleo
que a demanda restante pediria no rendimento sorteado, e pode usar o
restante até $\sum_i K^P_{i,t}$. $P_t = \sum_i x_{i,t} / R_{i,t}$.

$$
\bar R_t = \frac{\sum_i R_{i,t} K^P_{i,t}}{\sum_i K^P_{i,t}}
$$

Etapa 1: minimizar $u_t$ com $P_t$ limitado a esse teto. Etapa 2: fixar
$u_t$ no ótimo da etapa 1 com tolerância $10^{-6}$ m³ e minimizar $P_t$.

## Restrições

$$
0 \le x_{i,t} \le y_{i,t} \, C_{i,t}
$$

$$
x_{i,t} \ge y_{i,t} \, L_{i,t}
$$

$$
L_{i,t} \le C_{i,t}
$$

$$
S_{t-1} + \sum_i x_{i,t} + u_t - D_t - S_t = 0
$$

$P_t \le \min\bigl(\sum_i K^P_{i,t},\ \text{restante} - P_{\max} \frac{\sum_{s > t} D_s / \bar R_s}{\sum_s D_s / \bar R_s}\bigr)$

$$
u_t \ge 0, \quad S_t \ge 0, \quad y_{i,t} \in \{0, 1\}
$$

$S_0$ vem do painel. Para $t > 1$, $S_{t-1}$ é o estoque resolvido do mês
anterior.

## FUT

Processamento planejado: $P_{i,t} = x_{i,t} / R_{i,t}$.

$$
\text{FUT}_{\text{Total}, t} = 100 \times \frac{\sum_i P_{i,t}}{\sum_i K^P_{i,t}}
$$

$$
\text{FUT}_{\text{Total}, \text{ano}} = 100 \times \frac{\sum_t \sum_i P_{i,t}}{\sum_t \sum_i K^P_{i,t}}
$$

O Histórico usa o mesmo formato com processamento observado. Sempre razão de
somas sobre as 13 refinarias, inclusive inativas. FUT individual é só
diagnóstico.

## Controles

$D_t = D_t^{\text{base}} (1 + a/100)$. $S_0$ é o estoque inicial do painel.
