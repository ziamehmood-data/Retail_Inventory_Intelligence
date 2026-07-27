# Career Assets
## Retail Inventory Intelligence Platform (RIIP)

| Field | Value |
|---|---|
| **Document** | Career Assets Pack |
| **Version** | 1.0 |
| **Date** | 26 July 2026 |

> **Honesty first.** Every asset below frames this truthfully as a **portfolio case study built on synthetic data for a fictional retailer**. It is deliberately *not* worded as paid work for a real company — because a discovered exaggeration ends an interview, while a well-built case study, described accurately, impresses. The work is strong enough that it doesn't need inflation.

**Contents:** [Resume](#1-resume-bullet-points) · [LinkedIn](#2-linkedin-project-description) · [GitHub](#3-github-repository-description) · [Recruiter summary](#4-recruiter-friendly-summary) · [Elevator pitch](#5-elevator-pitch-30-seconds) · [5-minute walkthrough](#6-five-minute-interview-explanation) · [30 interview questions](#7-top-30-interview-questions--answers) · [Fiverr](#8-fiverr-service-description) · [Upwork](#9-upwork-portfolio-description) · [Proposal template](#10-client-proposal-template)

---

## 1. Resume bullet points

Pick 3–5. Lead with an action verb; keep the quantified outcomes.

- Designed and built an **end-to-end retail inventory BI platform** (PostgreSQL, Python, SQL, Power BI, DAX) as an in-depth portfolio case study simulating a 120-store, ~$1B retailer.
- Engineered a **reproducible, config-driven synthetic-data pipeline** that simulates inventory day-by-day, generating 5 years of interconnected sales, purchasing, and daily-snapshot data with realistic seasonality, stock-outs, and supplier variability.
- Modelled a **Kimball star schema** (7 dimensions, 5 facts) using all three fact types, with **semi-additive** inventory handling, PostgreSQL **range partitioning**, and **BRIN** indexing for scale.
- Authored **54 production SQL business queries** (CTEs, window functions, anti-joins) — all executed and validated against the data — and **44 documented DAX measures** including GMROI, inventory turnover, and supplier OTIF.
- Built a **gated Python data-quality pipeline** (12 validation checks, blocks bad loads) and a **9-page Power BI executive dashboard** with Row-Level Security, drillthrough, and mobile layouts.
- Produced a **consultant-style analysis** identifying **~$0.7–1.0M in annual opportunity** — ~$729K trapped working capital and ~$1.3M in stock-out-driven lost sales — and traced **42% of stock-outs to a targetable 18% of suppliers**.

---

## 2. LinkedIn project description

*(Featured / Projects section)*

**Retail Inventory Intelligence Platform — End-to-End BI Case Study**

I built a complete Business Intelligence solution for a fictional retailer, end to end, the way a consulting team would deliver it: from a PostgreSQL data warehouse and a Python data-simulation pipeline, through 54 SQL business queries and Excel analysis, to a 9-page Power BI executive dashboard with 44 DAX measures and Row-Level Security.

What I'm most proud of: the data isn't random — it's a **day-by-day inventory simulation**, so stock-outs, dead stock, late deliveries, and seasonality *emerge* from the mechanics and behave like a real business. That let me run a genuine analysis, which surfaced a sharp insight — the retailer was **overstocked and out-of-stock at the same time**, the signature of an undifferentiated inventory policy — and a ~$0.7–1.0M improvement opportunity.

Tech: PostgreSQL · Python (Pandas) · SQL · Power BI · DAX · Power Query · Excel · Git.

🔗 Full project & docs on GitHub: [link]

---

## 3. GitHub repository description

**Short "About" field (with topics):**

> End-to-end retail inventory BI platform — PostgreSQL warehouse, Python inventory simulation, 54 SQL queries, and a 9-page Power BI dashboard. Portfolio case study on synthetic data.

**Topics:** `business-intelligence` `power-bi` `sql` `postgresql` `python` `data-engineering` `dax` `data-warehouse` `dimensional-modeling` `retail-analytics` `etl` `data-analytics`

---

## 4. Recruiter-friendly summary

*(For a non-technical reader — a recruiter or hiring manager's first screen.)*

This project is a full Business Intelligence solution for a retail company, built the way a professional consulting team would build it for a client. It takes messy inventory and sales data, organises it into a proper data warehouse, checks its quality automatically, and turns it into an executive dashboard that answers real business questions: *What should we reorder? Which suppliers are unreliable? Where is our cash trapped?*

The standout is that it doesn't just present data — it **finds the problem and recommends the fix**, identifying roughly $0.7–1.0M of annual opportunity and tracing the biggest issue to a small, fixable group of suppliers. It demonstrates the complete skill set of a BI developer/analyst: data engineering, SQL, dashboarding, and — crucially — translating numbers into business decisions. Built entirely on synthetic data for a fictional company.

---

## 5. Elevator pitch (30 seconds)

> "I built an end-to-end retail inventory BI platform — the whole stack, from a PostgreSQL warehouse and a Python data pipeline to a Power BI executive dashboard. The interesting part is the data: instead of random numbers, I wrote a day-by-day inventory *simulation*, so problems like stock-outs and dead stock emerge naturally and behave like a real business. That let me do a real analysis — and I found the retailer was overstocked and out-of-stock *at the same time*, which pointed to about a million dollars a year in trapped cash and lost sales. It's a portfolio case study, but every piece is production-quality."

---

## 6. Five-minute interview explanation

A structured script. Practise it out loud; the arc is **context → problem → build → decisions → results → reflection.**

**(0:00–0:30) Context.** "I wanted a portfolio project that proved I could deliver a *complete* BI solution, not just a dashboard. So I scoped it as a consulting engagement for a fictional mid-market retailer — 120 stores, 8 warehouses, 250 suppliers — facing the classic problems: stock-outs, overstock, unreliable suppliers, and manual reporting."

**(0:30–1:30) The data decision.** "The first real decision was the data. Public datasets like Superstore are a giveaway, so I generated my own — but not with random numbers. I built a *simulation* that rolls each product-location's inventory forward one day at a time: demand draws down stock, reorder points trigger purchase orders, suppliers deliver with tier-based reliability. That means stock-outs, dead stock, and late deliveries *emerge* from the mechanics. It's reproducible from a seed and scales via config from a laptop demo to the full 5-year, 50,000-SKU spec."

**(1:30–2:30) Modelling.** "I modelled it as a Kimball star schema. The key decision was the daily inventory snapshot — inventory is *semi-additive*, you can sum it across stores but never across dates, so it needs a periodic-snapshot fact and specific handling in both SQL and DAX. I used all three Kimball fact types deliberately, unified stores and warehouses into one location dimension so transfers and network inventory stay clean, and partitioned the snapshot by month with BRIN indexes for scale."

**(2:30–3:30) The stack.** "On top of the warehouse: 54 SQL business queries — all executed against the data, not just written — covering everything from GMROI to supplier OTIF. A Python pipeline that cleans deliberately-injected data issues and runs a gated validation suite. Excel workbooks for finance. And a 9-page Power BI dashboard with 44 DAX measures, Row-Level Security by region, drillthrough, and mobile layouts. A nice proof point: SQL, Excel, and Python all independently report the same headline numbers, because they read the same data."

**(3:30–4:30) Results.** "Then I put on the consultant hat. The analysis surfaced that the retailer was overstocked *and* out-of-stock simultaneously — the signature of applying the same buying rules to fast and slow movers. Around $729K was trapped in dead and overstocked inventory, and about $1.3M in sales was being lost to stock-outs. The sharpest finding: 18% of suppliers — the Bronze tier — were driving 42% of stock-outs. So the recommendation prioritised velocity-based buying and fixing that specific supplier group, targeting roughly $0.7–1.0M in annual value."

**(4:30–5:00) Reflection.** "What I'd do next is ML forecasting on Microsoft Fabric — I scoped it as Phase 2 rather than over-engineering the core. The biggest thing I learned is that the modelling decisions upstream — especially the semi-additive snapshot — determine whether the whole thing works. Happy to go deep on any layer."

---

## 7. Top 30 interview questions & answers

### Project & approach

**Q1. Why did you build this project?**
To prove I can deliver a complete BI solution end-to-end, not just a dashboard — data engineering, modelling, SQL, dashboarding, and business analysis — and to have a defensible talking point for every layer.

**Q2. Why synthetic data instead of a public dataset?**
Public datasets (Superstore, AdventureWorks) are instantly recognisable and signal a tutorial. Generating realistic, interconnected data is itself a skill, and it let me *engineer the business problems into the data* so the dashboards had something real to surface.

**Q3. How did you make the synthetic data realistic?**
It's a day-by-day inventory simulation, not random values. A ledger rolls each product-location forward: demand (with seasonality, weekend lift, promotions) draws down stock; reorder points trigger POs; suppliers deliver with tier-based lead-time reliability. Problems emerge from the mechanics, and it's seed-reproducible.

**Q4. What was the hardest part?**
Getting the inventory simulation coherent and the semi-additive modelling right. During validation I also caught real bugs — e.g., supplier reliability wasn't flowing into delivery times — which I fixed and documented rather than hiding.

**Q5. How would you scale this to a real company?**
The core is portable PostgreSQL + Power BI. For real volume I'd rely on the partitioning and incremental refresh already designed in, connect to real source extracts, and add ML forecasting on Fabric as Phase 2.

### Data modelling

**Q6. Star schema or snowflake — and why?**
Star. Analytics favours denormalised, wide dimensions for read performance and usability; OLTP normalises to protect writes, OLAP denormalises to accelerate reads. I kept the category hierarchy denormalised into the product dimension.

**Q7. What is a semi-additive measure and how did you handle it?**
Inventory on-hand can be summed across products and locations but *not across dates* — summing Monday and Tuesday stock is meaningless. I handled it with a periodic-snapshot fact, a latest-snapshot pattern in SQL, and `LASTNONBLANK` / average-of-daily patterns in DAX.

**Q8. Explain the three fact types you used.**
Transaction (sales, returns, transfers — one immutable row per event), periodic snapshot (daily inventory — state captured on a schedule), and accumulating snapshot (purchase orders — one row whose order/expected/received dates fill in over its lifecycle, enabling OTIF).

**Q9. Why one location dimension instead of separate store and warehouse dimensions?**
Inventory lives at both and transfers move between them. One `dim_location` with a type discriminator keeps the snapshot and transfer facts clean, and lets transfers role-play the same dimension as source and destination. Two dimensions would force awkward either/or foreign keys.

**Q10. What are surrogate keys and why use them?**
Warehouse-generated integer keys separate from business keys. They decouple the warehouse from source key changes, join faster, handle unknown members, and are a prerequisite for slowly changing dimensions.

**Q11. What's a role-playing dimension? Give an example here.**
One dimension referenced in multiple roles. `dim_date` plays sale/order/expected/received/transfer dates; `dim_location` plays source and destination on transfers. In Power BI you use inactive relationships with `USERELATIONSHIP`.

**Q12. Did you consider slowly changing dimensions?**
Yes — default is Type 1 (overwrite) for simplicity, but I flagged unit cost as a Type 2 candidate because historically-accurate inventory valuation should use the cost that applied at the time. I documented it as a deliberate simplification with an upgrade path.

### SQL

**Q13. What window functions did you use and where?**
`LAG` for month-over-month and YoY, `RANK`/`ROW_NUMBER` for store league tables and Pareto, running `SUM OVER` for cumulative revenue, and partitioned `AVG OVER` to compare each store to its region average.

**Q14. How did you find dead stock in SQL?**
An anti-join: `LEFT JOIN` the last-sale-per-product against current stock and keep rows where the last sale is null or older than 180 days while on-hand > 0.

**Q15. How do you compute inventory turnover correctly?**
COGS divided by *average* inventory value — where average is the mean of the daily inventory totals, not a sum across days. Getting that denominator right is the semi-additive trap.

**Q16. A bug you found in your own SQL?**
Two: one query put a window function in a `WHERE` clause (illegal in PostgreSQL — I moved it into a CTE), and a Pareto sampler returned zero rows due to an over-clever self-join, which I simplified. Both caught during validation.

**Q17. How did you optimise for performance?**
Range partitioning on the snapshot by month, BRIN indexes on the append-only date columns, a partial index for the stock-out exception path, composite indexes matching the dominant query, and `ANALYZE` after loads.

**Q18. Why BRIN over B-tree on the big facts?**
BRIN is tiny and ideal for large, append-only, naturally date-ordered data — it stores min/max per block range instead of every value, so it's a fraction of the size while still pruning date-range scans effectively.

### Python & data quality

**Q19. Walk me through your data pipeline.**
Generator → raw CSVs → cleaning (dedupe, impute missing prices from catalog, recompute dependent measures) → a gated validation suite → warehouse load. EDA and an automated KPI report run off the cleaned data. Raw is never mutated in place, so a bad transform is fixed by re-running.

**Q20. What does your validation suite check?**
Four families: referential integrity, key uniqueness, completeness, and business rules — including re-deriving OTIF from its components to catch logic drift, and checking received ≤ ordered. It gates on critical failures and a 99% pass threshold, and exits non-zero so CI blocks the merge.

**Q21. Why inject data-quality issues on purpose?**
So the cleaning and validation have real work to do — a pipeline that cleans already-perfect data is a tell of a fake project. I documented exactly what was injected so the quality report is verifiable.

**Q22. How is the pipeline reproducible?**
A fixed seed and all parameters in one config file, so anyone who clones the repo gets identical data — which is what makes the numbers across SQL, Excel, and Power BI agree.

### Power BI & DAX

**Q23. How does your semi-additive inventory measure work in DAX?**
`Inventory Value` uses `CALCULATE(SUM(...), LASTNONBLANK(date))` to take the closing balance on the last date with data, so it never double-counts across days. Turnover then divides COGS by an `AVERAGEX` over daily totals.

**Q24. How did you implement Row-Level Security?**
Two roles filtering `dim_location` — region for regional managers, warehouse type for DC managers. Because relationships filter one-way from the dimension, filtering it cascades to every fact automatically. Validated with "View as role."

**Q25. What is GMROI and why include it?**
Gross Margin Return on Inventory — gross margin per dollar of inventory cost. It's the metric retailers actually run on because it combines profitability and capital efficiency; below 1.0 an item loses money to hold. Including it signals real domain knowledge.

**Q26. How did you handle forecasting?**
An honest baseline — Power BI's built-in exponential-smoothing forecast line plus a rolling-average measure. True ML forecasting I scoped as a Phase-2 Fabric item rather than faking sophistication.

**Q27. Why `DIVIDE` instead of `/` in DAX?**
`DIVIDE` handles division by zero gracefully (returns blank or a specified alternative) instead of erroring — essential when a denominator like revenue can be zero in a filter context.

### Business & domain

**Q28. What did the analysis actually find?**
The retailer was overstocked and out-of-stock simultaneously — undifferentiated buying policy. ~$729K trapped in dead/overstock, ~$1.3M lost to stock-outs, and 18% of suppliers driving 42% of stock-outs. I framed a ~$0.7–1.0M opportunity with quick wins funding the structural fixes.

**Q29. Overstocked and out-of-stock at once — how is that possible?**
Because the same buying rules were applied to fast and slow movers. Slow movers accumulate months of cover (overstock) while fast movers, exposed to supplier variability, run dry (stock-outs). The fix is velocity-differentiated policy — ABC/XYZ — not simply buying more or less.

**Q30. Why is availability worth more than cost reduction here?**
Because estimated lost sales (~$1.3M) were about 2.5× the annual carrying cost (~$506K). Improving availability recovers margin on sales you're currently missing — a bigger prize than shaving holding cost, though the programme delivers both.

---

## 8. Fiverr service description

**Title:** I will build a professional Power BI dashboard and BI solution for your business

**Description:**
I design and build end-to-end Business Intelligence solutions — from data cleaning and modelling to a polished, interactive Power BI dashboard your team will actually use. Whether your data lives in Excel, a database, or CSV exports, I'll turn it into clear, decision-ready insights.

**What you get:**
- A clean, well-modelled dataset (star schema, proper KPIs)
- An interactive Power BI dashboard with the metrics that matter to you
- DAX measures, filters, drillthrough, and a mobile layout
- Documentation so you can maintain it

**Packages:**
- **Basic** — single-page dashboard, up to 5 KPIs, your cleaned data.
- **Standard** — multi-page dashboard, data modelling, 15+ measures, conditional formatting.
- **Premium** — full solution: data cleaning pipeline, modelled warehouse, multi-page dashboard with RLS, drillthrough, and documentation.

*Portfolio: an end-to-end retail inventory BI platform (PostgreSQL → Python → Power BI) — see my GitHub.*

---

## 9. Upwork portfolio description

**Portfolio item title:** End-to-End Retail Inventory BI Platform (PostgreSQL · Python · Power BI)

**Description:**
A complete Business Intelligence solution built to production standards. I designed a PostgreSQL data warehouse (Kimball star schema), engineered a reproducible Python data pipeline with automated quality checks, wrote 54 analytical SQL queries, and delivered a 9-page Power BI executive dashboard with 44 DAX measures, Row-Level Security, and drillthrough.

Beyond the build, I produced a consultant-style analysis that identified roughly $0.7–1.0M in annual opportunity and traced the client's biggest availability problem to a small, fixable group of suppliers. This piece demonstrates the full arc I bring to client work: data engineering, modelling, SQL, dashboarding, and translating data into decisions.

*Built on synthetic data for a fictional retailer. Full source and documentation available on request.*

**Profile blurb angle:** "BI Developer who delivers the whole solution — clean data, solid model, and a dashboard that drives decisions — not just charts."

---

## 10. Client proposal template

*(Reusable for a real BI engagement. Fill the brackets.)*

**Proposal: Business Intelligence Solution for [Client]**

**1. Understanding your challenge**
You're currently [manual reporting / no single source of truth / limited visibility into X]. This makes it hard to [reorder confidently / measure supplier performance / free trapped capital], and decisions rely on data that's [days old / inconsistent across teams].

**2. Proposed solution**
I'll deliver an end-to-end BI solution: a governed data model, automated data-quality checks, and an interactive dashboard tailored to your decisions — [executives / purchasing / operations].

**3. Scope & deliverables**
- Requirements & KPI definition (what "good" looks like for you)
- Data modelling (star schema / single source of truth)
- Data cleaning & validation pipeline
- [N]-page interactive dashboard with role-based access
- Documentation & handover / training

**4. Approach & timeline**
- Week 1: requirements & data audit
- Weeks 2–3: modelling & pipeline
- Weeks 4–5: dashboard build & review
- Week 6: UAT, documentation, handover
*(Indicative; refined after discovery.)*

**5. Why me**
I deliver the whole solution, not just visuals — with clean architecture and documentation you can maintain. See my end-to-end retail inventory BI platform: [GitHub link].

**6. Investment**
- Discovery & modelling: [fixed]
- Dashboard build: [fixed / per page]
- Optional: ongoing support & enhancements [monthly]

**7. Next step**
A 30-minute call to walk through your data and confirm scope. [Booking link]

---

*End of Career Assets v1.0 — and of the RIIP project. Every section built, reviewed, and improved. Go stand out.*
