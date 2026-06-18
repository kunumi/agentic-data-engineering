
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select is_official_nba_matchup
from "nba_dbt"."main"."mart_nba__games"
where is_official_nba_matchup is null



  
  
      
    ) dbt_internal_test