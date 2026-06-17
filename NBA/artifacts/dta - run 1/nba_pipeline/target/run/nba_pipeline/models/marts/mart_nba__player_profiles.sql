
  
    
    

    create  table
      "nba_dbt"."main"."mart_nba__player_profiles__dbt_tmp"
  
    as (
      -- CLEAN-005/006/007/008: consumption-ready player dimension.
-- Spine is the full canonical player list (4815); has_detailed_info flags the
-- ~1183 players without a detailed profile (CLEAN-008). Physical measures are
-- numeric metric units (CLEAN-005), birthdate is sentinel-free (CLEAN-006), and
-- position_group is never NULL ('Unknown' bucket, CLEAN-007). Age is computed at
-- the pipeline run date so rankings are not distorted by placeholder birthdates.

with  __dbt__cte__int_nba__player_coverage as (
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
), coverage as (
    select * from __dbt__cte__int_nba__player_coverage
),

final as (
    select
        player_id,
        player_full_name,
        is_active,
        has_detailed_info,
        coalesce(position_group, 'Unknown')               as position_group,
        birthdate,
        case
            when birthdate is not null
            then date_diff('year', birthdate, current_date)
        end                                               as age_years,
        height_cm,
        weight_kg,
        from_year,
        to_year
    from coverage
)

select * from final
    );
  
  