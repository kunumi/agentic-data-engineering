
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        wl_home as value_field,
        count(*) as n_records

    from "nba_dbt"."main"."stg_nba__games"
    group by wl_home

)

select *
from all_values
where value_field not in (
    'w','l'
)



  
  
      
    ) dbt_internal_test