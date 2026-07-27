# Future Improvements

The core platform is deliberately scoped as decision-support on a portable stack.
These are the credible next steps — useful both as a roadmap and as interview
answers to "what would you do next?"

## Phase 2 — analytics depth

- **ML demand forecasting** (Microsoft Fabric) — replace the rule-based reorder
  signals and the exponential-smoothing baseline with trained time-series /
  gradient-boosted models per SKU-location.
- **Safety-stock optimisation** — size safety stock from each supplier's lead-time
  *variability* and a target service level, rather than a flat rule.
- **What-if analysis** — Power BI parameters to trade service level against
  carrying cost interactively.

## Phase 3 — operationalisation

- **Automated replenishment** — push recommended POs into the ERP (the platform
  currently recommends; execution stays manual by design).
- **Alerting** — email/Teams alerts for new stock-out risks and late suppliers,
  so purchasing doesn't have to open the dashboard to be warned.
- **Supplier portal / scorecards** — share OTIF scorecards with suppliers to drive
  accountability.

## Platform & engineering

- **Real-time inventory** — streaming updates for high-velocity categories
  (daily batch is sufficient for everything in the current scope).
- **SCD Type 2 on cost** — track historical unit cost for exact inventory
  valuation over time (currently Type 1 by design).
- **dbt** — manage the SQL transformations as a tested, documented dbt project.
- **Fuller CI/CD** — expand GitHub Actions into a multi-environment pipeline with
  automated data tests on every change.

## Analytics extensions

- **Price & markdown optimisation** — attack margin leakage directly.
- **Demand sensing** — incorporate external signals (weather, promotions).
- **Customer analytics** — a separate engagement; deliberately out of scope here
  to keep the platform focused on inventory.
