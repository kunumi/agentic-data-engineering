# SQL Recipes

SQL recipes validated on this database. The agent registers them automatically.

## RCP-001: List the name and city of all teams
- Context: `team` table (NBA, connection_id 87e6b067). Columns full_name, city.
- Query:
  ```sql
  SELECT full_name, city FROM [TEAM_TABLE] ORDER BY full_name
  ```
- Tested on: team (2026-06-17) → 30 rows.

## RCP-002: List players' name, position and height
- Context: `common_player_info` (NBA, 87e6b067). name=display_first_last, position=position, height=height ("feet-inches", e.g. 6-10).
- Query:
  ```sql
  SELECT display_first_last AS nome, position AS posicao, height AS altura
  FROM [CPI_TABLE]
  WHERE position IS NOT NULL AND position <> ''
  ORDER BY display_first_last
  ```
- Tested on: common_player_info (2026-06-17) → 3587 rows (with position filled in).
- Gotcha: position/height do NOT exist in the `player` table (4815 rows). Only in common_player_info (3632 rows).

## RCP-003: Convert height "feet-inches" to meters and filter
- Context: `common_player_info.height` is text like "7-2". Conversion: (feet*12 + inches)*0.0254 m.
- Query:
  ```sql
  WITH h AS (
    SELECT display_first_last AS nome, position AS posicao, height AS altura_ft,
           (CAST(SPLIT_PART(height,'-',1) AS INT)*12 + CAST(SPLIT_PART(height,'-',2) AS INT)) * 0.0254 AS altura_m
    FROM [CPI_TABLE]
    WHERE height IS NOT NULL AND height LIKE '%-%'
  )
  SELECT nome, posicao, altura_ft, ROUND(altura_m,3) AS altura_m
  FROM h WHERE altura_m > [LIMITE_M] ORDER BY altura_m DESC, nome
  ```
- Tested on: common_player_info (2026-06-17) → 986 players above 2.05 m.
- Combines with: RCP-002.
- Note: 2.05 m ≈ 80.7 in → includes 6-9 (2.057 m) and above.

## RCP-004: Average height and average weight of players
- Context: common_player_info. weight in pounds (text), height "feet-in". Use TRY_CAST (there are empties). 1 lb=0.453592 kg.
- Query:
  ```sql
  SELECT
    ROUND(AVG((TRY_CAST(SPLIT_PART(height,'-',1) AS INT)*12 + TRY_CAST(SPLIT_PART(height,'-',2) AS INT))*0.0254),3) AS altura_media_m,
    ROUND(AVG(TRY_CAST(weight AS DOUBLE)*0.453592),1) AS peso_medio_kg,
    ROUND(AVG(TRY_CAST(weight AS DOUBLE)),1) AS peso_medio_lbs
  FROM [CPI_TABLE]
  ```
- Tested on: common_player_info (2026-06-17) → 1.983 m / 95.8 kg (211.2 lbs); n=3558 height, 3555 weight.
- Combines with: RCP-003. See ERR-001 (use TRY_CAST).

## RCP-005: Players by position (Center/Forward/Guard)
- Context: common_player_info.position is in ENGLISH. Pivô=Center, Ala=Forward, Armador=Guard.
  - Values: Guard(1416), Forward(1306), Center(497), Guard-Forward(134), Forward-Center(112), Center-Forward(68), Forward-Guard(54), ''(45).
  - "Center" includes hybrids → use `position LIKE '%Center%'` (677). Pure only = `position = 'Center'` (497).
- Query:
  ```sql
  SELECT display_first_last AS nome, position AS posicao, height AS altura
  FROM [CPI_TABLE] WHERE position LIKE '%Center%' ORDER BY display_first_last
  ```
- Tested on: common_player_info (2026-06-17) → 677 (Center incl. hybrids).

## RCP-006: Wins/losses per franchise (home + away)
- Context: `game` table, wl_home/wl_away = 'W'/'L'. Group by team_id (franchise).
- Query:
  ```sql
  WITH g AS (
    SELECT team_id_home AS tid, team_name_home AS nome, wl_home AS wl FROM [GAME]
    UNION ALL
    SELECT team_id_away, team_name_away, wl_away FROM [GAME]
  )
  SELECT ANY_VALUE(nome) AS time,
         COUNT(*) FILTER (WHERE wl='W') AS vitorias,
         COUNT(*) FILTER (WHERE wl='L') AS derrotas
  FROM g GROUP BY tid ORDER BY vitorias DESC
  ```
- For "away only": `COUNT(*) FILTER (WHERE wl_away='W') ... GROUP BY team_id_away`.
- Tested on: game (2026-06-17).

## RCP-007: Biggest blowout (point differential) between teams
- Context: `game` table, pts_home/pts_away.
- Query:
  ```sql
  SELECT CAST(game_date AS DATE) AS data, season_id, team_name_home, pts_home,
         team_name_away, pts_away, ABS(pts_home-pts_away) AS diferenca
  FROM [GAME] WHERE pts_home IS NOT NULL AND pts_away IS NOT NULL
  ORDER BY diferenca DESC LIMIT [N]
  ```
- Tested on: game (2026-06-17) → biggest all-time: Memphis 152 x 79 OKC (2021-12-02), diff 73.
- Note: filter by season_id to limit to a specific season.

## RCP-008: Longest winning streak per team (gaps & islands)
- Context: `game` table. Combine home+away per franchise, order by date, islands of wl='W'.
- Query:
  ```sql
  WITH res AS (
    SELECT team_id_home tid, team_name_home nome, game_date, wl_home wl FROM [GAME] WHERE season_id='[SID]'
    UNION ALL SELECT team_id_away, team_name_away, game_date, wl_away FROM [GAME] WHERE season_id='[SID]'),
  seq AS (SELECT tid, nome, wl,
    ROW_NUMBER() OVER (PARTITION BY tid ORDER BY game_date)
    - ROW_NUMBER() OVER (PARTITION BY tid, wl ORDER BY game_date) grp FROM res)
  SELECT ANY_VALUE(nome) time, MAX(cnt) maior_seq FROM
    (SELECT tid, grp, COUNT(*) cnt FROM seq WHERE wl='W' GROUP BY tid, grp) GROUP BY tid ORDER BY maior_seq DESC
  ```
- Tested on: game season 22022 (2022-23) → Milwaukee 16. Swap wl='W'→sign of delta for improvement streaks (Q9).
- Combines with: RCP-006.

## RCP-009: Cumulative / point differential / win rate per team (window)
- Context: `game` table. "Explode" home+away per franchise and apply a window function.
- Patterns tested on game (2026-06-17):
  - Cumulative points: `SUM(pts) OVER (PARTITION BY tid ORDER BY game_date)`.
  - Average point differential (Q11): `AVG(pf-pa)` with res(tid, pf=own pts, pa=opponent pts). Top 2022-23: BOS +6.52.
  - Win rate over last N: `ROW_NUMBER() OVER (PARTITION BY tid ORDER BY game_date DESC)`, filter rn<=N. **Filter tid IN (SELECT id FROM team) and season_type='Regular Season'** to exclude exhibition teams (Unicaja, Waterloo etc.) with few games.
  - Head-to-head matchups (Q6): `LEAST/GREATEST(team_id_home,team_id_away)` + JOIN team. Top: Celtics x Knicks 515.
- Combines with: RCP-006, RCP-008.
