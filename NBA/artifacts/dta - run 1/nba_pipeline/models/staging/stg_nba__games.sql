-- Cleaned games from `game` (team-level box score, one row per game).
-- Addresses CLEAN-003: standardize season_type ("All Star" -> "All-Star").
-- Also deduplicates game_id: the source has 56 duplicate game_ids (65698 rows /
-- 65642 distinct). We keep one row per game_id (latest game_date) so game_id is a
-- valid primary key downstream (post-mortem from ERR: always check for dupes).
-- Columns are listed explicitly to avoid the CTE-inlining INTERNAL error on the
-- sqlite scanner (ERR-002).

with source as (
    select
        game_id,
        season_id,
        cast(game_date as date)        as game_date,
        season_type,
        cast(team_id_home as varchar)  as team_id_home,
        team_name_home,
        wl_home,
        pts_home,
        cast(team_id_away as varchar)  as team_id_away,
        team_name_away,
        wl_away,
        pts_away,
        min                            as game_minutes
    from {{ source('nba', 'game') }}
),

standardized as (
    select
        game_id,
        season_id,
        game_date,
        -- CLEAN-003: collapse the two spellings into a single canonical value.
        case
            when season_type = 'All Star' then 'All-Star'
            else season_type
        end                            as season_type,
        team_id_home,
        team_name_home,
        lower(nullif(trim(wl_home), '')) as wl_home,
        pts_home,
        team_id_away,
        team_name_away,
        lower(nullif(trim(wl_away), '')) as wl_away,
        pts_away,
        game_minutes
    from source
),

deduped as (
    select *
    from standardized
    qualify row_number() over (
        partition by game_id
        order by game_date desc
    ) = 1
)

select * from deduped
