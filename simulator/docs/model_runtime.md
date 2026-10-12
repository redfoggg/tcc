# Execução do modelo

Caminhos relativos a `simulator/`. A matemática está em
`docs/model_specification.md`.

## Módulos

| Módulo | Papel |
|---|---|
| `Data.Repository` | Lê demanda, $K^P$ e rendimentos mensais dos CSVs |
| `Data.Catalog` | Nomes e UFs das 12 refinarias |
| `Refineries.Plant` | GenServer de uma refinaria (`restart: :temporary`). Avisa origem e destino se a entrega cai. Conta perdas seguidas da rota e pausa 10 dias depois de 3 |
| `Refineries.Delivery` | Processo de uma carga em trânsito (`restart: :temporary`) |
| `Refineries.DeliverySupervisor` | Árvore das entregas. Falha logística encerra o processo da carga |
| `Refineries.Distances` | Quilômetros de rodovia de cada par e os dias de caminhão |
| `Refineries.Logistics` | Pergunta quem responde, soma o que chegou e manda a sobra de quem passou do plano para quem ficou abaixo |
| `Refineries.Supervisor` | Árvore `:one_for_one` das 12 plantas |
| `Data.Historical` | Lê `historical_2025_summary.json` |
| `Scenarios.YieldSampling` | Sorteia $R_{i,d}$ na lista mensal válida da refinaria |
| `Models.Overrides` | Ajuste de demanda e dias de trânsito |
| `Models.Problem` | Monta o dia e a entrada do NIF |
| `Models.Refinery` | Struct da refinaria no problema |
| `Models.Result` | Junta solução nativa, FUT e rendimento usado |
| `Models.Plan` | Estado em memória de uma execução |
| `Scenarios.Runner` | Sequência dos 365 dias (no painel, no mínimo 30 s) |
| `Scenarios.Orchestrator` | Planos, monitor das plantas e PubSub |
| `Scenarios.Methodology` | Onze cenários da bateria e a montagem de cada execução |
| `Scenarios.Study` | Bateria em segundo plano, separada das plantas do painel |
| `Scenarios.Export` | CSV de cada execução e `manifest.csv` |
| `Solver` / `Solver.Native` | Timeout Elixir e NIF Rustler |

Structs de domínio ficam em `lib/gasoline_simulator/models/`.

## Resolução nativa

`native/gasoline_solver` usa `good_lp` e HiGHS. Uma chamada planeja o
dia inteiro. O piso de cada planta é o FUT aceitável, $94\%$ no padrão,
ou o degrau da rampa. O teto é $100\%$. A função soma o déficit nacional
(peso $1$ por m³), o excesso (peso $10^{-4}$) e o uso dos tetos (peso
$10^{-4}$ por ponto de $P/C$). O plano devolvido é o petróleo da campanha
de cada planta. O HiGHS não vê o rendimento sorteado. No dia 1 a demanda
de gasolina entra dividida pela média nacional. Do dia 2 em diante entra
dividida pela gasolina realizada até o dia anterior, sobre o petróleo
processado até o dia anterior. Na execução, a gasolina da
planta é esse petróleo vezes
$R_{i,d}$, e o déficit do dia é recalculado com esse volume. Não há teto
global de petróleo. Cada planta cabe em
$C_{i,d} = \max(K^P_{i,d} - O_{i,d}, 0)$.
$O_{i,d}$ são as outras cargas observadas do mês, em base diária.
Planta que já está no ar no dia 1 oferece piso no FUT aceitável. O padrão
é $0{,}94$ e entra por `sustainable_utilization_ratio`. Planta religada
oferece piso em $\rho = 0{,}40$ e sobe $1$ p.p. por dia até esse valor.
O planejamento pode subir qualquer planta até $1$ para cobrir a demanda.
Padrão Elixir: 5.000 ms por dia. `Optimal` e
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
Processo que não responde também não entra. Não há estoque nacional. A
planta que passou do plano envia a sobra para a que ficou mais abaixo,
em comboios de no máximo 30 m³. Um comboio só sai com pelo menos 20 m³.
O volume entra na demanda no dia da chegada. O prazo mínimo é 1 dia. A
taxa de falha vai de 0 a 100 e é sorteada quando a entrega vai sair. A
chave da rota, tupla ordenada ou texto `ORIGEM|DESTINO`, vale primeiro.
Sem ela, vale a porcentagem do destino, como no painel. 1 é o padrão de
quem não configura o painel. 100 perde a carga. Três perdas seguidas na
rota fazem a origem esperar 10 dias. Uma entrega que sai zera a contagem.
A pausa não perde carga: a origem tenta a próxima planta com falta. Se
ninguém recebe, o volume fica na origem. O Runner não guarda quem
recebeu. Um cenário pode passar `closed_roads`, a função do dia que
lista os pares de estrada fechados. O par fecha nos dois sentidos. O
cenário de rotas bloqueadas fecha três pares por dois meses. O painel
não fecha estrada. A bateria usa 1 dia, exceto o cenário de remessa. A
referência sorteia falha de 1% a 5% em cada rota. A falha alta sorteia
de 41% a 100%. Os outros cenários deixam a porcentagem em 1.

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
Os GenServers do painel permanecem como o usuário os deixou. A demanda
vem do cenário. O ano da bateria segue direto, sem a espera de 30 s do
painel.
