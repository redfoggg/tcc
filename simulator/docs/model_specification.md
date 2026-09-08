# Especificação do modelo de alocação de gasolina

Este documento especifica o modelo de otimização implementado pelo solver em
Rust (`native/gasoline_solver/src/model.rs`, `solve.rs`, `error.rs`), pela
camada de sequenciamento em Elixir (`lib/gasoline_simulator/problem.ex`,
`result.ex`, `scenarios/runner.ex`, `scenarios/overrides.ex`), junto com os
dados estáticos de 2025 derivados da ANP que o alimentam
(`data/curated/anp_2025_*`). Veja `docs/data_report.md` para fontes,
premissas e escopo de refinarias.

O painel tem dois lados distintos. Histórico 2025 não é uma execução do
modelo. Ele lê `data/curated/historical_2025_summary.json`, cujos totais
mensais e anuais de produção, demanda, saldo assinado e FUT Total foram
pré-computados a partir dos CSVs curados de origem. Planejado 2025 executa o
modelo especificado abaixo uma vez, de janeiro a dezembro.

## 1. Conjuntos e sequenciamento anual

- `M`: meses do ano de referência (`2025-01` .. `2025-12`).
- `F`: o escopo fixo de 13 refinarias listadas no `estudo_tcc.typ`. Todas as
  refinarias de `F` participam de todo mês `t`, com capacidade máxima curada
  e um rendimento de referência válido, incluindo o fallback nacional quando
  aplicável. Não existe mais nenhum conceito de exclusão de refinaria por mês.
- Um MILP é resolvido por mês (`GasolineSimulator.Solver.solve/2`, uma
  chamada nativa por mês). `GasolineSimulator.Scenarios.Runner.run/2` conduz
  a sequência: resolve o mês 1, usa seu estoque final como estoque inicial do
  mês 2, e assim por diante até o mês 12. Se a resolução de algum mês
  retornar uma falha genuína (`:invalid_input`, `:solver_failure`,
  `:solver_panic` ou `:timeout`), toda a execução é interrompida naquele mês.
  Um déficit de demanda nunca é uma falha, veja a seção 7.

## 2. Parâmetros (por mês `t`, por refinaria `i in F`)

| Símbolo | Campo | Significado | Unidade |
|---|---|---|---|
| `demand_t` | `demand_m3` | Proxy de demanda nacional de gasolina A para o mês `t` (após qualquer ajuste de demanda planejado) | m³ |
| `S_{t-1}` | `initial_inventory_m3` | Estoque nacional inicial do mês `t`, igual ao estoque final do mês `t-1` (ou o estoque inicial editável pelo usuário para o mês 1) | m³ |
| `R_i` | `reference_yield` | Rendimento de referência fixo de gasolina A da refinaria `i`, constante para os doze meses de 2025 (veja a seção 3) | adimensional, `> 0` |
| `capacity_{i,t}` | `capacity_m3` | Capacidade máxima mensal curada de gasolina A, `K^G_{i,t}` | m³ |
| `processing_capacity_{i,t}` | `processing_capacity_m3` | Capacidade bruta mensal de processamento de petróleo, `K^P_{i,t}` | m³ |
| `floor_i` | `floor_m3` | Produção mínima mensal de gasolina A da refinaria `i` quando ativa | m³ |

`capacity_m3` e `processing_capacity_m3` vêm de
`anp_2025_refinery_capacity_monthly.csv` (`capacity_gasoline_a_m3_month` e
`capacity_m3_month`). `floor_m3` vem de `operating_floor_m3_2025` no mesmo
arquivo, e é sempre limitado (clampado) para nunca exceder `capacity_m3`.
`reference_yield` vem de `anp_2025_reference_yields_by_refinery.csv`.
`demand_m3` vem de `anp_2025_demand_proxy_national_monthly.csv`
(`gasolina_a_equivalent_m3`). Todos os volumes são em metros cúbicos (m³).

## 3. Rendimento de referência `R_i` (`anp_2025_reference_yields_by_refinery.csv`)

Diferente de uma previsão móvel mensal, o modelo usa um único rendimento de
referência anual fixo por refinaria, o mesmo nos doze meses de 2025:

```
R_i = sum_t producao_gasolina_a_{i,t} / sum_t petroleo_processado_{i,t}
```

Essa razão local só é aceita quando é finita, o denominador é positivo e
`0 < R_i <= 1`. Caso contrário, `R_i` é o fallback nacional ponderado,
calculado apenas a partir das refinarias com razão local válida. Duas
refinarias do escopo fixo usam o fallback nacional em 2025 (LUBNOR e REAM).
Veja `docs/data_report.md#rendimento-de-referência-fixo-por-refinaria` para a
fórmula completa do fallback e a proveniência de cada refinaria.

## 4. Variáveis de decisão (por mês, por refinaria `i in F`)

- `allocation_i in [0, capacity_{i,t}]` (contínua): produção de gasolina A
  alocada à refinaria `i` no mês, em m³.
- `active_i in {0, 1}` (binária): se a refinaria `i` está produzindo naquele
  mês.
- `deficit >= 0` (contínua, uma por mês): demanda não atendida após estoque e
  produção (`u_t`).
- `ending_inventory >= 0` (contínua, uma por mês): estoque nacional
  transportado para o mês seguinte (`S_t`).

## 5. Otimização lexicográfica em duas etapas

Cada mês é resolvido em duas etapas estritas, sem nenhum peso de penalidade
combinando os dois objetivos em uma única expressão:

**Etapa 1** minimiza o déficit:

```
minimizar  deficit
sujeito a  todas as restrições da seção 6
```

**Etapa 2** fixa o déficit no ótimo encontrado na etapa 1 (dentro de uma
tolerância numérica de `1e-6` m³) e então minimiza o processamento total de
petróleo implícito nas alocações:

```
minimizar  sum_{i in F} allocation_i / R_i
sujeito a  todas as restrições da seção 6
           deficit_etapa1 - tolerância <= deficit <= deficit_etapa1 + tolerância
```

O termo minimizado na etapa 2 é o processamento total de petróleo necessário
para produzir a gasolina A alocada. Como o denominador do FUT Total do mês
(a soma da capacidade bruta de processamento de todo o escopo fixo) é
constante dentro de um mês, minimizar esse processamento total é equivalente
a minimizar o FUT Total daquele mês, mas o FUT Total exato é reportado como a
razão de fato, não inferido do valor do objetivo.

Essa formulação em duas etapas prioriza estritamente o atendimento da
demanda: nenhuma quantidade de economia de processamento de petróleo pode
justificar um déficit maior do que o estritamente necessário, porque a etapa
2 nunca reabre a escolha do déficit.

## 6. Restrições

Para toda `i in F`:

1. **Vínculo entre ativação binária e capacidade**
   `allocation_i <= active_i * capacity_{i,t}`
2. **Piso operacional**
   `allocation_i >= active_i * floor_i`
   Quando `active_i = 0` esta restrição é vazia, portanto o piso nunca força
   uma refinaria a ficar ativa, apenas restringe quanto uma refinaria ativa
   deve produzir.

Balanço de estoque do sistema para o mês:

3. `S_{t-1} + sum_{i in F} allocation_i - demand_t + deficit - ending_inventory = 0`
   ou seja `ending_inventory = S_{t-1} + production_t - demand_t + deficit`,
   com `ending_inventory >= 0` e `deficit >= 0` garantidos pelos próprios
   limites das variáveis. A demanda atendida no mês é `demand_t - deficit`.

Não há restrição exigindo `sum_{i} allocation_i >= demand_t`: qualquer falta
que o sistema realmente não consiga cobrir com estoque e produção é absorvida
por `deficit`, nunca por inviabilidade do solver (veja a seção 7).

## 7. Déficit versus inviabilidade

Uma falta de demanda é sempre viável: `deficit` pode crescer sem limite para
satisfazer a equação de balanço, então uma demanda que excede a capacidade e
o estoque disponíveis nunca torna o MILP inviável.
`GasolineSimulator.Result` nunca reporta `deficit_m3 > 0` como status de
falha, `status` permanece `:ok`.

Uma inviabilidade inesperada do HiGHS indica um modelo malformado ou uma
falha numérica, e é reportada como `SolverError::SolverFailure`.

O painel controlado e os CSVs curados estáticos são confiáveis. A única
verificação matemática mínima aplicada na fronteira do solver em Rust é que
o rendimento de referência de cada refinaria seja finito e positivo, exigido
pela própria divisão `allocation_i / R_i` no objetivo da etapa 2. Um valor
inválido retorna `SolverError::InvalidInput`.

Os CSVs curados em `data/curated/` são tratados como um conjunto de dados
fixo e já validado: `GasolineSimulator.Data.Repository` os interpreta
diretamente, sem reafirmar vocabulários de proveniência, restrições de sinal
ou limites entre campos em tempo de execução. `docs/data_report.md` é a
autoridade sobre como esses arquivos foram produzidos.

## 8. Contrato de resultado

Saída do solver nativo (`SolverOutput` em `model.rs`), em caso de sucesso,
por mês:

| Campo | Significado |
|---|---|
| `demand` | Demanda de entrada do mês, ecoada |
| `starting_inventory` | `S_{t-1}` ecoado |
| `ending_inventory` | `S_t` resolvido |
| `production` | `sum_i allocation_i` |
| `served_demand` | `demand - deficit` |
| `deficit` | `u_t` resolvido |
| `coverage` | `served_demand / demand`, ou `1.0` se `demand = 0` |
| `facilities` | Lista de `FacilityResult` por refinaria |

`FacilityResult` por refinaria: `id`, `allocated`, `active` (arredondado em
`> 0.5`), `utilization` (`allocated / capacity`, ou `0.0` se `capacity = 0`),
`binding_capacity` (`true` se ativa e `capacity - allocated <= 1e-6`).

`GasolineSimulator.Result.from_solver/2` envolve isso por mês em
`%Result{}`: `status` (`:ok`, ou um átomo de tipo de erro em caso de falha),
`month`, saldo, FUT Total, processamento de petróleo total e capacidade de
processamento total do mês, demanda, estoques, produção, demanda atendida,
déficit, cobertura, motivo de falha, e `refineries` (todas as 13 refinarias
do escopo fixo, mescladas com seu resultado do solver, rendimento de
referência e proveniência).

Cada refinaria em `refineries` inclui identidade, rendimento de referência e
proveniência, capacidades, piso, alocação, processamento implícito de
petróleo, FUT individual (diagnóstico), ativação, utilização e a sinalização
de capacidade binding.

`GasolineSimulator.Scenarios.Runner.run/2` retorna
`{:ok, %{months: [%Result{}, ...], annual: annual_summary}}`, onde
`annual_summary` soma `demand_m3`/`production_m3`/`served_demand_m3`/
`deficit_m3`/processamento de petróleo total/capacidade de processamento
total ao longo dos doze meses, ecoa o `starting_inventory_m3` do ano (mês 1)
e o `ending_inventory_m3` (mês 12), recalcula a `coverage` anual, e lista
`active_refinery_ids`. O FUT Total anual é a razão de somas entre o
processamento total de petróleo somado nos doze meses e a capacidade de
processamento total somada nos doze meses, nunca a média das doze razões
mensais. Em caso de falha genuína de algum mês, retorna
`{:error, %Result{}}` para o mês que falhou.

## 9. Controles de planejamento anual (`GasolineSimulator.Scenarios.Overrides`)

Aplicados uniformemente aos doze meses de uma execução anual:

- `initial_inventory_m3`: substitui o padrão `0.0` de estoque inicial de
  janeiro.
- `demand_adjustment_pct`: escala a demanda de cada mês por
  `(1 + pct / 100)`.
- `floor_overrides`: substituição por refinaria do piso operacional padrão,
  sempre limitada (clampada) para não exceder a capacidade daquele mês.

O painel executa um único processo anual planejado com esses controles. Não
há execução de solver de linha de base, segundo cenário, seletor de mês, nem
qualquer controle de disponibilidade, degradação de rendimento ou parada
predefinida: todas as 13 refinarias do escopo fixo são sempre elegíveis para
produzir em todo mês.

## 10. Proxy de demanda de gasolina A a partir de gasolina C

A série de vendas de combustíveis da ANP reporta **gasolina C**: o produto
varejista misturado com etanol, vendido no posto. As refinarias produzem
**gasolina A**: o produto sem mistura, antes da adição de etanol anidro a
jusante. `demand_m3` é, portanto, um equivalente de gasolina A, não a cifra
bruta de vendas:

```
gasolina_a_equivalent_m3 = gasolina_c_sales_m3 * (1 - ethanol_anidro_fraction_assumed)
```

usando a fração de mistura de etanol anidro determinada pelo CNPE para a
gasolina C comum naquele mês (`0,27` até 2025-07, `0,30` a partir de
2025-08). Veja
`docs/data_report.md#proxy-de-demanda-de-gasolina-c-para-gasolina-a` para a
citação regulatória completa e o vocabulário de proveniência.

## 11. Comportamento de timeout

`solve(input, time_limit_secs)` recebe um orçamento de tempo obrigatório em
segundos para a resolução de um mês, repartido entre as duas etapas: a etapa
1 recebe o orçamento completo, e a etapa 2 recebe o tempo restante após a
etapa 1 terminar. Dois caminhos produzem `SolverError::Timeout`: o solver
retorna `SolutionStatus::TimeLimit` (encontrou uma solução ou um limite mas
não conseguiu certificar otimalidade) em qualquer etapa, ou retorna
`ResolutionError::Other("NoSolutionFound")`. Do lado do Elixir, a opção
`:timeout` (milissegundos) de `GasolineSimulator.Solver.solve/2` é convertida
para segundos e repassada ao mesmo limite nativo. Se a espera externa de
`Task.yield` desistir primeiro, o chamador ainda recebe
`{:error, {:timeout, reason}}`, o que interrompe a execução anual naquele
mês, mesmo que o NIF dirty CPU subjacente continue em execução até o fim.

## 12. Limitações conhecidas do modelo

- A capacidade de refino é um único instantâneo nominal referente a
  `2025-12-31`, aplicado uniformemente a todos os meses de 2025, portanto
  mudanças de capacidade dentro do ano não são capturadas, e
  `capacity_gasoline_a_m3_month` usa um rendimento médio nacional em vez do
  rendimento próprio de cada refinaria. Isso pode fazer o FUT Total planejado
  ultrapassar 100%, já que uma refinaria com rendimento de referência próprio
  bem acima da média nacional pode ter sua capacidade teórica de gasolina A
  subestimada por essa fórmula, veja `docs/data_report.md`.
- O piso operacional é derivado uma única vez a partir da menor produção
  mensal observada de gasolina A de uma refinaria ao longo de 2025 e mantido
  constante durante o ano. Ele não distingue uma taxa mínima de operação
  genuína de um mês afetado por uma parada não relacionada.
- O catálogo de refinarias é fixo às refinarias explicitamente listadas no
  `estudo_tcc.typ` da raiz. Veja `docs/data_report.md` para o escopo
  completo.
- `data/curated/anp_2025_*` é entrada acadêmica estática e versionada para
  2025. Não há automação de download ou regeneração neste repositório.
