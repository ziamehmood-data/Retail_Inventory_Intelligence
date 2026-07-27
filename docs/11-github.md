# GitHub
## Retail Inventory Intelligence Platform (RIIP)

| Field | Value |
|---|---|
| **Document** | GitHub Repository Strategy |
| **Version** | 1.0 |
| **Date** | 26 July 2026 |

The repository is set up like a real open-source project, not a code dump. That
polish is what a reviewer notices before reading a single line.

---

## 1. What ships in the repo

| File / folder | Purpose |
|---|---|
| `README.md` | The portfolio hero — screenshot, results, quick start, doc index |
| `LICENSE` | MIT (with a synthetic-data note) |
| `CONTRIBUTING.md` | How to contribute, conventions, workflow |
| `CHANGELOG.md` | Versioned change history (Keep a Changelog) |
| `.gitignore` | Excludes large generated data and temp files; keeps `data/samples/` |
| `.github/workflows/ci.yml` | CI: generate → clean → **data-quality gate** → KPI report |
| `.github/ISSUE_TEMPLATE/` | Bug + feature templates, blank issues disabled |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR checklist (SQL/DAX/gate/docs/commits) |

Full tree is in the [README](../README.md#repository-structure).

---

## 2. Commit plan

The history should read as a build narrative using **Conventional Commits**. A
meaningful sequence (one logical commit per step):

```
chore: initialise repo, license, readme skeleton
docs: add business requirements document (BRD)
docs: add solution architecture + mermaid diagram
docs: add database design, ER diagram, data dictionary
feat: add config-driven synthetic data generator (inventory simulation)
test: validate generated data (integrity, OTIF-by-tier, dead stock)
fix: flow supplier reliability tier into lead-time simulation
feat: add SQL schema — dimensions, facts, partitioned snapshot
feat: add constraints, foreign keys, indexes (BRIN, partial)
feat: add analytical views and stored procedures
feat: add 54 business queries (executed against the data)
fix: refactor Q44 window filter; simplify Q23 pareto sampler
feat: add Excel raw/cleaning/analysis workbooks
feat: add Python pipeline — clean, validate, DQ report
feat: add EDA and automated KPI report
docs: add Power BI spec, 44 DAX measures, theme, mockup
docs: add business insights, recommendations, priority matrix
docs: add README, installation/user/business/technical guides
ci: add GitHub Actions data-quality gate + issue/PR templates
chore: release v1.0.0
```

**Why it matters:** a reviewer skimming the commit list should see a professional
building a system in logical order — including the `fix:` commits, which show real
debugging rather than a suspiciously perfect first pass.

---

## 3. Release strategy

- **Semantic Versioning** (`MAJOR.MINOR.PATCH`). The complete solution is **v1.0.0**.
- **Git tags + GitHub Releases** — tag `v1.0.0`, publish a Release with notes drawn
  from the `CHANGELOG.md`.
- **Branches** — `main` (always green, releasable), `develop` (integration),
  `feature/*` and `fix/*` for work.
- **Milestones** map to the roadmap: `v1.1` forecasting (Fabric), `v1.2`
  safety-stock optimisation, `v1.3` dbt migration.
- **Protect `main`** — require the CI check and a PR review before merge.

---

## 4. Repository badges

Shown in the README, each links to something real:

| Badge | Signals |
|---|---|
| PostgreSQL / Python / Power BI / Excel | the stack at a glance |
| License: MIT | reuse terms |
| Status: portfolio case study | honest framing |
| *Build passing* (add after first CI run) | `![CI](https://github.com/<you>/<repo>/actions/workflows/ci.yml/badge.svg)` |

Add the build badge once the workflow has run once, so it reflects real status.

---

## 5. GitHub Actions

The included `ci.yml` runs on every push and PR to `main`/`develop`:

1. **Data-quality job** — installs deps, generates the demo dataset, cleans it,
   and runs `src/quality/validate.py`, which **exits non-zero if the gate fails**,
   blocking the merge. It then generates the KPI report and uploads `reports/` as
   an artifact.
2. **SQL-lint job** — runs `sqlfluff` over `sql/` (non-blocking, advisory).

**Suggested extensions:**
- Add `pytest` unit tests for the generator and cleaning, run in CI.
- Cache pip and the generated dataset between runs for speed.
- A scheduled (`cron`) run that regenerates the KPI report as a freshness check.
- CodeQL for the Python code if the repo grows.

---

## 6. Reviews

**Senior BI Architect** — CI gates on the *data-quality* validation, not just code
compilation — the right thing to protect in a data project. *Strengthened:*
`validate.py` now returns a proper exit code so the gate genuinely blocks merges.

**Hiring Manager** — Conventional commits, templates, a changelog, and a green CI
badge are the signals that separate a polished repo from a homework dump.
*Strengthened:* the commit plan deliberately includes `fix:` commits, so the
history reads as real engineering.

**Freelancing** — A repo set up this professionally reassures a client that the
work will be maintainable and handed over cleanly — a differentiator on proposals.

---

*End of GitHub v1.0.*
