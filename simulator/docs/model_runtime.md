# Execução do modelo

Caminhos relativos a `simulator/`. A matemática está em
`docs/model_specification.md`.

## Módulos

| Módulo | Papel |
|---|---|
| `Data.Repository` | Lê demanda, $K^G$, $K^P$ e $\hat R_i$ dos CSVs |
| `Data.Catalog` | Nomes, UFs e aliases das 13 refinarias |
| `Data.Historical` | Lê `historical_2025_summary.json` |
| `Scenarios.YieldSampling` | Sorteia $R_{i,t} \sim \text{Uniforme}(0{,}20,\ \hat R_i)$ |
| `Models.Overrides` | Estoque inicial e ajuste de demanda |
| `Models.Problem` | Monta o mês e a entrada do NIF |
| `Models.Refinery` | Struct da refinaria no problema |
| `Models.Result` | Junta solução nativa, FUT e rendimento usado |
| `Models.Plan` | Estado em memória de uma execução |
| `Scenarios.Runner` | Sequência jan-dez e resumo anual |
| `Scenarios.Orchestrator` | `GenServer` e PubSub do painel |
| `Scenarios.PlanningExport` | JSON esquema `5.0.0` |
| `Solver` / `Solver.Native` | Timeout Elixir e NIF Rustler |

Structs de domínio ficam em `lib/gasoline_simulator/models/`.

## Resolução nativa

`native/gasoline_solver` usa `good_lp` e HiGHS. Uma chamada resolve um mês.
A etapa 1 recebe o orçamento de tempo inteiro. A etapa 2 recebe o tempo
restante. O Runner fatia o orçamento anual de petróleo por $D_t / \bar R_t$
e envia o teto do mês. Padrão
Elixir: 5.000 ms por mês. `Optimal` e `GapLimit` são aceitos.

A checagem nativa exige rendimento finito e positivo e `max_petroleum`
finito e não negativo. Timeout nativo ou
`Task.yield` viram `:timeout` e interrompem o ano. O NIF em dirty CPU não é
cancelável.

Falhas genuínas: `:invalid_input`, `:solver_failure`, `:solver_panic`,
`:timeout`. Déficit com `status :ok` não interrompe.

## Resultado

Cada mês traz saldo, FUT Total, processamento implícito, capacidade bruta,
estoques, produção, demanda atendida, déficit, cobertura e as 13 refinarias
com o `simulated_yield` usado. Ativação se o binário for maior que 0,5.
Capacidade binding se ativa e $K^G - x \le 10^{-6}$.

O anual soma volumes e processamentos. Também lista `active_refinery_ids`.

## Painel e exportação

A página está em português. `GET /api/plans/:planned_id` exporta Histórico e
Planejado. `planned.mechanics` guarda o rendimento sorteado de cada
refinaria-mês. Planos vivem só na memória do `GenServer`.
