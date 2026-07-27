# Business Requirements Document (BRD)
## Retail Inventory Intelligence Platform

| Field | Value |
|---|---|
| **Document** | Business Requirements Document |
| **Project** | Retail Inventory Intelligence Platform (RIIP) |
| **Client** | Meridian Retail Group *(fictional client — portfolio case study, synthetic data)* |
| **Prepared by** | *[Your Name]* — BI Consultant |
| **Version** | 1.0 |
| **Date** | 25 July 2026 |
| **Status** | Draft for stakeholder sign-off |
| **Classification** | Internal / Portfolio |

> **Case-study note.** This document describes a *simulated* consulting engagement for a fictional retailer, built on synthetic data. It is written to production standards so that every artifact — model, SQL, dashboard, documentation — is defensible in an interview. Where numbers describe the "current state," they are illustrative baselines to be validated, not audited figures.

---

## 1. Executive Summary

Meridian Retail Group is a mid-market omnichannel retailer operating **120 stores** across **4 sales regions**, supplied through **8 distribution centres (DCs)** and **250 suppliers**, carrying roughly **25,000 active SKUs** across **12 product categories**. Annual revenue is in the ~$1.1B range.

Meridian's growth has outpaced its reporting. Inventory decisions — what to reorder, what to mark down, which suppliers to trust, where to move stock — are made from **manually assembled spreadsheets** that are days old by the time they reach a decision-maker. The business has no single, trusted view of inventory, and no executive dashboard. The symptoms are familiar and expensive: **stock-outs on fast movers, capital trapped in overstock and dead inventory, revenue leakage the finance team can't fully quantify, and supplier performance that is discussed anecdotally rather than measured.**

The **Retail Inventory Intelligence Platform (RIIP)** delivers a centralised, governed BI solution on PostgreSQL and Power BI. It gives each stakeholder group — executives, regional managers, warehouse managers, purchasing, and finance — a role-appropriate, decision-ready view of inventory health, sales performance, supplier reliability, and exceptions that need action *today*.

The engagement is scoped as an **analytics and decision-support platform**, not a replenishment engine. RIIP will *tell Meridian what to do*; the ERP and buyers execute. This boundary keeps the project deliverable, auditable, and low-risk, while still targeting the working-capital and margin outcomes management cares about.

**Targeted outcomes (12 months post-adoption):**

- Reduce stock-out rate on A-class items by **30–40%**.
- Release **8–12%** of working capital currently locked in excess and dead inventory.
- Cut the inventory reporting cycle from **~3 days of manual effort to a daily automated refresh**.
- Establish OTIF (On-Time-In-Full) as the standard, measured basis for supplier reviews.

---

## 2. Business Objectives

| # | Objective | Why it matters | Primary KPI(s) |
|---|---|---|---|
| BO-1 | Reduce stock-outs on high-value / high-velocity items | Stock-outs on A-class SKUs are direct lost revenue and erode customer trust | In-Stock Rate, Stock-out Rate, Estimated Lost Sales |
| BO-2 | Release working capital from excess & dead inventory | Overstock and dead stock are cash sitting on shelves; freeing it funds growth | Dead Stock %, Excess Stock %, Inventory Carrying Cost |
| BO-3 | Improve inventory velocity and return on inventory | Faster turns and higher GMROI mean the same capital earns more margin | Inventory Turnover, DIO, GMROI |
| BO-4 | Make supplier performance measurable and comparable | Late/incomplete deliveries drive both stock-outs *and* overstock; today it's anecdotal | OTIF, Lead-Time Variability, Supplier Defect Rate |
| BO-5 | Quantify and reduce revenue leakage | Leakage (shrinkage, markdown, stock-out lost sales) is real but currently invisible | Shrinkage %, Markdown %, Estimated Lost Sales |
| BO-6 | Replace manual reporting with a governed daily platform | Frees analysts, removes version conflicts, creates one source of truth | Reporting Cycle Time, Refresh Success Rate, Adoption |
| BO-7 | Give each role a decision-ready, secure view | Executives, regions, DCs and buyers need different lenses on the same trusted data | Dashboard Adoption (MAU), RLS coverage |

---

## 3. Current State & Problems

Meridian's core problem is not a lack of data — the ERP and POS systems capture it — but a lack of a **trusted, timely, single view**. Reporting is assembled by hand in Excel from partial extracts, which produces the following pain points:

| Problem | Business impact | Root symptom (hypothesis) |
|---|---|---|
| Frequent stock-outs | Lost sales, substitution, customer churn | Reorder points not tuned to demand; supplier lead-time variability |
| Overstock inventory | Working capital tied up; markdown pressure | Over-ordering to hedge against stock-outs; poor demand visibility |
| Dead inventory | Capital + storage cost with no return | No systematic aging/no-movement flagging |
| Revenue leakage | Margin erosion that finance can't fully explain | Shrinkage, unplanned markdowns, stock-out lost sales uncaptured |
| Poor supplier performance | Unreliable inbound → both stock-outs and overstock | No OTIF/lead-time measurement; supplier reviews are anecdotal |
| Slow inventory turnover | Low GMROI; aging risk | Assortment and replenishment not managed by velocity class |
| Manual reporting | ~3 days/cycle of analyst effort; stale, conflicting numbers | No central model; spreadsheet sprawl |
| No executive dashboard | Decisions made on gut feel or late data | No governed semantic layer or BI front end |

> These are stated as **hypotheses to be confirmed by the data** in the analytics phase (Section 9). A consultant frames current-state pain as testable, not asserted.

---

## 4. Scope

### 4.1 In Scope

- A governed **PostgreSQL data warehouse** (star schema) covering products, suppliers, stores, warehouses, employees, customers (lightweight), inventory, sales, purchases, returns, shipments, stock transfers, and a **daily inventory snapshot**.
- **ETL / transformation** using Power Query and Python (Pandas) for cleaning, validation, and load.
- A **Power BI semantic model** with documented DAX measures and **Row-Level Security** by region and role.
- **Nine analytical dashboard pages** (see Functional Requirements), with navigation, bookmarks, tooltips, drillthrough, and a mobile layout.
- **Inventory classification** (ABC by revenue/velocity; XYZ by demand variability) to drive prioritisation.
- **Exception detection** (stock-out risk, overstock, dead stock, late suppliers) surfaced as an actionable dashboard.
- **Documentation suite** and a **GitHub-ready repository**.
- A basic **demand/reorder signal** (reorder point + safety stock indicators) as a decision aid.

### 4.2 Out of Scope (deliberately)

| Excluded | Rationale |
|---|---|
| Customer segmentation, CLV, marketing/loyalty analytics | This is an *inventory* platform. A lightweight customer dimension supports demand analysis; full customer analytics is a separate domain and would dilute focus. |
| Automated replenishment / PO execution | RIIP *recommends*; the ERP and buyers *execute*. Keeps the project decision-support, not operational-control, which is lower-risk and deliverable. |
| Real-time / streaming inventory | Daily batch meets every stated business question. Real-time is a costly Phase 2 upgrade, listed under Future Enhancements. |
| Full financial GL / P&L reporting | Only inventory-relevant financials (COGS, carrying cost, margin) are in scope. |
| Price optimisation / promo planning | Advanced pricing science is a distinct engagement; RIIP surfaces margin leakage but does not set prices. |
| HR / workforce analytics | Employee dimension exists only to attribute sales/transactions, not for performance management. |
| E-commerce clickstream / web analytics | Out of the inventory-decision scope. |

> **Consulting note:** the *Out of Scope* section is where a BRD earns credibility. Scope creep is the number-one killer of BI projects; explicitly naming what we are *not* building — and why — is a sign of a mature engagement, not a limitation.

---

## 5. Key Business Questions

These are the executive-level questions the platform must answer. Each maps to a stakeholder and a KPI. (The full library of 50+ operational questions is delivered as SQL in Section 5 of the project.)

| # | Business question | Stakeholder | KPI lens |
|---|---|---|---|
| Q1 | Which products are at risk of stock-out in the next lead-time window? | Purchasing, Store Mgrs | Stock-out Risk, Days of Supply |
| Q2 | Where is our capital trapped in overstock and dead inventory? | Finance, Exec | Excess %, Dead Stock %, Carrying Cost |
| Q3 | How fast is inventory turning, by category / region / store? | Exec, Regional Mgrs | Turnover, DIO |
| Q4 | Which SKUs earn the most margin per dollar of inventory? | Exec, Merchandising | GMROI |
| Q5 | Which suppliers are reliable, and which cause our stock problems? | Purchasing | OTIF, Lead-Time Variability, Defect Rate |
| Q6 | How much revenue are we losing to stock-outs, shrinkage and markdowns? | Finance, Exec | Estimated Lost Sales, Shrinkage %, Markdown % |
| Q7 | Which stores and regions over/under-perform on sales and inventory efficiency? | Regional Mgrs | Revenue, GMROI, Turnover |
| Q8 | Which products have declining sales and should be reviewed for exit? | Merchandising | Sales Trend, Sell-Through, Aging |
| Q9 | Which warehouse carries the highest holding cost, and is stock in the right place? | Warehouse Mgrs, Supply Chain | Holding Cost, Transfer Volume |
| Q10 | What should we reorder now, and how much? | Purchasing | Reorder Point, Safety Stock, Days of Supply |
| Q11 | What is our A/B/C mix, and are we managing each class appropriately? | Merchandising, Exec | ABC/XYZ Classification |
| Q12 | Are returns concentrated in specific products, suppliers or stores? | Quality, Purchasing | Return Rate |

---

## 6. KPIs & Metric Definitions

Grouped by theme. Every KPI has a **formula**, an **owner**, and a **target direction** so the semantic model and dashboards have an unambiguous definition to implement.

### 6.1 Inventory Health

| KPI | Definition / Formula | Owner | Target |
|---|---|---|---|
| Inventory Turnover | COGS ÷ Average Inventory Value (period) | Supply Chain | ↑ |
| Days Inventory Outstanding (DIO) | 365 ÷ Inventory Turnover | Supply Chain | ↓ |
| In-Stock Rate | Days in stock ÷ Total days (SKU-store) | Purchasing | ↑ |
| Stock-out Rate | 1 − In-Stock Rate | Purchasing | ↓ |
| Sell-Through Rate | Units Sold ÷ Units Received | Merchandising | ↑ (context) |
| **GMROI** | Gross Margin $ ÷ Average Inventory Cost | Merchandising | ↑ |
| Dead Stock % | Value of SKUs with 0 movement > 180 days ÷ Total inventory value | Finance | ↓ |
| Excess / Overstock % | Value of on-hand above target (vs demand) ÷ Total inventory value | Finance | ↓ |
| Inventory Carrying Cost | Avg Inventory Value × Carrying Cost Rate (capital + storage + risk) | Finance | ↓ |
| Aged Inventory Buckets | Inventory value by age band (0–30 / 31–60 / 61–90 / 91–180 / 180+) | Supply Chain | ↓ tail |
| Days of Supply | On-hand units ÷ Average daily demand | Purchasing | tuned |

### 6.2 Sales & Demand

| KPI | Definition / Formula | Owner | Target |
|---|---|---|---|
| Net Revenue | Gross sales − returns − discounts | Exec | ↑ |
| Gross Margin % | (Revenue − COGS) ÷ Revenue | Finance | ↑ |
| Estimated Lost Sales | Stock-out days × avg daily demand × price (unrealised) | Finance | ↓ |
| Return Rate | Returned units ÷ Units sold | Quality | ↓ |
| Sales Trend / Velocity | Rolling unit sales slope by SKU | Merchandising | monitor |

### 6.3 Supplier Performance

| KPI | Definition / Formula | Owner | Target |
|---|---|---|---|
| OTIF (On-Time-In-Full) | POs delivered on time **and** complete ÷ Total POs | Purchasing | ↑ |
| Average Lead Time | Mean days from PO to receipt | Purchasing | ↓ |
| Lead-Time Variability | Std dev of lead time (reliability, not just speed) | Purchasing | ↓ |
| Supplier Defect / Return Rate | Returned/rejected units ÷ Units received | Quality | ↓ |
| PO Fill Rate | Units received ÷ Units ordered | Purchasing | ↑ |

### 6.4 Warehouse & Network

| KPI | Definition / Formula | Owner | Target |
|---|---|---|---|
| Holding Cost by DC | Carrying cost allocated per warehouse | Warehouse Mgr | ↓ |
| Stock Transfer Volume/Cost | Units & cost of inter-DC/store transfers | Supply Chain | monitor |
| Inventory Balance Fit | On-hand vs demand alignment across the network | Supply Chain | ↑ |

### 6.5 Project / Adoption Success Metrics *(distinct from business KPIs)*

| Metric | Baseline | Target |
|---|---|---|
| Reporting cycle time | ~3 days manual | Daily automated refresh |
| Dashboard adoption (monthly active users) | 0 | ≥ 70% of target stakeholders |
| Refresh success rate | n/a | ≥ 99% |
| Data freshness | Days old | ≤ 24 hours |
| Data quality pass rate (validation suite) | Unknown | ≥ 99% of records passing checks |

> **Why separate business KPIs from project success metrics?** Business KPIs measure *the business*; success metrics measure *whether the BI solution worked*. Conflating them is a classic BRD mistake — a beautiful dashboard nobody opens is a failed project even if turnover improves for unrelated reasons.

---

## 7. Stakeholders (RACI)

| Stakeholder | Interest | R | A | C | I |
|---|---|:-:|:-:|:-:|:-:|
| COO / Executive Sponsor | Overall inventory & margin health | | ✔ | ✔ | |
| CFO / Finance | Working capital, carrying cost, leakage | | | ✔ | ✔ |
| Supply Chain Director | Turnover, network balance, forecasting | ✔ | | ✔ | |
| Purchasing / Procurement | Reorder decisions, supplier performance | ✔ | | ✔ | |
| Warehouse / DC Managers | Holding cost, transfers, DC-level stock | ✔ | | | ✔ |
| Regional Managers | Regional sales & inventory efficiency | | | ✔ | ✔ |
| Store Managers | Store stock availability | | | | ✔ |
| Merchandising | Assortment, ABC mix, exits, GMROI | ✔ | | ✔ | |
| BI / Data Team | Build, model, govern, maintain | ✔ | ✔ | | |

*(R = Responsible, A = Accountable, C = Consulted, I = Informed)*

---

## 8. Functional Requirements

| ID | Requirement |
|---|---|
| FR-1 | Ingest data from source systems into a PostgreSQL warehouse modelled as a star schema. |
| FR-2 | Maintain a **daily inventory snapshot** fact table to support point-in-time and trend analysis of on-hand stock. |
| FR-3 | Cleanse, validate and deduplicate source data via Power Query and Python before load. |
| FR-4 | Compute ABC (revenue/velocity) and XYZ (demand variability) classifications per SKU. |
| FR-5 | Expose a governed Power BI semantic model with documented DAX measures for all KPIs in Section 6. |
| FR-6 | Deliver 9 dashboard pages: Executive Overview, Inventory Health, Sales Performance, Warehouse Performance, Supplier Analytics, Store Performance, Product Performance, Forecasting, Exceptions. |
| FR-7 | Provide navigation, bookmarks, tooltips, drillthrough, and a phone (mobile) layout. |
| FR-8 | Enforce **Row-Level Security**: regional managers see only their region; DC managers see their DC; executives see all. |
| FR-9 | Surface an **Exceptions dashboard**: stock-out risk, overstock, dead stock, late suppliers — each actionable and filterable. |
| FR-10 | Provide reorder-point and safety-stock **indicators** as a purchasing decision aid (recommendation only). |
| FR-11 | Support export of key views and a Smart Narrative summary on the executive page. |
| FR-12 | Refresh daily on a schedule, with load success/failure logging. |

---

## 9. Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-1 | Performance | Report pages render in < 5 seconds on the published model at target data volume. |
| NFR-2 | Data volume | Model designed to scale to ~2–3 years of daily snapshots across 25k SKUs × 120 stores without redesign. |
| NFR-3 | Refresh SLA | Daily refresh completes and is available by 06:00 local; ≥ 99% success rate. |
| NFR-4 | Security | RLS by region/role; no real PII in the dataset; least-privilege DB access. |
| NFR-5 | Data quality | ≥ 99% of records pass the automated validation suite; failures logged and reported. |
| NFR-6 | Maintainability | Naming conventions, documented model, version-controlled SQL/DAX in Git. |
| NFR-7 | Availability | Solution tolerates a failed refresh by serving last-good data with a freshness indicator. |
| NFR-8 | Portability | Warehouse is standard PostgreSQL; no proprietary lock-in in the data layer. |
| NFR-9 | Documentation | Full README, data dictionary, install/user/technical/business guides. |

---

## 10. Assumptions

- Source data is available as periodic extracts (POS, ERP/purchasing, WMS); daily batch is acceptable.
- The dataset is **synthetic** and contains **no real PII**; customer records are anonymised placeholders.
- A single reporting currency and a single time zone at the reporting layer.
- Historical depth of **~2–3 years** is sufficient for trend and seasonality analysis.
- Carrying cost rate, safety-stock service levels, and dead-stock thresholds (e.g., 180 days) are agreed with Finance/Supply Chain and configurable.
- Power BI (Pro or Premium/Fabric capacity) and a PostgreSQL instance are available for deployment.

---

## 11. Risks & Mitigations

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|:-:|:-:|---|
| R-1 | **Scope creep** across 12 deliverable areas | High | High | Phased delivery; strict Out-of-Scope; change-control on additions. |
| R-2 | Daily snapshot table growth degrades performance | Med | High | Partitioning, incremental refresh, aggregation tables, retention policy. |
| R-3 | Source data quality issues (nulls, dupes, orphan keys) | High | Med | Automated validation suite (Python) + referential integrity in DB. |
| R-4 | Low user adoption; dashboards ignored | Med | High | Role-based design, training, exception-driven "action" pages, adoption metric. |
| R-5 | Semi-additive inventory measures summed incorrectly | Med | High | Snapshot grain + explicit DAX patterns (LASTNONBLANK etc.); documented. |
| R-6 | Reorder signals mistaken for automated replenishment | Med | Med | Clear "recommendation only" framing; execution stays in ERP. |
| R-7 | RLS misconfiguration exposes cross-region data | Low | High | RLS test matrix; validate each role before release. |
| R-8 | Estimated Lost Sales misread as booked revenue | Med | Med | Label as *estimated/unrealised*; document methodology and caveats. |

---

## 12. Future Enhancements (Phase 2+)

- **ML demand forecasting** (e.g., time-series/gradient-boosted models) via Microsoft Fabric, replacing rule-based signals.
- **Automated replenishment integration** — push recommended POs into the ERP.
- **Real-time / near-real-time** inventory via streaming for high-velocity categories.
- **Price & markdown optimisation** to attack margin leakage directly.
- **Supplier scorecards & alerts** delivered to procurement via email/Teams.
- **What-if scenario analysis** (service-level vs carrying-cost trade-offs).
- **Demand sensing** using external signals (weather, promotions, seasonality).

---

## 13. Sign-off

| Role | Name | Signature | Date |
|---|---|---|---|
| Executive Sponsor (COO) | | | |
| Finance (CFO) | | | |
| Supply Chain Director | | | |
| BI Lead / Consultant | | | |

---

*End of Business Requirements Document v1.0.*
