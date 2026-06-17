-- Cleaned detailed player attributes from `common_player_info`.
-- Addresses three roadmap items:
--   CLEAN-005: height/weight stored as text with empty strings -> numeric height_cm / weight_kg
--   CLEAN-006: birthdate sentinel 1900-01-01 (placeholder) -> NULL
--   CLEAN-007: empty position -> NULL plus an explicit 'Unknown' bucket

with source as (
    select * from "nba"."main"."common_player_info"
),

renamed as (
    select
        cast(person_id as varchar)                    as player_id,
        display_first_last                            as player_full_name,
        first_name,
        last_name,

        -- CLEAN-006: 1900-01-01 is a placeholder, not a real birthdate.
        case
            when cast(birthdate as date) <= date '1900-01-01' then null
            else cast(birthdate as date)
        end                                           as birthdate,

        -- CLEAN-007: normalize empty string -> NULL, and a coalesced bucket.
        nullif(trim(position), '')                    as position,
        coalesce(nullif(trim(position), ''), 'Unknown') as position_group,

        -- CLEAN-005: parse text measures into numeric metric units (NULL-safe).
        nullif(trim(height), '')                      as height_raw,
        nullif(trim(weight), '')                      as weight_raw,
        
    case
        when height is null or trim(height) = '' then null
        else round(
            try_cast(split_part(height, '-', 1) as integer) * 30.48
            + try_cast(split_part(height, '-', 2) as integer) * 2.54
        , 1)
    end
             as height_cm,
        
    case
        when weight is null or trim(weight) = '' then null
        else round(try_cast(weight as double) * 0.453592, 1)
    end
                     as weight_kg,

        school,
        country,
        cast(team_id as varchar)                      as team_id,
        team_name,
        team_abbreviation,
        cast(from_year as integer)                    as from_year,
        cast(to_year as integer)                      as to_year,
        rosterstatus                                  as roster_status
    from source
)

select * from renamed