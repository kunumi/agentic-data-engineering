# Pipeline

Pipeline inventory: models, schedules, dependencies. Project: `nba_pipeline` (dbt-duckdb 1.10.1, dbt-core 1.11.11).

## Engine & connection
- Adapter: dbt-duckdb. Output warehouse: `warehouse/nba_dbt.duckdb`.
- Source: `/data/databases/nba.sqlite` attached READ_ONLY as catalog `nba` via DuckDB `sqlite` extension.
- Profiles: `nba_pipeline/profiles.yml` (DBT_PROFILES_DIR points at project dir).

## Inventory
- Models: 12 (6 staging, 3 intermediate, 3 marts)
- Sources: 1 (nba, 6 tables declared)
- Tests: 62 (61 PASS, 1 WARN, 0 ERROR)
- Materialization: 6 views, 3 ephemeral, 3 tables
- DAG depth: 3 (source → staging → intermediate → mart)

## Dependency Graph
```
mart_nba__games
  └── int_nba__games_classified
        ├── stg_nba__games          ← source: nba.game
        └── stg_nba__teams          ← source: nba.team

mart_nba__teams
  ├── stg_nba__teams                ← source: nba.team
  └── int_nba__franchise_names
        └── stg_nba__games          ← source: nba.game

mart_nba__player_profiles
  └── int_nba__player_coverage
        ├── stg_nba__players        ← source: nba.player
        └── stg_nba__player_info    ← source: nba.common_player_info

stg_nba__team_details               ← source: nba.team_details   (CLEAN-010)
stg_nba__team_info_common           ← source: nba.team_info_common (EMPTY, CLEAN-001)
```

## Orchestration (Dagster)
- `definitions.py`: `nba_dbt_assets` wraps `dbt build`; job `nba_dbt_build_job`; schedule `nba_daily_build` (cron `0 6 * * *`).
- Run dev UI: `dagster dev -f definitions.py` (DBT_PROFILES_DIR=project dir).

## Commands
```bash
export PATH="$HOME/.local/bin:$PATH"
export DBT_PROFILES_DIR=/tmp/maestro-deng-47db742bf8e7b3e3-ryih7kor/nba_pipeline
cd /tmp/maestro-deng-47db742bf8e7b3e3-ryih7kor/nba_pipeline
dbt build            # full run + test
dbt docs generate    # manifest + catalog
```

## Open items (need external source data — out of dbt scope)
- CLEAN-001 team_info_common empty · CLEAN-002 no player box score · CLEAN-010 no coach hire date.
