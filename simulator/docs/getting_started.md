# Primeiros passos

Simulador acadêmico de alocação mensal de gasolina A no Brasil em 2025.
O painel Phoenix LiveView está em português. O núcleo MILP é Rust. Os CSVs
em `data/curated/` são a fonte de verdade. Identificadores de código, nomes
de arquivo e notação matemática permanecem em inglês.

## O que o painel faz

Histórico 2025 lê `data/curated/historical_2025_summary.json` e não chama o
solver. Planejado 2025 sorteia $R_{i,d}$ nos rendimentos mensais válidos
daquela refinaria em 2025, resolve os 365 dias com transporte de estoque e
mostra no painel o agregado mensal e anual.
Controles: estoque inicial e ajuste de demanda. As 12 refinarias do
escopo fixo entram em todos os meses. LUBNOR não entra: não produz
gasolina A.

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
