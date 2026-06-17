
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select canonical_team_name
from "nba_dbt"."main"."mart_nba__teams"
where canonical_team_name is null



  
  
      
    ) dbt_internal_test