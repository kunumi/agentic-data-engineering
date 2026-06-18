
  
  create view "nba_dbt"."main"."stg_nba__players__dbt_tmp" as (
    -- Canonical list of all players (4815). 1:1 with source `player`.
-- This is the spine for player coverage analysis (CLEAN-008).

with source as (
    select * from "nba"."main"."player"
),

renamed as (
    select
        cast(id as varchar)                 as player_id,
        full_name                           as player_full_name,
        first_name                          as first_name,
        last_name                           as last_name,
        cast(is_active as boolean)          as is_active
    from source
)

select * from renamed
  );
