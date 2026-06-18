# Data Agents over Natural Language — NBA Case Study

> Supporting material submitted to **SBBD (Brazilian Symposium on Databases)**.
> A demonstration of two AI agents — one for **exploration/querying** and one for **data engineering** — that operate over a relational database from **natural-language** instructions, recording knowledge, data-quality findings, and a reproducible transformation pipeline.

This repository gathers **the evaluation questions, the agent runs, and every artifact the agents produced**, so a reviewer can inspect exactly what each agent read, decided, and generated.

---

## 1. Overview

The experiment uses the **Maestro Agent Runtime** (Instituto Kunumi), which exposes two complementary agents over the same database (`nba.sqlite`):

| Agent | Icon | Role | What it produces |
|-------|------|------|------------------|
| **DXA** | 📊 | Answers business questions in natural language, explores the schema, validates SQL, and accumulates knowledge about the database. | Knowledge files: `NOTES.md`, `RECIPES.md`, `ERRORS.md`, `INSIGHTS.md`, `CLEANING_ROADMAP.md`, `SKILLS.md`. |
| **DTA** | ⚙ | Reads the `CLEANING_ROADMAP` produced during exploration and builds a transformation pipeline (dbt + Dagster) that materializes the cleaning roadmap into tested models. | dbt project `nba_pipeline`, DuckDB data warehouse, `MODELS.md`, `TESTS.md`, `PIPELINE.md`. |

The agents are driven by **natural-language questions** (see [`NBA/questions/`](NBA/questions/)) and can use different backend LLMs (Claude, GPT‑4o, Gemini, Llama, Mistral — selectable in the interface).

> **About the `dxa` and `dta` labels:** they identify the recorded runs. By inspecting the transcripts, **`dxa` corresponds to DXA runs (exploration)** and **`dta` corresponds to the DTA run (pipeline)**. Each `… - run N` folder is an independent run.

---

## 2. Repository map

```
SBBD/
└── NBA/
    ├── questions/          # Evaluation question set (experiment input)
    ├── runs/               # HTML transcripts of the conversations with the agents (run evidence)
    └── artifacts/          # Everything the agents produced (knowledge + pipeline + warehouse)
```

Each part is detailed below.

---

### 2.1 `NBA/questions/` — Evaluation set

[`questions_sql_nba.csv`](NBA/questions/questions_sql_nba.csv) — **30 questions** about the NBA domain, classified by difficulty (`Easy`, `Medium`, `Hard`). This is the experiment input: what the agents are asked to answer.

| Difficulty | # of questions | Examples |
|------------|----------------|----------|
| Easy | 10 | "List the name and city of all registered teams."; "What is the average height and average weight of all players?" |
| Medium | 10 | "How many wins did each team achieve playing away?"; "What was the game with the largest point difference (biggest 'blowout')?" |
| Hard | 10 | "Compute the longest streak of consecutive wins of each team."; "For each team, find the most consistent player (lowest standard deviation of points)…" |

> The questions were deliberately designed to **expose limitations of the database**: some of them (per-player statistics, conference/division, January 2025 games, head-coach hire dates) **cannot be answered** with the available data. The value of the evaluation lies in observing how the agent **detects and communicates** these gaps — not merely in getting the SQL right.

---

### 2.2 `NBA/runs/` — Run transcripts

Each subfolder is a **self-contained HTML page** (open it in a browser) with the full conversation: the user's question, the agent's reasoning, the SQL queries executed, errors, fixes, and reads/writes of the knowledge files.

| Folder | Agent | Content |
|--------|-------|---------|
| [`dxa - run 1/`](NBA/runs/dxa%20-%20run%201/) | 📊 DXA | Longest exploration session (≈238 KB) — schema discovery, building the recipes and the roadmap. File: `dxa.html`. |
| [`dxa - run 2/`](NBA/runs/dxa%20-%20run%202/) | 📊 DXA | Second exploration run. File: `SQL Agent.html`. |
| [`dta - run 1/`](NBA/runs/dta%20-%20run%201/) | ⚙ DTA | Building the dbt pipeline from the roadmap. File: `SQL Agent.html`. |

The `*_files/` subfolders contain only the static assets (CSS, syntax highlighting, `marked.js`) needed to render the HTML — **there is no research content there**.

---

### 2.3 `NBA/artifacts/` — Produced artifacts

The agents' actual output, split by the run that generated it.

#### `artifacts/dxa - run 1/` — Exploration knowledge (DXA)

Knowledge files that DXA accumulates and reuses across sessions:

| File | Contents |
|------|----------|
| [`NOTES.md`](NBA/artifacts/dxa%20-%20run%201/NOTES.md) | **Database metadata**: tables, types, relationships, business rules confirmed with the user, and limitations. The starting point for understanding the NBA schema. |
| [`RECIPES.md`](NBA/artifacts/dxa%20-%20run%201/RECIPES.md) | **Validated SQL recipes** (RCP‑001…009) — queries tested on the database, with context, the result obtained, and gotchas. Covers everything from "list teams" to window functions (win streaks, running totals, win rate). |
| [`ERRORS.md`](NBA/artifacts/dxa%20-%20run%201/ERRORS.md) | **Error log with post‑mortems** (ERR‑001…) — syntactic and business errors encountered and how to avoid them (e.g., use `TRY_CAST` on text columns with empty strings; `data` is a reserved word in DuckDB). |
| [`CLEANING_ROADMAP.md`](NBA/artifacts/dxa%20-%20run%201/CLEANING_ROADMAP.md) | **Prescriptive data-quality roadmap** (CLEAN‑001…010), ordered by severity, with SQL evidence, result, and recommended action. **This is the bridge between the two agents**: DTA consumes it as a specification. |
| [`INSIGHTS.md`](NBA/artifacts/dxa%20-%20run%201/INSIGHTS.md) | Business findings confirmed by the user (empty in this run). |
| [`SKILLS.md`](NBA/artifacts/dxa%20-%20run%201/SKILLS.md) | **Advanced agent skills**: protocols for **causal analysis** (prepare → discover → estimate → refute → report), **chart generation** (`/plot`), and **data profiling** with Desbordante (FDs, UCCs, INDs, association rules, denial constraints). |

#### `artifacts/dta - run 1/` — Data-engineering pipeline (DTA)

Materializes the `CLEANING_ROADMAP` into a reproducible dbt pipeline.

```
dta - run 1/
├── PIPELINE.md          # Pipeline inventory: engine, connection, DAG, orchestration, commands
├── MODELS.md            # Catalog of the 12 dbt models (MOD-001…012) and what each one cleans
├── TESTS.md             # Test results (61 PASS / 1 WARN / 0 ERROR) and business validations
├── CLEANING_ROADMAP.md  # Copy of the roadmap, annotated with each item's status (✅ resolved / ⚠️ needs external source)
├── ERRORS.md            # Errors found while building the pipeline (e.g., game_id is not unique)
├── SKILLS.md            # Reference of the dbt and Dagster commands used
├── nba_pipeline/        # >>> Complete dbt project (see below) <<<
└── warehouse/
    └── nba_dbt.duckdb   # Materialized DuckDB data warehouse (output of `dbt build`)
```

**dbt project `nba_pipeline/`** — layered architecture (`source → staging → intermediate → marts`):

| Layer | Materialization | Models | Function |
|-------|-----------------|--------|----------|
| **staging** (`models/staging/`) | view | 6 | 1:1 cleanup of the sources: standardizes `season_type`, deduplicates `game_id`, converts height/weight to numeric, handles sentinel dates and empty positions. |
| **intermediate** (`models/intermediate/`) | ephemeral | 3 | Business logic: classifies official vs. exhibition games, resolves historical franchise names, computes player-profile coverage. |
| **marts** (`models/marts/`) | table | 3 | Consumption tables: `mart_nba__games`, `mart_nba__teams`, `mart_nba__player_profiles`. |

Other components of the dbt project:
- `macros/unit_conversions.sql` — feet→cm and pounds→kg conversions.
- `tests/` — singular tests (birthdate domain, non-empty marts) and the generic `positive_values` test.
- `definitions.py` — **Dagster** orchestration (`dbt build` as an asset, a job, and a daily schedule `0 6 * * *`).
- `profiles.yml` — attaches `nba.sqlite` in **read-only** mode via DuckDB's `sqlite` extension.
- `target/` — dbt-generated artifacts (`manifest.json`, `catalog.json`, compiled SQL, `run_results.json`, docs). Useful to audit exactly what ran.

> **How to read it together:** start with `PIPELINE.md` (overview and DAG) → `MODELS.md` (what each model does and which CLEAN item it resolves) → `TESTS.md` (evidence that it worked). The annotated `CLEANING_ROADMAP.md` shows the item-by-item traceability from the exploration roadmap to the implementation.

---

## 3. The NBA database (summary)

`nba.sqlite` (~2.3 GB) — a historical NBA snapshot. Main tables: `game`, `player`, `team`, `common_player_info`, `team_details`, `team_info_common`, `play_by_play`, among others. Key points (detailed in [`NOTES.md`](NBA/artifacts/dxa%20-%20run%201/NOTES.md)):

- **Temporal coverage:** 1946‑11‑01 to **2023‑06‑12** (ends with the 2022‑23 season). No games after June 2023.
- **Team-level stats only:** `pts/ast/reb/min…` exist only at team level (`_home`/`_away`) in the `game` table. **There is no per-player box score.**
- **`team_info_common` is empty** (0 rows) — the only source of conference/division/standings data.
- **30 current franchises**, but the `game` table contains 122 distinct team entities (including exhibition teams and defunct franchises).

### Gaps that make some questions unanswerable

This is the main analytical contribution of the case study — questions from the evaluation set that **cannot be answered** with the data, and why:

| Gap (roadmap item) | Affected questions |
|--------------------|--------------------|
| No per-player box score (**CLEAN‑002**) | Points/assists/rebounds per player, PPG, leaders, consistency, games with >35 min, rebounds by position. |
| `team_info_common` empty (**CLEAN‑001**) | Teams by conference (East/West). |
| No head-coach hire date (**CLEAN‑010**) | "Coaches and the date they were hired." |
| 2023 temporal cutoff | "Games in January 2025" → 0 rows. |

---

## 4. Key results

- **Exploration (DXA):** 9 validated SQL recipes, 5 documented errors with post‑mortems, **10 data-quality items** mapped with severity and evidence.
- **Engineering (DTA):** **12 dbt models**, **62 tests** (61 PASS, 1 intentional WARN, 0 ERROR). 7 of the 10 roadmap items were resolved in code; 3 depend on external-source ingestion and were explicitly documented (with a placeholder model/test where applicable).

---

## 5. How to navigate (suggested for reviewers)

1. **Input:** read [`NBA/questions/questions_sql_nba.csv`](NBA/questions/questions_sql_nba.csv) to see what was asked.
2. **Runs:** open the HTML files in [`NBA/runs/`](NBA/runs/) in a browser to follow the agents' reasoning step by step.
3. **Exploration knowledge:** read, in this order, `NOTES.md` → `RECIPES.md` → `ERRORS.md` → `CLEANING_ROADMAP.md` in [`artifacts/dxa - run 1/`](NBA/artifacts/dxa%20-%20run%201/).
4. **Data pipeline:** read `PIPELINE.md` → `MODELS.md` → `TESTS.md` in [`artifacts/dta - run 1/`](NBA/artifacts/dta%20-%20run%201/), and inspect the dbt project under `nba_pipeline/models/`.

### Reproducing the dbt pipeline (optional)

Requires `dbt-duckdb` and `nba.sqlite` mounted at `/data/databases/`. From `artifacts/dta - run 1/nba_pipeline/`:

```bash
export DBT_PROFILES_DIR="$(pwd)"
dbt build           # run all models + tests in dependency order
dbt docs generate   # generate manifest + catalog
```

The resulting warehouse is already versioned at [`artifacts/dta - run 1/warehouse/nba_dbt.duckdb`](NBA/artifacts/dta%20-%20run%201/warehouse/) and can be queried directly with the DuckDB CLI.

---

## 6. Technical structure in one sentence

> Given a relational database and natural-language questions, an **exploration agent** discovers the schema, validates SQL, and produces a data-quality roadmap; an **engineering agent** consumes that roadmap and materializes it into a tested **dbt + Dagster** pipeline over **DuckDB** — with every decision, error, and piece of evidence recorded in auditable knowledge files.
