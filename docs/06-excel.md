# Excel
## Retail Inventory Intelligence Platform (RIIP)

| Field | Value |
|---|---|
| **Document** | Excel Deliverables |
| **Version** | 1.0 |
| **Date** | 25 July 2026 |
| **Depends on** | Synthetic Dataset v1.0 |
| **Files** | `excel/01_raw_data_workbook.xlsx`, `excel/02_cleaning_workbook.xlsx`, `excel/03_business_analysis_workbook.xlsx` |
| **Validation** | Recalculated in LibreOffice — **0 formula errors** across all workbooks |

---

## 1. Why Excel is still in the stack

Power BI is the executive layer, but finance and purchasing live in Excel. A credible BI engagement meets them there. The three workbooks mirror the warehouse pipeline in miniature — **raw → cleansed → analysed** — so a non-technical stakeholder can see the whole journey in a tool they already trust.

---

## 2. The three workbooks

### `01_raw_data_workbook.xlsx` — the untouched source
Raw extracts landed as-is: a sales sheet **including the deliberate data-quality issues** (missing prices, duplicates), plus product, supplier, location, and purchase-order dimension sheets. Missing prices are highlighted with conditional formatting so a reviewer can *see* the dirt. This is the input to the cleaning workbook.

### `02_cleaning_workbook.xlsx` — detect and fix, with formulas
The cleaning is done with real formulas, not pre-cleaned values:
- **Issue_Flags** — `ISBLANK` flags missing prices; `COUNTIFS` detects duplicate rows; conditional formatting colours each issue type.
- **Cleaning_Summary** — `COUNTBLANK` and `SUMPRODUCT` quantify the issues (total rows, missing, duplicates, rows passing).
- **Sales_Clean** — an imputation formula (`IF(ISBLANK(price), catalog_price, price)`) repairs missing prices; imputed rows are highlighted green.
- **PowerQuery_Steps** — the equivalent **Power Query (M) script** with its applied-steps list, so the same cleaning is reproducible in the Power BI / Excel query engine, not just in cell formulas.

### `03_business_analysis_workbook.xlsx` — the analysis layer
- **Data / PO_Data** — enriched flat tables (sales joined to category/region/month; POs joined to supplier tier).
- **Four summary sheets** — revenue & margin by category, revenue by region, revenue by month, and OTIF % by supplier tier — all built with `SUMIFS` / `COUNTIFS` referencing the Data sheets (they recalculate when the data changes).
- **Dashboard** — five formula-driven KPI cards (Revenue, Gross Margin, Margin %, Units, OTIF %), a region-filter data-validation dropdown, and four native charts (bar, line, pie, bar).
- **Conditional formatting** — data bars on category revenue, a red-yellow-green colour scale on margin %, and a traffic-light icon set on OTIF %.

---

## 3. Power Query integration

Cell formulas are the visible layer; **Power Query is the repeatable ETL layer**. The `PowerQuery_Steps` sheet documents the M script that: promotes headers, enforces types, **removes duplicates**, merges the product dimension for a catalog price, and **imputes missing `unit_price`**. Because Power Query connects to the same PostgreSQL warehouse and folds its transforms back to the database, the Excel analysis and the Power BI model draw from one governed source — no divergent spreadsheet logic. This is the mechanism that keeps Excel a *consumer* of the single source of truth rather than a competing one.

---

## 4. A note on PivotTables (honest and practical)

The summary sheets are built with `SUMIFS`/`COUNTIFS` rather than PivotTable objects because programmatic tools can't author live pivot caches reliably. In practice this is a feature, not a limitation: the formula-driven summaries **recalculate automatically** and drive the charts directly. For a stakeholder who prefers native pivots, the enriched **Data** sheet is pivot-ready — *Insert → PivotTable → PivotChart* on that range reproduces any of the summaries interactively in two clicks. Both paths, formula and pivot, read the same enriched table.

---

## 5. Validation

Every workbook containing formulas was recalculated in LibreOffice:

| Workbook | Formulas | Errors |
|---|---|---|
| 02_cleaning_workbook | ~23,900 | **0** |
| 03_business_analysis_workbook | 90 | **0** |

Recalculated KPI values are consistent with the SQL section — e.g., **OTIF by tier came out Gold 83% > Silver 68% > Bronze 51%**, the same engineered supplier-reliability signal that appeared in the database analytics. The numbers agree across SQL and Excel because both read the same generated data.

---

## 6. Reviews

**Senior BI Architect** — Cleaning is done with auditable formulas and a documented Power Query script, not silently pre-cleaned data; Excel consumes the warehouse rather than forking it. *Strengthened:* one formula error (a summary cell referencing a text label) was caught by the mandatory recalc and fixed — nothing ships with `#VALUE!`.

**Hiring Manager** — Three workbooks that show the raw→clean→analyse arc, with conditional formatting and a KPI dashboard, demonstrate real spreadsheet craft beyond "I put data in cells." *Strengthened:* every KPI is a live formula, so a reviewer editing the data sees the dashboard move.

**Freelancing** — "Clean my messy sales spreadsheet and build me a dashboard" is one of the most common freelance requests; these three workbooks are a directly reusable template.

---

*End of Excel v1.0.*
