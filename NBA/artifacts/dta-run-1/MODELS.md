# Models

Inventory of dbt models implemented by this agent (project: `nba_pipeline`, DuckDB + sqlite scanner over `/data/databases/nba.sqlite`).

## MOD-001: stg_nba__teams
- Layer: staging | Source: nba.team | Materialization: view
- Tests: not_null+unique(team_id), not_null(team_full_name)
- Roadmap: CLEAN-004, CLEAN-009 | Status: ✅ green | Created: 2026-06-17

## MOD-002: stg_nba__players
- Layer: staging | Source: nba.player | Materialization: view
- Tests: not_null+unique(player_id)
- Roadmap: CLEAN-008 | Status: ✅ green | Created: 2026-06-17

## MOD-003: stg_nba__player_info
- Layer: staging | Source: nba.common_player_info | Materialization: view
- Transforms: height_cm/weight_kg via TRY_CAST macros (CLEAN-005); birthdate 1900-01-01 → NULL (CLEAN-006); position ''→NULL + position_group 'Unknown' bucket (CLEAN-007)
- Tests: not_null+unique(player_id), relationships→stg_nba__players, accepted_values(position, position_group), positive_values(height_cm, weight_kg)
- Roadmap: CLEAN-005, CLEAN-006, CLEAN-007 | Status: ✅ green | Created: 2026-06-17

## MOD-004: stg_nba__games
- Layer: staging | Source: nba.game | Materialization: view
- Transforms: season_type 'All Star'→'All-Star' (CLEAN-003); dedup game_id via qualify row_number (latest game_date); explicit column list (ERR-002)
- Tests: not_null+unique(game_id), accepted_values(season_type, wl_home)
- Roadmap: CLEAN-003 | Status: ✅ green | Created: 2026-06-17

## MOD-005: stg_nba__team_details
- Layer: staging | Source: nba.team_details | Materialization: view
- Notes: head_coach_hire_date NULL placeholder — no source (CLEAN-010)
- Tests: not_null+unique(team_id)
- Roadmap: CLEAN-010 | Status: ✅ green (gap documented) | Created: 2026-06-17

## MOD-006: stg_nba__team_info_common
- Layer: staging | Source: nba.team_info_common (EMPTY, 0 rows) | Materialization: view
- Notes: schema preserved for when source is repopulated (CLEAN-001)
- Tests: singular assert_team_info_common_not_empty (severity=warn)
- Roadmap: CLEAN-001 | Status: ⚠️ warn (no source) | Created: 2026-06-17

## MOD-007: int_nba__games_classified
- Layer: intermediate | Materialization: ephemeral
- Logic: flag is_home/away_nba_franchise + is_official_nba_matchup via join to stg_nba__teams (CLEAN-004)
- Tests: not_null+unique(game_id), not_null(is_official_nba_matchup)
- Roadmap: CLEAN-004 | Status: ✅ green | Created: 2026-06-17

## MOD-008: int_nba__franchise_names
- Layer: intermediate | Materialization: ephemeral
- Logic: distinct historical names per team_id from game, most_recent_name (CLEAN-009)
- Tests: not_null+unique(team_id)
- Roadmap: CLEAN-009 | Status: ✅ green | Created: 2026-06-17

## MOD-009: int_nba__player_coverage
- Layer: intermediate | Materialization: ephemeral
- Logic: players left join player_info, has_detailed_info flag (CLEAN-008)
- Tests: not_null+unique(player_id), not_null(has_detailed_info)
- Roadmap: CLEAN-008 | Status: ✅ green | Created: 2026-06-17

## MOD-010: mart_nba__teams
- Layer: mart | Materialization: table
- Logic: canonical franchise dimension (current name + historical names) (CLEAN-009)
- Tests: not_null+unique(team_id), not_null(canonical_team_name, historical_name_count), assert_marts_not_empty
- Roadmap: CLEAN-009 | Status: ✅ green | Created: 2026-06-17

## MOD-011: mart_nba__games
- Layer: mart | Materialization: table
- Logic: consumption games fact, standardized season_type + franchise flags (CLEAN-003/004)
- Tests: not_null+unique(game_id), accepted_values(season_type), not_null(is_official_nba_matchup)
- Roadmap: CLEAN-003, CLEAN-004 | Status: ✅ green | Created: 2026-06-17

## MOD-012: mart_nba__player_profiles
- Layer: mart | Materialization: table
- Logic: player dimension; cleaned measures, age_years, coverage flag (CLEAN-005/006/007/008)
- Tests: not_null+unique(player_id), not_null+accepted_values(position_group), not_null(has_detailed_info), positive_values(height_cm, weight_kg)
- Roadmap: CLEAN-005/006/007/008 | Status: ✅ green | Created: 2026-06-17

---
## Not implementable in dbt (require external source data — manual intervention)
- CLEAN-001: team_info_common is empty. Staging + warn test in place; needs source ingestion.
- CLEAN-002: no per-player box score table exists in source. No dbt model possible until a player_game_stats table is ingested.
- CLEAN-010: team_details has no coach hire date column. Placeholder column added; needs source.
