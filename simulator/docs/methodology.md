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
manifesto. As opções `--bootstrap-resamples` e `--bootstrap-seed` controlam
a reamostragem (padrões: 9999 e 20261022). `--output <pasta>` permite
revisar uma análise em outra pasta antes de substituir `analysis/`.

O relatório `report.md` é acompanhado de `scenario_annual.csv`,
`scenario_vs_reference.csv`, `scenario_daily.csv`, `scenario_monthly.csv`,
`scenario_refineries.csv`, `scenario_regions.csv`, `scenario_ceiling.csv`
e `statistical_diagnostics.csv`. Campos vazios indicam valores não
estimáveis; não representam zero. As médias e os desvios padrão
continuam descrevendo os mesmos resultados brutos.

### Como ler a estatística

**Unidade de análise.** Uma observação é uma execução completa do ano.
Os dias e as refinarias de uma mesma execução não são tratados como
repetições independentes. Cada cenário tem 100 execuções; em
`mobilidade_fut` há dez condições diferentes, com 10 execuções por teto.

**Média, dispersão e precisão.** O desvio padrão amostral usa $n-1$ no
denominador. O erro padrão da média é $s/\sqrt{n}$. Para uma condição
fixa, o intervalo individual de 95% pela distribuição t de Student é:

$$
\bar x \pm t_{0{,}975;\,n-1}\frac{s}{\sqrt n}
$$

Com 100 execuções, são 99 graus de liberdade e o multiplicador é
aproximadamente 1,984; com 10 execuções por teto, são 9 graus de
liberdade e multiplicador 2,262. Repetindo baterias independentes e
construindo um intervalo em cada uma, o método busca conter a média
verdadeira em aproximadamente 95% dos intervalos, sob suas hipóteses.
O intervalo não é uma previsão para uma execução individual. Limites
que ultrapassem o domínio físico são mantidos no CSV e devem ser
interpretados junto com os diagnósticos, sem corte silencioso.

**Comparação pareada contra a referência.** A execução de número $j$ de
um cenário compartilha parte dos sorteios com a execução $j$ da
referência. O analisador valida o número e a semente de cada par,
rejeita duplicatas, pares ausentes, execuções com falha e dados não
finitos. A ordem das linhas no manifesto não determina o pareamento.

Para cada medida, calcula-se uma diferença dentro de cada par:

$$
d_j = x_{\mathrm{cenário},j}-x_{\mathrm{referência},j},
\qquad
\Delta=\bar d,
\qquad
\mathrm{ep}_{\Delta}=\frac{s_d}{\sqrt n},
\qquad
t=\frac{\bar d}{s_d/\sqrt n}
$$

O teste t pareado é bilateral e testa média das diferenças igual a zero,
com $n-1$ graus de liberdade. A inferência depende da independência entre
pares; a relação dentro de cada par é incorporada pelo cálculo das
diferenças. Esse método substitui Welch, que tratava os grupos como
independentes. Não se seleciona o teste com base no p de normalidade.

**Comparações múltiplas.** A correção de Holm é aplicada a uma única
família planejada: 7 cenários de condição fixa × 13 medidas e 10 tetos
× 13 medidas, totalizando 221 comparações nesta bateria. A família
inclui as medidas que não aparecem na tabela resumida do relatório.
Comparações não estimáveis permanecem na contagem da família, mas não
recebem p nem podem ser rejeitadas.

Ordenam-se os valores p válidos do menor para o maior. Para o p na
posição $k$ (começando em 1), o fator é $m-k+1$, com $m$ igual ao número
planejado de comparações. O p ajustado é o máximo acumulado desses
produtos, limitado a 1. O asterisco requer p ajustado menor que 0,05.
Sob a validade dos testes individuais, Holm controla a probabilidade de
uma ou mais rejeições falsas na família em até 5%, sem exigir
independência entre testes. Isso não é a probabilidade de cada
conclusão estar errada. Os ICs de 95% continuam individuais, sem
cobertura simultânea de 95% para a família.

**Distribuição e sensibilidade.** O diagnóstico das medidas anuais,
separado por condição, fica em `statistical_diagnostics.csv`. Inclui
quantis, assimetria, curtose, Shapiro–Wilk, pontos fora das cercas de
Tukey ($1{,}5\times\mathrm{IQR}$) e observações nos limites físicos de
cobertura e FUT. Os mesmos diagnósticos, exceto limites físicos de
nível, acompanham as diferenças em `scenario_vs_reference.csv`.
Nenhum ponto extremo é removido.

Os alertas são exploratórios: `small_sample` para $n<30$,
`strong_skew` para assimetria absoluta maior que 1,
`shapiro_p_below_0.05` para p de Shapiro abaixo de 0,05,
`tukey_outliers` para pontos fora das cercas e `boundary_mass` para
observações nos limites. Esses limites são convenções de diagnóstico,
não regras que garantem ou invalidam automaticamente o teste t.
Os valores p de Shapiro não são testes de efeito e não entram em Holm.

Além do IC t, calculamos IC bootstrap BCa de 95% para as médias e para
as médias das diferenças. O bootstrap reamostra execuções inteiras;
para comparações, reamostra as diferenças dos pares, preservando o
pareamento. A semente e a quantidade de reamostragens são registradas,
e a mesma entrada produz os mesmos resultados. O IC BCa é uma análise
de sensibilidade, não um substituto selecionado depois de olhar o p.

O relatório sinaliza com † quando t e BCa discordam sobre a exclusão
de zero ou quando BCa não é estimável. Concordância não comprova a
validade de ambos; os dois dependem da representatividade da amostra.
Com 10 pares por teto, mesmo o bootstrap não recupera informação que
não foi observada. O p ajustado continua vindo do teste t pareado;
o bootstrap não produz um segundo conjunto de asteriscos.

**Tetos de FUT.** A média e o desvio padrão agregados de
`mobilidade_fut` são apenas descritivos. Misturam o efeito dos tetos e
a variação dos sorteios; por isso não recebem IC ou teste agregado.
A inferência é feita por teto, usando as suas 10 execuções e as 10
execuções correspondentes da referência. As comparações por teto
entram na mesma família de Holm das demais medidas anuais.

**Amostras constantes.** Se a amostra ou as diferenças pareadas não
apresentam variação distinguível da precisão numérica, o script
preserva média, desvio padrão, mínimo e máximo, mas deixa ICs, t e p
vazios e informa o motivo em `inference_status`. Não atribui p zero ou
um nem interpreta IC pontual como certeza. Uma amostra constante não
demonstra determinismo do modelo nem equivalência entre cenários.

**Limites da conclusão.** O tamanho do efeito e seus intervalos devem
acompanhar o asterisco. A ausência de significância não demonstra
igualdade. Os diagnósticos tornam visíveis as condições de uso, sem
transformar aproximações em garantias. Mais execuções não corrigem
premissas inadequadas nem quantificam automaticamente a incerteza dos
dados históricos e da estrutura do modelo.

Referências dos métodos: [IC da média, NIST](https://www.itl.nist.gov/div898/handbook/eda/section3/eda352.htm),
[teste pareado, SciPy](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.ttest_rel.html),
[bootstrap BCa, SciPy](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.bootstrap.html),
[Shapiro–Wilk, SciPy](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.shapiro.html)
e [correção de Holm, statsmodels](https://www.statsmodels.org/stable/generated/statsmodels.stats.multitest.multipletests.html).
A implementação usa NumPy e SciPy; não adiciona dependência de statsmodels.

O relatório tem estas seções:

- **Resultado anual:** cobertura nacional, cobertura efetiva com o IC
  95%, déficit, produção, FUT e perdas. As duas coberturas estão em
  `docs/model_specification.md`, seção Indicadores do painel.
- **Efeito contra a referência:** quanto cada choque muda as duas
  coberturas, o déficit, a produção e o FUT, com teste pareado e Holm.
  No cenário 9, cada teto tem sua própria linha e seus pares de referência.
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
