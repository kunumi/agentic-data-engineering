
    
    

select
    team_id as unique_field,
    count(*) as n_records

from "nba_dbt"."main"."stg_nba__team_details"
where team_id is not null
group by team_id
having count(*) > 1


