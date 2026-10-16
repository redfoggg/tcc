# Execução do modelo

Caminhos relativos a `simulator/`. A matemática está em
`docs/model_specification.md`.

O aplicativo é Elixir, rodando na BEAM, a máquina virtual do Erlang. Cada
execução sobe a própria árvore de processos: as 12 refinarias, um
supervisor de comboios e um processo para cada comboio. Nada dessa
árvore é compartilhado com outra execução, e ela é derrubada no fim do
ano. Um GenServer é um processo servidor do OTP, a biblioteca padrão do
Erlang para processos supervisionados. O solver é Rust, chamado por um
NIF (função nativa implementada fora da BEAM) gerado pelo Rustler.

## Módulos

| Módulo | Papel |
|---|---|
| `Data.Repository` | Lê demanda, capacidade, outras cargas e rendimentos mensais dos CSVs |
| `Data.Catalog` | Nomes e UFs (unidades da federação) das 12 refinarias |
| `Data.Regions` | População de cada região e a região de cada refinaria |
| `Data.Historical` | Lê `historical_2025_summary.json` |
| `Refineries.Fleet` | Sobe e derruba a árvore de uma execução: plantas, supervisor de comboios e comboios |
| `Refineries.Plant` | GenServer de uma refinaria dentro de uma execução: tanque, rampa, envio de comboios, contagem de perdas e pausa de rota |
| `Refineries.Delivery` | Processo de um comboio na estrada |
| `Refineries.DeliverySupervisor` | Supervisor dos comboios de uma execução. Encerra o que falha no sorteio |
| `Refineries.Distances` | Quilômetros de rodovia de cada par e dias de caminhão |
| `Refineries.Logistics` | Soma as chegadas do dia, calcula pedido e oferta de cada região e envia os comboios |
| `Refineries.Supervisor` | As 12 plantas do painel, que dizem quem está no ar. Uma planta que cai não derruba as outras |
| `Scenarios.YieldSampling` | Sorteia $R_{i,d}$ na lista mensal válida da refinaria |
| `Models.Overrides` | Ajuste de demanda, único ou por mês |
| `Models.Problem` | Monta o dia, os limites de cada planta e a entrada do solver |
| `Models.Refinery` | Dados de uma refinaria dentro do problema do dia |
| `Models.Result` | Junta a resposta do solver, a gasolina realizada e o fechamento de cada região |
| `Models.Plan` | Estado em memória de uma execução |
| `Scenarios.Runner` | Percorre os 365 dias e guarda o que passa de um dia para o outro |
| `Scenarios.Orchestrator` | Execuções do painel, monitor das plantas e PubSub (avisos do servidor para a página) |
| `Scenarios.Methodology` | Os dez cenários da bateria e a montagem de cada execução |
| `Scenarios.Study` | Roda a bateria em segundo plano, sem mexer nas plantas do painel |
| `Scenarios.Export` | CSV de cada execução e `manifest.csv` |
| `Solver` / `Solver.Native` | Limite de tempo e chamada ao NIF |

## Um dia de simulação

`Scenarios.Runner` faz, em cada dia:

1. Pergunta às plantas quem responde e recebe as cargas que chegam.
2. Monta o problema com o tanque de cada região, as chegadas, o déficit
   de ontem, o rendimento de planejamento e o piso de cada planta.
3. Chama o solver uma vez, para todas as plantas.
4. Calcula a gasolina realizada com o rendimento sorteado e credita no
   tanque de cada planta.
5. Envia os comboios por `Refineries.Logistics`.
6. Fecha cada região, tira a demanda dos tanques e avisa cada planta do
   próprio plano e do déficit do país.
7. Guarda para amanhã o déficit, o rendimento acumulado e a dívida de
   cada planta contra o próprio plano.

As plantas não negociam entre si e não veem o plano umas das outras.

## Solver

`native/gasoline_solver` usa a biblioteca `good_lp` com o HiGHS. O
limite padrão é 5.000 ms por dia. O HiGHS aceita a solução ótima ou a
que para no limite de folga de otimalidade. Estouro de tempo vira
`:timeout` e interrompe o ano. O NIF roda num agendador de CPU separado
e não pode ser cancelado no meio. As falhas possíveis são
`:solver_failure`, `:solver_panic` e `:timeout`. Déficit não é falha: o
dia termina com `status :ok`.

## Resultado

Cada dia traz demanda, produção, déficit, excedente, chegadas, tanque de
cada planta, fechamento de cada região, FUT (fator de utilização total)
e as refinarias no ar, com o rendimento sorteado. O mês soma os dias. O
ano soma os dias e calcula duas coberturas. A nacional usa a produção do
ano menos as perdas no transporte, contra a demanda do país. A efetiva
soma o que cada região teve no ano, até a demanda dela.

## Painel

A página é Phoenix LiveView, atualizada pelo servidor sem recarregar. As
execuções vivem só na memória. O painel mostra:

- O Histórico 2025 e o Planejado 2025, com indicadores do ano e tabela
  mensal.
- A tabela por região, com demanda, produção, demanda atendida, tanque
  no fim do ano e cobertura.
- O cartão de cada refinaria, com o FUT do último dia, a gasolina
  acumulada e o tanque. Planta ausente fica em 0%.
- As entregas a caminho, agrupadas por origem e destino. Cinco rotas
  aparecem, e "Ver mais" mostra o resto.

O ano do painel leva pelo menos 30 s, para dar tempo de derrubar uma
planta no meio. "Derrubar" desliga a planta do painel e a planta da
execução em curso, que perde o tanque e as cargas que esperava.
"Recuperar" sobe as duas de novo, com a planta da execução zerada e na
rampa. A lista de entregas a caminho mostra só os comboios do Planejado.

## Bateria

O botão "Rodar bateria" roda os dez cenários de `docs/methodology.md`,
dez vezes cada, e grava os CSVs em `data/studies/`. A bateria usa a
própria lista de plantas no ar e não espera os 30 s. As 100 execuções
rodam ao mesmo tempo, cada uma com a própria árvore de processos. Uma
execução não espera pelas plantas de outra nem vê os dados dela. Planta
fora do ar num cenário de parada continua viva na árvore e guarda o
tanque. Ela só deixa de entrar no plano e na logística enquanto estiver
parada.
