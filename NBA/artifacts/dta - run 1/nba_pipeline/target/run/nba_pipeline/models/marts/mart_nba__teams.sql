
  
    
    

    create  table
      "nba_dbt"."main"."mart_nba__teams__dbt_tmp"
  
    as (
      -- CLEAN-009: canonical franchise dimension.
-- One row per current NBA franchise (team_id) carrying the canonical current name
-- from `team`, enriched with the count and list of historical names observed in
-- `game`. Report on canonical_team_name to avoid fragmenting franchises by era.

with  __dbt__cte__int_nba__franchise_names as (
-- CLEAN-009: build the set of historical names each franchise has used in `game`.
-- Same team_id appears under different names across eras (relocations, e.g.
-- "Minneapolis Lakers" -> "Los Angeles Lakers"). We collect distinct historical
-- names per team_id (from both home and away appearances) so the franchise
-- dimension can carry a canonical current name plus its history.

with game_team_names as (
    select team_id_home as team_id, team_name_home as team_name, game_date
    from "nba_dbt"."main"."stg_nba__games"
    union all
    select team_id_away as team_id, team_name_away as team_name, game_date
    from "nba_dbt"."main"."stg_nba__games"
),

cleaned as (
    select
        team_id,
        nullif(trim(team_name), '') as team_name,
        game_date
    from game_team_names
    where nullif(trim(team_name), '') is not null
),

aggregated as (
    select
        team_id,
        count(distinct team_name)                         as historical_name_count,
        list(distinct team_name)                          as historical_names,
        max(game_date)                                    as last_seen_date,
        arg_max(team_name, game_date)                     as most_recent_name
    from cleaned
    group by team_id
)

select * from aggregated
), teams as (
    select * from "nba_dbt"."main"."stg_nba__teams"
),

names as (
    select * from __dbt__cte__int_nba__franchise_names
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
    );
  
  