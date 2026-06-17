# Errors

Error log (syntactic and business) with post-mortem.

## ERR-001: CAST fails on empty strings in common_player_info
- Type: syntactic
- Query: `AVG(CAST(weight AS DOUBLE))` and `CAST(SPLIT_PART(height,'-',1) AS INT)`
- Error: `Could not convert string '' to DOUBLE/INT32`. weight/height contain '' (empty) values.
- Detail: `AVG(... ) FILTER (WHERE ...)` does NOT avoid the error — the CAST is evaluated on every row before the FILTER.
- Fix: use **TRY_CAST** (returns NULL instead of erroring). E.g.: `AVG(TRY_CAST(weight AS DOUBLE))`,
  `TRY_CAST(SPLIT_PART(height,'-',1) AS INT)`.
- Post-mortem: ALWAYS use TRY_CAST when converting text columns in common_player_info (weight, height, etc.) — there are empty strings.

## ERR-002: INTERNAL Error (CTE inlining) with `SELECT *` over the sqlite scanner + UNION ALL
- Type: syntactic
- Query: `WITH s AS (SELECT * FROM game WHERE ...), g AS (... UNION ALL ... FROM s)` → DuckDB INTERNAL Error "Attempted to access index 0 within vector of size 0" (CTEInlining).
- Fix: do NOT use `SELECT *` in an intermediate CTE over a sqlite table when combined in a UNION ALL. Select columns explicitly and repeat the WHERE filter directly against the `game` table in each branch of the UNION.
- Post-mortem: always list columns explicitly in CTEs over the sqlite scanner; avoid nested `SELECT *`.

## ERR-003: `data` is a reserved word in DuckDB
- Type: syntactic
- Query: `CAST(game_date AS DATE) data` → Parser Error at "data".
- Fix: use another alias (e.g., `dia`, `data_jogo`) or double quotes: `AS "data"`.
- Post-mortem: avoid the aliases `data`/`date`/`time` without quotes.

## ERR-004: `game.game_id` is NOT unique (56 duplicates)
- Type: business/data-quality (discovered while building stg_nba__games)
- Detail: the `game` table has 65698 rows but 65642 distinct game_id → 56 duplicates. All 56 are All-Star games (128 All Star + All-Star rows → 72 distinct game_id).
- Fix: dedup in staging with `qualify row_number() over (partition by game_id order by game_date desc) = 1`. Only then does `unique(game_id)` pass.
- Post-mortem: NEVER assume a source "id" is a PK — check `COUNT(*)` vs `COUNT(DISTINCT id)` before declaring a unique test. Deduplicate in staging.

## ERR-005: dbt-duckdb attach of read-only SQLite
- Type: config
- Detail: 2.3GB SQLite. To avoid locking/writing and read via the DuckDB sqlite scanner.
- Fix: profiles.yml → outputs.dev.extensions: [sqlite]; attach: [{path, type: sqlite, alias: nba, options: {read_only: true}}]. Source with database: nba, schema: main.
- Post-mortem: use `options: {read_only: true}` (not the top-level `read_only` key) for the SQLite attach in dbt-duckdb 1.10.
