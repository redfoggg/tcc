#import "@preview/touying:0.7.1": *
#import themes.university: *

#show: university-theme.with(
  aspect-ratio: "4-3",
  config-page(margin: (top: 4em, rest: 2em)),
  config-info(
    title: [Simulação econômica com programação linear na BEAM],
    subtitle: [Uma abordagem planificada para o setor petrolífero brasileiro],
    author: [David Ferrari],
    institution: [Universidade Federal da Bahia -- UFBA],
    date: [2026],
  ),
)

#title-slide()

// ============================================================
// SEÇÃO 1: MOTIVAÇÃO
// ============================================================

= Motivação

== O Problema: Preços versus Realidade

- Modelos econômicos tradicionais se baseiam em *valores de mercado* (preços)

#pause

- Preços são influenciados por especulação, inflação e fatores financeiros

#pause

- Preços *não refletem* a capacidade real de produção e abastecimento

#pause

- Exemplo: o preço do barril pode dobrar sem que a capacidade de refino tenha mudado

== Por Que Isso Importa?

#pause

- Planejamento governamental depende de dados reais de capacidade produtiva

#pause

- Crises de abastecimento (pandemia, guerra) expuseram fragilidades nas cadeias

#pause

- Países como EUA e China já usam modelos de otimização logística

#pause

- *Amazon, Walmart, FedEx* usam Programação Linear diariamente para logística

#pause

- *Proposta*: aplicar as mesmas técnicas ao setor petrolífero brasileiro

// ============================================================
// SEÇÃO 2: FUNDAMENTAÇÃO TEÓRICA
// ============================================================

= Fundamentação Teórica

== Programação Linear

A formulação canônica de um problema de Programação Linear:

$ max quad z = bold(c)^T bold(x) $

$ "sujeito a:" quad bold(A) bold(x) <= bold(b), quad bold(x) >= bold(0) $

#v(1em)

Onde:
- $bold(x)$: vetor de variáveis de decisão (níveis de produção por unidade)
- $bold(c)$: coeficientes da função objetivo (utilidade, prioridade)
- $bold(A)$: matriz de restrições (recursos, capacidade)
- $bold(b)$: limites de recursos disponíveis

== Modelagem Econômica com LP

Aplicando LP à economia, queremos maximizar o atendimento da demanda:

$ max quad sum_(i=1)^n w_i x_i $

$ "s.a:" quad sum_(i=1)^n a_(i j) x_i <= R_j, quad forall j in {1, ..., m} $

$ x_i >= d_i, quad forall i in {1, ..., n} $

#v(0.5em)

- $x_i$: produção da unidade $i$ (refinaria, terminal, oleoduto...)
- $w_i$: peso de prioridade (ex: gasolina > querosene)
- $R_j$: recurso $j$ disponível (petróleo bruto, capacidade de refino, transporte)
- $d_i$: demanda mínima do produto $i$

== BEAM: "Let It Crash"

- Elixir roda na *BEAM (BEAM)*, criada pela Ericsson para telecomunicações

#pause

- Filosofia: processos leves, isolados e supervisionados

#pause

- *Supervisor Trees*: cada refinaria é um processo supervisionado

#pause

- Quando uma refinaria sai de operação, o sistema *propaga a informação* e o modelo LP recalcula a alocação ótima entre as refinarias restantes

#pause

- Elixir como camada de *comunicação e coordenação* entre os componentes do modelo

// ============================================================
// SEÇÃO 3: PROPOSTA
// ============================================================

= Proposta

== O Sistema Proposto

- Sistema de *simulação econômica* baseado em dados reais de produção

#v(0.5em)

- *Entrada*: dados do setor petrolífero (capacidade de refino, demanda, infraestrutura)

- *Processamento*: otimização via Programação Linear (Simplex / Mixed Integer) através de NIF Rust

- *Saída*: níveis ótimos de produção e distribuição, gargalos identificados

#v(0.5em)

- *Diferencial*: foco em utilidade real, não em valores monetários

== Inovação: Utilidade Real

#align(center)[
  #table(
    columns: 2,
    align: (left, left),
    stroke: 0.5pt,
    inset: 10pt,
    table.header(
      [*Abordagem de Mercado*],
      [*Abordagem Proposta*],
    ),
    [Baseada em preços], [Baseada em quantidades físicas],
    [PIB como métrica], [Capacidade produtiva como métrica],
    [Otimiza lucro], [Otimiza utilidade],
    [Ignora restrições físicas], [Modela restrições reais],
    [Vulnerável a especulação], [Independente do mercado financeiro],
  )
]

// ============================================================
// SEÇÃO 4: ARQUITETURA
// ============================================================

= Arquitetura

== Arquitetura Geral do Sistema

#align(center)[
  #text(size: 14pt)[
    ```
    ┌─────────────────────┐
    │   Dados ANP / MME   │
    │  (demanda, insumos) │ 
    └──────────┬──────────┘
               │
    ┌──────────▼──────────┐
    │  Módulo de Ingestão │
    │      (Elixir)       │
    └──────────┬──────────┘
               │
    ┌──────────▼──────────┐
    │     Supervisor      │
    │   de Refinarias     │
    └──┬───┬───┬───┬───┬──┘
       │   │   │   │   │
      REPLAN RLAM REVAP ...  ← GenServers
       │   │   │   │   │
    ┌──▼───▼───▼───▼───▼───┐
    │  Motor LP (Rust NIF) │
    │  "Dada demanda X,    │
    │   como alocar entre  │
    │   N refinarias?"     │
    └──────────┬───────────┘
               │
    ┌──────────▼──────────┐
    │     Dashboard       │
    │   Phoenix LiveView  │
    └─────────────────────┘
    ```
  ]
]

== Árvores de Supervisão

#text(size: 16pt)[
```elixir
refinarias = [:replan, :rlam, :revap, :reduc, :rpbc, :refap]

children =
  Enum.map(refinarias, &{Refinery, &1}) ++
  [{LPSolver, engine: :rust_nif}]

Supervisor.start_link(children, strategy: :one_for_one)
```
]

#v(0.5em)

- Cada refinaria é um *GenServer* com sua capacidade, insumos e estado

#pause

- RLAM sai de operação? O processo notifica o solver, que *recalcula* a alocação ótima entre as demais

#pause

- Pergunta central: dada demanda $X$, com que capacidade e insumos operar cada refinaria?

== Fluxo de Processamento

+ Coleta de dados reais (ANP, Petrobras, capacidade de refino)

#pause

+ Normalização e modelagem como restrições LP

#pause

+ Cada refinaria representada como processo Elixir (capacidade, insumos, estado)

#pause

+ Mudança de cenário (refinaria cai) → Elixir propaga → LP recalcula

#pause

+ Resultado: alocação ótima de produção entre as $N$ refinarias disponíveis

#pause

+ Identificação de *gargalos* (refinarias saturadas, insumos insuficientes)

// ============================================================
// SEÇÃO 5: METODOLOGIA
// ============================================================

= Metodologia

== Metodologia

+ *Revisão bibliográfica*: LP em economia, otimização, programação concorrente

+ *Coleta de dados*: bases públicas (ANP, Petrobras, MME)

+ *Modelagem*: formular restrições e função objetivo para cadeia petrolífera

+ *Implementação*: sistema em Elixir com solver LP via NIF Rust

+ *Validação*: comparar resultados com dados históricos

+ *Análise*: interpretar gargalos e níveis ótimos

== Stack Tecnológica

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *Linguagem / Plataforma*
    - Elixir 1.17+ / BEAM (BEAM)
    - Phoenix LiveView (dashboard)

    #v(1em)

    *Algoritmos / Solver*
    - Programação Linear (Simplex, Mixed Integer)
    - Solver em Rust via NIF (Rustler)
  ],
  [
    *Dados*
    - ANP (Agência Nacional do Petróleo)
    - Relatórios Petrobras
    - MME (Ministério de Minas e Energia)

    #v(1em)

    *Infraestrutura*
    - Supervision Trees, GenServer, Task
    - Testes com ExUnit
  ],
)

// ============================================================
// SEÇÃO 6: RESULTADOS ESPERADOS
// ============================================================

= Resultados Esperados

== Resultados Esperados

- Sistema funcional: dada demanda $X$, determinar alocação ótima entre $N$ refinarias

- Simulação de cenários adversos: refinaria desativada, variação de insumos

- Demonstração de que LP + BEAM é viável para planejamento do setor

- Visualização interativa dos resultados (dashboard Phoenix LiveView)

== Cenário: E se a RLAM Parar?

*Pergunta*: "Se a refinaria Landulpho Alves (BA) sair de operação, o Brasil mantém o abastecimento?"

#v(0.5em)

- *Componentes*: REPLAN, RLAM, REVAP, REDUC, oleodutos, terminais

#pause

- *Restrições*: capacidade de refino, malha de transporte, demanda regional

#pause

- *Função objetivo*: maximizar abastecimento interno de derivados

#pause

- *Resultado esperado*: redistribuição ótima entre refinarias e gargalos críticos

== Contribuições

- Evidência técnica para o debate *economia planificada vs. orientada a mercado*: o avanço computacional torna o planejamento centralizado quão melhor que o baseado em mercado?

- Demonstração prática: com LP + BEAM é possível simular e otimizar um setor real em tempo hábil

// ============================================================
// ENCERRAMENTO
// ============================================================

#focus-slide[
  #align(center)[#text(size: 36pt)[Fim]]
]
