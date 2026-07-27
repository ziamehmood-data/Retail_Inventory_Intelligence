#!/usr/bin/env bash
# =============================================================================
# init_repo.sh — initialise the RIIP git repository with a meaningful,
# conventional-commit history (the build narrative from docs/11-github.md).
# Run once from the repo root:  bash init_repo.sh
# =============================================================================
set -e

git init -q
git symbolic-ref HEAD refs/heads/main 2>/dev/null || true

commit () {  # commit <message> <path> [path...]
  local msg="$1"; shift
  git add "$@" 2>/dev/null || true
  git commit -q -m "$msg" 2>/dev/null && echo "  ✓ $msg" || echo "  · skipped (nothing to add): $msg"
}

echo "Building commit history..."
commit "chore: initialise repo, license, readme"            README.md LICENSE .gitignore requirements.txt init_repo.sh
commit "docs: add business requirements document (BRD)"      docs/01-business-requirements-document.md
commit "docs: add solution architecture + mermaid diagram"   docs/02-solution-architecture.md
commit "docs: add database design, ER diagram, dictionary"   docs/03-database-design.md
commit "feat: add config-driven synthetic data generator"    config/ src/generator/ src/__init__.py
commit "docs: document synthetic dataset + commit samples"   docs/04-synthetic-dataset.md data/samples/
commit "feat: add SQL schema — dimensions and facts"         sql/00_database_setup/ sql/01_schema/
commit "feat: add constraints, foreign keys, indexes"        sql/02_constraints_indexes/
commit "feat: add analytical views and stored procedures"    sql/03_views/ sql/04_procedures/
commit "feat: add 54 business queries (executed)"            sql/05_business_queries/ docs/05-sql-development.md
commit "feat: add Excel raw/cleaning/analysis workbooks"     excel/ docs/06-excel.md
commit "feat: add Python pipeline — clean and validate"      src/etl/ src/quality/
commit "feat: add EDA and automated KPI report"              src/analysis/ docs/07-python.md
commit "docs: add Power BI spec, DAX measures, theme, mockup" powerbi/ docs/08-power-bi.md docs/screenshots/
commit "docs: add business insights and recommendations"     docs/09-business-insights.md
commit "docs: add README guides (install/user/business/tech)" docs/installation-guide.md docs/user-guide.md docs/business-guide.md docs/technical-guide.md docs/screenshots-guide.md docs/future-improvements.md
commit "ci: add Actions data-quality gate + issue/PR templates" .github/ docs/11-github.md
commit "docs: add career assets pack"                        docs/12-career-assets.md
commit "chore: add contributing guide and changelog"         CONTRIBUTING.md CHANGELOG.md
git add -A 2>/dev/null || true
git commit -q -m "chore: finalise remaining assets" 2>/dev/null || true
git commit -q --allow-empty -m "chore: release v1.0.0" && echo "  ✓ chore: release v1.0.0"
git tag -a v1.0.0 -m "RIIP v1.0.0 — complete end-to-end BI solution" 2>/dev/null || true

echo ""
echo "Done. History:"
git --no-pager log --oneline
echo ""
echo "Next: create an empty GitHub repo, then:"
echo "  git remote add origin https://github.com/<you>/retail-inventory-intelligence-platform.git"
echo "  git push -u origin main --tags"
