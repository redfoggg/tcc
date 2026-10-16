# Metodologia dos cenários

A bateria é um experimento separado do painel. O botão "Rodar bateria"
roda 10 cenários, com 10 execuções cada, e grava um CSV (arquivo de
valores separados por vírgula) por execução em
`data/studies/<timestamp>/`. A bateria e a análise dela ficam no
repositório como resultado do trabalho. As plantas do
painel permanecem como estão, e o ajuste de demanda e as taxas de falha
do formulário não entram: cada cenário traz os próprios insumos.

## O que vale em todos os cenários

Cada execução resolve os 365 dias de 2025 com o mesmo modelo do
Planejado 2025, descrito em `docs/model_specification.md`, sem a pausa
de 30 s do painel. Ficam fixos:

- O calendário de 2025, a demanda curada e a capacidade curada.
- As 12 refinarias do catálogo. A LUBNOR, refinaria de lubrificantes do
  Nordeste, fica de fora porque não produz gasolina A.
- A divisão da demanda entre Norte, Nordeste, Sudeste e Sul pela
  população do Censo 2022 do IBGE (Instituto Brasileiro de Geografia e
  Estatística), com o Centro-Oeste somado ao Sudeste.
- O FUT (fator de utilização total): piso de 94% e teto de 100%. O
  cenário 10 muda o piso.
- A rampa de quem volta de uma parada: começa em 40% e sobe 1 ponto
  percentual em cada dia em que o déficit do país fica em até 1 m³.
- O prazo de cada comboio: o tempo de caminhão da estrada, com mínimo de
  1 dia.
- A taxa de falha dos comboios: 1%, exceto nos cenários 3 e 7.
- A disponibilidade: as 12 plantas ficam no ar o ano inteiro, mesmo nos
  meses em que o histórico registra parada. As paradas de manutenção,
  como as da RNEST em fevereiro e da REVAP em outubro e novembro, ficam
  de fora do plano. O efeito de parar plantas é medido nos cenários 2 e
  6.
- O rendimento: zero no histórico é tratado como decisão de mercado e
  vira a média nacional. A REAM, que deixou de refinar depois da
  privatização, usa a média nacional todo dia.

Essas hipóteses, onde pesam e por quê estão em
`docs/data_transformations.md`, seção Hipóteses e simplificações.

## Protocolo

São 100 execuções. `manifest.csv` tem uma linha por execução.
`<cenario>/run_XX.csv` tem uma linha por refinaria e dia. Planta fora do
modelo naquele dia entra com `in_model` igual a 0. O manifesto e o CSV
registram tudo o que foi sorteado: par e meses de parada, rotas
fechadas, ajustes mensais e rendimentos.

Os cenários que usam um rendimento fixo por planta usam só meses com
rendimento positivo. Sem nenhum, vale a média nacional de gasolina A,
como no painel.

## Cenários

### 1. rendimento_minimo

Todas as refinarias ficam no ar. Em todos os dias, cada uma rende o
menor rendimento mensal positivo que teve em 2025. O rendimento é o
mesmo nas dez execuções. Só os sorteios de falha dos comboios mudam.

### 2. paradas_produtivas

Cada execução sorteia duas das quatro refinarias que mais produziram
gasolina A em 2025 e as tira do modelo por três meses consecutivos. O
mês inicial vai de janeiro a outubro, para o bloco caber no ano. São
sempre duas plantas, para o choque ter o mesmo tamanho nas dez
execuções. A demanda é redistribuída entre as que ficam.

| Refinaria | Gasolina A em 2025 |
|---|---|
| REPLAN | 6,1 milhões de m³ |
| REPAR | 4,0 milhões de m³ |
| REFMAT | 3,4 milhões de m³ |
| REVAP | 2,9 milhões de m³ |

### 3. referencia

O controle. As doze plantas ficam no ar, o rendimento é sorteado todo
dia e a demanda segue o dado curado. Cada execução sorteia uma taxa de
falha inteira de 1% a 5% para cada uma das 66 rotas. Rota é o par de
refinarias sem direção, e a taxa vale nos dois sentidos. Só este cenário
usa essa faixa.

### 4. choque_demanda

Como a referência, mas a demanda fica 15% acima do dado curado em todos
os dias.

### 5. demanda_mensal

Cada execução sorteia, para cada mês, um ajuste inteiro de -1% a +15%.
O ajuste vale em todos os dias do mês e não se acumula de um mês para o
outro. A nota do manifesto grava os doze valores, no formato
`demanda 1:-1 2:11`.

### 6. manutencao_escalonada

Cada execução sorteia uma ordem das 12 refinarias e tira uma do modelo
em cada mês. Em qualquer dia há exatamente uma parada.

### 7. falha_alta_remessa

Cada execução sorteia uma taxa de falha inteira de 41% a 100% para cada
rota. As doze plantas ficam no ar.

### 8. rotas_bloqueadas

Cada execução sorteia três rotas entre as 66 e um bloco de dois meses
consecutivos, começando entre janeiro e novembro. Nesses meses as três
estradas ficam fechadas nos dois sentidos. A nota grava as rotas e os
meses, no formato `rotas RECAP|REPLAN REDUC|REFAP REPAR|REVAP meses 3|4`.

### 9. campanha_estavel

Cada execução sorteia um rendimento por refinaria e o mantém nos 365
dias. Na referência, o rendimento muda todo dia.

### 10. mobilidade_fut

Uma campanha de rendimento é sorteada uma vez e repetida nas dez
execuções: cada planta guarda o mesmo rendimento o ano inteiro. O que
muda é o piso de FUT, de 85% na execução 1 a 94% na execução 10, um ponto
por execução. O teto continua em 100%. O manifesto grava o piso em
`fut_lock`.

## Arquivos

Colunas de `manifest.csv`:

| Coluna | Conteúdo |
|---|---|
| `scenario_id`, `scenario_name`, `run`, `status` | Cenário, execução e se o ano terminou (`ok`) ou falhou |
| `yield_mode` | Como o rendimento foi escolhido |
| `demand_adjustment_pct` | Ajuste de demanda único, em % |
| `transit_days` | Sempre `par`: o prazo vem da estrada de cada par |
| `availability`, `offline_refineries`, `offline_months` | Regra de plantas no ar, quais saíram e em que meses |
| `fut_lock` | Piso de FUT da execução |
| `annual_demand_m3`, `annual_production_m3` | Demanda e gasolina A produzida no ano |
| `annual_served_demand_m3`, `annual_deficit_m3`, `annual_coverage` | Demanda atendida, déficit e cobertura do ano |
| `annual_fut_pct` | FUT do ano |
| `landed_m3`, `excess_m3`, `plant_stock_m3`, `lost_m3` | Chegadas, excedente, tanque no fim do ano e perdas no transporte |
| `csv_path`, `note` | Caminho do CSV da execução e o que foi sorteado |

Colunas de `run_XX.csv`, por refinaria e dia: `date`, `refinery_id`,
`uf` (unidade da federação), `in_model`, `simulated_yield` (rendimento
sorteado), `allocated_m3` (gasolina produzida), `petroleum_processed_m3`,
`other_charges_m3`, `processing_capacity_m3`, `fut_pct`, `active` e
`stock_m3` (tanque no fim do dia). As colunas `day_*` repetem os totais
do país no dia em todas as linhas daquele dia: demanda, produção,
déficit, chegadas, excedente e FUT. Somar essas colunas em todas as
linhas multiplica o valor por 12. As contas de cada coluna estão em
`docs/model_specification.md`.

## Análise

```
python3 data/scripts/analyze_study.py [data/studies/<pasta>]
```

Sem argumento, o script usa a bateria mais recente. Só aceita pastas
dentro de `data/studies` e usa apenas a biblioteca padrão do Python. Ele
grava em `<pasta>/analysis/` um `report.md` com as tabelas abaixo e os
CSVs com todos os números: `scenario_annual.csv`,
`scenario_vs_reference.csv`, `scenario_daily.csv`,
`scenario_monthly.csv`, `scenario_refineries.csv` e
`scenario_regions.csv`.

Para cada cenário, o resumo das execuções que terminaram traz:

| Medida | Significado |
|---|---|
| Média e desvio padrão (dp) | Valor típico e quanto as execuções se afastam dele |
| Coeficiente de variação (CV) | Desvio padrão dividido pela média. Compara a dispersão de medidas em escalas diferentes |
| Mínimo e máximo | Melhor e pior execução |
| IC 95% | Intervalo de confiança de 95% da média, pela distribuição t de Student com $n-1$ graus de liberdade, onde $n$ é o número de execuções |
| Δ contra a referência | Média do cenário menos média da referência. A diferença é marcada quando o intervalo de 95% do teste de Welch, que compara médias com variâncias diferentes, não inclui zero |

O relatório tem estas seções:

- **Resultado anual:** cobertura, déficit, produção, FUT e perdas, e
  quantas execuções cobriram 100% da demanda do ano.
- **Efeito contra a referência:** quanto cada choque muda cobertura,
  déficit, produção e FUT.
- **Referência contra o Histórico 2025:** produção, demanda, saldo e FUT.
- **Fechamento diário:** dias com falta, maior falta diária, falta no
  percentil 95 (o valor que 95% dos dias não ultrapassam), maior
  sequência de dias seguidos com falta e falta diária somada. Mostra
  quando a gasolina não estava na região certa, mesmo com o ano coberto.
- **FUT mensal:** média de cada mês, para ver em que época o parque
  trabalha mais.
- **Autossuficiência por região:** produção das refinarias da região
  dividida pela demanda dela, antes dos comboios.
- **Refinarias na referência:** produção, participação na produção
  nacional, FUT, dias no teto (FUT de pelo menos 99,5%) e dias fora do
  modelo.

## Ressalva

A demanda curada vem das vendas observadas de gasolina C (gasolina A
misturada com etanol anidro, a que se vende nos postos), no regime de
preços de 2025. O modelo a trata como dado externo, o que é uma
simplificação.
