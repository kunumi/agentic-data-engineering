
    
    

select
    player_id as unique_field,
    count(*) as n_records

from "nba_dbt"."main"."stg_nba__player_info"
where player_id is not null
group by player_id
having count(*) > 1


