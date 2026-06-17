# Skills: dbt & Dagster Commands

## dbt Quick Reference

```bash
# Project setup
dbt init <name>                           # scaffold new project
dbt debug                                 # verify connection & config

# Run
dbt run                                   # run all models
dbt run --select <model>                  # run single model
dbt run --select staging.*                # run all staging
dbt run --select +<model>                 # model + all upstream deps
dbt run --select <model>+                 # model + all downstream deps
dbt run --full-refresh                    # rebuild incremental from scratch

# Test
dbt test                                  # all tests
dbt test --select <model>                 # tests for one model
dbt test --select source:*               # test all sources

# Build (run + test in dependency order)
dbt build                                 # full pipeline
dbt build --select +<model>               # model + upstream

# Compile (check SQL without executing)
dbt compile --select <model>

# Docs
dbt docs generate
dbt docs serve --port 8080

# Source freshness
dbt source freshness

# List
dbt ls --select staging.*                 # list models matching selector
dbt ls --resource-type test               # list all tests
```

## dbt Selector Syntax

| Selector | Meaning |
|----------|---------|
| `model_name` | exact model |
| `+model_name` | model + all upstream |
| `model_name+` | model + all downstream |
| `+model_name+` | model + all upstream + downstream |
| `staging.*` | all models in staging/ |
| `source:ecommerce.*` | all source tests |
| `tag:critical` | all models tagged critical |
| `config.materialized:incremental` | all incremental models |

## profiles.yml for DuckDB

```yaml
dbt_project:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: /data/databases/{{ db_file }}
      schema: main
      threads: 4
```

## profiles.yml for Spark

```yaml
dbt_project:
  target: dev
  outputs:
    dev:
      type: spark
      method: thrift
      host: spark-thrift-server
      port: 10000
      schema: default
      threads: 4
```

## Dagster CLI

```bash
# Development
dagster dev                               # start webserver + daemon (dev mode)
dagster dev -f definitions.py             # specify definitions file

# Assets
dagster asset materialize --select <key>  # materialize specific asset
dagster asset list                        # list all assets

# Jobs
dagster job execute -j <job_name>         # execute a job

# Production
dagster-webserver -h 0.0.0.0 -p 3000     # start webserver
dagster-daemon run                        # start scheduler + sensor daemon
```

## dbt_project.yml Template

```yaml
name: '{{ project_name }}'
version: '1.0.0'
config-version: 2

profile: '{{ project_name }}'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

clean-targets:
  - "target"
  - "dbt_packages"

models:
  {{ project_name }}:
    staging:
      +materialized: view
    intermediate:
      +materialized: ephemeral
    marts:
      +materialized: table
```
