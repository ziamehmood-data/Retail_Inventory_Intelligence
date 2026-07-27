# Installation Guide

## Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Python | 3.10+ | data generation, ETL, analysis |
| PostgreSQL | 15+ | data warehouse |
| Power BI Desktop | latest | dashboard (Windows) |
| Excel | 2016+ | workbooks (optional) |
| Git | any | clone the repo |

## 1. Clone and install

```bash
git clone https://github.com/<you>/retail-inventory-intelligence-platform.git
cd retail-inventory-intelligence-platform
pip install -r requirements.txt
```

## 2. Generate the data

```bash
# fast demo (a few seconds)
python -m src.generator.run

# full 5-year spec (larger; see config.yaml to tune volume)
python -m src.generator.run --profile full
```

Raw extracts land in `data/raw/`; 500-row previews in `data/samples/`.

## 3. Run the Python pipeline

```bash
python -m src.quality.quality_report   # clean → validate → DQ report
python -m src.analysis.eda             # EDA + figures
python -m src.analysis.kpi_report      # automated KPI report
```

Outputs land in `reports/`. Cleaned, warehouse-ready CSVs land in `data/processed/`.

## 4. Build the PostgreSQL warehouse

```bash
# create the database, then run the scripts in order:
psql -d riip -f sql/00_database_setup/00_create_database.sql
psql -d riip -f sql/01_schema/01_dimensions.sql
psql -d riip -f sql/01_schema/02_facts.sql
psql -d riip -f sql/02_constraints_indexes/01_foreign_keys.sql
psql -d riip -f sql/02_constraints_indexes/02_indexes.sql
psql -d riip -f sql/03_views/01_analytical_views.sql
psql -d riip -f sql/04_procedures/01_functions_procedures.sql
```

Load the cleaned CSVs from `data/processed/` into the matching `dw` tables (e.g. via `\copy`), then run the 54 business queries in `sql/05_business_queries/`.

## 5. Build the dashboard

Open Power BI Desktop, connect to the `dw` schema, import the theme
(`powerbi/theme/riip_theme.json`) and the measures (`powerbi/measures/dax_measures.md`),
and follow the page-by-page build in [08-power-bi.md](08-power-bi.md).

## Troubleshooting

- **Import errors running modules** — run from the repo root so `python -m src.…` resolves.
- **Snapshot too large at full scale** — lower `avg_locations_per_product` or `daily_snapshot_months` in `config/config.yaml`.
- **Different numbers than the docs** — confirm `seed: 42` and `active_profile` in the config.
