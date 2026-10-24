# Metodologia dos cenários

A bateria é um experimento separado do painel. O botão "Rodar bateria"
roda 9 cenários, com 100 execuções cada, e grava um CSV (arquivo de
valores separados por vírgula) por execução em
`data/studies/<timestamp>/`. A bateria e a análise dela ficam no
repositório como resultado do trabalho. As plantas do
painel permanecem como estão, e o ajuste de demanda e as taxas de falha
do formulário não entram: cada cenário traz os próprios insumos.

As execuções rodam em paralelo, no máximo uma por núcleo da máquina.
Uma bateria de 900 execuções leva cerca de 13 minutos numa máquina de
14 núcleos e ocupa perto de 700 MB em disco.

## O que vale em todos os cenários

Cada execução resolve os 365 dias de 2025 com o mesmo modelo do
Planejado 2025, descrito em `docs/model_specification.md`, sem a pausa
de 30 s do painel. As 90 execuções rodam ao mesmo tempo, cada uma com
as próprias plantas e os próprios comboios, e o manifesto grava as
linhas na ordem dos cenários. O que as execuções compartilham são
sorteios: a execução $n$ de todos os cenários usa as mesmas taxas de
falha e os mesmos rendimentos.
Ficam fixos:

- O calendário de 2025, a demanda curada e a capacidade curada.
- As 11 refinarias do catálogo. A LUBNOR, refinaria de lubrificantes do
  Nordeste, fica de fora porque não produz gasolina A.
- A divisão da demanda entre Norte, Nordeste, Sudeste e Sul pela
  população do Censo 2022 do IBGE (Instituto Brasileiro de Geografia e
  Estatística), com o Centro-Oeste somado ao Sudeste.
- O FUT (fator de utilização total): piso de 94% e teto de 100%. O
  cenário 9 muda o teto.
- A previsão do ano: o planejador conhece desde janeiro a demanda de
  cada dia, já com o ajuste do cenário, e o teto do parque. Quando um
  mês à frente pede mais do que o parque refina no teto, como dezembro,
  ele forma estoque antes, subindo as plantas acima do piso. Paradas,
  rendimento sorteado e falhas de comboio ficam fora da previsão. A
  conta está em `docs/model_specification.md`, Previsão do ano.
- A rampa de quem volta de uma parada: começa em 40% e sobe 1 ponto
  percentual em cada dia em que o déficit do país fica em até 1 m³.
- O prazo de cada comboio: o tempo de caminhão da estrada, com mínimo de
  1 dia.
- A taxa de falha dos comboios, exceto no cenário 7. No início da
  bateria, cada número de execução, de 1 a 100, recebe um sorteio de uma
  taxa inteira de 1% a 5% para cada uma das 55 rotas. Rota é o par de
  refinarias sem direção, e a taxa vale nos dois sentidos. A execução
  $n$ de todos os cenários usa as mesmas taxas da execução $n$ da
  referência. Assim, cenário e referência diferem só no choque, e o
  sorteio comum reduz o ruído da comparação.
- A disponibilidade: as 11 plantas ficam no ar o ano inteiro, mesmo nos
  meses em que o histórico registra parada. As paradas de manutenção,
  como a da REVAP em outubro e novembro, ficam
  de fora do plano. O efeito de parar plantas é medido nos cenários 2 e
  6.
- O rendimento: zero no histórico é tratado como decisão de mercado e
  vira a média nacional. A REAM, que deixou de refinar depois da
  privatização, usa a média nacional todo dia. No início da bateria,
  cada número de execução, de 1 a 100, recebe um sorteio de rendimento
  para cada refinaria e dia, e a execução $n$ de todos os cenários usa
  esse mesmo sorteio. A exceção é o cenário 1, que fixa o rendimento
  mínimo.

Essas hipóteses, onde pesam e por quê estão em
`docs/data_transformations.md`, seção Hipóteses e simplificações.

## Protocolo

São 90 execuções. Uma semente inteira fixa todos os sorteios da
bateria: taxas de falha, paradas, rotas fechadas, demanda mensal,
rendimentos e perdas de comboio. Cada processo que sorteia recebe uma
semente derivada dela e do próprio papel (cenário, execução e
refinaria), então o resultado não depende da ordem em que as execuções
paralelas terminam. Sem semente informada, a bateria sorteia uma. A
semente fica na coluna `seed` do manifesto e no início de `report.md`.
Rodar de novo com a mesma semente reproduz todos os CSV byte a byte.

`manifest.csv` tem uma linha por execução.
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
mesmo em todas as execuções. Só os sorteios de falha dos comboios mudam.

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

O controle. As 11 plantas ficam no ar, o rendimento muda todo dia,
a demanda segue o dado curado, e rendimento e falha usam os sorteios
comuns da execução. Os outros cenários mudam uma coisa em relação a este.

### 4. choque_demanda

Como a referência, mas a demanda fica 15% acima do dado curado em todos
os dias.

### 5. demanda_mensal

Cada execução sorteia, para cada mês, um ajuste inteiro de -1% a +15%.
O ajuste vale em todos os dias do mês e não se acumula de um mês para o
outro. O planejador conhece os doze ajustes desde janeiro, como parte da
previsão do ano. A nota do manifesto grava os doze valores, no formato
`demanda 1:-1 2:11`.

### 6. manutencao_escalonada

Cada execução tira uma refinaria do modelo em cada mês. Em qualquer dia
há exatamente uma parada. São 12 meses e 11 refinarias: todas param uma
vez, e uma delas, sorteada, para uma segunda vez. A ordem dos 12 meses é
sorteada, então as duas paradas da refinaria repetida podem cair em
quaisquer meses, inclusive seguidos. A nota do manifesto grava os
pares, no formato `1:REPAR|2:REAM`.

### 7. falha_alta_remessa

Cada execução sorteia uma taxa de falha inteira de 41% a 100% para cada
rota, no lugar das taxas comuns. As 11 plantas ficam no ar.

### 8. rotas_bloqueadas

O bloqueio mira as rotas que mais carregam gasolina. Numa execução da
referência, só cerca de 36 das 55 rotas levam comboio, e seis delas
levam cerca de 87% do volume: REAM–REPLAN, REFMAT–REPLAN, REAM–REPAR, REFMAT–REPAR,
REAM–REFAP e REFAP–REFMAT. Essa ordem se repete com sementes diferentes.

Cada execução sorteia duas dessas seis rotas, sem repetição, e um bloco
de dois meses consecutivos, começando entre janeiro e novembro. Nesses
meses as duas estradas ficam fechadas nos dois sentidos, e o comboio
segue para o próximo destino da lista. A nota grava as rotas e os
meses, no formato `rotas REAM|REPAR REFMAT|REPLAN meses 3|4`.

### 9. mobilidade_fut

O rendimento segue a referência, que muda a cada dia. O que muda é o
teto de FUT, de 80% a 98%, dois pontos por vez. Cada teto vale para um
bloco de 10 execuções seguidas: 80% nas execuções 1 a 10, 82% nas
execuções 11 a 20, até 98% nas execuções 91 a 100. Quando o teto fica abaixo de 94%, o piso desce junto e as
plantas rodam travadas no teto. O manifesto grava o teto em `fut_lock`.

Os dez blocos são dez tetos diferentes, e a média anual do cenário
mistura todos eles. O resultado se lê como curva: cobertura, déficit e
produção em função do teto. Dentro de um bloco, as 10 execuções são
repetições do mesmo teto, e a tabela por teto do relatório traz média e
desvio padrão de cada um, com o IC 95% em `scenario_ceiling.csv`. A execução $n$ usa os mesmos rendimentos e as mesmas
taxas de falha da execução $n$ da referência, que tem teto de 100%.

## Arquivos

Colunas de `manifest.csv`:

| Coluna | Conteúdo |
|---|---|
| `scenario_id`, `scenario_name`, `run`, `status` | Cenário, execução e se o ano terminou (`ok`) ou falhou |
| `seed` | Semente da bateria, a mesma em todas as linhas |
| `yield_mode` | Como o rendimento foi escolhido |
| `demand_adjustment_pct` | Ajuste de demanda único, em % |
| `transit_days` | Sempre `par`: o prazo vem da estrada de cada par |
| `availability`, `offline_refineries`, `offline_months` | Regra de plantas no ar, quais saíram e em que meses |
| `fut_lock` | Teto de FUT da execução |
| `annual_demand_m3`, `annual_production_m3` | Demanda e gasolina A produzida no ano |
| `annual_served_demand_m3`, `annual_deficit_m3`, `annual_coverage` | Demanda atendida, déficit e cobertura nacional do ano |
| `annual_effective_served_m3`, `annual_effective_coverage` | Soma do que cada região teve no ano, até a demanda dela, e a cobertura efetiva |
| `coverage_north`, `coverage_northeast`, `coverage_southeast`, `coverage_south` | Fração da demanda de cada região servida no ano |
| `annual_fut_pct` | FUT do ano |
| `landed_m3`, `excess_m3`, `plant_stock_m3`, `lost_m3` | Chegadas, excedente, tanque no fim do ano e perdas no transporte |
| `csv_path`, `note` | Caminho do CSV da execução e o que foi sorteado |

Colunas de `run_XX.csv`, por refinaria e dia: `date`, `refinery_id`,
`uf` (unidade da federação), `in_model`, `simulated_yield` (rendimento
sorteado), `allocated_m3` (gasolina produzida), `petroleum_processed_m3`,
`other_charges_m3`, `processing_capacity_m3`, `fut_pct` e `stock_m3` (tanque no fim do dia). As colunas `day_*` repetem os totais
do país no dia em todas as linhas daquele dia: demanda, produção,
déficit, chegadas, excedente e FUT. Somar essas colunas em todas as
linhas multiplica o valor por 12. As contas de cada coluna estão em
`docs/model_specification.md`.

## Análise

```
python3 -m venv .venv
.venv/bin/pip install -r data/scripts/requirements.txt
.venv/bin/python data/scripts/analyze_study.py [data/studies/<pasta>]
```

O script usa NumPy e SciPy, nas versões de `data/scripts/requirements.txt`.
Ele lê `manifest.csv` e os CSVs de cada execução, sem modificá-los nem
rodar novas simulações. Só os arquivos de `analysis/` são regenerados.
`analysis_metadata.json` registra os parâmetros, as versões, os hashes
SHA-256 dos dados de entrada e do código e a confirmação de que os dados
permaneceram intactos durante a análise.

Sem argumento, o script usa a bateria mais recente que contém um
manifesto. `--output <pasta>` permite revisar uma análise em outra pasta
antes de substituir `analysis/`.

O relatório `report.md` é acompanhado de `scenario_annual.csv`,
`scenario_vs_reference.csv`, `scenario_daily.csv`, `scenario_monthly.csv`,
`scenario_refineries.csv`, `scenario_regions.csv`, `scenario_ceiling.csv`
e `statistical_diagnostics.csv`. Campos vazios indicam valores não
estimáveis; não representam zero. As médias e os desvios padrão
continuam descrevendo os mesmos resultados brutos.

### Como ler a estatística

**A unidade é a execução.** Cada execução é um ano inteiro simulado. Os
dias e as refinarias de uma execução não contam como repetições. Cada
cenário tem 100 execuções. Em `mobilidade_fut` são dez tetos, com 10
execuções cada.

**Desvio padrão e erro padrão.** O desvio padrão (dp) mede quanto uma
execução se afasta da média: é a variação de um ano simulado para
outro. O erro padrão (ep) mede quanto a própria média variaria se a
bateria fosse refeita com outra semente:

$$\text{ep} = \frac{\text{dp}}{\sqrt{n}}$$

Com 100 execuções, o ep é um décimo do dp. Mais execuções não mudam o
dp, mas deixam a média mais precisa.

**IC 95%.** O intervalo de confiança de 95% da média é

$$\text{IC} = \text{média} \pm t \times \text{ep}$$

O multiplicador $t$ vem da distribuição t de Student e depende do número
de execuções. Com 100 execuções ele é 1,984, quase o 1,96 da curva
normal. Com 10 execuções, como em cada teto de `mobilidade_fut`, ele é
2,262, porque com poucas execuções o próprio dp é menos confiável.

| Execuções | Multiplicador $t$ |
|---|---|
| 10 | 2,262 |
| 30 | 2,05 |
| 100 | 1,984 |
| infinitas | 1,96 |

Leitura: se a bateria fosse repetida muitas vezes com sementes novas,
cerca de 95% dos intervalos conteriam a média verdadeira do cenário. O
intervalo fala da média, não de uma execução isolada.

Exemplo com a cobertura efetiva da referência na bateria
`data/studies/20261022T182537Z`:

| Passo | Valor |
|---|---|
| Média de 100 execuções | 99,082% |
| dp | 0,284 p.p. |
| ep $= 0{,}284 / \sqrt{100}$ | 0,028 p.p. |
| Multiplicador $t$ | 1,984 |
| Meia largura $= 1{,}984 \times 0{,}028$ | 0,056 p.p. |
| IC 95% | 99,03% a 99,14% |

É o mesmo intervalo da coluna "IC 95% da efetiva" do `report.md`.

**Comparação com a referência: teste t pareado.** A execução $n$ de cada
cenário usa os mesmos rendimentos e taxas de falha da execução $n$ da
referência. Por isso a comparação é feita par a par: para cada número
de execução, calcula-se a diferença entre o cenário e a referência, e o
teste olha a média dessas diferenças.

$$d_n = \text{cenário}_n - \text{referência}_n \qquad \Delta = \text{média dos } d_n \qquad t = \frac{\Delta}{\text{ep dos } d_n}$$

Comparar par a par tira da conta a variação que os dois compartilham,
como um ano de rendimento baixo que afeta igualmente o cenário e a
referência. Sobra só o efeito do choque, e o teste fica mais preciso do
que se comparasse os dois grupos inteiros. Em `mobilidade_fut`, cada
teto é comparado com as 10 execuções de mesmo número da referência.

Exemplo, cobertura efetiva de demanda_mensal contra a referência:

| Passo | Valor |
|---|---|
| Diferença média $\Delta$ | -4,54 p.p. |
| dp das diferenças | 1,334 p.p. |
| ep $= 1{,}334 / \sqrt{100}$ | 0,133 p.p. |
| $t = -4{,}54 / 0{,}133$ | -34,0 |
| IC 95% da diferença | -4,81 a -4,28 p.p. |

A diferença é 34 erros padrão, e o relatório mostra -4,54 *.

**O asterisco e a correção de Holm.** O valor p é a chance de ver uma
diferença desse tamanho, ou maior, se o cenário não mudasse nada. O
relatório faz 221 comparações: 7 cenários e 10 tetos, cada um com 13
medidas. Com tantas comparações, umas 11 passariam de 0,05 por puro
acaso. A correção de Holm compensa isso: ela multiplica os valores p,
começando pelo menor, pelo número de comparações que ainda restam. O
asterisco só aparece quando o p corrigido fica abaixo de 0,05.

Um exemplo do efeito: no teto de 98% de `mobilidade_fut`, a cobertura
efetiva cai 0,41 p.p., e o IC 95% da diferença não inclui zero. Mesmo
assim, com só 10 pares e a correção para 221 comparações, o p corrigido
fica em cerca de 0,09, e a diferença fica sem asterisco.

**Diferenças constantes.** Algumas medidas dão exatamente a mesma
diferença em todos os pares, por exemplo um cenário que não muda o
excedente. Aí não há variação para testar, e o relatório deixa o p
vazio e marca NI, em vez de inventar um p. São 32 das 221 comparações.

**Diagnósticos.** O arquivo `statistical_diagnostics.csv` e a seção de
diagnósticos do relatório mostram a forma das distribuições: assimetria,
o teste de normalidade de Shapiro–Wilk, pontos muito afastados e valores
no limite da medida, como cobertura de 100%. São alertas para a leitura,
não regras que invalidam o teste. Nenhuma execução é removida.

**Cuidados.**

- Significativo não quer dizer importante. O asterisco diz que a
  diferença provavelmente não é sorte, não que ela é grande. Com 100
  execuções, até diferenças de poucos décimos de ponto percentual ganham
  asterisco, então o tamanho do Δ é a leitura principal.
- Sem asterisco não quer dizer igual. Pode ser só que há poucas
  execuções para enxergar a diferença, como nos tetos de
  `mobilidade_fut`.
- A média anual de `mobilidade_fut` mistura os dez tetos. Ela é só
  descritiva, sem IC nem teste. Use a tabela por teto.
- Mais execuções deixam a média mais precisa, mas não corrigem as
  premissas do modelo.

O relatório tem estas seções:

- **Resultado anual:** cobertura nacional, cobertura efetiva com o IC
  95%, déficit, produção, FUT e perdas. As duas coberturas estão em
  `docs/model_specification.md`, seção Indicadores do painel.
- **Efeito contra a referência:** quanto cada choque muda as duas
  coberturas, o déficit, a produção e o FUT, com teste pareado e Holm.
  No cenário 9, cada teto tem sua própria linha e seus pares de referência.
- **Diagnósticos da cobertura efetiva:** para cada cenário e teto, a
  diferença média, o IC 95%, o p corrigido por Holm e os alertas sobre a
  forma das diferenças.
- **Referência contra o Histórico 2025:** produção, demanda, saldo e FUT.
- **Cobertura do Histórico 2025 com as mesmas simplificações:** a
  cobertura nacional do Histórico, produção observada sobre a demanda, e
  a cobertura efetiva dele. A demanda regional segue a população do
  Censo 2022. Ao lado, a autossuficiência de cada região no Histórico e
  na referência.

  A cobertura efetiva do Histórico é um intervalo, e não um valor único,
  porque a ANP informa quanto cada refinaria produziu, mas não quanta
  gasolina foi levada de uma região para outra. Na simulação, cada
  comboio é registrado, então a cobertura efetiva sai exata. No
  Histórico, só dá para calcular os dois extremos possíveis:

  - **Menor valor:** nenhuma região mandou gasolina para outra. Cada
    região só usou o que refinou, e a sobra do Sul e do Sudeste ficou
    parada.
  - **Maior valor:** toda a sobra chegou onde faltava. Nenhum m³ ficou na
    região errada, então o valor é igual à cobertura nacional.

  O valor real de 2025 está entre os dois. Esse intervalo não é um
  intervalo de confiança, como o IC 95% da tabela anual:

  | | IC 95% da simulação | Intervalo do Histórico |
  |---|---|---|
  | Origem da incerteza | Variação dos sorteios entre as execuções | Falta de dado sobre o transporte entre regiões |
  | Significado | Procedimento com cobertura nominal de 95% para a média | O valor real está garantidamente nessa faixa |
  | Diminui com mais execuções | Sim | Não, só com dados de transporte |
- **Fechamento diário:** dias com falta, maior falta diária, falta no
  percentil 95 (o valor que 95% dos dias não ultrapassam), maior
  sequência de dias seguidos com falta e falta diária somada. Mostra
  quando a gasolina não estava na região certa, mesmo com o ano coberto.
- **Mobilidade do FUT por teto:** uma linha por teto do cenário 9,
  resumindo as suas 10 execuções: FUT, produção, cobertura efetiva, diferença contra a
  execução de mesmo número da referência, déficit, dias com falta e falta
  diária somada. Os mesmos números ficam em `scenario_ceiling.csv`.
- **FUT mensal:** média de cada mês, para ver em que época o parque
  trabalha mais.
- **Cobertura efetiva por região:** quanto da demanda de cada região foi
  servido no ano, com a refinação dela e as chegadas de comboio.
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
