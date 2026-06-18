
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select team_id
from "nba_dbt"."main"."stg_nba__team_details"
where team_id is null



  
  
      
    ) dbt_internal_test