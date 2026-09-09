# Transformações e escopo dos dados

Fórmulas aplicadas sobre as fontes de `docs/data_report.md`.

## Demanda

A ANP publica gasolina C. O modelo usa equivalente de gasolina A:

$$
D_t^{\text{base}} = \text{vendas\_C}_t \times (1 - e_t)
$$

`e_t = 0,27` até 2025-07 (Resolução CNPE 16/2021). `e_t = 0,30` a partir de
2025-08 (Resolução CNPE 9/2025). A série ANP não separa comum e premium. A
fração da comum vale para o total. Proveniência:
`derived_assumption_not_observed`.

## Capacidade

Instantâneo nominal de 2025-12-31, em bbl/dia, repetido em todos os meses:

$$
K^P_{i,t} = \text{nameplate\_bbl\_day} \times \text{dias\_do\_mês} \times 0{,}158987
$$

$$
K^G_{i,t} = K^P_{i,t} \times \text{rendimento\_médio\_nacional}
$$

`0.158987` é o fator ANP de barril para m³. $K^G$ é teórico
(`derived_theoretical_not_observed`). A coluna de piso observado do CSV
não entra no Planejado.

## Rendimento simulado

O teto por refinaria $\hat R_i$ usa produção e processamento observados
de 2025 (razão de somas no ano). Valores fora de $(0,\ 0{,}40]$ viram
piso $0{,}20$.

$$
R_{i,t} \sim \text{Uniforme}(0{,}20,\ \hat R_i)
$$

A razão nacional 2025 no escopo das 13 refinarias é `0,250164`. O CSV de
rendimentos derivados só documenta a variação histórica mensal por
produto. Não entra no sorteio.

## Histórico 2025

`historical_2025_summary.json` traz produção observada, demanda-alvo e saldo
`produção - demanda`. Não reconstrói estoque. FUT Total:

$$
\text{FUT} = 100 \times \frac{\sum \text{processamento\_obs}}{\sum K^P}
$$

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

- $K^G$ usa média nacional
- Um único instantâneo de capacidade cobre o ano inteiro
- $R_{i,t}$ não é rendimento de engenharia por refinaria
