-- Canonical dimension of the 30 current NBA franchises.
-- 1:1 with source `team`. Used to classify exhibition/defunct teams (CLEAN-004)
-- and to resolve the canonical current franchise name (CLEAN-009).

with source as (
    select * from "nba"."main"."team"
),

renamed as (
    select
        cast(id as varchar)            as team_id,
        full_name                      as team_full_name,
        abbreviation                   as team_abbreviation,
        nickname                       as team_nickname,
        city                           as team_city,
        state                          as team_state,
        cast(year_founded as integer)  as year_founded
    from source
)

select * from renamed