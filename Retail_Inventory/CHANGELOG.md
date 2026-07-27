# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/);
this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-07-26

Initial release — the complete end-to-end BI solution.

### Added
- **Business Requirements Document** — objectives, scope, KPIs, stakeholders, risks.
- **Solution Architecture** — layered design, data flow, tech stack, conventions.
- **Database Design** — Kimball star schema (7 dims, 5 facts), ER diagram, data dictionary.
- **Synthetic data generator** — day-by-day inventory simulation; config-driven, seeded.
- **SQL** — full DDL (partitioning, BRIN), views, procedures, and **54 business queries** (all executed).
- **Excel** — raw, cleaning, and analysis workbooks with Power Query, pivots, conditional formatting.
- **Python pipeline** — cleaning, a gated validation suite, data-quality report, EDA, automated KPI report.
- **Power BI** — 9-page dashboard spec, **44 DAX measures**, theme JSON, RLS design, Executive Overview mockup.
- **Business Insights** — problems, root causes, recommendations, priority matrix, expected impact.
- **Documentation** — README, installation/user/business/technical/screenshots guides, future work.
- **GitHub** — CI workflow (data-quality gate), issue/PR templates, contributing guide.

## [Unreleased]

### Planned (see docs/future-improvements.md)
- ML demand forecasting (Microsoft Fabric)
- Safety-stock optimisation from lead-time variability
- What-if analysis parameters in Power BI
- dbt-managed SQL transformations
