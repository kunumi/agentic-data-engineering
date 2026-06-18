
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        position_group as value_field,
        count(*) as n_records

    from "nba_dbt"."main"."stg_nba__player_info"
    group by position_group

)

select *
from all_values
where value_field not in (
    'Guard','Forward','Center','Guard-Forward','Forward-Guard','Forward-Center','Center-Forward','Unknown'
)



  
  
      
    ) dbt_internal_test