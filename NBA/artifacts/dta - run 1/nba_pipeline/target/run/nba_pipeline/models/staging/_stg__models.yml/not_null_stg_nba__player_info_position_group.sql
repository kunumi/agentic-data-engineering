
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select position_group
from "nba_dbt"."main"."stg_nba__player_info"
where position_group is null



  
  
      
    ) dbt_internal_test