
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    player_id as unique_field,
    count(*) as n_records

from "nba_dbt"."main"."mart_nba__player_profiles"
where player_id is not null
group by player_id
having count(*) > 1



  
  
      
    ) dbt_internal_test