# Primeiros passos

Simulador acadêmico da produção diária de gasolina A no Brasil em 2025.
Gasolina A é a gasolina sem etanol, como sai da refinaria. O painel é
web, em português. O núcleo de otimização é Rust. Os CSVs em
`data/curated/` são a fonte de verdade. Identificadores de código, nomes
de arquivo e notação matemática ficam em inglês.

## O que o painel faz

- **Histórico 2025** lê o resumo curado do ano observado. Não chama o
  solver.
- **Planejado 2025** simula os 365 dias. Cada dia, um plano central
  decide quanto petróleo cada refinaria processa. Um rendimento sorteado
  transforma esse petróleo em gasolina. Comboios de caminhão levam a
  sobra das regiões que refinam mais para as que refinam menos. O painel
  mostra o ano, os meses e cada região.
- **Controles**: ajuste de demanda em %, taxa de falha dos comboios para
  cada refinaria de destino (começa em 1%) e os botões para derrubar e
  recuperar uma planta no meio do ano. O ano leva pelo menos 30 s para
  dar tempo de usar esses botões.
- **Bateria** roda os 9 cenários de `docs/methodology.md` e grava os
  CSVs em `data/studies/`.

## Siglas

| Sigla | Significado |
|---|---|
| ANP | Agência Nacional do Petróleo, Gás Natural e Biocombustíveis |
| BEAM | Máquina virtual do Erlang, onde o Elixir roda |
| CNPE | Conselho Nacional de Política Energética |
| CSV | Arquivo de texto com valores separados por vírgula |
| FUE | Fator de utilização efetivo, publicado pela ANP |
| FUT | Fator de utilização total: fração da capacidade da refinaria ocupada pela destilação |
| GenServer | Processo servidor do OTP |
| HiGHS | Solver de código aberto de programação linear e inteira mista |
| IBGE | Instituto Brasileiro de Geografia e Estatística |
| JSON | Formato de texto para dados estruturados |
| LiveView | Páginas do Phoenix atualizadas pelo servidor sem recarregar |
| LP | Programação linear (*linear programming*) |
| NIF | Função nativa, escrita fora da BEAM e chamada por ela |
| OSRM | Open Source Routing Machine, roteador de mapas usado nas distâncias |
| OTP | Open Telecom Platform, a biblioteca padrão do Erlang para processos supervisionados |
| p.p. | Ponto percentual |
| UF | Unidade da federação |
| Mm³ | Milhões de metros cúbicos |

Os códigos das refinarias (REAM, REPLAN e outras) estão com nome e UF em
`docs/refinery_distances.md`. A LUBNOR, refinaria de lubrificantes do
Nordeste, fica de fora porque não produz gasolina A.

## Documentação

| Documento | Conteúdo |
|---|---|
| `docs/model_specification.md` | Equações do plano diário, da execução, dos comboios e dos indicadores |
| `docs/model_runtime.md` | Módulos Elixir e Rust, ciclo de um dia, solver e painel |
| `docs/methodology.md` | Os 9 cenários da bateria e as colunas dos CSVs |
| `docs/data_report.md` | Fontes da ANP e arquivos curados |
| `docs/data_transformations.md` | Conversões dos dados e as hipóteses e simplificações do modelo |
| `docs/other_charges.md` | Outras cargas e a definição de FUT |
| `docs/refinery_distances.md` | Coordenadas, distâncias e tempo de caminhão |
| `docs/findings.md` | Conclusões que a bateria sustenta contra o Histórico 2025, e as que não sustenta |

## Pré-requisitos

- Elixir 1.17 ou mais recente, com Erlang/OTP compatível
- Rust e Cargo estáveis, para compilar o solver na primeira vez
- Rede na primeira execução, para baixar dependências

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
