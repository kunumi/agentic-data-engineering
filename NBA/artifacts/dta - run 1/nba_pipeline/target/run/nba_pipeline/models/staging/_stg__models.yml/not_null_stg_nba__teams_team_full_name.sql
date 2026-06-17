
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select team_full_name
from "nba_dbt"."main"."stg_nba__teams"
where team_full_name is null



  
  
      
    ) dbt_internal_test