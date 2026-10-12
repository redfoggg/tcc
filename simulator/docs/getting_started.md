# Primeiros passos

Simulador acadêmico de alocação diária de gasolina A no Brasil em 2025.
O painel Phoenix LiveView está em português. O núcleo MILP é Rust. Os CSVs
em `data/curated/` são a fonte de verdade. Identificadores de código, nomes
de arquivo e notação matemática permanecem em inglês.

## O que o painel faz

Histórico 2025 lê `data/curated/historical_2025_summary.json` e não chama o
solver. Planejado 2025 resolve os 365 dias pela capacidade das plantas.
O rendimento $R_{i,d}$ é sorteado na execução, nos meses válidos daquela
refinaria em 2025, e multiplica o petróleo que o plano mandou. O painel
mostra o agregado mensal e anual. Não há estoque nacional. Planta que
produziu acima do plano envia a sobra para a que ficou abaixo, em comboios
de no máximo 30 m³, e só se o comboio tiver pelo menos 20 m³.
Controles: ajuste de demanda, porcentagem de
falha das entregas para cada refinaria de destino, derrubar e
recuperar planta. O prazo de cada comboio é o tempo de caminhão da
estrada, com mínimo de 1 dia. Cada entrega é um processo.
A origem avisa a planta com falta e o volume entra na demanda no dia da
chegada. A porcentagem vai de 0 a 100. Em 0 a remessa segue sem falha
forçada. Em 100 toda entrega para aquela refinaria falha e a carga se
perde. Origem e destino são avisados. A carga não volta para a origem
e não entra na demanda. Depois de 3 perdas seguidas na mesma rota, a
origem espera 10 dias antes de iniciar outra entrega para aquele
destino. Na pausa, ela tenta a próxima planta com falta. Pular a rota não perde
carga.
Processo que não responde fica de fora do dia. Ao recuperar, a planta
rampa de 40% até 100% a 1 p.p. por dia. O cartão
de cada planta mostra o FUT do último dia resolvido e a gasolina A
acumulada em m³, atualizados a cada dia do Planejado. O ano no painel
leva pelo menos 30 s, para dar tempo de derrubar uma planta no meio.
LUBNOR não entra: não produz gasolina A.

## Documentação

| Documento | Conteúdo |
|---|---|
| `docs/model_specification.md` | Conjuntos, restrições e FUT |
| `docs/model_runtime.md` | Módulos Elixir e Rust, timeout e painel |
| `docs/methodology.md` | Bateria de 10 cenários, 100 execuções e CSV |
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
