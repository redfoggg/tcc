# Metodologia dos cenários

A bateria é um experimento separado do painel. O botão "Rodar bateria"
dispara 10 cenários, com 10 execuções cada, e grava um CSV por execução.
Os processos das refinarias do painel permanecem como estão. O ajuste de
demanda e a porcentagem de falha do formulário ficam
de fora: cada cenário traz os próprios insumos. A referência sorteia, em
cada execução, uma taxa de acidente por rota, de 1% a 5%. O cenário de
falha alta sorteia, em cada execução, uma taxa por rota de 41% a 100%.
Nos outros oito cenários a porcentagem fica em 1. Não há estoque nacional.

Cada execução resolve os 365 dias de 2025 com o mesmo MILP do Planejado.
A pausa mínima de 30 s do painel fica desligada. As execuções correm em
sequência. O resultado vai para `data/studies/<timestamp>/`.

## O que permanece fixo

Calendário de 2025, demanda curada, capacidade de processamento curada,
as 12 refinarias do catálogo e a regra de FUT. O planejamento é
nacional e usa a capacidade da placa. O piso de quem está no ar é o FUT
aceitável: 94% no padrão. No cenário 10 o piso vai de 85% a 94%, um ponto por execução. O teto é
100%. O HiGHS devolve o petróleo da campanha. No dia 1 a demanda entra
dividida pela média nacional. Nos dias seguintes, pela gasolina realizada
até ali sobre o petróleo processado até ali. O rendimento sorteado
multiplica o petróleo na execução. LUBNOR continua de fora.

Quando uma planta volta depois de uma parada, o piso entra em rampa: 40%
e mais 1 ponto percentual por dia até o FUT aceitável. O planejamento
pode usar essa planta acima do piso, até 100%, se a demanda pedir.

Não há estoque nacional. Planta que produziu acima do plano abre um
processo de entrega para a que ficou abaixo do plano. Cada comboio leva
no máximo 30 m³ e só sai com pelo menos 20 m³. A carga fica nesse
processo. Ela entra na demanda só no dia da chegada.
Se o processo cai, a carga é perdida e as duas plantas são avisadas.
Três perdas seguidas na mesma rota fazem a origem esperar 10 dias.
Uma entrega que sai zera a contagem. A pausa não perde carga: a origem
tenta a próxima planta com falta.
O prazo de cada comboio é o tempo de caminhão da estrada, o teto de
quilômetros / 60 / 24, com mínimo de 1 dia. Não há chegada no mesmo dia.
`RPCC → RPBC` leva 3 dias e `RNEST → RPCC` leva 1 dia. O cenário 8 fecha
três rotas por dois meses civis. Fora do bloco, nenhuma estrada fecha.
Processo que não responde conta como planta ausente.

## Protocolo

São 100 execuções. O arquivo `manifest.csv` tem uma linha por execução,
com o choque sorteado, a nota e os totais anuais. Cada execução também gera
`<cenario>/run_XX.csv`, com uma linha por refinaria e dia. Planta fora
do modelo naquele dia entra com `in_model` igual a 0.

No cenário de rendimento mínimo o insumo é o mesmo nas dez
execuções. Os dez arquivos repetem o mesmo plano. Nos demais, cada
execução sorteia de novo. O par, os meses, as rotas fechadas e os
rendimentos usados ficam no manifesto e no CSV da execução.

Rendimento 0 no histórico é decisão de mercado, não piso técnico. O
mínimo usa só os meses válidos com rendimento estritamente
positivo. Se a refinaria não tem nenhum, entra a média nacional de
gasolina A, a mesma regra do sorteio do painel.

## Cenários

### 1. rendimento_minimo

Todas as refinarias ficam no ar o ano inteiro. Em todos os dias, o
rendimento de gasolina A de cada uma é o menor rendimento mensal válido
observado em 2025 para aquela planta.

### 2. paradas_produtivas

As mais produtivas são as quatro com maior volume de gasolina A
observado em 2025:

| Refinaria | Gasolina A em 2025 |
|---|---|
| REPLAN | 6,1 milhões de m³ |
| REPAR | 4,0 milhões de m³ |
| REFMAT | 3,4 milhões de m³ |
| REVAP | 2,9 milhões de m³ |

Cada execução sorteia duas dessas quatro. Elas ficam fora do modelo por
três meses civis consecutivos. O mês inicial é sorteado entre janeiro e
outubro, para o bloco caber em 2025. O rendimento segue o sorteio diário
do painel. A demanda do dia é realocada nas refinarias que permanecem,
dentro do FUT disponível de cada uma.

O choque tem sempre duas plantas, para o tamanho ficar igual nas dez
execuções. O par e o bloco de meses mudam. O manifesto registra os dois.

### 3. referencia

Controle. O rendimento é sorteado a cada dia na lista mensal válida da
refinaria. As doze ficam no ar. A demanda segue o proxy curado. Não há
saldo nacional entre os dias. É o mesmo mecanismo do Planejado,
percorrendo o ano direto e com as doze plantas disponíveis.

Cada execução sorteia uma vez um inteiro de 1 a 5, inclusive, para cada
uma das 66 rotas. A rota é o par de refinarias sem direção, o mesmo par
de `Refineries.Distances`. O valor vale nos dois sentidos. O mapa entra
em `failure_pct`. A chave da rota é a tupla ordenada, por exemplo
`{"RECAP", "REPLAN"}`, e também o texto `RECAP|REPLAN`, com os
identificadores em ordem. Se o mapa não tem a rota, o modelo usa a
porcentagem do destino, como o painel. Chave ausente vale 0. O valor
fica entre 0 e 100. Esta faixa de 1% a 5% vale só neste controle.

### 4. choque_demanda

Rendimento, plantas no ar e o prazo de caminhão seguem a referência. A
demanda fica 15% acima do proxy curado em todos os dias. A porcentagem
de falha fica em 1.

### 5. demanda_mensal

Cada execução sorteia um inteiro de -1 a 15, inclusive, para cada mês
civil. O mesmo valor vale em todos os dias daquele mês. A demanda pode
cair até 1% ou subir até 15% em relação ao proxy curado. O sorteio não
se acumula de um mês para o outro. Plantas, rendimento e prazo seguem a
referência. A porcentagem de falha fica em 1. O manifesto grava os doze
valores na nota, no formato `demanda 1:-1 2:11`.

### 6. manutencao_escalonada

Cada execução sorteia uma ordem das 12 refinarias e associa uma a cada
mês. Naquele mês a planta fica fora. Em qualquer dia há exatamente uma
parada. O rendimento segue o sorteio diário. A porcentagem de falha fica
em 1.

### 7. falha_alta_remessa

Cada execução sorteia uma vez um inteiro de 41 a 100, inclusive, para
cada rota sem direção. 70, 80 e 100 cabem no sorteio. A faixa de 1% a
5% do controle não entra aqui. As doze plantas ficam no ar. O rendimento
segue o sorteio diário. O prazo é o tempo de caminhão de cada par. A chave do mapa é
a mesma da referência.

### 8. rotas_bloqueadas

Cada execução sorteia três rotas entre os 66 pares de
`Refineries.Distances` e ordena o trio. Também sorteia um bloco de dois
meses civis consecutivos. O mês inicial cai entre janeiro e novembro.
Nesses dois meses as três rotas ficam fechadas em todos os dias, nos
dois sentidos, pela opção `closed_roads`. Fora do bloco a função devolve
lista vazia. A porcentagem de falha permanece 1. As plantas ficam no ar.
O rendimento segue o sorteio diário. O prazo é o tempo de caminhão de cada par. O
manifesto grava as rotas e os meses no campo `note`, no formato
`rotas RECAP|REPLAN REDUC|REFAP REPAR|REVAP meses 3|4`.

### 9. campanha_estavel

Cada execução sorteia um rendimento por refinaria e o mantém nos 365
dias. As plantas ficam no ar. Demanda e trânsito seguem a referência.
Na referência, o rendimento muda todo dia. Aqui a campanha da planta
é estável. A porcentagem de falha fica em 1.

### 10. mobilidade_fut

As doze plantas ficam no ar. A falha logística fica em 1. O prazo é o
tempo de caminhão. Uma campanha de rendimento é sorteada uma vez e
repetida nas dez execuções: cada planta guarda o mesmo rendimento nos
365 dias, e esse rendimento não muda de uma execução para outra.

O piso de FUT muda com a execução. A execução 1 usa 85%. Cada execução
seguinte sobe 1 ponto percentual, até 94% na execução 10. O teto continua
100%. O plano pode usar a planta acima do piso, até esse teto, se a
demanda pedir. O manifesto grava o piso em `fut_lock`.

## Arquivos

`manifest.csv` junta cenário, execução, modo de rendimento, ajuste de
demanda, dias de trânsito (`par` em todos os cenários), disponibilidade,
trava de FUT, plantas e meses fora, totais anuais, o caminho do CSV
detalhado e a nota. No cenário 8 a nota traz as rotas fechadas e os meses.
No cenário 5 a nota traz o ajuste de cada mês. Parada de uma refinaria,
um mês de cada vez, é o cenário 6.

O CSV da execução traz, por refinaria e dia, o rendimento usado, a
alocação, o petróleo da campanha, as outras cargas, a capacidade, o FUT
da planta, se ela
entrou no modelo, e os totais do dia: demanda, produção, déficit,
chegadas, excedente, estoque da planta (produzido menos enviado) e FUT total.

A pasta `data/studies/` fica de fora do git.

## Ressalva

A demanda proxy é afetada pelos números de mercado: as vendas de
gasolina C foram observadas no regime de preços vigente. O modelo a
trata como exógena, o que é uma simplificação.
