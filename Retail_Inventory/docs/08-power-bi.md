# Power BI
## Retail Inventory Intelligence Platform (RIIP)

| Field | Value |
|---|---|
| **Document** | Power BI Build Specification |
| **Version** | 1.0 |
| **Date** | 26 July 2026 |
| **Depends on** | Database Design v1.0, DAX library, theme JSON |
| **Assets** | `powerbi/measures/dax_measures.md`, `powerbi/theme/riip_theme.json`, `powerbi/mockups/executive_overview.html` |

---

## 1. What this section delivers

A Power BI `.pbix` is a binary that can't be generated outside Power BI Desktop, so this section delivers everything needed to **build it and defend every choice**: the complete page-by-page design, the full DAX library (44 measures, each explained), the theme JSON, the RLS design, and a **working HTML mockup of the Executive Overview** rendered from the real pipeline numbers so the intended design is visible, not just described.

Open `powerbi/mockups/executive_overview.html` in a browser to see the flagship page.

---

## 2. Semantic model

- **Star schema** connected exactly as designed in Section 3: 7 dimensions filter 5 facts, single-direction relationships, no bidirectional filters.
- **`dim_date` marked as the date table** — required for all time-intelligence measures.
- **Role-playing dates** (order/expected/received on POs) handled with inactive relationships + `USERELATIONSHIP`.
- **Measures** on a hidden `_Measures` table, organised into display folders (Sales, Time Intelligence, Inventory Health, Supplier, Store & Product, Exceptions).
- **Storage mode:** Import, with **incremental refresh** on `fact_inventory_snapshot` and `fact_sales` partitioned by date — matching the warehouse partitioning.

---

## 3. The nine pages

Each page targets a stakeholder and answers specific BRD questions.

| # | Page | Audience | Key visuals | Headline measures |
|---|---|---|---|---|
| 1 | **Executive Overview** | COO / CFO | 6 KPI cards, revenue by category, region donut, revenue trend, OTIF by tier, Smart Narrative, exceptions | Revenue, Margin %, Inventory Value, Turnover, Stock-out Rate, OTIF % |
| 2 | **Inventory Health** | Supply Chain | Turnover & DIO by category, GMROI scatter, aged-inventory bar, dead-stock table, days-of-supply matrix | Turnover, DIO, GMROI, Dead Stock Value |
| 3 | **Sales Performance** | Regional / Exec | Trend with YoY, category tree, MoM growth, promo vs non-promo, weekend lift | Revenue, Revenue YoY %, Revenue MoM % |
| 4 | **Warehouse Performance** | DC Managers | Holding cost by DC, capacity utilisation, transfer routes (Sankey/matrix), inflow/outflow | Inventory Value, Annual Carrying Cost |
| 5 | **Supplier Analytics** | Purchasing | OTIF ranking, lead-time avg vs variability scatter, fill-rate table, supplier scorecard, spend | OTIF %, Avg Lead Time, Lead Time Variability, Supplier Score |
| 6 | **Store Performance** | Regional Mgrs | Store league table, store-vs-region variance, margin map, return rate | Revenue Rank, Store vs Region Avg %, Return Rate |
| 7 | **Product Performance** | Merchandising | ABC/XYZ matrix, performance quadrant, declining-products list, top/bottom SKUs | GMROI, Category Revenue Share, Return Rate |
| 8 | **Forecasting** | Supply Chain | Revenue trend with Power BI analytics-line forecast, 3-month rolling avg, seasonality by month | Revenue 3M Rolling Avg, Revenue forecast (built-in) |
| 9 | **Exceptions** | Purchasing / Ops | Reorder-now table, current stock-outs, overstock candidates, late suppliers — all action-oriented | Reorder Now Count, Stock-out SKU Count, Estimated Lost Sales |

**Page 8 forecasting** uses Power BI's built-in analytics forecast line on the monthly trend (exponential smoothing) plus the rolling-average measure — an honest, no-ML baseline. True ML forecasting is the Fabric Phase-2 item, kept out of the core deliberately.

---

## 4. Interactivity

**Navigation.** A left nav rail (page-navigator buttons) on every page, styled to the theme — the same rail shown in the mockup. Selected page is highlighted; one click moves between pages, no Power BI tab-hunting.

**Bookmarks.** Used for: (a) a collapsible filter panel (show/hide), (b) chart-vs-table toggles on Sales and Supplier pages, and (c) a "reset filters" bookmark. Bookmarks are wired to buttons, not left in the pane.

**Drillthrough.** From any category/store/supplier visual, right-click → drillthrough to a detail page filtered to that entity (e.g., click a supplier on page 5 → a supplier detail page showing its POs, lead-time history, and affected SKUs). A back-button (auto-added) returns to source.

**Tooltips.** Custom **report-page tooltips**: hovering a category bar shows a mini-card with that category's revenue, margin %, turnover, and stock-out rate — richer than the default single-value tooltip.

**Smart Narrative.** On the Executive Overview, a Smart Narrative visual auto-summarises the headline numbers and the biggest movers in plain English (the mockup shows the intended wording). It updates with slicers.

**Icons & KPI cards.** KPI cards use conditional colour (green/amber/red) driven by the `Inventory Health Status`-style `SWITCH` measures, with up/down indicators against targets. Icons come from a consistent set (the theme defines the colour semantics).

---

## 5. Mobile layout

Every page gets a **phone layout** in Power BI's mobile authoring view — not the desktop page squeezed, but a re-stacked, single-column arrangement prioritising: the KPI cards first, then the exceptions list, then one hero chart. A regional manager checks stock-outs from the floor; the mobile Exceptions view is built for exactly that.

---

## 6. Theme

`powerbi/theme/riip_theme.json` is a real Power BI theme file: the executive palette (navy `#1F3864`, teal `#2C8C99`, amber accent), semantic good/neutral/bad colours for KPIs, an 8-colour data series, typography classes, and card/border defaults. Importing it makes every visual on-brand without per-visual formatting. The mockup uses the same palette so the built report matches the preview.

---

## 7. Row-Level Security

Two roles (full definitions in the DAX library):
- **`RLS_Region`** — a regional manager sees only their region (`dim_location[region]` filtered via a user-to-region security table).
- **`RLS_Warehouse`** — a DC manager sees only warehouse locations.

Because relationships filter one-way from `dim_location`, filtering that one dimension restricts *every* fact (sales, inventory, transfers) to the allowed scope automatically. Executives get an unrestricted role. RLS is validated with Power BI's "View as role" against a test matrix before publish (mitigating risk R-7 from the BRD).

---

## 8. How to build the `.pbix`

1. Connect Power BI Desktop to PostgreSQL (`dw` schema) via the native connector; import the dimensions and facts.
2. Set relationships per Section 3; mark `dim_date` as the date table.
3. Import the theme JSON (View → Themes → Browse).
4. Create the `_Measures` table; paste each measure from `dax_measures.md` into its display folder.
5. Build the 9 pages per the table above (the mockup is the Executive Overview reference).
6. Add the nav rail, bookmarks, drillthrough pages, and custom tooltips.
7. Author the phone layouts.
8. Define the two RLS roles; test with "View as role."
9. Configure scheduled + incremental refresh; publish.

---

## 9. Reviews

**Senior BI Architect** — The model is a clean star with a marked date table; the semi-additive inventory measures use the closing/average patterns, not naïve SUMs; RLS filters one dimension and lets relationships cascade. *Strengthened:* incremental refresh aligned to the warehouse partitioning, and role-playing dates handled explicitly with `USERELATIONSHIP` rather than duplicated date tables.

**Hiring Manager** — A visible mockup rendered from real numbers plus 44 explained measures is far more convincing than "I made a dashboard." *Strengthened:* every page is mapped to a stakeholder and to specific BRD questions, so the report demonstrably answers requirements rather than showing charts for their own sake.

**Freelancing** — This spec *is* the paid artifact of a Power BI engagement — a client can approve the design before a single visual is built. *Strengthened:* the theme JSON and measure library are drop-in reusable assets across future dashboards.

---

## 10. Interview talking points

- *"Inventory is semi-additive, so `Inventory Value` takes the closing balance with `LASTNONBLANK`, and turnover divides COGS by the *average of daily* inventory — never a SUM across dates."*
- *"RLS filters one dimension; single-direction relationships cascade it to every fact."*
- *"GMROI, not just turnover — margin per dollar of inventory is the metric retailers actually run on."*
- *"Forecasting is an honest exponential-smoothing baseline; ML is a scoped Phase-2 upgrade, not vaporware."*

---

*End of Power BI v1.0.*
