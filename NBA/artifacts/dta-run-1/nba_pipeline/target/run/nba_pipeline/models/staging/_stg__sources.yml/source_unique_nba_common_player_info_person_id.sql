
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    person_id as unique_field,
    count(*) as n_records

from "nba"."main"."common_player_info"
where person_id is not null
group by person_id
having count(*) > 1



  
  
      
    ) dbt_internal_test