"""Dagster definitions for the NBA dbt pipeline.

Generated after the dbt pipeline is fully green (PASS=61, WARN=1, ERROR=0).
Wraps the dbt project as Dagster assets and exposes a daily schedule that runs
`dbt build` (run + test in dependency order).
"""
import os
from pathlib import Path

from dagster import Definitions, ScheduleDefinition, define_asset_job
from dagster_dbt import DbtCliResource, DbtProject, dbt_assets

DBT_PROJECT_DIR = Path(__file__).parent
os.environ.setdefault("DBT_PROFILES_DIR", str(DBT_PROJECT_DIR))

nba_project = DbtProject(project_dir=DBT_PROJECT_DIR)
nba_project.prepare_if_dev()


@dbt_assets(manifest=nba_project.manifest_path)
def nba_dbt_assets(context, dbt: DbtCliResource):
    # `build` = run + test in DAG order, mirroring the validated pipeline.
    yield from dbt.cli(["build"], context=context).stream()


# Daily refresh job + schedule (06:00). Source is static here, but the schedule
# documents the intended cadence and is ready when the source refreshes.
nba_dbt_job = define_asset_job(name="nba_dbt_build_job", selection="*")
nba_daily_schedule = ScheduleDefinition(
    job=nba_dbt_job,
    cron_schedule="0 6 * * *",
    name="nba_daily_build",
)

defs = Definitions(
    assets=[nba_dbt_assets],
    jobs=[nba_dbt_job],
    schedules=[nba_daily_schedule],
    resources={"dbt": DbtCliResource(project_dir=str(DBT_PROJECT_DIR))},
)
