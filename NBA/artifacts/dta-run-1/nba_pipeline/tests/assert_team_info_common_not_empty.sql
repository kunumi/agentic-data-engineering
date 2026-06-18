-- Singular test (CLEAN-001): flags that team_info_common is empty.
-- Severity = warn so the pipeline stays green while documenting the data gap.
-- Returns a row (=> failure) whenever the staging model has 0 rows.
{{ config(severity = 'warn') }}

select 1 as is_empty
where (select count(*) from {{ ref('stg_nba__team_info_common') }}) = 0
