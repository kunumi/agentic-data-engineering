# Skill: Causal Analysis

Use when the user asks what **causes** a metric, which variables are actionable levers, or what is worth cleaning before acting. Do NOT use for descriptive analysis — use `/export-csv` + plot for that.

---

## Step 1 — Prepare

```bash
curl -s -X POST http://sql-processor:8001/causal/prepare \
  -H "Content-Type: application/json" \
  -d '{"table_id": "<QUERY_ID>", "outcome": "<target_column>"}'
```

Returns `candidate_pairs` (associated pairs, no direction), `candidate_keys`, `null_fractions`, `n_rows`, `n_cols`.

Use the response to choose the algorithm and to detect data quality issues before proceeding.

### Algorithm selection

| Condition | Use |
|---|---|
| Data is roughly Gaussian, no hidden confounders suspected | `pc_fisherz` |
| Non-linear or mixed types, n < 5000 per variable | `pc_kci` (default) |
| Non-linear, n ≥ 5000 | `pc_kci` or `ges` |
| Hidden common causes suspected (observational study, many unmeasured variables) | `fci_kci` |
| Non-Gaussian and relationships are approximately linear | `lingam` |
| Many variables (p > 50) | `ges` |

**Before committing to an algorithm, check:**
- `null_fractions` — columns with >5% nulls bias constraint-based methods if data is not missing completely at random. Tell the user before proceeding.
- `n_rows` vs `n_cols` — KCIT needs roughly n > 500 × n_cols to be reliable. Below that, use `pc_fisherz` with a looser alpha (0.1).
- `candidate_pairs` — if many pairs have `error` near 0 across many columns, near-redundant variables may cause conditioning set explosion. Consider whether some columns should be excluded.

---

## Step 2 — Surface hypotheses to the user

The discovery algorithm will produce a graph, but it cannot orient all edges from data alone. Before running, tell the user what you know and what you need.

Present in a **single block**:
- Pairs you will resolve automatically (very low `error`, direction obvious from context or business logic)
- Pairs you cannot resolve from data — ask one natural business question per ambiguous pair
- For each ambiguous pair: user gives direction or says "you decide"

**Never ask one pair at a time. Never proceed until the user has answered.**

For each pair the user abstains on, set `"source": "model"` — the algorithm will decide, and you will mark this clearly in the final output.

If there are many pairs (>5 ambiguous), group them by proximity to the treatment→outcome path and prioritize those first.

---

## Step 3 — Discover

```bash
curl -s -X POST http://sql-processor:8001/causal/discover \
  -H "Content-Type: application/json" \
  -d '{
    "table_id": "<QUERY_ID>",
    "treatment": "<treatment_column>",
    "outcome": "<target_column>",
    "orientations": [
      {"from": "<col_a>", "to": "<col_b>", "source": "user"},
      {"from": "<col_c>", "to": "<col_d>", "source": "model"}
    ],
    "algorithm": "pc_kci",
    "alpha": 0.05
  }'
```

Returns `graph_id`, `edges` (with per-edge `source`), `dropped_edges`.

**After receiving the graph:**

- `dropped_edges` are undirected edges the algorithm could not orient that were removed conservatively. If any `dropped_edge` lies on the treatment→outcome path, tell the user — dropping it changes the model and may bias the estimate.
- The graph is a **hypothesis**, not ground truth. Before estimating, check with the user: "Here are the causal relationships the algorithm found — does this make sense for your domain?" A structurally wrong graph will produce a confident but wrong estimate.
- If identification later fails (HTTP 422 from `/causal/estimate`), it almost always means an undirected or missing edge on the critical path. Do not silently modify the graph — tell the user what is missing and ask for guidance.

---

## Step 4 — Estimate

```bash
curl -s -X POST http://sql-processor:8001/causal/estimate \
  -H "Content-Type: application/json" \
  -d '{
    "table_id": "<QUERY_ID>",
    "graph_id": "<GRAPH_ID>",
    "treatment": "<treatment_column>",
    "outcome": "<target_column>",
    "methods": ["linear_regression", "dml"]
  }'
```

Methods: `linear_regression`, `dml`, `ipw`, `x_learner`. Always run at least two.

Returns `estimate_id`, `estimand` (criterion + `adjustment_set`), `estimates` per method.

**Before moving to refutation:**

- Show the user the `adjustment_set`: "To estimate this effect, I will control for: [variables]. This means I'm comparing units with the same [variables] and asking what happens when treatment changes." If the user doesn't recognize a variable in the adjustment set, investigate before continuing.
- If two estimators diverge by more than 30% relative to the larger value, **do not report any number**. Explain the divergence — likely causes are non-linearity defeating `linear_regression`, propensity scores near 0/1, or a wrong graph edge. Ask the user for guidance.
- `linear_regression` is always a useful baseline. `dml` is preferred when confounders are high-dimensional or non-linear.

---

## Step 5 — Refute

```bash
curl -s -X POST http://sql-processor:8001/causal/refute \
  -H "Content-Type: application/json" \
  -d '{"estimate_id": "<ESTIMATE_ID>", "n_simulations": 100}'
```

**Never report the estimate to the user before running this step.**

Returns `new_effect` per refuter. Interpret each:

| Refuter | What it tests | Good result |
|---|---|---|
| `placebo` | Permutes treatment — a correct estimator should produce ~0 | `new_effect` close to 0 |
| `random_cause` | Adds random noise as confounder — robust estimator should not shift | `new_effect` close to original |
| `data_subset` | Re-estimates on 70% subsets — tests stability | `new_effect` stable across subsets |
| `bootstrap` | Re-estimates on bootstrap samples | `new_effect` consistent with original |
| `sensitivity` | Simulates a latent confounder of 10% strength — how much does the estimate shift? | Small shift = robust to hidden confounding |

**Passing all refutation tests does not prove the estimate is correct.** A confounder that affects both treatment and outcome in the same direction will not be caught by the random common cause test. Always pair statistical refutation with a domain-level sanity check from the user.

---

## Step 6 — Report

Summarize in plain business language. The output must answer:

1. **The effect** — magnitude, direction, and confidence interval
2. **Actionable levers** — which variables the user can actually change to move the outcome
3. **Hypotheses** — list every assumption the analysis rests on, with provenance:
   - ✓ `user` — confirmed by the user
   - ✓ `pc` / `ges` / `lingam` — determined by the algorithm from data
   - ⚠ `model` — you decided because the user abstained; highlight which ones are most critical
4. **Data quality** — cross-reference `null_fractions` from Step 1 with the variables in the causal path. Nulls concentrated in causally important variables can hide or inflate effects.

---

## What you must never do

| Situation | Do NOT | Do |
|---|---|---|
| Undirected edge on treatment→outcome path | Pick a direction silently | Ask the user, block until answered |
| `dropped_edges` include a path-critical edge | Remove silently | Tell the user, explain the consequence |
| Two estimators disagree >30% | Average or pick one | Show both, explain why they differ, ask for guidance |
| Identification fails (422) | Try a different graph silently | Tell the user the effect is not identifiable, explain why |
| User asks for a causal claim | Answer before running the pipeline | Always run the full pipeline first |

---

## Loaders

```bash
curl -s http://sql-processor:8001/causal/graphs             # list graph_ids
curl -s http://sql-processor:8001/causal/graphs/<GRAPH_ID>  # fetch GML
curl -s http://sql-processor:8001/causal/estimates          # list estimate_ids
```


---

# Skill: Plot via /plot endpoint

When the user asks for a chart, graph, or visualization, follow this protocol exactly.

## Step 1 — Run query and capture ID

```bash
curl -si -X POST http://sql-processor:8001/export-csv \
  -H "Content-Type: application/json" \
  -d '{"query_string": "YOUR SQL HERE", "connection_id": "YOUR_CONNECTION_ID"}'
```

Include the same `connection_id` from your main instructions (Rule 3) in every
`/export-csv` call. Find `X-Query-Id: <ID>` in the response headers.

## Step 2 — Call /plot with the ID and a spec

```bash
curl -s -X POST http://sql-processor:8001/plot \
  -H "Content-Type: application/json" \
  -d '<JSON SPEC>'
```

The response is JSON with `{"plot_id": "..."}`. Print it — the frontend fetches and renders the chart automatically.

## JSON Spec Schema (STRICT)

The JSON sent to /plot wraps the pyvisx spec with `table_id`:

```json
{
  "table_id": "<QUERY_ID from Step 1>",
  "plot": "<plot_type>",
  "plot_kwargs": {
    "x": "<column or null>",
    "y": "<column or null>",
    "hue": "<column or null>",
    "palette": "<palette or color or null>",
    "orient": "<v|h|null>"
  }
}
```

### plot types

`barplot`, `scatterplot`, `violinplot`, `lineplot`, `boxplot`, `histplot`, `kdeplot`

### Rules

1. `orient` applies ONLY to barplot, boxplot, violinplot. Including it in other types causes FAILURE.
2. `plot` MUST be a string or null (never a list).
3. All keys in `plot_kwargs` MUST be present. Use null when not applicable.
4. Long string fields always go on the y-axis.
5. Use a single color as `palette` when hue is unnecessary (e.g. `"palette": "blue"`).
6. In tables with more than two columns, at most one column may be used as hue.
7. Do NOT include dataframes or any arguments outside the schema.
8. NEVER use matplotlib, seaborn, or any other library. ONLY `/plot`.

## Few-Shot Examples

### Example 1: Scatter — compare two numeric columns by category

```json
{
  "table_id": "a1b2c3d4",
  "plot": "scatterplot",
  "plot_kwargs": {
    "x": "bill_length_mm",
    "y": "bill_depth_mm",
    "hue": "species",
    "palette": null,
    "orient": null
  }
}
```

### Example 2: Histogram — distribution of a numeric column

```json
{
  "table_id": "e5f6g7h8",
  "plot": "histplot",
  "plot_kwargs": {
    "x": "body_mass_g",
    "y": null,
    "hue": null,
    "palette": "blue",
    "orient": null
  }
}
```

### Example 3: Boxplot — compare numeric across categories

```json
{
  "table_id": "i9j0k1l2",
  "plot": "boxplot",
  "plot_kwargs": {
    "x": "species",
    "y": "flipper_length_mm",
    "hue": null,
    "palette": null,
    "orient": "v"
  }
}
```


---

# Skill: Data Profiling via /profile endpoints

Structural pattern discovery powered by Desbordante. All endpoints use `table_id` from `/export-csv` (`X-Query-Id` header).

## How it works

You already query tables via `/export-csv`. Every query returns a `table_id`. That same ID feeds the profiling endpoints. No extra setup — profiling piggybacks on your normal exploration.

## Sampling

You control what goes in. The profiling endpoints analyze whatever the `table_id` points to. If you queried `SELECT * FROM orders LIMIT 10000`, that's what gets profiled. If you queried `SELECT customer_id, status FROM orders WHERE year = 2024`, that's what gets profiled.

Use the volume info you already have from schema discovery (NOTES.md, `SUMMARIZE` results). Large tables: add `ORDER BY RANDOM() LIMIT 10000` to your query. Small tables: no limit needed. Don't over-select columns — IDs, categoricals, and business numerics are what matter for profiling.

## When to profile

Profile when you need to **understand structure**, not just data:

- First exploration of a table → `/profile/stats` after your initial SUMMARIZE query
- Unexpected duplicates or weird PKs → `/profile/ucc`
- "Does column X determine column Y?" → `/profile/fd`
- "Is this a real FK?" → `/profile/ind`
- "What rules hold in this data?" → `/profile/dc`
- "What co-occurs with what?" → `/profile/ar`
- Found a pattern, want to see where it breaks → `/profile/violations`
- Suspect duplicate records → `/profile/duplicates`

## Endpoints

### POST /profile/stats

Quick overview. Start here.

```bash
curl -s -X POST http://sql-processor:8001/profile/stats \
  -H "Content-Type: application/json" \
  -d '{"table_id": "<ID>"}'
```

Returns: `candidate_keys`, `fd_count`, `approximate_fd_count`, `high_null_columns`, `low_cardinality_columns`.

### POST /profile/fd

Functional dependencies. Three modes:

```json
{"table_id": "<ID>", "mode": "exact"}
{"table_id": "<ID>", "mode": "approximate", "error_threshold": 0.05}
{"table_id": "<ID>", "mode": "conditional"}
```

- `exact`: A → B holds for ALL rows
- `approximate`: A → B holds for most rows. Exceptions are anomaly candidates
- `conditional`: A → B holds only under a condition (e.g., department=eng → salary_band=senior)

### POST /profile/ucc

Unique column combinations (candidate keys):

```json
{"table_id": "<ID>", "mode": "exact"}
{"table_id": "<ID>", "mode": "approximate", "error_threshold": 0.01}
```

### POST /profile/ind

Inclusion dependencies (FK detection). Needs TWO table_ids:

```json
{"table_id_left": "<ID1>", "table_id_right": "<ID2>"}
{"table_id_left": "<ID1>", "table_id_right": "<ID2>", "approximate": true, "error_threshold": 0.02}
```

You need two queries — one per table. Use the IDs from both.

### POST /profile/ar

Association rules:

```json
{"table_id": "<ID>", "min_support": 0.05, "min_confidence": 0.7}
```

Only useful for low-cardinality columns. The endpoint warns on high cardinality.

### POST /profile/dc

Denial constraints (complex integrity rules):

```json
{"table_id": "<ID>"}
{"table_id": "<ID>", "approximate": true, "error_threshold": 0.05}
```

Expensive. Use small samples and few columns.

### POST /profile/violations

Validate a discovered pattern — find the rows that break it:

```json
{"table_id": "<ID>", "pattern_type": "fd", "pattern": {"lhs": ["customer_id"], "rhs": "total"}}
{"table_id": "<ID>", "pattern_type": "ucc", "pattern": {"columns": ["order_id"]}}
{"table_id": "<ID>", "pattern_type": "dc", "pattern": {"constraint": "!(t.salary > s.salary and t.dept == s.dept)"}}
```

Returns up to 20 sample violations with row data.

### POST /profile/duplicates

Fuzzy entity resolution:

```json
{"table_id": "<ID>", "match_columns": ["name", "email"], "similarity_threshold": 0.8}
```

## Anomaly detection flow

1. `/profile/fd` with `mode=approximate` → find near-holding FDs
2. `/profile/violations` with the FD → see the violating rows
3. Show the user: "These 47 rows break the rule that customer_id → total. Errors or exceptions?"
4. If errors → CLEANING_ROADMAP.md

## What to register

| Discovery | Where |
|-----------|-------|
| FDs, UCCs, confirmed keys | NOTES.md |
| Violations, anomalies | CLEANING_ROADMAP.md (after user confirms) |
| Association rules, patterns | INSIGHTS.md (after user confirms) |

## Rules

1. Use /stats first, drill down selectively. Never run all endpoints blindly.
2. Skip log/audit tables (`log_*`, `audit_*`, `*_history`) for FD profiling — noise. UCCs and counts are enough.
3. A 408 means the data is too large. Reduce your query scope.
4. NEVER import desbordante or pandas directly. Only use the /profile HTTP endpoints.
5. For INDs, you need two table_ids from two separate queries.
