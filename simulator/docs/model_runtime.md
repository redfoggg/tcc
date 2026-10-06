# Execução do modelo

Caminhos relativos a `simulator/`. A matemática está em
`docs/model_specification.md`.

## Módulos

| Módulo | Papel |
|---|---|
| `Data.Repository` | Lê demanda, $K^P$ e rendimentos mensais dos CSVs |
| `Data.Catalog` | Nomes e UFs das 12 refinarias |
| `Refineries.Plant` | GenServer de uma refinaria (`restart: :temporary`) |
| `Refineries.Supervisor` | Árvore `:one_for_one` das 12 plantas |
| `Data.Historical` | Lê `historical_2025_summary.json` |
| `Scenarios.YieldSampling` | Sorteia $R_{i,d}$ na lista mensal válida da refinaria |
| `Models.Overrides` | Struct de estoque inicial e ajuste de demanda |
| `Models.Problem` | Monta o dia e a entrada do NIF |
| `Models.Refinery` | Struct da refinaria no problema |
| `Models.Result` | Junta solução nativa, FUT e rendimento usado |
| `Models.Plan` | Estado em memória de uma execução |
| `Scenarios.Runner` | Sequência dos 365 dias (no painel, no mínimo 30 s) |
| `Scenarios.Orchestrator` | Planos, monitor das plantas e PubSub |
| `Scenarios.Methodology` | Dez cenários da bateria e a montagem de cada execução |
| `Scenarios.Study` | Bateria em segundo plano, separada das plantas do painel |
| `Scenarios.Export` | CSV de cada execução e `manifest.csv` |
| `Solver` / `Solver.Native` | Timeout Elixir e NIF Rustler |

Structs de domínio ficam em `lib/gasoline_simulator/models/`.

## Resolução nativa

`native/gasoline_solver` usa `good_lp` e HiGHS. Uma chamada resolve um dia,
com uma função só. Toda planta do dia fica ligada. A função soma o
déficit (peso $1$ por m³) e o uso dos tetos (peso $10^{-4}$ m³ por ponto
de $x/C$). O tempo limite vale para essa resolução. Não há teto global
de petróleo. Cada planta
cabe em $C_{i,d} = \rho_{i,d} R_{i,d} K^P_{i,d}$.
Planta que já está no ar no dia 1 abre com $\rho = 1$.
Planta religada (processo de volta) entra com $\rho = 0{,}40$ e sobe
$1$ p.p. por dia até $1$. Depois o ciclo aberto / descida / trava em
$0{,}90$ pelo excesso. Padrão Elixir: 5.000 ms por dia. `Optimal` e
`GapLimit` são aceitos.

Timeout nativo ou `Task.yield` viram `:timeout` e interrompem o ano. O NIF
em dirty CPU não é cancelável.

Falhas genuínas: `:solver_failure`, `:solver_panic`, `:timeout`. Déficit
com `status :ok` não interrompe.

## Resultado

Cada dia traz saldo, FUT Total, processamento implícito, capacidade bruta,
estoques, produção, demanda atendida, déficit, cobertura e as refinarias
no ar naquele dia, com o `simulated_yield` usado. Ativação se o binário
for maior que 0,5. Planta derrubada no painel não entra em $F_d$.

O mensal e o anual somam os dias. O painel mostra só esses agregados.

## Painel

A página está em português. Planos vivem só na memória do `GenServer`.
O cartão de cada refinaria mostra o FUT do último dia resolvido e a
gasolina A acumulada no Planejado em curso. Os dois valores atualizam
a cada dia. Planta ausente fica em 0% e mantém o volume já produzido.

## Bateria

O botão "Rodar bateria" dispara os dez cenários de
`docs/methodology.md`, dez vezes cada, e grava CSV em `data/studies/`.
Essa execução chama o `Runner` com a própria lista de plantas no ar.
Os GenServers do painel permanecem como o usuário os deixou. Estoque
e demanda vêm do cenário. O ano da bateria segue direto, sem a espera
de 30 s do painel.
