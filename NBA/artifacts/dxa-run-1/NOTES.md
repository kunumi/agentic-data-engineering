# Notes

Database metadata: schema, relationships, business rules, limitations.

## Connection / Setup (IMPORTANT)
- The fixed `connection_id` in the instructions (`5ee606d7`) **DOES NOT exist** in this environment.
- The processor starts with no registered connections (`GET /connections` => empty). You must
  register one via `POST /connections` with `{"type","path"}`. The `connection_id` is deterministic per file.
- Available databases (`GET /databases` and `/connections/files`):
  - `nba.sqlite` (/data/databases/nba.sqlite) => connection_id **87e6b067**
  - `crime_database.db` => c907483f
  - `dtsulv5.sqlite` (~10GB) => 7e459ffb
  - `mimic4_demo.db` => 67c9a274
  - `quikr_car.csv` => d4ead505 (type=csv)
- For questions about "times"/"teams" → **NBA** database (connection_id 87e6b067).

## NBA Database (87e6b067)
- Tables: game, game_summary, other_stats, officials, inactive_players, game_info,
  line_score, play_by_play, player, team, common_player_info, team_details,
  team_history, draft_combine_stats, draft_history, team_info_common.
- **team**: id (BIGINT, e.g. 1610612737), full_name, abbreviation, nickname, city, state, year_founded (FLOAT).
  - 30 teams (current NBA franchises). `full_name` = full name; `city` = city/region.
  - Gotcha: `city` is sometimes a region, not a literal city (e.g. "Golden State", "Indiana", "Utah", "Minnesota").
  - LA appears 2x (Clippers and Lakers) with city "Los Angeles".
- **player**: id, full_name, first_name, last_name, is_active. 4815 rows. Canonical list of players, but WITHOUT position/height.
- **common_player_info**: 3632 rows. Has position, height ("6-10" = feet-inches), weight, birthdate, team_*, draft_* etc.
  - person_id = FK to player.id (display_first_last = name).
  - Gotcha: 45 with empty/NULL position, 74 with empty/NULL height. Covers only ~75% of the 4815 in the player table.
  - For "name+position+height" use common_player_info (it cannot be obtained from player).
  - Business rule (confirmed by the user 2026-06-17): "Pivô"=Center and INCLUDES hybrids (Forward-Center, Center-Forward) → `position LIKE '%Center%'`. Translations: Armador=Guard, Ala=Forward, Pivô=Center.
- **game**: 55+ columns (stats _home/_away). game_date is TIMESTAMP. game_id VARCHAR. Columns team_id/abbreviation/name _home and _away, pts_home/away, wl_home/away, season_id, season_type, matchup_*.
  - **TEMPORAL LIMIT: data ranges from 1946-11-01 to 2023-06-12.** There are NO games after Jun/2023 (e.g. Jan/2025 returns 0). Historical snapshot ending at the 2022-23 season.
- **team_info_common**: EMPTY TABLE (0 rows). It is the ONLY one with columns team_conference/team_division/conf_rank → therefore there is NO usable conference/division data in the database. For "Eastern/Western conference" questions there is no source.
- **team_details**: team_id, abbreviation, nickname, yearfounded, city, arena, arenacapacity, owner, generalmanager, headcoach, dleagueaffiliation, social media. (no conference; headcoach = coach name, WITHOUT hire date)
- **CRITICAL LIMITATION — no per-player box score**: pts/ast/reb/min/stl/blk etc. exist only PER TEAM in the `game` table (_home/_away suffixes) and in team_info_common (empty). There is NO per-player per-game statistic. play_by_play is event-level (events), with no aggregated totals and no minutes. Therefore, it is NOT possible to answer: points/assists/rebounds/minutes per player, PPG per player, games with >X min, rebounds by position. All of this would require a box score table that does not exist.
- **game.season_id**: VARCHAR like "22021" (prefix: 1=preseason, 2=regular season, 4=playoffs; suffix=year). season_type also available.
- Wins/losses: wl_home / wl_away = 'W'/'L'. Group by team_id_home/away (franchise). ANY_VALUE(team_name) returns ONE historical name of the franchise (e.g. Lakers appears as "Minneapolis Lakers").
- **common_player_info.birthdate**: TIMESTAMP. Do NOT compare with '' (conversion error); filter only IS NOT NULL. Gotcha: there is 1 sentinel record '1900-01-01' (Bill Laimbeer) — invalid/placeholder date. The other valid ones start in 1905.
