# Cleaning Roadmap — NBA Database (connection_id 87e6b067)

Prescriptive data-quality roadmap for the Data Engineering Agent.
Generated on 2026-06-17 from interactive exploration. Ordered by severity.

---

## CLEAN-001: Table `team_info_common` is completely empty ⚠️ (staging + warn test created; needs external source — manual intervention)
- **Table:** team_info_common
- **Severity:** critical
- **Problem:** This is the ONLY table with conference information (`team_conference`), division (`team_division`), ranking (`conf_rank`/`div_rank`) and per-season standings (w, l, pct). It has 0 rows — making any analysis by conference/division impossible.
- **Evidence:**
  ```sql
  SELECT COUNT(*) AS n_rows FROM team_info_common;
  ```
- **Result:** 0 rows.
- **Recommended action:** Repopulate the table from the original source (NBA stats / per-season standings), or remove it from the schema if no source exists. Without this, questions about conference/division/standings cannot be answered.

## CLEAN-002: Missing per-player box score (per-player/per-game statistics) ⚠️ (no source table; impossible in dbt until player_game_stats is ingested — manual intervention)
- **Table:** game (and absence of a dedicated table)
- **Severity:** critical
- **Problem:** All game statistics (pts, ast, reb, stl, blk, min, fg etc.) exist only **per team** (`_home`/`_away` suffixes) in the `game` table. There is no table linking player → per-game statistic. `play_by_play` records events, with no aggregated totals and no minutes. This makes the following infeasible: points/assists/rebounds per player, PPG, statistical leaders, consistency, games with >X minutes, rebounds by position.
- **Evidence:**
  ```sql
  SELECT DISTINCT table_name FROM information_schema.columns
  WHERE LOWER(column_name) IN ('pts','ast','reb') OR LOWER(column_name) LIKE 'ast%';
  -- returns only: game (team level) and team_info_common (empty)
  ```
- **Result:** No table with per-player stats. Only `game` (team) and `team_info_common` (empty).
- **Recommended action:** Ingest a per-player/per-game box score table (player_game_stats: game_id, player_id, team_id, min, pts, ast, reb, stl, blk, fg, ...). This is the database's biggest analytical blocker.

## CLEAN-003: Inconsistent values in `game.season_type` ("All Star" vs "All-Star") ✅ (stg_nba__games + mart_nba__games; accepted_values)
- **Table:** game
- **Severity:** warning
- **Problem:** The same game type appears with two different spellings, fragmenting aggregations by type.
- **Evidence:**
  ```sql
  SELECT season_type, COUNT(*) n FROM game GROUP BY 1 ORDER BY n DESC;
  ```
- **Result:** Regular Season 60192, Playoffs 3842, Pre Season 1536, **All Star 65**, **All-Star 63** (same category, 2 spellings).
- **Recommended action:** Standardize `season_type` to a single canonical value (e.g., 'All-Star'). `UPDATE game SET season_type='All-Star' WHERE season_type='All Star'`.

## CLEAN-004: Exhibition/defunct teams mixed into the `game` table ✅ (int_nba__games_classified + is_official_nba_matchup flags)
- **Table:** game
- **Severity:** warning
- **Problem:** The table contains 122 distinct team entities, but only 30 are current franchises. The other 65 include international exhibition teams (e.g., "Unicaja Malaga"), All-Star teams and defunct franchises. Without filtering, they distort metrics (e.g., the "last N games" win rate was 1.0 for teams with very few games).
- **Evidence:**
  ```sql
  WITH ids AS (SELECT team_id_home tid FROM game UNION SELECT team_id_away FROM game)
  SELECT COUNT(*) times_distintos,
         COUNT(*) FILTER (WHERE tid NOT IN (SELECT CAST(id AS VARCHAR) FROM team)) fora_das_30
  FROM ids;
  ```
- **Result:** 122 distinct teams; 65 outside the current 30 franchises.
- **Recommended action:** Add a flag/column classifying the team (current NBA / defunct / exhibition / all-star), or normalize via a team dimension. For NBA analyses, standardize the filter on `team_id IN (SELECT id FROM team)` and/or the appropriate `season_type`.

## CLEAN-005: `height` and `weight` stored as text (not numeric) with empty strings ✅ (stg_nba__player_info height_cm/weight_kg via TRY_CAST)
- **Table:** common_player_info
- **Severity:** warning
- **Problem:** `height` is text in the "6-10" (feet-inches) format and `weight` is text in pounds; both contain empty strings `''`. This breaks a direct CAST (requires TRY_CAST) and prevents calculations without parsing.
- **Evidence:**
  ```sql
  SELECT COUNT(*) total,
         COUNT(*) FILTER (WHERE height IS NULL OR height='') alt_vazia,
         COUNT(*) FILTER (WHERE weight IS NULL OR weight='') peso_vazio
  FROM common_player_info;
  ```
- **Result:** total 3632; empty height 74; empty weight 77.
- **Recommended action:** Create derived numeric columns: `height_cm` (parse "ft-in" → cm) and `weight_kg` (lbs → kg), with NULL for empty values. Keep the original or deprecate the text.

## CLEAN-006: Invalid sentinel birthdate (1900-01-01) ✅ (1900-01-01 → NULL; domain test)
- **Table:** common_player_info
- **Severity:** warning
- **Problem:** A record with `birthdate` = 1900-01-01, clearly a placeholder (e.g., Bill Laimbeer, who was born in 1957). It distorts age rankings ("oldest").
- **Evidence:**
  ```sql
  SELECT display_first_last, CAST(birthdate AS DATE) FROM common_player_info
  WHERE CAST(birthdate AS DATE) = DATE '1900-01-01';
  ```
- **Result:** 1 row (Bill Laimbeer, 1900-01-01).
- **Recommended action:** Replace with NULL or correct with the real date. Add a domain check (birthdate > 1900-01-01) at ingestion.

## CLEAN-007: Missing values in `position` (and height/weight) in common_player_info ✅ ('' → NULL; position_group 'Unknown'; accepted_values)
- **Table:** common_player_info
- **Severity:** warning
- **Problem:** Key fields for position-based analysis come in empty/NULL for some of the records.
- **Evidence:**
  ```sql
  SELECT COUNT(*) FILTER (WHERE position IS NULL OR position='') pos_vazia FROM common_player_info;
  ```
- **Result:** 45 players without a position (of 3632).
- **Recommended action:** Impute from an external source or mark explicitly as 'Unknown'. Standardize empty → NULL.

## CLEAN-008: Coverage gap between `player` and `common_player_info` ✅ (int_nba__player_coverage + has_detailed_info flag; relationships FK)
- **Table:** player / common_player_info
- **Severity:** info
- **Problem:** `player` has 4815 players (canonical list), but `common_player_info` (the only one with position/height/weight) covers only 3632 — ~1183 players without a detailed record.
- **Evidence:**
  ```sql
  SELECT (SELECT COUNT(*) FROM player) n_player, (SELECT COUNT(*) FROM common_player_info) n_cpi;
  ```
- **Result:** player 4815; common_player_info 3632 (~75% coverage).
- **Recommended action:** Complete `common_player_info` for the missing players or document the gap. Ensure FK person_id → player.id.

## CLEAN-009: Inconsistent franchise name across history ✅ (mart_nba__teams: canonical name + historical names)
- **Table:** game
- **Severity:** info
- **Problem:** The same `team_id` appears with different names in different eras (relocations: e.g. "Minneapolis Lakers" = L.A. Lakers). Aggregating by `team_name` fragments the franchise; aggregating by `team_id` mixes historical names.
- **Evidence:**
  ```sql
  SELECT team_id_home, COUNT(DISTINCT team_name_home) nomes FROM game
  GROUP BY 1 HAVING COUNT(DISTINCT team_name_home) > 1 ORDER BY nomes DESC LIMIT 5;
  ```
- **Result:** Several team_id values with multiple historical names.
- **Recommended action:** Create a team dimension with `team_id` + current canonical name (join with `team`) and a historical names table. Standardize reports on the current name.

## CLEAN-010: `team_details` has no coach hire date ⚠️ (head_coach_hire_date placeholder created; needs source — manual intervention)
- **Table:** team_details
- **Severity:** info
- **Problem:** There is `headcoach` (name), but no hire/start date column, making temporal analyses of the coaching staff impossible.
- **Evidence:**
  ```sql
  SELECT table_name, column_name FROM information_schema.columns
  WHERE LOWER(column_name) LIKE '%coach%' OR LOWER(column_name) LIKE '%hire%';
  -- only team_details.headcoach
  ```
- **Result:** Only `team_details.headcoach`; no date column.
- **Recommended action:** Add `headcoach_hire_date` (and ideally a coaching history) if a source is available.

===CLEANING_ROADMAP===
