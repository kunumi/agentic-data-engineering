# Agentic Data Engineering

**Open source notice**
>
> This repository is publicly available as part of the materials
> presented at **[CONFERENCE NAME]**. It has been made open source
> to support transparency, reproducibility, and community engagement
> around the work shared at the conference.
>
> Outside of this context, the code and resources contained here are
> provided as-is, without active maintenance or support guarantees.
> Contributions and feedback are welcome, but response times may vary.



This repo presents details about Agentic Data Engineering archtecture proposed in the paper "Towards Agentic Data Engineering: A Contract-Driven System with Self-Evolving Knowledge" [1] and the [demonstration](./NBA/README.md) of the archicture use to improve the NBA database [2].

The agentic architecture comprises (Figure 1): 

- Data Explorer Agent (DXA): explores a business database, externalizes knowledge, and creates a roadmap; and, 
- Data Transformation Agent (DTA): uses the roadmap to improve the business database.


![The Data Engineer Agentic Architecture](images/agentic-architecture.png)

Figure 1. The Data Engineer Agentic Architecture.

DXA and DTA are implemented as agents (LLM that uses tools) with persistent, file-based memory. 
The user interacts with both agents in natural language through a prompt User Interface.
The interaction with DXA is primarily to have business questions answered while exploring the database. 
The DXA may proactively reach out to the user whenever it encounters fields, business rules, or semantic ambiguities that require domain knowledge to proceed — such as clarifying the meaning of a column or confirming how a specific rule should be applied. 
Newly validated findings are written back into the knowledge base (KB).
Once the exploration is complete, DXA requests the user's approval before producing a roadmap, which is only generated upon explicit user consent. 
The roadmap items act as data contracts for DXA and DTA communication.
The roadmap is consumed by the DTA to create production-grade data pipelines.
DTA employs data tools to transform the business database in a improved one based on the pipelines.
The user interaction is optional during DTA execution.

## Data Explorer Agent (DXA)

The DXA supports analysts, domain experts, and data engineers during database exploration and requirement elicitation. The current implementation targets relational databases and relies on SQL queries plus standard DBMS metadata facilities.

During database exploration, DXA builds a persistent knowledge base (KB) composed of four Markdown files:

- NOTES.md: schema metadata, descriptive statistics, and business rules.
- ERRORS.md: syntactic, semantic, and logical issues.
- INSIGHTS.md: business-relevant findings.
- RECIPES.md: query templates validated through execution.
- SKILLS.md: instructions to perform causal analysis, to plot charts, graphs, or other kinds of visualization, to execute data profiling.

Examples of DXA artificats corresponding to the experiments conducted over the NBA database are available at [/NBA/artifacts/dxa](./NBA/artifacts/dxa-run-1/).

Once the business database exploration is complete, DXA produces a roadmap. Each roadmap item corresponds to a contract that specifies a data engineering issue validated by the DXA and to be resolved by the DTA. A contract is created only after a query that evidence the issue has been executed and validated. An example of roadmap is presented [here](NBA/artifacts/dxa-run-1/CLEANING_ROADMAP.md). 

Each roadmap contract contains:

- **Problem issue id and description**: e.g., "CLEAN-001: Table team_info_common is completely empty";
- **Severity**: critical, warning, or info;
- **Artifact**: where the issue was found (e.g., a table `team_info_common`);
- **Problem**: Issue characterization (e.g., nulls, inconsistent types, denormalizations, ambiguous encodings);
- **Evidence**: Query that evidences the issue and summary of its execution results (e.g., number of query columns and returned rows, mixed data types in a column); and
- **Recommended action**: action to solve the issue (e.g., cast, impute, normalize, deduplicate, or remove).


An example of a roadmap contract is presented as follows.

---

**CLEAN-001: Table `team_info_common` is empty.**
- **Table:** `team_info_common`
- **Severity:** critical
- **Problem:** The table exists with 26 columns but contains 0 rows. It cannot be used as a data source and may cause confusion in joins.
- **Evidence:**
```sql
SELECT COUNT(*) as total_rows FROM team_info_common;
-- Result: 0
```
- **Result:** 0 lines, 26 columns — Table 100% empty
- **Recommended action:** Check if the table should be populated (via ETL (Extract-Transform-Load)) or dropped. If it's a duplicate of the table `team_details`, consolidate them and drop the table `team_info_common`.
---

## Data Transformation Agent (DTA)

The DTA receives the roadmap and implements each roadmap contract as a data pipeline, i.e., the DTA translates the roadmap contracts into models, tests, and orchestration assets to transform the business database. In the current implementation, the DTA produces dbt1 models for transformation and uses Dagster for orchestration.

Examples of DTA artificats corresponding to the experiments conducted over the NBA database are available at [/NBA/artifacts/dta](./NBA/artifacts/dta-run-1/).

dbt expresses transformations declaratively as SQL SELECT statements, while handling testing, documentation, lineage, and versioning. Dagster complements this by orchestrating asset execution, inferring dependencies, attaching observability metadata, and managing scheduling and recovery. Together, they enable DTA to translate validated specifications into executable, monitorable pipelines.

The DTA maintains its own KB, composed of:

- ROADMAP.md: the contracts received from DXA;
- MODELS.md: the created dbt models;
- TESTS.md: tests and results;
- PIPELINE.md: assets, dependencies, and schedules;
- ERRORS.md: transformation-time failures and workarounds;
- SKILLS.md: command references for dbt and Dagster.

On the first session, DTA initializes the dbt project, configures the target database, and processes the roadmap contracts sequentially. Then, DTA follows an execution loop. For each contract, it reads the specification, writes the corresponding model and tests, executes them, and either registers success or records the failure and its workaround. Once the full pipeline succeeds, DTA generates Dagster assets, runs the workflow, updates PIPELINE.md, and commits changes to Git3, for version control. Failures are also
recorded, generalized, and made available for reuse in later contracts and future sessions.

## References

[1] Silva, L. P., Azevedo, L. G., Veloso, A. "Towards Agentic Data Engineering: A Contract-Driven System with Self-Evolving Knowledge". In: 41o Brazilian Symposium in Databases (SBBD 2026), São Carlos, SP, Brazil. (To be published)

[2] Walsh, W. (2026). NBA database. Version 3.1. Available at: https://www.kaggle.com/datasets/wyattowalsh/basketball. URL date: June 15th, 2026.
