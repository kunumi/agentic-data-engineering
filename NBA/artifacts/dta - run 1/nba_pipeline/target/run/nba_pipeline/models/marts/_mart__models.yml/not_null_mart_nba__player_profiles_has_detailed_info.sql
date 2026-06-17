
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select has_detailed_info
from "nba_dbt"."main"."mart_nba__player_profiles"
where has_detailed_info is null



  
  
      
    ) dbt_internal_test