## Python
## Retail Inventory Intelligence Platform (RIIP)

| Field | Value |
|---|---|
| **Document** | Python Layer |
| **Version** | 1.0 |
| **Date** | 26 July 2026 |
| **Depends on** | Synthetic Dataset v1.0, Database Design v1.0 |
| **Status** | All scripts executed against generated data |

---

## 1. The Python layer at a glance

Six scripts form a runnable pipeline. The generator was delivered in Section 4; this section adds cleaning, validation, quality reporting, EDA, and an automated KPI report.

```
src/
├── generator/     (Section 4)  synthetic data simulation
├── etl/clean.py                RAW  -> processed (dedupe, impute, type-coerce)
├── quality/validate.py         referential / uniqueness / domain / business-rule checks
├── quality/quality_report.py   orchestrates clean+validate -> Data Quality Report
└── analysis/
    ├── eda.py                  profiling + 5 figures -> EDA report
    └── kpi_report.py           BRD headline KPIs -> KPI report
```

**Pipeline order:** `clean → validate → quality_report → eda → kpi_report`. Each stage reads the previous stage's output, so the whole thing runs from a clean checkout.

---

## 2. `etl/clean.py` — cleaning

Turns RAW extracts into cleansed, warehouse-ready tables (the staging step). It fixes exactly the defects the generator injects, and — critically — **never mutates raw in place**: it reads `data/raw/`, writes `data/processed/`, so a wrong transform is fixed by re-running, not by repairing data by hand.

Rules on `fact_sales`: remove exact duplicate rows; impute missing `unit_price` from the product catalog; **recompute the price-dependent measures** (`gross`, `net`, `cogs`, `margin`) so nothing is left internally inconsistent after imputation; coerce numeric types. Every action is counted and returned as a cleaning log.

**Live result:** `40,344 → 40,184` rows (160 duplicates removed), **401 missing prices imputed**.

---

## 3. `quality/validate.py` — validation

A suite of checks in four families, each returning a `CheckResult` (violations, pass rate, sample), aggregated by a **gate** that fails if any *critical* check has violations or the overall pass rate drops below 99%.

| Family | Examples |
|---|---|
| Referential integrity | every `product_key` / `location_key` / `supplier_key` in a fact exists in its dimension |
| Uniqueness | `sku` and `product_key` are unique |
| Completeness | `unit_price` has no nulls after cleaning |
| Domain / business rule | `units_sold_qty > 0`, `price ≥ cost`, `on_hand ≥ 0`, **`OTIF = (on-time AND in-full)`**, `received ≤ ordered` |

The OTIF consistency check is the sophisticated one: it recomputes OTIF from its components and asserts the stored flag matches — catching silent logic drift.

**Live result:** **12/12 checks PASS, gate PASSED, 100% pass rate.**

---

## 4. `quality/quality_report.py` — data quality report

Runs clean + validate and writes `reports/data_quality_report.md`: the cleaning actions, the full check table, an "issues requiring attention" section, and an interpretation. This is the artifact a data steward signs off before the warehouse load is trusted — and the answer to *"how do you know your data is good?"*

---

## 5. `analysis/eda.py` — exploratory analysis

Profiles the cleaned data and writes `reports/eda_report.md` plus five figures in `reports/eda/`. The point is to *see* the engineered behaviour before building dashboards:

- **Revenue by month** — the Nov–Dec seasonality peak.
- **Revenue by category** — assortment contribution.
- **Pareto curve** — cumulative revenue by SKU rank, crossing the 80% line (the justification for ABC management).
- **OTIF by supplier tier** — the clean Gold → Silver → Bronze decline, in traffic-light colours.
- **On-hand distribution** — the overstock tail.

These charts double as the "before" evidence that the data is realistic, and as ready-made assets for the README.

---

## 6. `analysis/kpi_report.py` — automated KPI report

The single command that replaces the manual monthly spreadsheet the BRD flagged as a core pain point. Computes the headline KPIs from the metric catalogue and writes `reports/kpi_report.md`.

**Live output (demo dataset):**

| KPI | Value |
|---|---:|
| Total Revenue | $10,413,649 |
| Gross Margin % | 47.0% |
| Current Inventory Value | $2,011,013 |
| Inventory Turnover | 2.72x |
| Days Inventory Outstanding | 134 days |
| GMROI | 2.42 |
| Stock-out Rate | 2.8% |
| Dead-stock % (value) | 7.3% |
| Supplier OTIF % | 69.1% |
| Average Lead Time | 13.0 days |

These numbers are **consistent with the SQL and Excel sections** ($10.4M revenue, 47% margin, ~69% OTIF) because all three read the same generated data — cross-tool agreement is the integrity proof.

---

## 7. Reviews

**Senior BI Architect** — Raw is immutable; cleaning is auditable via the log; validation is a real gate with a critical/non-critical distinction and a pass-rate threshold, not a rubber stamp. *Strengthened:* recomputing price-dependent measures after imputation (so no row is left inconsistent), and a business-rule check that re-derives OTIF rather than trusting the stored flag.

**Hiring Manager** — Executed scripts with real reports and figures beat described scripts. *Strengthened:* a noisy pandas 3.0 deprecation warning was silenced so the output is clean — small, but it's the difference between "runs" and "polished."

**Freelancing** — "Clean my data and give me an automated report" is a packaged, repeatable service; this pipeline is the template, and the DQ report is a professional client-facing artifact.

---

*End of Python v1.0.*
