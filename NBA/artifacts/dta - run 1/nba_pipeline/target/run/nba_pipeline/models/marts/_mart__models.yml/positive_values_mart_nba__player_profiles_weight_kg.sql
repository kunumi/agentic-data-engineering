
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  

select weight_kg
from "nba_dbt"."main"."mart_nba__player_profiles"
where weight_kg is not null
  and weight_kg <= 0


  
  
      
    ) dbt_internal_test