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

`0.158987` é o fator ANP de barril para m³. $K^G$ no CSV é teórico
(`derived_theoretical_not_observed`): $K^P$ vezes o rendimento médio
nacional do mês. Essa coluna não entra no Planejado. O teto de gasolina A
é $\rho R K^P$ de cada refinaria. A coluna de piso observado do CSV
também não entra.

## Rendimento simulado

O sorteio de $R_{i,d}$ usa os rendimentos mensais da própria refinaria em
2025. A produção publicada não é alterada. Meses sem petróleo processado,
ou com A/petróleo $> 1$, ficam de fora da lista. O dia sorteia um desses
valores, com reposição. Sorteio $0$ (ou lista vazia) vira a média nacional
ANP do ano, a mesma coluna `national_avg_gasoline_a_yield_used`. Zero
histórico é mercado, não restrição de processo.

$$
R_{i,d} \in \{R_{i,\text{mês}}: \text{mês válido de } i\}
$$

A demanda e as capacidades diárias são o valor mensal dividido pelos dias
do mês.

A razão nacional 2025 no escopo das 12 refinarias é `0,251151`. O CSV de
rendimentos derivados só documenta a variação histórica mensal por
produto. Não entra no sorteio.

## Histórico 2025

`historical_2025_summary.json` traz produção observada, demanda-alvo e saldo
`produção - demanda`. Não reconstrói estoque. FUT Total:

$$
\text{FUT} = 100 \times \frac{\sum \text{processamento\_obs}}{\sum K^P}
$$

mensal e anual, sobre as 12 refinarias. REPAR em 2025-02 fica com FUT
individual 100,2535% (954.411 m³ processados contra 951.998,117 m³ de
capacidade convertida).

## Escopo

Catálogo em `lib/gasoline_simulator/data/catalog.ex`: RNEST, REFMAT, RECAP,
REDUC, REFAP, REGAP, REPAR, RPBC, REPLAN, REVAP, REAM e RPCC.
Clara Camarão usa `RPCC`, não o rótulo `RECAP` de `estudo_tcc.typ`.

LUBNOR (Fortaleza) fica de fora do Histórico e do Planejado. É a refinaria
de lubrificantes e derivados do Nordeste. A ANP não registra gasolina A
lá em 2025. O parque é de lubrificantes, parafina e asfalto, não de
gasolina. Incluí-la só somaria petróleo no FUT sem A possível.

Fora do modelo: LUBNOR, DAX OIL, MANGUINHOS, PARANÁ XISTO, RIOGRANDENSE,
SSOIL e UNIVEN.

## Limitações

- Um único instantâneo de capacidade cobre o ano inteiro
- $R_{i,d}$ não é rendimento de engenharia por refinaria
