# Referência do modelo e das funções

Esta referência descreve o modelo de gasolina A de 2025 implementado e seus
contratos de software atuais. Os caminhos são relativos a `simulator/`.

## 1. Escopo e terminologia

| Termo | Definição |
|---|---|
| Histórico 2025 | Registro estático pré-computado lido de `data/curated/historical_2025_summary.json`. O tempo de execução não o recalcula. |
| Planejado 2025 | Simulação de janeiro a dezembro usando entradas de CSV curadas, rendimento de referência fixo por refinaria, controles anuais e um programa linear inteiro misto mensal, resolvido em duas etapas lexicográficas. |
| Proxy de demanda de gasolina A | Gasolina A pura estimada como necessária para sustentar as vendas observadas no varejo de gasolina C. Não é demanda observada de gasolina A. |
| FUT | Processamento bruto de petróleo dividido pela capacidade bruta de processamento de petróleo, expresso em percentual. É um indicador, não o objetivo. Quando agregado (mensal ou anual, sobre o escopo fixo), é sempre uma razão de somas, nunca uma média das razões individuais. |

O proxy de demanda base é:

$$
D_t^{base}=SalesC_t(1-e_t)
$$

onde $e_t=0.27$ até julho de 2025 e $e_t=0.30$ a partir de agosto de 2025.

Os volumes são em metros cúbicos, escritos m³. O rendimento é adimensional.
O FUT é um percentual.

O escopo fixo contém 13 refinarias: LUBNOR, REAM, RECAP, REDUC, REFAP,
REFMAT, REGAP, REPAR, REPLAN, REVAP, RNEST, RPBC e RPCC. REFMAT reconhece
RLAM e CEBV como aliases. REAM reconhece REMAN. RPCC é o código ANP de Clara
Camarão. Todas as 13 refinarias participam de todos os 12 meses: não existe
mais nenhum conceito de refinaria excluída.

## 2. Símbolos e índices

| Símbolo | Significado | Unidade |
|---|---|---|
| $t \in T=\{1,\ldots,12\}$ | Mês, janeiro a dezembro de 2025 | índice |
| $i \in F$ | Refinaria do escopo fixo (13 refinarias, todas presentes em todos os meses) | índice |
| $R_i$ | Rendimento de referência fixo de gasolina A da refinaria $i$, constante nos 12 meses | razão |
| $K^G_{i,t}$ | Capacidade teórica curada de gasolina A | m³ gasolina A/mês |
| $K^P_{i,t}$ | Capacidade bruta de processamento de petróleo | m³ petróleo/mês |
| $L_{i,t}$ | Piso operacional efetivo, sempre limitado a $K^G_{i,t}$ | m³ gasolina A/mês |
| $D_t$ | Proxy de demanda de gasolina A ajustado | m³ gasolina A |
| $S_{t-1}$ | Estoque inicial | m³ gasolina A |
| $x_{i,t}$ | Alocação planejada de gasolina A | m³ gasolina A |
| $y_{i,t}$ | Ativação da refinaria | binária |
| $u_t$ | Déficit de demanda | m³ gasolina A |
| $S_t$ | Estoque final | m³ gasolina A |

Não há mais coeficiente de penalidade $\lambda$: a priorização entre déficit e
processamento de petróleo é feita por duas etapas lexicográficas estritas,
não por uma soma ponderada de termos em um único objetivo.

## 3. Objetivo lexicográfico em duas etapas

Cada mês é resolvido de forma independente, em duas etapas estritas.

**Etapa 1**, minimiza o déficit do mês:

$$
\min u_t \quad \text{sujeito às restrições da seção 4}
$$

Seja $u_t^{\star}$ o valor ótimo encontrado na etapa 1. **Etapa 2**, fixa o
déficit em $u_t^{\star}$ (dentro de uma tolerância $\varepsilon=10^{-6}$ m³) e
minimiza o processamento total de petróleo implícito:

$$
\min \sum_{i \in F}\frac{x_{i,t}}{R_i}
\quad \text{sujeito às restrições da seção 4 e a }
u_t^{\star}-\varepsilon \le u_t \le u_t^{\star}+\varepsilon
$$

O termo minimizado na etapa 2 é o processamento de petróleo implícito, porque
$R_i$ é a saída de gasolina A por unidade de petróleo processado. Isso não é
um MILP anual conjuntamente otimizado, porque cada $S_t$ é comprometido antes
de resolver o mês $t+1$.

Como o denominador do FUT Total do mês (a soma de $K^P_{i,t}$ sobre todo o
escopo fixo $F$) é constante dentro daquele mês, minimizar o processamento
total de petróleo na etapa 2 é matematicamente equivalente a minimizar o FUT
Total daquele mês. O FUT Total exato reportado é sempre calculado como a
razão de fato a partir da solução final, não inferido do valor do objetivo.

A formulação em duas etapas garante uma prioridade estrita: nenhuma redução
de processamento de petróleo pode justificar um déficit maior que
$u_t^{\star}$, porque a etapa 2 nunca reabre a escolha de $u_t$. O déficit
permanece uma variável de folga não negativa e sem limite superior, então
produção e estoque insuficientes produzem um resultado ótimo válido com
$u_t>0$, não inviabilidade do solver.

## 4. Restrições implementadas

### 4.1 Balanço de estoque

$$
S_{t-1}+\sum_{i\in F}x_{i,t}+u_t-D_t-S_t=0
$$

Não há limite superior explícito de estoque ou déficit: a etapa 1 minimiza o
déficit diretamente, e a etapa 2 mantém esse déficit fixo, então nenhum dos
dois cresce sem necessidade. A demanda atendida é $D_t-u_t$. A cobertura é a
demanda atendida dividida pela demanda, ou $1{,}0$ quando a demanda é zero.

### 4.2 Não negatividade

$$
u_t\ge 0,\qquad S_t\ge 0,\qquad 0\le x_{i,t}\le K^G_{i,t}
$$

Capacidade zero fixa a alocação em zero.

### 4.3 Ativação, capacidade e piso operacional

$$
y_{i,t}\in\{0,1\},\qquad
x_{i,t}\le y_{i,t}K^G_{i,t},\qquad
x_{i,t}\ge y_{i,t}L_{i,t}
$$

O piso se aplica apenas a refinarias ativas e não força ativação. Os pisos do
repositório são a menor produção positiva observada de gasolina A em 2025, ou
zero quando não existe nenhuma. Pisos curados e definidos pelo usuário são
sempre limitados (clampados) à capacidade efetiva $K^G_{i,t}$. Uma refinaria
de capacidade zero pode ficar ativa sem produção quando seu piso também é
zero. A ativação é decodificada a partir de um valor binário resolvido maior
que 0,5.

### 4.4 Capacidade efetiva

O único limite de produção é a capacidade teórica de gasolina A curada:

$$
x_{i,t}\le K^G_{i,t}
$$

Não há mais nenhum limite derivado do processamento de petróleo
($\widehat R_{i,t}K^P_{i,t}$) combinado ao limite de gasolina A: essa
combinação existia no modelo anterior e foi removida. $K^P_{i,t}$ é mantido
apenas como denominador do FUT, para relatório e diagnóstico. A capacidade
teórica de gasolina A usa capacidade nominal e um rendimento médio nacional,
não um limite específico observado da refinaria, veja
`docs/data_report.md`.

### 4.5 Transporte sequencial de estoque

$$
S_{t-1}^{input}=
\begin{cases}
S_0^{user}, & t=1\\
S_{t-1}^{solved}, & t>1
\end{cases}
$$

Qualquer resultado mensal que não seja `:ok` interrompe a execução anual. O
modelo não tem antecipação de meses futuros nem meta de estoque terminal.

### 4.6 Controles de demanda e piso

$$
D_t=D_t^{base}\left(1+\frac{a}{100}\right)
$$

Valores em branco na interface são omitidos e os padrões se aplicam. Ajustes
de demanda abaixo de -100% criam demanda negativa. Não há mais controle de
degradação de rendimento nem de disponibilidade/parada: todas as refinarias
do escopo fixo estão sempre elegíveis para produzir em todo mês, com $R_i$
fixo e imutável por controles de cenário.

### 4.7 Limites e status do solver

O orçamento de tempo padrão é 5.000 ms por mês, repartido entre as duas
etapas lexicográficas: a etapa 1 recebe o orçamento completo, e a etapa 2
recebe o tempo restante depois que a etapa 1 termina, ambos passados ao Rust
em segundos através de `WithTimeLimit`. `Optimal` e `GapLimit` são aceitos
em cada etapa. Nenhum gap relativo ou absoluto de MIP é configurado
explicitamente.

`TimeLimit` e `NoSolutionFound` em qualquer etapa mapeiam para `:timeout`. A
tarefa externa do Elixir também pode expirar. O NIF de dirty CPU não pode ser
cancelado à força, então o trabalho nativo pode continuar brevemente após um
timeout externo.

## 5. Rendimento de referência fixo por refinaria

Diferente de uma previsão móvel mensal, cada refinaria tem um único
rendimento de referência anual, fixo para os doze meses de 2025:

$$
R_i=\frac{\sum_{t\in T} P^{obs}_{i,t}}{\sum_{t\in T} Q^{obs}_{i,t}}
$$

onde $P^{obs}_{i,t}$ é a produção observada de gasolina A e $Q^{obs}_{i,t}$ é
o processamento observado de petróleo. Essa razão local só é usada quando é
finita, o denominador é positivo e $0<R_i\le 1$. Caso contrário, $R_i$ recebe
o fallback nacional ponderado:

$$
R^{fallback}=\frac{\sum_{i\in V}\sum_{t\in T} P^{obs}_{i,t}}{\sum_{i\in V}\sum_{t\in T} Q^{obs}_{i,t}}
$$

somando apenas sobre o conjunto $V$ de refinarias com razão local válida. Em
2025, LUBNOR (sem produção observada de gasolina A) e REAM (razão local
observada maior que 1) usam o fallback nacional. O resultado completo, com
totais observados, razão bruta, validade e proveniência de cada refinaria,
está em `data/curated/anp_2025_reference_yields_by_refinery.csv`.

## 6. FUT e proveniência histórica

O FUT individual histórico por refinaria-mês é diagnóstico:

$$
FUT^{hist}_{i,t}=100
\frac{P^{obs}_{i,t}}{K^P_{i,t}}
$$

O FUT Total histórico, mensal e anual, é sempre uma razão de somas sobre o
escopo fixo de 13 refinarias, nunca a média das razões individuais:

$$
FUT^{hist,Total}_{t}=100\frac{\sum_{i=1}^{13}P^{obs}_{i,t}}{\sum_{i=1}^{13}K^P_{i,t}}
$$

$$
FUT^{hist,Total}_{ano}=100\frac{\sum_{t=1}^{12}\sum_{i=1}^{13}P^{obs}_{i,t}}{\sum_{t=1}^{12}\sum_{i=1}^{13}K^P_{i,t}}
$$

Processamento ausente ou nulo contribui com 0 para o numerador, sem alterar
o denominador. O artefato estático preserva o FUT individual não limitado de
REPAR em fevereiro de 2025, de 100,2535%, onde o processamento observado
(954.411 m³) excede a capacidade convertida daquele mês (951.998,117 m³).

O processamento planejado de petróleo e o FUT individual planejado por
refinaria são:

$$
P^{plan}_{i,t}=\frac{x_{i,t}}{R_i},
\qquad
FUT^{plan}_{i,t}=
\begin{cases}
100P^{plan}_{i,t}/K^P_{i,t}, & K^P_{i,t}>0\\
0, & K^P_{i,t}\le 0
\end{cases}
$$

O FUT Total planejado, mensal e anual, segue a mesma razão de somas sobre as
13 refinarias do escopo fixo, usada para o Histórico 2025:

$$
FUT^{plan,Total}_{t}=100\frac{\sum_{i=1}^{13}P^{plan}_{i,t}}{\sum_{i=1}^{13}K^P_{i,t}}
\qquad
FUT^{plan,Total}_{ano}=100\frac{\sum_{t=1}^{12}\sum_{i=1}^{13}P^{plan}_{i,t}}{\sum_{t=1}^{12}\sum_{i=1}^{13}K^P_{i,t}}
$$

Como $K^G_{i,t}$ usa um rendimento médio nacional em vez do rendimento
próprio de cada refinaria (veja `docs/data_report.md`), uma refinaria cujo
$R_i$ é bem maior que a média nacional pode ter $P^{plan}_{i,t}$ maior que
$K^P_{i,t}$ quando ativa em sua capacidade máxima, o que pode fazer tanto o
FUT individual planejado quanto o FUT Total agregado ultrapassarem 100%. Essa
é uma consequência conhecida da limitação de $K^G_{i,t}$ descrita em
`docs/data_report.md`, não um erro de cálculo.

O FUT individual histórico não é armazenado no JSON estático (apenas os
totais agregados por razão de somas). O FUT individual planejado existe
apenas nos resultados mensais de refinaria em memória.

## 7. Simulação anual e controles

A execução anual:

1. Carrega demanda, capacidades, pisos e rendimentos de referência dos CSVs
   curados.
2. Constrói os controles anuais e inicializa o estoque de janeiro.
3. Para cada mês, aplica o ajuste de demanda e a substituição de piso.
4. Resolve o problema mensal em duas etapas lexicográficas e calcula o
   processamento de petróleo e o FUT.
5. Transporta o estoque final bem-sucedido adiante ou interrompe em caso de
   falha.
6. Soma os volumes anuais, recalcula a cobertura anual e o FUT Total anual
   como razão de somas.

Apenas o estoque final é transportado entre meses. Os rendimentos de
referência são fixos e vêm de dados curados estáticos. Os controles
permanecem constantes ao longo do ano.

| Entrada da interface | Controle armazenado | Efeito matemático ou no modelo |
|---|---|---|
| Estoque inicial | `initial_inventory_m3` | Define $S_0$ de janeiro |
| Ajuste de demanda (%) | `demand_adjustment_pct` | Multiplica todo $D_t^{base}$ por $1+a/100$ |
| Substituição do piso operacional (m³) | `floor_overrides[id]` | Substitui $L_{i,t}$ para todos os meses, depois a limita a $K^G_{i,t}$ |

A exportação preserva os valores submetidos em `planned.controls`.

## 8. Contrato de resultado e exportação

As entradas de comparação anual e mensal do Histórico expõem
`production_supplied_m3`, `demand_target_m3`, `balance_m3` e
`total_fut_pct`. As entradas mensais também expõem `month`.

Um `Result` mensal planejado contém status, mês, saldo, FUT Total,
processamento de petróleo total e capacidade de processamento total do mês,
demanda, estoques, produção, demanda atendida, déficit, cobertura, motivo de
falha e as 13 refinarias do escopo fixo modeladas. Cada refinaria inclui
identidade, rendimento de referência e proveniência, capacidades, piso,
alocação, processamento implícito, FUT individual, ativação, utilização e a
sinalização de capacidade binding. A capacidade é binding quando uma alocação
ativa está a menos de $10^{-6}$ m³ da capacidade efetiva.

O resultado anual soma demanda, produção, demanda atendida, déficit,
processamento de petróleo total e capacidade de processamento total. Também
inclui saldo, FUT Total anual (razão de somas), primeiro e último estoque,
cobertura anual e `active_refinery_ids`.

`PlanningExport.build/3` emite a versão de esquema `5.0.0` com
`generated_at`, comparações anuais e mensais do Histórico, e identidade,
status, controles, timestamps, proveniência, erro opcional, comparação anual
e comparações mensais do Planejado.

A exportação pública omite processamento de petróleo total, capacidade de
processamento total, estoques, déficit, cobertura e a mecânica por refinaria
no nível superior. `outcome/1` constrói `mechanics` internamente, mas
`planned_entry/1` não o retorna. Resultados com falha, pendentes ou ausentes
não têm comparação anual, têm uma lista de meses vazia e um erro quando
aplicável. IDs de plano desconhecidos retornam HTTP 404.

## 9. Premissas e limitações

- O modelo é uma sequência mensal gulosa com transporte de estoque, não um
  plano anual globalmente otimizado.
- A demanda é nacional. Não há restrições de transporte, demanda regional,
  logística de mistura, custo, preço, importação, exportação ou fluxo entre
  refinarias.
- As determinações de mistura de etanol do grau comum são aplicadas a todas
  as vendas de gasolina C porque a fonte não separa os graus comum e premium.
- Um único instantâneo nominal de 2025-12-31 representa todos os meses.
- A capacidade teórica de gasolina A usa um rendimento médio nacional, não o
  rendimento próprio de cada refinaria, o que pode fazer o FUT Total
  planejado ultrapassar 100%, veja a seção 6.
- Os pisos são estatísticas históricas, não taxas mínimas de operação de
  engenharia.
- O FUT Total mantém o denominador de 13 refinarias do escopo fixo, incluindo
  refinarias inativas em um dado mês.
- O saldo histórico não é um modelo de estoque nem um déficit histórico.
- Planos ficam em memória do GenServer e desaparecem ao reiniciar. IDs não
  são persistentes.
- As entradas HTML e as verificações numéricas nativas mínimas fornecem a
  validação disponível. Chamadores diretos podem submeter controles
  economicamente incomuns.
- Nenhum gap de MIP explícito é configurado. `GapLimit` reportado pelo
  solver é aceito.
- As entradas curadas não têm pipeline de download ou regeneração neste
  repositório.

## 10. Checklist de sincronização

1. Manter os contratos de modelo, resolução e NIF em Rust sincronizados com
   a entrada do solver em Elixir.
2. Manter resultados mensais, resumos anuais, exportações, campos do painel
   e a versão de esquema sincronizados.
3. Atualizar rendimentos de referência, capacidade efetiva e proveniência em
   conjunto quando a lógica de rendimento mudar.
4. Atualizar controles, parsing da interface, controles de exportação e
   fórmulas em conjunto.
5. Regenerar `historical_2025_summary.json` separadamente quando as fórmulas
   ou o escopo histórico mudarem.
6. Manter o escopo de refinarias e os aliases sincronizados entre o
   catálogo, os arquivos curados, o artefato histórico e os denominadores de
   FUT.
7. Atualizar `docs/model_specification.md`, `docs/data_report.md` e esta
   referência quando os contratos do modelo mudarem.
8. Verificar os contratos documentados, depois rodar os testes nativos e
   `mix precommit`.
