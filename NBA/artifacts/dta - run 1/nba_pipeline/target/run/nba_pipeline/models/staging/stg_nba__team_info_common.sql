
  
  create view "nba_dbt"."main"."stg_nba__team_info_common__dbt_tmp" as (
    -- Staging for `team_info_common` (conference/division/standings per season).
-- CLEAN-001: the source table is EMPTY (0 rows). This model preserves the cleaned
-- schema so the pipeline is ready the moment the table is repopulated, and a
-- warn-severity test (assert_team_info_common_not_empty) flags the emptiness
-- without failing the build. Repopulating requires an external source.

with source as (
    select * from "nba"."main"."team_info_common"
),

renamed as (
    select
        cast(team_id as varchar)          as team_id,
        season_id,
        season_year,
        team_city,
        team_name,
        team_abbreviation,
        team_conference,
        team_division,
        cast(w as integer)                as wins,
        cast(l as integer)                as losses,
        cast(pct as double)               as win_pct,
        cast(conf_rank as integer)        as conference_rank,
        cast(div_rank as integer)         as division_rank,
        cast(pts_pg as double)            as pts_per_game,
        cast(reb_pg as double)            as reb_per_game,
        cast(ast_pg as double)            as ast_per_game,
        cast(opp_pts_pg as double)        as opp_pts_per_game
    from source
)

select * from renamed
  );
