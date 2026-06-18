
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  

select height_cm
from "nba_dbt"."main"."stg_nba__player_info"
where height_cm is not null
  and height_cm <= 0


  
  
      
    ) dbt_internal_test