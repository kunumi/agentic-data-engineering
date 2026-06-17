
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  -- Guard: every mart must have at least one row. Returns a row (=> failure) for
-- any mart that is empty.
with counts as (
    select 'mart_nba__teams'           as mart, count(*) as n from "nba_dbt"."main"."mart_nba__teams"
    union all
    select 'mart_nba__games'           as mart, count(*) as n from "nba_dbt"."main"."mart_nba__games"
    union all
    select 'mart_nba__player_profiles' as mart, count(*) as n from "nba_dbt"."main"."mart_nba__player_profiles"
)

select * from counts where n = 0
  
  
      
    ) dbt_internal_test