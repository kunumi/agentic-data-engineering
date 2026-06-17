-- CLEAN-003 + CLEAN-004: consumption-ready games fact.
-- Standardized season_type (upstream) and franchise classification flags so NBA
-- analytics can filter out exhibition/defunct teams via is_official_nba_matchup.

with games as (
    select * from {{ ref('int_nba__games_classified') }}
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
