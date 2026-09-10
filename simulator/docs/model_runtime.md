# Execução do modelo

Caminhos relativos a `simulator/`. A matemática está em
`docs/model_specification.md`.

## Módulos

| Módulo | Papel |
|---|---|
| `Data.Repository` | Lê demanda, $K^P$ e $\hat R_i$ dos CSVs |
| `Data.Catalog` | Nomes e UFs das 12 refinarias |
| `Data.Historical` | Lê `historical_2025_summary.json` |
| `Scenarios.YieldSampling` | Sorteia $R_{i,d}$ na lista mensal válida da refinaria |
| `Models.Overrides` | Struct de estoque inicial e ajuste de demanda |
| `Models.Problem` | Monta o mês e a entrada do NIF |
| `Models.Refinery` | Struct da refinaria no problema |
| `Models.Result` | Junta solução nativa, FUT e rendimento usado |
| `Models.Plan` | Estado em memória de uma execução |
| `Scenarios.Runner` | Sequência dos 365 dias e agregado mensal e anual |
| `Scenarios.Orchestrator` | `GenServer` e PubSub do painel |
| `Solver` / `Solver.Native` | Timeout Elixir e NIF Rustler |

Structs de domínio ficam em `lib/gasoline_simulator/models/`.

## Resolução nativa

`native/gasoline_solver` usa `good_lp` e HiGHS. Uma chamada resolve um dia.
A etapa 1 recebe o orçamento de tempo inteiro e minimiza o déficit. A
etapa 2 recebe o tempo restante e penaliza utilização alta
($x_{i,d}/C_{i,d}$). O teto de petróleo do dia é a soma de
$\rho_{i,d} K^P_{i,d}$. $\rho$ sobe até 1, só desce depois do pico, e
trava em $0{,}90$ pelo excesso do ciclo. Padrão Elixir: 5.000 ms por dia.
`Optimal` e `GapLimit` são aceitos.

A checagem nativa exige rendimento finito e positivo e `max_petroleum`
finito e não negativo. Timeout nativo ou
`Task.yield` viram `:timeout` e interrompem o ano. O NIF em dirty CPU não é
cancelável.

Falhas genuínas: `:invalid_input`, `:solver_failure`, `:solver_panic`,
`:timeout`. Déficit com `status :ok` não interrompe.

## Resultado

Cada dia traz saldo, FUT Total, processamento implícito, capacidade bruta,
estoques, produção, demanda atendida, déficit, cobertura e as 12 refinarias
com o `simulated_yield` usado. Ativação se o binário for maior que 0,5.

O mensal e o anual somam os dias. O painel mostra só esses agregados.

## Painel

A página está em português. Planos vivem só na memória do `GenServer`.
