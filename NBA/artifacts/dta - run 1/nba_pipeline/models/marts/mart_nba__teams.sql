-- CLEAN-009: canonical franchise dimension.
-- One row per current NBA franchise (team_id) carrying the canonical current name
-- from `team`, enriched with the count and list of historical names observed in
-- `game`. Report on canonical_team_name to avoid fragmenting franchises by era.

with teams as (
    select * from {{ ref('stg_nba__teams') }}
),

names as (
    select * from {{ ref('int_nba__franchise_names') }}
),

final as (
    select
        t.team_id,
        t.team_full_name                                  as canonical_team_name,
        t.team_abbreviation,
        t.team_nickname,
        t.team_city,
        t.team_state,
        t.year_founded,
        coalesce(n.historical_name_count, 0)              as historical_name_count,
        n.historical_names,
        n.last_seen_date
    from teams t
    left join names n on t.team_id = n.team_id
)

select * from final
