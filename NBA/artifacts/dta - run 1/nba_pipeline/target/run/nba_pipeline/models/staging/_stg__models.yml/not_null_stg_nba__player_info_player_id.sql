
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select player_id
from "nba_dbt"."main"."stg_nba__player_info"
where player_id is null



  
  
      
    ) dbt_internal_test