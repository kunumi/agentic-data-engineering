-- CLEAN-003 + CLEAN-004: consumption-ready games fact.
-- Standardized season_type (upstream) and franchise classification flags so NBA
-- analytics can filter out exhibition/defunct teams via is_official_nba_matchup.

with  __dbt__cte__int_nba__games_classified as (
-- CLEAN-004: classify the teams in each game.
-- The `game` table mixes the 30 current NBA franchises with exhibition teams
-- (e.g. "Unicaja Malaga"), All-Star squads and defunct franchises. We flag
-- whether each side is a current franchise (team_id present in stg_nba__teams)
-- and derive is_official_nba_matchup = both sides are franchises and the game is
-- a real NBA season type. Downstream NBA analytics should filter on these flags.

with games as (
    select * from "nba_dbt"."main"."stg_nba__games"
),

franchises as (
    select team_id from "nba_dbt"."main"."stg_nba__teams"
),

classified as (
    select
        g.game_id,
        g.season_id,
        g.game_date,
        g.season_type,
        g.team_id_home,
        g.team_name_home,
        g.wl_home,
        g.pts_home,
        g.team_id_away,
        g.team_name_away,
        g.wl_away,
        g.pts_away,
        g.game_minutes,
        (fh.team_id is not null)                       as is_home_nba_franchise,
        (fa.team_id is not null)                       as is_away_nba_franchise,
        (
            fh.team_id is not null
            and fa.team_id is not null
            and g.season_type in ('Regular Season', 'Playoffs', 'Pre Season')
        )                                              as is_official_nba_matchup
    from games g
    left join franchises fh on g.team_id_home = fh.team_id
    left join franchises fa on g.team_id_away = fa.team_id
)

select * from classified
), games as (
    select * from __dbt__cte__int_nba__games_classified
),

final as (
    select
        game_id,
        season_id,
        game_date,
        season_type,
        team_id_home,
        team_name_home,
        wl_home,
        pts_home,
        team_id_away,
        team_name_away,
        wl_away,
        pts_away,
        game_minutes,
        is_home_nba_franchise,
        is_away_nba_franchise,
        is_official_nba_matchup
    from games
)

select * from final