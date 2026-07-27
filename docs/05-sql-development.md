# SQL Development
## Retail Inventory Intelligence Platform (RIIP)

| Field | Value |
|---|---|
| **Document** | SQL Development |
| **Version** | 1.0 |
| **Date** | 25 July 2026 |
| **Depends on** | Database Design v1.0, Synthetic Dataset v1.0 |
| **Target** | PostgreSQL 15+ |
| **Validation** | 54/54 business queries + 5 views executed against generated data |

---

## 1. What's in this section

Production-quality PostgreSQL organised by execution order:

```
sql/
├── 00_database_setup/00_create_database.sql   -- schemas (raw/staging/dw) + roles
├── 01_schema/01_dimensions.sql                -- 7 dimension DDL
├── 01_schema/02_facts.sql                     -- 5 facts incl. partitioned snapshot
├── 02_constraints_indexes/01_foreign_keys.sql -- FK wiring (role-playing dims)
├── 02_constraints_indexes/02_indexes.sql      -- B-tree + BRIN + partial indexes
├── 03_views/01_analytical_views.sql           -- 5 reusable business views
├── 04_procedures/01_functions_procedures.sql  -- partition mgmt + KPI refresh
└── 05_business_queries/business_questions.sql  -- 54 solved business questions
```

The numbered folders encode run order: a reviewer can execute top to bottom without guessing dependencies.

---

## 2. The 54 business questions

Every stakeholder question from the BRD is answered in SQL, grouped by theme:

| Theme | Questions | Example |
|---|---|---|
| Inventory Health | Q1–Q12 | Dead stock, GMROI, turnover, days-of-supply, chronic stock-outs |
| Sales & Demand | Q13–Q24 | MoM growth, declining products, Pareto concentration, lost sales |
| Supplier Performance | Q25–Q34 | OTIF ranking, lead-time variability, composite scorecard, single-source risk |
| Warehouse & Network | Q35–Q42 | Holding cost, transfer routes, capacity utilisation, regional balance |
| Store & Product | Q43–Q48 | Store ranking, under-performers vs region, performance quadrant, returns |
| Executive & Exceptions | Q49–Q54 | KPI scorecard, reorder worklist, capital-release, ABC×XYZ, leakage |

Each query carries a header comment stating **the business question, its value, and the technique used** — so the file reads as a portfolio of solved problems, not a wall of SQL.

---

## 3. SQL techniques demonstrated

The query set is deliberately built to showcase the full analytical toolkit an interviewer probes for:

| Technique | Where | Why it matters |
|---|---|---|
| **CTEs** (multi-stage) | Q3–Q9, Q16, Q33, Q52, Q54 | Readable decomposition of complex logic |
| **Window functions** | LAG (Q11, Q15), RANK/ROW_NUMBER (Q10, Q23, Q43), running SUM (Q23), partitioned AVG (Q44) | Period-over-period, ranking, Pareto, peer comparison |
| **Anti-joins** (`LEFT JOIN … IS NULL`) | Q4 dead stock | Finding what *isn't* there — SKUs with no sales |
| **`FILTER` aggregates** | Q2, Q12, Q25, Q52 | Conditional counts without CASE clutter |
| **Correlated / scalar subqueries** | latest-snapshot pattern, Q45 quadrant splits | Point-in-time and threshold logic |
| **Multi-fact joins** | Q29, Q31 (returns↔sales↔PO) | Cross-process insight (supplier → stock-out) |
| **UNION for signed flows** | Q38 net transfer | Elegant in/out netting |
| **`NULLIF` guards** | throughout | Division-by-zero safety in production |

---

## 4. Performance optimisation

The schema and queries are built for scale, not just correctness:

- **Range partitioning** on `fact_inventory_snapshot` by month → queries prune to relevant partitions; old months drop cheaply (retention).
- **BRIN indexes** on the append-only, date-ordered facts (`snapshot_date_key`, `date_key`) → a fraction of a B-tree's size, ideal for time-range scans.
- **Partial index** `WHERE is_stockout_flag` → exception queries scan a tiny subset.
- **Composite index** `(location_key, product_key, snapshot_date_key)` matches the dominant inventory access path.
- **Materialised `mv_executive_kpis`** → the executive card loads instantly instead of re-scanning facts on every open; refreshed by `usp_refresh_analytics()` at end of load.
- **Latest-snapshot subquery pattern** (`WHERE snapshot_date_key = (SELECT MAX(...))`) → avoids scanning history for "current position" questions.
- **`ANALYZE` after bulk load** → keeps the planner's statistics honest.

A reviewer's likely question — *"how does this hold up at 25M snapshot rows?"* — is answered by partition pruning + BRIN + the materialised summary, all present in the DDL.

---

## 5. Views & stored logic

Five **analytical views** encapsulate logic so it isn't re-implemented in every query or in Power BI:
`vw_sales_enriched`, `vw_current_inventory`, `vw_supplier_scorecard`, `vw_reorder_worklist`, `vw_dead_stock`.

Two **stored routines** automate the operationally important bits:
- `fn_create_snapshot_partition(year, month)` — provisions next month's partition so nightly loads never hit the default partition.
- `usp_refresh_analytics()` — refreshes planner stats and the executive materialised view at the end of each load.

This is the line between "wrote some queries" and "built a maintainable data product."

---

## 6. Validation (executed, not asserted)

All SQL logic was run against the generated dataset (DuckDB used as an ANSI-SQL executor; the delivered SQL targets PostgreSQL). Results:

| Check | Result |
|---|---|
| Business queries executing successfully | **54 / 54** |
| Analytical views compiling & returning rows | **5 / 5** |
| Worst-OTIF suppliers | all **Bronze tier** (engineered reliability confirmed end-to-end) |
| Dead-stock view vs Q4 | consistent (**73 SKUs**) |
| Executive scorecard (demo slice) | $10.4M revenue, 47% gross margin |

Two defects were caught and fixed during validation, both genuine SQL-correctness issues (not dialect quirks):
1. **Q44** used a window function inside `WHERE` — illegal in PostgreSQL too; refactored to compute the region average in a CTE, then filter.
2. **Q23** (Pareto sampler) returned zero rows due to an over-clever self-referencing `IN`; simplified to a direct modulo sample of ranks.

> PostgreSQL-specific DDL (partitioning, BRIN, materialised views, `plpgsql` procedures) is written to the Postgres target and is not exercised by the ANSI executor; it follows standard PG 15 syntax.

---

## 7. Interview talking points this section earns

- *"I solved 54 real business questions in SQL and executed every one against the data."*
- *"Inventory is semi-additive, so the snapshot is a periodic-snapshot fact and I never sum on-hand across dates."*
- *"I partitioned the snapshot by month and used BRIN indexes because it's append-only and time-ordered."*
- *"I caught two bugs in my own query set during validation — here's what they were and how I fixed them."*

---

*End of SQL Development v1.0.*
