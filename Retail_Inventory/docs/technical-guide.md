# Technical Guide

For developers extending or maintaining the platform.

## Data flow

```
config.yaml ──► src/generator ──► data/raw/*.csv
                                      │
                          src/etl/clean.py  (dedupe, impute, retype)
                                      │
                                data/processed/*.csv
                          ┌───────────┼───────────────┐
              src/quality/validate.py   PostgreSQL load (dw)
                          │                     │
              reports/data_quality_report.md    ├─ sql/03 views
              src/analysis/{eda,kpi_report}     ├─ sql/04 procedures
                                                └─ Power BI (Power Query → DAX)
```

## Design decisions worth knowing

- **Layered schemas** (`raw`/`staging`/`dw`) — raw is immutable and reloadable;
  the warehouse is denormalised (star) for read performance.
- **Unified `dim_location`** — stores and warehouses share one dimension with a
  `location_type` discriminator, so the snapshot and transfer facts stay clean and
  transfers can role-play source/destination.
- **Three fact types** — transaction (`fact_sales`, `fact_returns`,
  `fact_stock_transfer`), periodic snapshot (`fact_inventory_snapshot`,
  semi-additive), accumulating snapshot (`fact_purchase_order`).
- **Snapshot retention** — daily for a recent window, month-end for older history,
  bounding the largest fact table; mirrored by PostgreSQL monthly partitioning.
- **Semi-additive inventory** — never `SUM` on-hand across dates; SQL uses the
  latest-snapshot pattern, DAX uses `LASTNONBLANK` / average-of-daily patterns.

## Extending the generator

All volumes, dates, thresholds, and the seed live in `config/config.yaml`.
Add a new profile under `profiles:` to change scale. The simulation logic is in
`src/generator/generator.py`; each entity has its own builder, and the day-by-day
loop (`simulate`) emits sales, POs, and snapshots together so they stay coherent.

## Adding a business query

Add it to `sql/05_business_queries/business_questions.sql` with a header comment
(question, value, technique). Keep it ANSI-standard so it runs on PostgreSQL;
validate against the data before committing.

## Adding a DAX measure

Add it to `powerbi/measures/dax_measures.md` under the right display folder with
an explanation. Use `DIVIDE` (never `/`) for ratios, and respect the semi-additive
patterns for anything touching the snapshot.

## Performance notes

- Index the join/filter columns queries actually use; BRIN on the big
  append-only date columns; a partial index for the stock-out exception path.
- Run `ANALYZE` after bulk loads (or call `dw.usp_refresh_analytics()`).
- In Power BI use import mode with incremental refresh on the large facts.

## Testing / CI

Point CI at `src/quality/validate.py` (data gate) and a SQL linter over `sql/`.
The validation gate should block a load when a critical check fails.
