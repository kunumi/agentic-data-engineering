
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select historical_name_count
from "nba_dbt"."main"."mart_nba__teams"
where historical_name_count is null



  
  
      
    ) dbt_internal_test