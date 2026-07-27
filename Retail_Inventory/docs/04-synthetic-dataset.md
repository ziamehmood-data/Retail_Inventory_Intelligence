# Synthetic Dataset
## Retail Inventory Intelligence Platform (RIIP)

| Field | Value |
|---|---|
| **Document** | Synthetic Dataset Design & Generator |
| **Project** | Retail Inventory Intelligence Platform |
| **Version** | 1.0 |
| **Date** | 25 July 2026 |
| **Depends on** | Database Design v1.0 |
| **Code** | `config/config.yaml`, `src/generator/generator.py`, `src/generator/run.py` |

---

## 1. Design Philosophy: Simulated, Not Faked

The single most important decision in this section: **the fact tables are the output of a day-by-day inventory simulation, not independently randomised columns.**

For every stocked `(product, location)` pair, the generator rolls a ledger forward one day at a time:

```
on_hand(t) = on_hand(t-1) + receipts(t) - sales(t)
```

- **receipts** arrive from purchase orders whose lead time depends on the supplier's reliability tier,
- **sales** are drawn from a demand model (seasonality × weekend × holiday × promotion), **capped by available stock**,
- when stock falls to the reorder point, a **new PO is placed**.

Because the ledger is real, the business problems in the BRD are **emergent, not scripted**:

| Business problem | How it emerges from the simulation |
|---|---|
| **Stock-outs** | Demand outruns replenishment → `on_hand` hits 0 → `is_stockout_flag` |
| **Overstock** | Low-velocity SKUs over-ordered relative to demand → high `days_of_supply` |
| **Dead stock** | Discontinued SKUs go dormant (zero demand) but retain stock |
| **Late deliveries** | Bronze-tier suppliers have high `late_probability` and lead-time variance |
| **Seasonality** | Nov/Dec demand ×1.45, summer ×1.15, Jan/Feb ×0.80; weekends ×1.25 |
| **Slow turnover** | The long-tail popularity distribution starves C-class SKUs of movement |
| **Revenue leakage** | Returns, discounts, and stock-out lost sales all fall out of the mechanics |

This is the answer to the interview question *"is your data just `random.randint`?"* — **no, it's a simulation, and here's the ledger equation.**

---

## 2. Generation Order (Foreign-Key Safe)

Dimensions are built before facts, so every fact row references a key that already exists. Referential integrity is guaranteed *by construction* — validated at 0 orphans (Section 6).

```
1. dim_date          (deterministic from date range)
2. dim_product       (50k SKUs; latent popularity drives demand)
3. dim_supplier      (250; reliability tier seeds OTIF spread)
4. dim_location      (120 stores + 8 warehouses, unified)
5. dim_employee      (assigned to stores)
6. dim_customer      (anonymised, no PII)
7. dim_promotion     (campaigns across the 5 years)
   ── linkage ──
8. product → supplier      (sourcing)
9. product → locations     (assortment / stocking breadth)
   ── simulation ──
10. SIMULATE → emits fact_sales, fact_purchase_order, fact_inventory_snapshot
11. fact_returns     (subset of sales)
12. fact_stock_transfer (network rebalancing)
13. ABC classification (post-hoc, by realised revenue → true Pareto)
14. inject documented dirt (raw layer only)
```

---

## 3. Volumes

Two profiles ship in `config.yaml`. **`demo`** runs in seconds on a laptop and is used to prove the pipeline; **`full`** is the locked production spec.

| Table | `demo` | `full` (locked spec) |
|---|---:|---:|
| dim_product | 800 | 50,000 |
| dim_supplier / stores / warehouses | 40 / 8 / 2 | 250 / 120 / 8 |
| dim_employee / dim_customer | 120 / 2,000 | 1,500 / 50,000 |
| dim_promotion | 12 | 120 |
| **fact_sales** | ~40k | **~1.2M** |
| **fact_inventory_snapshot** | ~293k | ~15–25M (after retention) |
| fact_purchase_order | ~4.8k | ~250–400k |
| fact_returns / fact_stock_transfer | ~1.6k / ~730 | hundreds of thousands |

> The `demo` numbers above are the *actual output* of a real run (seed 42), not estimates.

---

## 4. Reproducibility

- **Fixed seed** (`config.seed: 42`) → the exact same dataset every run. Anyone who clones the repo and runs `python -m src.generator.run` gets identical data. This is what makes results in the SQL, Excel, and Power BI sections verifiable.
- **All parameters in `config.yaml`** — volumes, dates, thresholds, dirt rates. Nothing is hard-coded in the scripts.
- **Committed samples** — `data/samples/*.sample.csv` (first 500 rows of every table) are version-controlled so a reviewer sees real data on clone, without generating millions of rows. The large `data/raw/` output is git-ignored.

---

## 5. Scaling to Full Volume

Two mechanisms keep the full 5-year build honest *and* tractable:

**a) Config switch.** Set `active_profile: full` (or `--profile full`). Same code, production volumes.

**b) Snapshot retention (implemented in code).** A naïve daily snapshot of 50k SKUs × ~128 locations × 1,826 days is ~500M+ rows — the R-2 risk from the BRD made real. The generator therefore keeps **daily** snapshots only for the recent `daily_snapshot_months` window and **month-end** snapshots for older history — preserving 5 years of *sales* history while bounding the snapshot fact. This mirrors how real retailers archive inventory history, and it's the same retention the Postgres partitioning strategy (Section 3) is built around.

To run the *full 5-year history* on a modest machine, tune two knobs: lower `avg_locations_per_product` (assortment breadth) and/or `daily_snapshot_months` (daily window). The behaviour stays realistic; only the row count scales.

---

## 6. Validation (proof it behaves like a real business)

Run at `demo` scale, seed 42. These are live outputs, not claims:

| Check | Result | Interpretation |
|---|---|---|
| Orphan foreign keys (sales→product, etc.) | **0** | Referential integrity holds by construction |
| Late-rate by supplier tier | Gold **4.8%** < Silver **18.4%** < Bronze **38.2%** | Engineered reliability flows through to OTIF |
| Dead-stock SKUs (zero sales) | **73 (9%)** | Dormant discontinued stock is detectable |
| Stock-out rate (snapshot at 0 on-hand) | **1.6%** | Emerges when demand outruns replenishment |
| Below-reorder rate | **19.7%** | Reorder policy is actively triggering |
| OTIF rate | **69%** | Realistic; leaves room for supplier improvement stories |
| ABC by revenue | A/B/C = 235/230/335; **A = 80% of revenue from ~30% of SKUs** | True Pareto distribution |
| Injected dirt | 1.00% missing prices, 160 duplicate rows | Cleaning stage has genuine work to do |

The full validation script lives in `src/quality/` (delivered in Section 7 as the Data Quality Report).

---

## 7. Engineering Review — Defects Found & Fixed

Per the review discipline, the Senior BI Architect pass on the *first* run caught two real defects, both fixed before this deliverable:

1. **Supplier reliability wasn't flowing through.** The simulation resolved lead-time tier by a `supplier_key % 3` shortcut instead of each supplier's *assigned* `reliability_tier`, so OTIF-by-tier was scrambled (Bronze appeared more reliable than Silver). Fixed to use the real tier mapping — the numbers above confirm the correct Gold < Silver < Bronze ordering.
2. **No dead stock at demo scale.** Discontinued SKUs still trickle-sold, so the dead-inventory analysis had nothing to find. Fixed by making discontinued SKUs fully dormant (zero demand) while retaining sane reorder sizing — now 9% of SKUs are genuine dead stock.

Documenting the defects and the fix is deliberate: it's honest, and it demonstrates the review loop actually does something rather than rubber-stamping.

---

## 8. How to Run

```bash
pip install -r requirements.txt

# fast demo (seconds) — proves the pipeline
python -m src.generator.run

# full 5-year production dataset
python -m src.generator.run --profile full
```

Outputs land in `data/raw/*.csv`; committed 500-row previews land in `data/samples/`. These raw extracts are the input to the SQL warehouse build (Section 5) and the Python ETL/quality pipeline (Section 7).

---

*End of Synthetic Dataset v1.0.*
