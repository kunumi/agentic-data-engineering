
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with __dbt__cte__int_nba__franchise_names as (
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
) select
    team_id as unique_field,
    count(*) as n_records

from __dbt__cte__int_nba__franchise_names
where team_id is not null
group by team_id
having count(*) > 1



  
  
      
    ) dbt_internal_test