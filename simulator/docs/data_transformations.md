# Transformações e escopo dos dados

Fórmulas aplicadas sobre as fontes de `docs/data_report.md`.

## Demanda

A ANP publica gasolina C. O modelo usa equivalente de gasolina A:

```
D_t^{base} = vendas_C_t * (1 - e_t)
```

`e_t = 0,27` até 2025-07 (Resolução CNPE 16/2021). `e_t = 0,30` a partir de
2025-08 (Resolução CNPE 9/2025). A série ANP não separa comum e premium. A
fração da comum vale para o total. Proveniência:
`derived_assumption_not_observed`.

## Capacidade

Instantâneo nominal de 2025-12-31, em bbl/dia, repetido em todos os meses:

```
K^P_{i,t} = nameplate_bbl_day * dias_do_mês * 0.158987
K^G_{i,t} = K^P_{i,t} * rendimento_médio_nacional
```

`0.158987` é o fator ANP de barril para m³. `K^G` é teórico
(`derived_theoretical_not_observed`). O piso `L_i` é a menor produção mensal
observada de gasolina A em 2025, limitada a `K^G_{i,t}`.

## Rendimento simulado

```
R_{i,t} ~ Uniforme(0.20, 0.25)
```

A razão nacional 2025 no escopo das 13 refinarias é `0,250164`
(`sum` produção / `sum` processamento, 156 pares refinaria-mês). Isso
calibra o intervalo. A uniforme é premissa. O CSV de rendimentos derivados
só documenta a variação histórica. Não entra no solver.

## Histórico 2025

`historical_2025_summary.json` traz produção observada, demanda-alvo e saldo
`produção - demanda`. Não reconstrói estoque. FUT Total:

```
100 * sum processamento_obs / sum K^P
```

mensal e anual, sobre as 13 refinarias. REPAR em 2025-02 fica com FUT
individual 100,2535% (954.411 m³ processados contra 951.998,117 m³ de
capacidade convertida).

## Escopo

Catálogo em `lib/gasoline_simulator/data/catalog.ex`: RNEST, REFMAT (aliases
RLAM, CEBV), RECAP, REDUC, REFAP, REGAP, REPAR, RPBC, REPLAN, REVAP, LUBNOR,
REAM (alias REMAN) e RPCC. Clara Camarão usa `RPCC`, não o rótulo `RECAP` de
`estudo_tcc.typ`. Fora do modelo: DAX OIL, MANGUINHOS, PARANÁ XISTO,
RIOGRANDENSE, SSOIL e UNIVEN.

## Limitações

- `K^G` usa média nacional, não o `R_{i,t}` sorteado, então o FUT planejado
  pode passar de 100%
- Um único instantâneo de capacidade cobre o ano inteiro
- O piso não separa operação mínima de parada pontual
- `R_{i,t}` não é rendimento de engenharia por refinaria
