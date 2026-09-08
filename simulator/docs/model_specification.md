# Especificação do modelo

O Planejado 2025 resolve um MILP por mês e transporta só o estoque. O
Histórico 2025 não é uma execução do modelo. Fontes e conversões:
`docs/data_report.md` e `docs/data_transformations.md`. Contrato de software:
`docs/model_runtime.md`.

## Conjuntos

- `T = {1, ..., 12}`: meses de 2025
- `F`: 13 refinarias de `estudo_tcc.typ` (LUBNOR, REAM, RECAP, REDUC, REFAP,
  REFMAT, REGAP, REPAR, REPLAN, REVAP, RNEST, RPBC, RPCC)
- Toda `i ∈ F` entra em todo `t`. Não há exclusão, parada nem degradação.

## Símbolos

| Símbolo | Significado | Unidade |
|---|---|---|
| `R_{i,t}` | Rendimento simulado de gasolina A | `[0.20, 0.25]` |
| `K^G_{i,t}` | Capacidade teórica curada de gasolina A | m³/mês |
| `K^P_{i,t}` | Capacidade bruta de processamento | m³ petróleo/mês |
| `L_{i,t}` | Piso operacional, limitado a `K^G_{i,t}` | m³/mês |
| `D_t` | Proxy de demanda de gasolina A, já ajustado | m³ |
| `x_{i,t}` | Alocação planejada | m³ |
| `y_{i,t}` | Ativação | `{0, 1}` |
| `u_t` | Déficit | m³ |
| `S_t` | Estoque final nacional | m³ |

`R_{i,t}` é sorteado uma vez por execução anual, de forma independente:

```
R_{i,t} ~ Uniforme(0.20, 0.25)
```

O intervalo vem do agregado nacional observado. A uniforme é premissa do
modelo. Não há semente. O único teto de produção é `K^G_{i,t}`. `K^P_{i,t}`
só entra no FUT.

## Otimização mensal

Etapa 1: minimizar `u_t`. Etapa 2: fixar `u_t` no ótimo da etapa 1 com
tolerância `10^{-6}` m³ e minimizar o processamento implícito

```
sum_{i ∈ F} x_{i,t} / R_{i,t}
```

Isso equivale a minimizar o FUT Total do mês, porque o denominador
`sum_i K^P_{i,t}` é constante. Déficit não é falha. Não existe `lambda`.

## Restrições

```
0 ≤ x_{i,t} ≤ y_{i,t} K^G_{i,t}
x_{i,t} ≥ y_{i,t} L_{i,t}
S_{t-1} + sum_i x_{i,t} + u_t - D_t - S_t = 0
u_t ≥ 0,  S_t ≥ 0,  y_{i,t} ∈ {0, 1}
```

O piso não força ativação. `S_0` vem do painel. Para `t > 1`, `S_{t-1}` é o
estoque resolvido do mês anterior.

## FUT

Processamento planejado: `P_{i,t} = x_{i,t} / R_{i,t}`.

```
FUT_Total_t = 100 * sum_i P_{i,t} / sum_i K^P_{i,t}
FUT_Total_ano = 100 * sum_t sum_i P_{i,t} / sum_t sum_i K^P_{i,t}
```

O Histórico usa o mesmo formato com processamento observado. Sempre razão de
somas sobre as 13 refinarias, inclusive inativas. FUT individual é só
diagnóstico. Pode passar de 100% porque `K^G` usa rendimento médio nacional,
não o `R_{i,t}` sorteado.

## Controles

`D_t = D_t^{base} (1 + a/100)`. Pisos do usuário são limitados a `K^G_{i,t}`.
O ano não é otimizado em conjunto.
