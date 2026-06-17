# Errors

Registro de erros (sintáticos e de negócio) com post-mortem.

## ERR-001: CAST falha em strings vazias em common_player_info
- Tipo: syntactic
- Query: `AVG(CAST(weight AS DOUBLE))` e `CAST(SPLIT_PART(height,'-',1) AS INT)`
- Erro: `Could not convert string '' to DOUBLE/INT32`. weight/height têm valores '' (vazio).
- Detalhe: `AVG(... ) FILTER (WHERE ...)` NÃO evita o erro — o CAST é avaliado em todas as linhas antes do FILTER.
- Correção: usar **TRY_CAST** (retorna NULL em vez de erro). Ex.: `AVG(TRY_CAST(weight AS DOUBLE))`,
  `TRY_CAST(SPLIT_PART(height,'-',1) AS INT)`.
- Post-mortem: SEMPRE usar TRY_CAST ao converter colunas de texto em common_player_info (weight, height, etc.) — há strings vazias.

## ERR-002: INTERNAL Error (CTE inlining) com `SELECT *` sobre scanner sqlite + UNION ALL
- Tipo: syntactic
- Query: `WITH s AS (SELECT * FROM game WHERE ...), g AS (... UNION ALL ... FROM s)` → DuckDB INTERNAL Error "Attempted to access index 0 within vector of size 0" (CTEInlining).
- Correção: NÃO usar `SELECT *` em CTE intermediária sobre tabela sqlite quando combinada em UNION ALL. Selecionar colunas explicitamente e repetir o filtro WHERE direto na tabela `game` em cada ramo do UNION.
- Post-mortem: sempre listar colunas explicitamente em CTEs sobre o scanner sqlite; evitar `SELECT *` aninhado.

## ERR-003: `data` é palavra reservada no DuckDB
- Tipo: syntactic
- Query: `CAST(game_date AS DATE) data` → Parser Error at "data".
- Correção: usar outro alias (ex.: `dia`, `data_jogo`) ou aspas duplas: `AS "data"`.
- Post-mortem: evitar aliases `data`/`date`/`time` sem aspas.

## ERR-004: `game.game_id` NÃO é único (56 duplicatas)
- Tipo: business/data-quality (descoberto ao construir stg_nba__games)
- Detalhe: tabela `game` tem 65698 linhas mas 65642 game_id distintos → 56 duplicatas. Todas as 56 são jogos All-Star (128 linhas All Star+All-Star → 72 game_id distintos).
- Correção: dedup em staging com `qualify row_number() over (partition by game_id order by game_date desc) = 1`. Só assim `unique(game_id)` passa.
- Post-mortem: NUNCA assumir que um "id" de origem é PK — checar `COUNT(*)` vs `COUNT(DISTINCT id)` antes de declarar teste unique. Deduplicar no staging.

## ERR-005: dbt-duckdb attach de SQLite read-only
- Tipo: config
- Detalhe: SQLite de 2.3GB. Para evitar lock/escrita e ler via DuckDB sqlite scanner.
- Correção: profiles.yml → outputs.dev.extensions: [sqlite]; attach: [{path, type: sqlite, alias: nba, options: {read_only: true}}]. Source com database: nba, schema: main.
- Post-mortem: usar `options: {read_only: true}` (não a chave `read_only` de topo) para o attach SQLite no dbt-duckdb 1.10.
