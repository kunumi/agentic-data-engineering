-- CLEAN-005/006/007/008: consumption-ready player dimension.
-- Spine is the full canonical player list (4815); has_detailed_info flags the
-- ~1183 players without a detailed profile (CLEAN-008). Physical measures are
-- numeric metric units (CLEAN-005), birthdate is sentinel-free (CLEAN-006), and
-- position_group is never NULL ('Unknown' bucket, CLEAN-007). Age is computed at
-- the pipeline run date so rankings are not distorted by placeholder birthdates.

with coverage as (
    select * from {{ ref('int_nba__player_coverage') }}
),

final as (
    select
        player_id,
        player_full_name,
        is_active,
        has_detailed_info,
        coalesce(position_group, 'Unknown')               as position_group,
        birthdate,
        case
            when birthdate is not null
            then date_diff('year', birthdate, current_date)
        end                                               as age_years,
        height_cm,
        weight_kg,
        from_year,
        to_year
    from coverage
)

select * from final
