-- Cleaned team metadata from `team_details`.
-- CLEAN-010: there is no coach hire date in the source. We expose headcoach and
-- a placeholder headcoach_hire_date (always NULL) so downstream consumers have a
-- stable contract; populating it requires an external source (manual intervention).

with source as (
    select * from "nba"."main"."team_details"
),

renamed as (
    select
        cast(team_id as varchar)           as team_id,
        abbreviation                       as team_abbreviation,
        nickname                           as team_nickname,
        cast(yearfounded as integer)       as year_founded,
        city                               as team_city,
        arena,
        cast(arenacapacity as integer)     as arena_capacity,
        owner,
        generalmanager                     as general_manager,
        nullif(trim(headcoach), '')        as head_coach,
        cast(null as date)                 as head_coach_hire_date,  -- CLEAN-010: no source
        dleagueaffiliation                 as dleague_affiliation
    from source
)

select * from renamed