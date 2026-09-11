# Primeiros passos

Simulador acadêmico de alocação diária de gasolina A no Brasil em 2025.
O painel Phoenix LiveView está em português. O núcleo MILP é Rust. Os CSVs
em `data/curated/` são a fonte de verdade. Identificadores de código, nomes
de arquivo e notação matemática permanecem em inglês.

## O que o painel faz

Histórico 2025 lê `data/curated/historical_2025_summary.json` e não chama o
solver. Planejado 2025 sorteia $R_{i,d}$ nos rendimentos mensais válidos
daquela refinaria em 2025, resolve os 365 dias com transporte de estoque e
mostra no painel o agregado mensal e anual.
Controles: estoque inicial, ajuste de demanda, derrubar e recuperar
planta. Só as refinarias cujo GenServer está no ar entram no dia. Ao
recuperar, a planta rampa de 40% até 100% a 1 p.p. por dia. O cartão
de cada planta mostra o FUT do último dia resolvido e a gasolina A
acumulada em m³, atualizados a cada dia do Planejado. O ano no painel
leva pelo menos 30 s, para dar tempo de derrubar uma planta no meio.
LUBNOR não entra: não produz gasolina A.

## Documentação

| Documento | Conteúdo |
|---|---|
| `docs/model_specification.md` | Conjuntos, restrições e FUT |
| `docs/model_runtime.md` | Módulos Elixir e Rust, timeout e painel |
| `docs/data_report.md` | Fontes ANP e arquivos curados |
| `docs/data_transformations.md` | Conversões, calibração e limitações |

## Pré-requisitos

- Elixir 1.17 ou mais recente, com Erlang/OTP compatível
- Rust e Cargo estáveis, usados na primeira compilação do crate nativo
- Rede na primeira execução, para dependências Elixir, esbuild e tailwind

## Execução

Todos os comandos partem de `simulator/`.

```
mix deps.get
mix phx.server
```

Painel: `http://localhost:4000/`

## Testes

```
cd native/gasoline_solver && cargo test
```

```
mix test
```
