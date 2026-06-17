# Errors

Log of errors (syntactic and business) with post-mortem.

## ERR-001: CAST fails on empty strings in common_player_info
- Type: syntactic
- Query: `AVG(CAST(weight AS DOUBLE))` and `CAST(SPLIT_PART(height,'-',1) AS INT)`
- Error: `Could not convert string '' to DOUBLE/INT32`. weight/height have '' (empty) values.
- Detail: `AVG(... ) FILTER (WHERE ...)` does NOT avoid the error — the CAST is evaluated on all rows before the FILTER.
- Fix: use **TRY_CAST** (returns NULL instead of an error). E.g.: `AVG(TRY_CAST(weight AS DOUBLE))`,
  `TRY_CAST(SPLIT_PART(height,'-',1) AS INT)`.
- Post-mortem: ALWAYS use TRY_CAST when converting text columns in common_player_info (weight, height, etc.) — there are empty strings.

## ERR-002: INTERNAL Error (CTE inlining) with `SELECT *` over the sqlite scanner + UNION ALL
- Type: syntactic
- Query: `WITH s AS (SELECT * FROM game WHERE ...), g AS (... UNION ALL ... FROM s)` → DuckDB INTERNAL Error "Attempted to access index 0 within vector of size 0" (CTEInlining).
- Fix: do NOT use `SELECT *` in an intermediate CTE over a sqlite table when combined in a UNION ALL. Select columns explicitly and repeat the WHERE filter directly on the `game` table in each branch of the UNION.
- Post-mortem: always list columns explicitly in CTEs over the sqlite scanner; avoid nested `SELECT *`.

## ERR-003: `data` is a reserved word in DuckDB
- Type: syntactic
- Query: `CAST(game_date AS DATE) data` → Parser Error at "data".
- Fix: use another alias (e.g. `dia`, `data_jogo`) or double quotes: `AS "data"`.
- Post-mortem: avoid aliases `data`/`date`/`time` without quotes.
