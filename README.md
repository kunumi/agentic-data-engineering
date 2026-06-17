# Agentes de Dados sobre Linguagem Natural — Estudo de Caso NBA

> Material de apoio submetido ao **SBBD (Simpósio Brasileiro de Banco de Dados)**.
> Demonstração de dois agentes de IA — um de **exploração/consulta** e um de **engenharia de dados** — que operam sobre um banco relacional a partir de instruções em **português**, registrando conhecimento, qualidade de dados e um pipeline de transformação reproduzível.

Este repositório reúne **as perguntas de avaliação, as execuções (runs) dos agentes e todos os artefatos por eles produzidos**, de modo que um avaliador consiga inspecionar exatamente o que cada agente leu, decidiu e gerou.

---

## 1. Visão geral

O experimento usa o **Maestro Agent Runtime** (Instituto Kunumi), que expõe dois agentes complementares sobre o mesmo banco de dados (`nba.sqlite`):

| Agente | Ícone | Papel | O que produz |
|--------|-------|-------|--------------|
| **DXA** | 📊 | Responde perguntas de negócio em português, explora o schema, valida SQL e acumula conhecimento sobre o banco. | Arquivos de conhecimento: `NOTES.md`, `RECIPES.md`, `ERRORS.md`, `INSIGHTS.md`, `CLEANING_ROADMAP.md`, `SKILLS.md`. |
| **DTA** | ⚙ | Lê o `CLEANING_ROADMAP` produzido na exploração e constrói um pipeline de transformação (dbt + Dagster) que materializa o roadmap de limpeza em modelos testados. | Projeto dbt `nba_pipeline`, data warehouse DuckDB, `MODELS.md`, `TESTS.md`, `PIPELINE.md`. |

Os agentes são guiados por **perguntas em linguagem natural** (ver [`NBA/questions/`](NBA/questions/)) e podem usar diferentes LLMs de backend (Claude, GPT‑4o, Gemini, Llama, Mistral — selecionáveis na interface).

> **Sobre os rótulos `dxa` e `dta`:** são identificadores das execuções gravadas. Pela inspeção das transcrições, **`dxa` corresponde a execuções do DXA (exploração)** e **`dta` corresponde à execução do DTA (pipeline)**. Cada pasta `… - run N` é uma execução independente.

---

## 2. Mapa do repositório

```
SBBD/
└── NBA/
    ├── questions/          # Conjunto de perguntas de avaliação (entrada do experimento)
    ├── runs/               # Transcrições HTML das conversas com os agentes (evidência das execuções)
    └── artifacts/          # Tudo que os agentes produziram (conhecimento + pipeline + warehouse)
```

A seguir, cada parte em detalhe.

---

### 2.1 `NBA/questions/` — Conjunto de avaliação

[`perguntas_sql_nba.csv`](NBA/questions/perguntas_sql_nba.csv) — **30 perguntas em português** sobre o domínio NBA, classificadas por dificuldade (`Fácil`, `Médio`, `Difícil`). É a entrada do experimento: o que se pede aos agentes responder.

| Dificuldade | Nº de perguntas | Exemplos |
|-------------|-----------------|----------|
| Fácil | 10 | "Liste o nome e a cidade de todos os times cadastrados."; "Qual é a altura média e o peso médio de todos os jogadores?" |
| Médio | 10 | "Quantas vitórias cada time obteve jogando como visitante?"; "Qual foi a partida com a maior diferença de pontos (maior 'goleada')?" |
| Difícil | 10 | "Calcule a maior sequência de vitórias consecutivas de cada time."; "Para cada time, encontre o jogador mais consistente (menor desvio padrão de pontos)…" |

> As perguntas foram deliberadamente desenhadas para **expor limitações do banco**: algumas (estatística por jogador, conferência/divisão, jogos de jan/2025, data de contratação de técnicos) **não têm resposta possível** com os dados disponíveis. O valor da avaliação está em observar como o agente **detecta e comunica** essas lacunas — não apenas em acertar SQL.
>
> *(O arquivo `.~lock.…#` é um lock temporário do LibreOffice; pode ser ignorado.)*

---

### 2.2 `NBA/runs/` — Transcrições das execuções

Cada subpasta é uma **página HTML autocontida** (abra no navegador) com a conversa completa: pergunta do usuário, raciocínio do agente, consultas SQL executadas, erros, correções e leitura/escrita dos arquivos de conhecimento.

| Pasta | Agente | Conteúdo |
|-------|--------|----------|
| [`dxa - run 1/`](NBA/runs/dxa%20-%20run%201/) | 📊 DXA | Sessão de exploração mais longa (≈238 KB) — descoberta de schema, construção das receitas e do roadmap. Arquivo: `dxa.html`. |
| [`dxa - run 2/`](NBA/runs/dxa%20-%20run%202/) | 📊 DXA | Segunda execução de exploração. Arquivo: `SQL Agent.html`. |
| [`dta - run 1/`](NBA/runs/dta%20-%20run%201/) | ⚙ DTA | Construção do pipeline dbt a partir do roadmap. Arquivo: `SQL Agent.html`. |

As subpastas `*_files/` contêm apenas os assets estáticos (CSS, realce de sintaxe, `marked.js`) necessários para renderizar o HTML — **não há conteúdo de pesquisa ali**.

---

### 2.3 `NBA/artifacts/` — Artefatos produzidos

Saída efetiva dos agentes. Dividida pela execução que a gerou.

#### `artifacts/dxa - run 1/` — Conhecimento da exploração (DXA)

Arquivos de conhecimento que o DXA acumula e reutiliza entre sessões:

| Arquivo | O que contém |
|---------|--------------|
| [`NOTES.md`](NBA/artifacts/dxa%20-%20run%201/NOTES.md) | **Metadados do banco**: tabelas, tipos, relações, regras de negócio confirmadas com o usuário e limitações. Ponto de partida para entender o schema NBA. |
| [`RECIPES.md`](NBA/artifacts/dxa%20-%20run%201/RECIPES.md) | **Receitas de SQL validadas** (RCP‑001…009) — consultas testadas no banco, com contexto, resultado obtido e *gotchas*. Cobre desde "listar times" até janelas (sequências de vitórias, acumulados, aproveitamento). |
| [`ERRORS.md`](NBA/artifacts/dxa%20-%20run%201/ERRORS.md) | **Registro de erros com post‑mortem** (ERR‑001…) — erros sintáticos e de negócio encontrados e como evitá‑los (ex.: usar `TRY_CAST` em colunas texto com vazios; `data` é palavra reservada no DuckDB). |
| [`CLEANING_ROADMAP.md`](NBA/artifacts/dxa%20-%20run%201/CLEANING_ROADMAP.md) | **Roadmap prescritivo de qualidade de dados** (CLEAN‑001…010), ordenado por severidade, com evidência SQL, resultado e ação recomendada. **É a ponte entre os dois agentes**: o DTA o consome como especificação. |
| [`INSIGHTS.md`](NBA/artifacts/dxa%20-%20run%201/INSIGHTS.md) | Descobertas de negócio confirmadas pelo usuário (neste run, em branco). |
| [`SKILLS.md`](NBA/artifacts/dxa%20-%20run%201/SKILLS.md) | **Habilidades avançadas** do agente: protocolos de **análise causal** (prepare → discover → estimate → refute → report), **geração de gráficos** (`/plot`) e **profiling de dados** com Desbordante (FDs, UCCs, INDs, regras de associação, *denial constraints*). |

#### `artifacts/dta - run 1/` — Pipeline de engenharia de dados (DTA)

Materializa o `CLEANING_ROADMAP` em um pipeline dbt reproduzível.

```
dta - run 1/
├── PIPELINE.md          # Inventário do pipeline: engine, conexão, DAG, orquestração, comandos
├── MODELS.md            # Catálogo dos 12 modelos dbt (MOD-001…012) e o que cada um limpa
├── TESTS.md             # Resultado dos testes (61 PASS / 1 WARN / 0 ERROR) e validações de negócio
├── CLEANING_ROADMAP.md  # Cópia do roadmap, anotada com o status de cada item (✅ resolvido / ⚠️ requer fonte externa)
├── ERRORS.md            # Erros encontrados ao construir o pipeline (ex.: game_id não é único)
├── SKILLS.md            # Referência de comandos dbt e Dagster usados
├── nba_pipeline/        # >>> Projeto dbt completo (ver abaixo) <<<
└── warehouse/
    └── nba_dbt.duckdb   # Data warehouse DuckDB materializado (saída do `dbt build`)
```

**Projeto dbt `nba_pipeline/`** — arquitetura em camadas (`source → staging → intermediate → marts`):

| Camada | Materialização | Modelos | Função |
|--------|----------------|---------|--------|
| **staging** (`models/staging/`) | view | 6 | Limpeza 1:1 das fontes: padroniza `season_type`, deduplica `game_id`, converte altura/peso para numérico, trata datas sentinela e posições vazias. |
| **intermediate** (`models/intermediate/`) | ephemeral | 3 | Lógica de negócio: classifica jogos oficiais vs. exibição, resolve nomes históricos de franquias, calcula cobertura de fichas de jogadores. |
| **marts** (`models/marts/`) | table | 3 | Tabelas de consumo: `mart_nba__games`, `mart_nba__teams`, `mart_nba__player_profiles`. |

Outros componentes do projeto dbt:
- `macros/unit_conversions.sql` — conversões pés→cm e libras→kg.
- `tests/` — testes singulares (domínio de `birthdate`, marts não‑vazios) e genérico `positive_values`.
- `definitions.py` — orquestração **Dagster** (`dbt build` como asset, job e schedule diário `0 6 * * *`).
- `profiles.yml` — anexa o `nba.sqlite` em **modo somente‑leitura** via extensão `sqlite` do DuckDB.
- `target/` — artefatos gerados pelo dbt (`manifest.json`, `catalog.json`, SQL compilado, `run_results.json`, docs). Útil para auditar exatamente o que rodou.

> **Como ler em conjunto:** comece por `PIPELINE.md` (visão geral e DAG) → `MODELS.md` (o que cada modelo faz e qual item CLEAN ele resolve) → `TESTS.md` (evidência de que funcionou). O `CLEANING_ROADMAP.md` anotado mostra o rastreamento item‑a‑item do roadmap de exploração até a implementação.

---

## 3. O banco de dados NBA (resumo)

`nba.sqlite` (~2,3 GB) — snapshot histórico da NBA. Tabelas principais: `game`, `player`, `team`, `common_player_info`, `team_details`, `team_info_common`, `play_by_play`, entre outras. Pontos essenciais (detalhados em [`NOTES.md`](NBA/artifacts/dxa%20-%20run%201/NOTES.md)):

- **Cobertura temporal:** 1946‑11‑01 a **2023‑06‑12** (encerra na temporada 2022‑23). Não há jogos após jun/2023.
- **Estatísticas só por time:** `pts/ast/reb/min…` existem apenas em nível de time (`_home`/`_away`) na tabela `game`. **Não há box score por jogador.**
- **`team_info_common` está vazia** (0 linhas) — única fonte de conferência/divisão/classificação.
- **30 franquias atuais**, mas a tabela `game` contém 122 entidades distintas de time (inclui times de exibição e franquias extintas).

### Lacunas que tornam perguntas irrespondíveis

Esta é a principal contribuição analítica do estudo de caso — perguntas do conjunto de avaliação que **não podem ser respondidas** com os dados, e por quê:

| Lacuna (item do roadmap) | Perguntas afetadas |
|--------------------------|--------------------|
| Sem box score por jogador (**CLEAN‑002**) | Pontos/assistências/rebotes por jogador, PPG, líderes, consistência, partidas com >35 min, rebotes por posição. |
| `team_info_common` vazia (**CLEAN‑001**) | Times por conferência (Leste/Oeste). |
| Sem data de contratação de técnico (**CLEAN‑010**) | "Técnicos e a data em que foram contratados." |
| Limite temporal 2023 | "Jogos de janeiro de 2025" → 0 linhas. |

---

## 4. Resultados principais

- **Exploração (DXA):** 9 receitas SQL validadas, 5 erros documentados com post‑mortem, **10 itens de qualidade de dados** mapeados com severidade e evidência.
- **Engenharia (DTA):** **12 modelos dbt**, **62 testes** (61 PASS, 1 WARN intencional, 0 ERROR). 7 dos 10 itens do roadmap foram resolvidos em código; 3 dependem de ingestão de fonte externa e ficaram explicitamente documentados (com modelo/teste placeholder onde aplicável).

---

## 5. Como navegar (sugestão para avaliadores)

1. **Entrada:** leia [`NBA/questions/perguntas_sql_nba.csv`](NBA/questions/perguntas_sql_nba.csv) para ver o que foi pedido.
2. **Execuções:** abra os HTML em [`NBA/runs/`](NBA/runs/) no navegador para acompanhar o raciocínio dos agentes passo a passo.
3. **Conhecimento da exploração:** leia, nesta ordem, `NOTES.md` → `RECIPES.md` → `ERRORS.md` → `CLEANING_ROADMAP.md` em [`artifacts/dxa - run 1/`](NBA/artifacts/dxa%20-%20run%201/).
4. **Pipeline de dados:** leia `PIPELINE.md` → `MODELS.md` → `TESTS.md` em [`artifacts/dta - run 1/`](NBA/artifacts/dta%20-%20run%201/), e inspecione o projeto dbt em `nba_pipeline/models/`.

### Reproduzir o pipeline dbt (opcional)

Requer `dbt-duckdb` e o `nba.sqlite` montado em `/data/databases/`. A partir de `artifacts/dta - run 1/nba_pipeline/`:

```bash
export DBT_PROFILES_DIR="$(pwd)"
dbt build           # executa todos os modelos + testes em ordem de dependência
dbt docs generate   # gera manifesto + catálogo
```

O warehouse resultante já está versionado em [`artifacts/dta - run 1/warehouse/nba_dbt.duckdb`](NBA/artifacts/dta%20-%20run%201/warehouse/) e pode ser consultado diretamente com a CLI do DuckDB.

---

## 6. Estrutura técnica em uma frase

> Dado um banco relacional e perguntas em português, um **agente de exploração** descobre o schema, valida SQL e produz um roadmap de qualidade de dados; um **agente de engenharia** consome esse roadmap e o materializa num pipeline **dbt + Dagster** testado sobre **DuckDB** — com todas as decisões, erros e evidências registrados em arquivos de conhecimento auditáveis.
