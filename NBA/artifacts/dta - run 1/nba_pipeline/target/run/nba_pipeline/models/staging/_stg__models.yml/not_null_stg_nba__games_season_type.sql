
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select season_type
from "nba_dbt"."main"."stg_nba__games"
where season_type is null



  
  
      
    ) dbt_internal_test