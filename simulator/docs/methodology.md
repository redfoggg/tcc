# Metodologia dos cenários

A bateria é um experimento separado do painel. O botão "Rodar bateria"
dispara 10 cenários, com 10 execuções cada, e grava um CSV por execução.
Os processos das refinarias do painel permanecem como estão. Estoque
inicial e ajuste de demanda do formulário ficam de fora: cada cenário
traz os próprios insumos.

Cada execução resolve os 365 dias de 2025 com o mesmo MILP do Planejado.
A pausa mínima de 30 s do painel fica desligada. As execuções correm em
sequência. O resultado vai para `data/studies/<timestamp>/`.

## O que permanece fixo

Calendário de 2025, demanda curada, capacidade de processamento curada,
as 12 refinarias do catálogo e a regra de FUT: abertura em 100%, descida
até 90%, trava pelo excesso acima de 90%, piso de 40% quando a planta
está ativa. LUBNOR continua de fora.

Quando uma planta volta depois de uma parada, ela entra em rampa: 40%
e mais 1 ponto percentual por dia até 100%. A partir daí vale o ciclo
aberto, descida e trava.

## Protocolo

São 100 execuções. O arquivo `manifest.csv` tem uma linha por execução,
com o choque sorteado e os totais anuais. Cada execução também gera
`<cenario>/run_XX.csv`, com uma linha por refinaria e dia. Planta fora
do modelo naquele dia entra com `in_model` igual a 0.

Nos cenários de rendimento mínimo e máximo o insumo é o mesmo nas dez
execuções. Os dez arquivos repetem o mesmo plano. Nos demais, cada
execução sorteia de novo. O par, os meses e os rendimentos usados ficam
no manifesto e no CSV da execução.

Rendimento 0 no histórico é decisão de mercado, não piso técnico. O
mínimo e o máximo usam só os meses válidos com rendimento estritamente
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

### 3. rendimento_maximo

Igual ao mínimo, com o maior rendimento mensal válido de cada refinaria
em todos os dias.

### 4. referencia

Controle. O rendimento é sorteado a cada dia na lista mensal válida da
refinaria. As doze ficam no ar. A demanda segue o proxy curado. O estoque
inicial é zero. É o mesmo mecanismo do Planejado, percorrendo o ano
direto e com as doze plantas disponíveis.

### 5. choque_demanda

Igual à referência, com a demanda 15% acima do proxy curado em todos os
dias.

### 6. demanda_retraida

Igual à referência, com a demanda 15% abaixo do proxy curado em todos os
dias.

### 7. manutencao_escalonada

Cada execução sorteia uma ordem das 12 refinarias e associa uma a cada
mês. Naquele mês a planta fica fora. Em qualquer dia há exatamente uma
parada. O rendimento segue o sorteio diário.

### 8. cluster_regional

Cada execução sorteia uma região e um bloco de dois meses civis
consecutivos. O início cai entre janeiro e novembro. Todas as plantas
da região ficam fora nesse bloco. O rendimento segue o sorteio diário.

| Região | Refinarias | Entra no sorteio |
|---|---|---|
| norte | REAM | não |
| sao_paulo | REPLAN, REVAP, RPBC, RECAP | sim |
| sul | REPAR, REFAP | sim |
| nordeste | REFMAT, RNEST, RPCC | sim |
| rio_minas | REDUC, REGAP | sim |

Norte é a REAM. Ela permanece no catálogo e no ar quando outra região
sai. O sorteio não a escolhe porque uma planta só não forma um cluster
regional. Parada de uma refinaria é o cenário 7.

### 9. estoque_de_abertura

Igual à referência, com estoque inicial igual a 15 dias da demanda
diária média de 2025. A média usa os 365 dias do proxy curado.

### 10. campanha_estavel

Cada execução sorteia um rendimento por refinaria e o mantém nos 365
dias. As plantas ficam no ar. Demanda e estoque seguem a referência.
Na referência, o rendimento muda todo dia. Aqui a campanha da planta
é estável.

## Arquivos

`manifest.csv` junta cenário, execução, modo de rendimento, ajuste de
demanda, estoque inicial, disponibilidade, plantas e meses fora, totais
anuais e o caminho do CSV detalhado.

O CSV da execução traz, por refinaria e dia, o rendimento usado, a
alocação, o petróleo processado, a capacidade, o FUT da planta, se ela
entrou no modelo, e os totais do dia: demanda, produção, déficit,
estoques e FUT total.

A pasta `data/studies/` fica de fora do git.
