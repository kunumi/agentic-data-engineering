
    
    



with __dbt__cte__int_nba__player_coverage as (
-- CLEAN-008: coverage of the canonical player list by detailed player info.
-- `player` is the spine (4815). `common_player_info` (position/height/weight)
-- covers ~3632. We left join to flag which players have a detailed profile so the
-- gap is explicit and measurable instead of silently dropping rows.

with players as (
    select * from "nba_dbt"."main"."stg_nba__players"
),

info as (
    select * from "nba_dbt"."main"."stg_nba__player_info"
),

joined as (
    select
        p.player_id,
        p.player_full_name,
        p.is_active,
        (i.player_id is not null)   as has_detailed_info,
        i.position_group,
        i.birthdate,
        i.height_cm,
        i.weight_kg,
        i.from_year,
        i.to_year
    from players p
    left join info i on p.player_id = i.player_id
)

select * from joined
) select has_detailed_info
from __dbt__cte__int_nba__player_coverage
where has_detailed_info is null


