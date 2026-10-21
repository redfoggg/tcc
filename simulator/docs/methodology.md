# Metodologia dos cenários

A bateria é um experimento separado do painel. O botão "Rodar bateria"
roda 9 cenários, com 10 execuções cada, e grava um CSV (arquivo de
valores separados por vírgula) por execução em
`data/studies/<timestamp>/`. A bateria e a análise dela ficam no
repositório como resultado do trabalho. As plantas do
painel permanecem como estão, e o ajuste de demanda e as taxas de falha
do formulário não entram: cada cenário traz os próprios insumos.

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
  bateria, cada número de execução, de 1 a 10, recebe um sorteio de uma
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
  cada número de execução, de 1 a 10, recebe um sorteio de rendimento
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
teto de FUT, de 80% na execução 1 a 98% na execução 10, dois pontos por
execução. Quando o teto fica abaixo de 94%, o piso desce junto e as
plantas rodam travadas no teto. O manifesto grava o teto em `fut_lock`.

As dez execuções são dez tetos diferentes, não repetições do mesmo
choque. O resultado se lê como curva: cobertura, déficit e produção em
função do teto. A execução $n$ usa os mesmos rendimentos e as mesmas
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

O script usa NumPy para as contas sobre os vetores de resultados e SciPy
para o intervalo de confiança e o teste de Welch. As versões estão em
`data/scripts/requirements.txt`, e o ambiente `.venv` fica fora do git.
Sem argumento, o script usa a bateria mais recente de `data/studies`.
Ele grava em `<pasta>/analysis/` um `report.md` com as tabelas abaixo e os
CSVs com todos os números: `scenario_annual.csv`,
`scenario_vs_reference.csv`, `scenario_daily.csv`,
`scenario_monthly.csv`, `scenario_refineries.csv`,
`scenario_regions.csv` e `scenario_ceiling.csv`.

Para cada cenário, o resumo das execuções que terminaram traz:

| Medida | Significado |
|---|---|
| Média e desvio padrão (dp) | Valor típico e quanto as execuções se afastam dele |
| Coeficiente de variação (CV) | Desvio padrão dividido pela média. Compara a dispersão de medidas em escalas diferentes |
| Mínimo e máximo | Melhor e pior execução |
| IC 95% | Intervalo de confiança de 95% da média, pela distribuição t de Student com $n-1$ graus de liberdade, onde $n$ é o número de execuções. Ver Como ler a estatística |
| Δ contra a referência | Média do cenário menos média da referência. A diferença é marcada quando o valor p do teste t de Welch, que compara médias com variâncias diferentes, fica abaixo de 0,05. O CSV traz também o valor p e o intervalo de 95% da diferença. Ver Como ler a estatística |

### Como ler a estatística

**O problema.** Cada cenário roda 10 vezes, e cada execução dá um número
diferente por causa dos sorteios. A média das 10 é uma estimativa, não o
valor verdadeiro do cenário. Daí saem duas perguntas diferentes:

| Pergunta | Ferramenta | No relatório |
|---|---|---|
| Quão precisa é a média? | Distribuição t de Student | Coluna IC 95% |
| A diferença contra a referência é real ou sorte? | Teste t de Welch | Asterisco no Δ |

**Ingredientes.** A média é a soma dividida por $n$. O desvio padrão
mede quanto uma execução se afasta da média. Ele divide a soma dos
quadrados por $n-1$, e não por $n$, porque os desvios são medidos contra
a própria média da amostra, que fica mais perto dos dados do que a média
verdadeira; dividir por $n$ subestimaria a dispersão. O erro padrão é a
incerteza da média, e não de uma execução:

$$\text{ep} = \frac{\text{dp}}{\sqrt{n}}$$

Com 10 execuções, o erro padrão é cerca de um terço do desvio padrão. A
média de 10 execuções varia menos do que uma execução sozinha.

**Distribuição t de Student e IC 95%.** Se o desvio padrão verdadeiro
fosse conhecido, bastaria a curva normal, com multiplicador 1,96. Mas
ele também é estimado com só 10 execuções, e pode sair menor do que o
real. A curva t de Student cobre esse risco: tem caudas mais pesadas e
alarga o intervalo. O tamanho do alargamento depende dos graus de
liberdade, $n-1 = 9$ aqui. Multiplicador para 95%:

| Execuções | Graus de liberdade | Multiplicador $t$ |
|---|---|---|
| 5 | 4 | 2,78 |
| 10 | 9 | 2,262 |
| 30 | 29 | 2,05 |
| infinitas | infinitos | 1,96 |

$$\text{IC} = \text{média} \pm t \times \text{ep}$$

Leitura: se a bateria fosse repetida 100 vezes com sementes novas, cerca
de 95 dos intervalos calculados conteriam a média verdadeira do cenário.
O intervalo não sabe que a cobertura não passa de 100%. Um limite acima
de 100 se lê como 100.

Exemplo com a cobertura efetiva da referência na bateria
`data/studies/20261021T045244Z`:

| Passo | Valor |
|---|---|
| Média de 10 execuções | 98,872% |
| dp | 0,565 p.p. |
| ep $= 0{,}565 / \sqrt{10}$ | 0,179 p.p. |
| $t$ com 9 graus de liberdade | 2,262 |
| Meia largura $= 2{,}262 \times 0{,}179$ | 0,40 p.p. |
| IC 95% | 98,47% a 99,28% |

É o mesmo intervalo da coluna "IC 95% da efetiva" do `report.md`.

**Teste t de Welch e o asterisco.** O teste mede a diferença das médias
em unidades de erro padrão. Os erros padrão dos dois grupos se somam em
quadrado:

$$\text{ep}_\text{dif} = \sqrt{\text{ep}_1^2 + \text{ep}_2^2} \qquad t = \frac{\text{diferença}}{\text{ep}_\text{dif}}$$

Os graus de liberdade saem da fórmula de Welch–Satterthwaite:

$$\text{gl} = \frac{(\text{ep}_1^2 + \text{ep}_2^2)^2}{\dfrac{\text{ep}_1^4}{n_1 - 1} + \dfrac{\text{ep}_2^4}{n_2 - 1}}$$

Com dois grupos de 10 que variam igual, ela dá 18. Quando um grupo varia
muito mais do que o outro, ela cai para perto de 9, porque quase toda a
incerteza vem de um grupo só. Menos graus de liberdade tornam o teste
mais exigente.

O valor p é a chance de ver uma diferença deste tamanho, ou maior, se o
cenário não mudasse nada. Abaixo de 0,05, a diferença ganha o asterisco.

Por que Welch e não o teste t de Student clássico: o clássico supõe que
os dois grupos variam igual. Aqui isso é falso. Na cobertura efetiva, o
dp de demanda_mensal é 1,35 p.p., e o da referência é 0,57 p.p.

Exemplo, cobertura efetiva de demanda_mensal contra a referência:

| Passo | Valor |
|---|---|
| Média de demanda_mensal | 93,869% (dp 1,351, ep 0,427) |
| Média da referência | 98,872% (dp 0,565, ep 0,179) |
| Diferença | -5,00 p.p. |
| ep da diferença $= \sqrt{0{,}427^2 + 0{,}179^2}$ | 0,463 p.p. |
| $t = -5{,}00 / 0{,}463$ | -10,8 |
| Graus de liberdade | 12,1 |
| Valor p | $1{,}5 \times 10^{-7}$ |

A diferença é 11 erros padrão, e o relatório mostra -5,00 *.

**Cuidados.**

- Significativo não quer dizer importante. O asterisco diz que a
  diferença não é sorte, não que ela é grande. Leia sempre o tamanho do
  Δ junto com o asterisco.
- `scenario_vs_reference.csv` faz 104 testes (8 cenários × 13
  medidas), sem correção para comparações múltiplas. A tabela do
  `report.md` mostra só 5 medidas por cenário, mas os outros testes
  existem. Com 5% de chance de erro em cada um, mesmo que nenhum cenário
  mudasse nada, uns 5 dos 104 sairiam com asterisco por acaso.
  Resultados com p perto de 0,05 pedem cautela. Efeitos grandes, como o
  do exemplo, não são afetados.
- O teste trata as execuções como independentes. Mas a execução $n$ de
  cada cenário usa os mesmos rendimentos e taxas de falha da execução
  $n$ da referência. Esse pareamento reduz o ruído real da diferença, e
  o teste não aproveita isso. Ele fica conservador: pode deixar de marcar
  uma diferença pequena, mas não invalida os asteriscos que já estão lá.

O relatório tem estas seções:

- **Resultado anual:** cobertura nacional, cobertura efetiva com o IC
  95%, déficit, produção, FUT e perdas. As duas coberturas estão em
  `docs/model_specification.md`, seção Indicadores do painel.
- **Efeito contra a referência:** quanto cada choque muda as duas
  coberturas, o déficit, a produção e o FUT. No cenário 9 essa linha
  é a média de dez tetos diferentes. O efeito do teto se lê como curva,
  execução a execução, como descrito na seção do cenário.
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
  | Significado | A média provavelmente está nessa faixa | O valor real está garantidamente nessa faixa |
  | Diminui com mais execuções | Sim | Não, só com dados de transporte |
- **Fechamento diário:** dias com falta, maior falta diária, falta no
  percentil 95 (o valor que 95% dos dias não ultrapassam), maior
  sequência de dias seguidos com falta e falta diária somada. Mostra
  quando a gasolina não estava na região certa, mesmo com o ano coberto.
- **Mobilidade do FUT por teto:** uma linha por execução do cenário 9,
  em ordem de teto: FUT, produção, cobertura efetiva, diferença contra a
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
