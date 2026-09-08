# Primeiros passos

Este é um simulador acadêmico construído para um TCC (trabalho de conclusão de
curso) que estuda como a produção brasileira de gasolina A poderia ser alocada,
mês a mês ao longo de um ano completo, para atender a um proxy de demanda
mensal enquanto carrega um estoque nacional de um mês para o outro. É uma
aplicação Phoenix LiveView pequena, apoiada em um núcleo de otimização em
Rust, rodando sobre um conjunto de dados estático e versionado de 2025. Não há
pipeline de ingestão ou regeneração em Python neste repositório. Os CSVs
curados em `data/curated/` são a fonte de verdade dos dados.

## Arquitetura

### Painel Phoenix LiveView

`GasolineSimulatorWeb.DashboardLive`
(`lib/gasoline_simulator_web/live/dashboard_live.ex`) é a única página da
aplicação. Não há seletor de mês: a única ação da página executa a sequência
planejada completa de janeiro a dezembro de 2025. O lado Histórico 2025
carrega imediatamente a partir de `data/curated/historical_2025_summary.json`.
É um artefato de exibição pré-computado e nunca invoca o solver.

### Fronteira entre dados, problema e solver em Elixir

- `GasolineSimulator.Data.Repository` lê os CSVs curados uma única vez para o
  ano inteiro (`load_year/1`) e retorna dois mapas simples: a demanda nacional
  por mês e os atributos de cada refinaria por mês (capacidade e capacidade de
  processamento bruto, e piso operacional). Todas as 13 refinarias do escopo
  fixo aparecem em todos os 12 meses. Não existe mais nenhum conceito de
  refinaria excluída ou não modelável.
- `GasolineSimulator.Scenarios.YieldSampling` sorteia o rendimento simulado de
  gasolina A `R_{i,t}` de cada refinaria-mês, uma única vez por execução
  anual, de uma distribuição uniforme em `[0.20, 0.25]`.
- `GasolineSimulator.Problem` constrói a estrutura de domínio de um mês a
  partir dos controles do painel e dos dados curados carregados. Nenhuma
  refinaria é filtrada aqui.
- `GasolineSimulator.Scenarios.Runner` conduz a sequência anual: carrega os
  dados do ano uma vez, depois resolve um mês de cada vez, repassando o
  estoque final de cada mês como estoque inicial do mês seguinte, e interrompe
  toda a execução se a resolução de algum mês retornar uma falha genuína (em
  contraste com um déficit de demanda, que nunca é uma falha).
  `GasolineSimulator.Scenarios.Overrides` aplica os controles de planejamento
  anuais (estoque inicial, ajuste de demanda e substituição do piso
  operacional por refinaria).
- `GasolineSimulator.Scenarios.Orchestrator` é um `GenServer` que rastreia
  execuções planejadas anuais por id e transmite atualizações via
  `Phoenix.PubSub` para que o painel se atualize ao vivo.
- `GasolineSimulator.Solver` é o ponto de entrada em Elixir para o solver
  nativo de um único mês. Verificações matemáticas mínimas são feitas na
  fronteira do solver em Rust.

### Task.Supervisor e comportamento de timeout

Tanto o orquestrador quanto o solver executam o trabalho sob um
`Task.Supervisor`, em vez de bloquear o processo chamador. `Solver.solve/2`
inicia a chamada nativa em uma tarefa supervisionada e aguarda com
`Task.yield/2`, usando uma opção `:timeout` em milissegundos aplicada à
resolução de cada mês individualmente. Se a tarefa não responder a tempo, ela
é encerrada e `{:error, {:timeout, reason}}` é retornado ao chamador, o que
interrompe a execução anual naquele mês. A chamada nativa continua rodando em
um scheduler dirty CPU e não é preemptível a partir do Elixir, então um
timeout muito curto pode retornar um erro ao chamador antes que a resolução
subjacente do HiGHS realmente tenha terminado. O orquestrador usa o mesmo
padrão com `Task.Supervisor.async_nolink/3` para a execução anual inteira,
então uma execução que falha ou expira é reportada como um plano com falha em
vez de derrubar o orquestrador.

### NIF via Rustler

`GasolineSimulator.Solver.Native` (`lib/gasoline_simulator/solver/native.ex`)
declara um NIF Rustler apoiado no crate Rust `native/gasoline_solver`. O
Rustler compila esse crate em uma biblioteca compartilhada e a carrega na
BEAM, de modo que chamar `Native.solve_nif/2` executa código nativo no mesmo
processo do sistema operacional que a aplicação Elixir. Uma chamada NIF
resolve exatamente um mês. O Elixir é responsável pelo sequenciamento e pela
transferência de estoque entre meses.

### Núcleo MILP em Rust com good_lp e HiGHS

`native/gasoline_solver/src/model.rs` e `solve.rs` constroem, para cada mês,
um programa linear inteiro misto usando o crate `good_lp`, resolvido pelo
solver HiGHS. Cada refinaria recebe uma variável binária de ativação e uma
variável contínua de alocação (produção), limitada apenas pela sua capacidade
máxima curada de gasolina A e pelo seu piso operacional. Duas variáveis
contínuas adicionais representam o estoque final do mês e o déficit de
demanda do mês, ligados à produção e ao estoque inicial do mês por uma
equação de balanço de estoque.

A resolução de cada mês segue uma otimização lexicográfica estrita em duas
etapas: a primeira etapa minimiza o déficit, e a segunda etapa fixa o déficit
no ótimo encontrado na primeira etapa (dentro de uma tolerância numérica
pequena) e então minimiza o processamento total de petróleo implícito nas
alocações. Isso elimina a necessidade de um peso de penalidade (`lambda`)
combinando os dois objetivos em uma única expressão. Detalhes completos estão
em `docs/model_specification.md`.

### Entradas de dados

`data/curated/` contém dados estáticos e versionados de 2025 derivados da
ANP: produção de gasolina A por refinaria, rendimentos de derivados por
refinaria (evidência histórica usada apenas para calibrar o intervalo de
sorteio do rendimento simulado, não lida em tempo de execução pelo
planejamento), capacidade de refino e demanda nacional. O catálogo de
refinarias é restrito às refinarias listadas no `estudo_tcc.typ` da raiz do
repositório. Veja `docs/data_report.md` para fontes, transformações e
escopo.

### Controles do painel

O painel Histórico 2025 exibe a produção observada de gasolina A fornecida, a
demanda estimada de gasolina A e sua diferença assinada. Valores positivos
são superávit e valores negativos são déficit. Ele não reconstrói estoque ou
déficit históricos. O FUT Total histórico é pré-computado como razão de somas:
soma do processamento de petróleo observado dividida pela soma da capacidade
bruta de processamento de petróleo, em todo o escopo fixo de refinarias, nunca
como média aritmética das razões individuais.

Para o Planejado 2025 você define um estoque inicial para 2025-01-01, um
percentual opcional de ajuste de demanda aplicado a todos os meses e, por
refinaria, uma substituição opcional do piso operacional. Um único clique
sorteia um novo rendimento simulado `R_{i,t}` para cada refinaria-mês e
executa um plano anual completo. O FUT planejado é calculado por refinaria a
partir do processamento de petróleo implícito `x / R_{i,t}` (alocação
dividida pelo rendimento simulado sorteado para aquela refinaria naquele
mês), sobre a mesma capacidade bruta de processamento como denominador. A
agregação mensal e anual usa a mesma razão de somas do Histórico 2025. O
modelo limita a produção de gasolina A apenas à capacidade máxima curada de
gasolina A da refinaria naquele mês, sem nenhum limite derivado do
processamento. Como o rendimento é sorteado novamente a cada execução,
execuções sucessivas do Planejado 2025 tendem a produzir alocações e FUT
diferentes entre si.

### Exportação JSON

Assim que a execução planejada termina, o painel exibe um link de exportação
para `GET /api/plans/:planned_id`, servido por
`GasolineSimulatorWeb.PlanningController`. A versão de esquema 5 contém
campos de comparação históricos e planejados correspondentes, além da
mecânica planejada em separado.

## Pré-requisitos

- Elixir 1.17 ou mais recente, com Erlang/OTP compatível
- Rust e Cargo (toolchain estável), usados para compilar o crate do solver
  nativo na primeira build da aplicação
- Acesso à rede na primeira execução, para buscar as dependências Elixir e os
  binários do esbuild/tailwind

## Executando a aplicação

Todos os comandos são executados a partir do diretório `simulator/`.

Buscar as dependências Elixir:

```
mix deps.get
```

Executar a aplicação:

```
mix phx.server
```

Abrir o painel no navegador em:

```
http://localhost:4000/
```

## Executando os testes

Executar os testes do núcleo MILP em Rust:

```
cd native/gasoline_solver
cargo test
```

Executar o teste de fumaça anual e os testes de renderização de erro gerados
pelo Phoenix:

```
mix test
```
