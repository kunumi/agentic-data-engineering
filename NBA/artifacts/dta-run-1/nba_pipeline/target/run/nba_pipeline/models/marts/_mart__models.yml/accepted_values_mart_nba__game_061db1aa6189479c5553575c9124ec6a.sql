
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        season_type as value_field,
        count(*) as n_records

    from "nba_dbt"."main"."mart_nba__games"
    group by season_type

)

select *
from all_values
where value_field not in (
    'Regular Season','Playoffs','Pre Season','All-Star'
)



  
  
      
    ) dbt_internal_test