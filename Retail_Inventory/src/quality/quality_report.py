"""
RIIP - Data Quality Report
==========================

Orchestrates the pipeline (clean -> validate) and writes a human-readable
Data Quality Report to reports/data_quality_report.md. This is the artifact a
data steward signs off before the warehouse load is trusted.

Run:
    python -m src.quality.quality_report
"""
from __future__ import annotations
import os
from datetime import datetime

from src.etl.clean import clean_all
from src.quality.validate import run_checks, gate

REPORT = "reports/data_quality_report.md"


def build_report() -> str:
    clean_log = clean_all(write=True)     # produce cleaned data + cleaning log
    checks = run_checks()                 # validate the cleaned data
    passed = gate(checks)

    s = clean_log["fact_sales"]
    total = sum(c.total for c in checks)
    viol = sum(c.violations for c in checks)
    overall_rate = 1.0 if total == 0 else 1 - viol / total

    lines = []
    lines.append("# Data Quality Report")
    lines.append(f"_Generated {datetime.now():%Y-%m-%d %H:%M} — RIIP pipeline_\n")
    lines.append(f"**Overall gate:** {'✅ PASSED' if passed else '❌ FAILED'}  ")
    lines.append(f"**Overall pass rate:** {overall_rate:.2%}\n")

    lines.append("## 1. Cleaning actions (RAW → processed)\n")
    lines.append("| Table | Rows in | Rows out | Duplicates removed | Prices imputed |")
    lines.append("|---|---:|---:|---:|---:|")
    lines.append(f"| fact_sales | {s['rows_in']:,} | {s['rows_out']:,} | "
                 f"{s['duplicates_removed']:,} | "
                 f"{s['missing_price_before'] - s['missing_price_after']:,} |")
    lines.append("")

    lines.append("## 2. Validation checks (on cleaned data)\n")
    lines.append("| Check | Critical | Violations | Pass rate | Result |")
    lines.append("|---|:--:|---:|---:|:--:|")
    for c in checks:
        lines.append(f"| {c.name} | {'yes' if c.critical else 'no'} | {c.violations:,} "
                     f"| {c.pass_rate:.1%} | {'✅' if c.passed else '❌'} |")
    lines.append("")

    failing = [c for c in checks if not c.passed]
    lines.append("## 3. Issues requiring attention\n")
    if not failing:
        lines.append("_No violations detected. All checks passed._")
    else:
        for c in failing:
            sev = "CRITICAL" if c.critical else "warning"
            lines.append(f"- **{c.name}** ({sev}): {c.violations:,} violations"
                         + (f" — sample: {c.sample}" if c.sample else ""))
    lines.append("")

    lines.append("## 4. Interpretation\n")
    lines.append("The cleaning stage removed the injected duplicate rows and imputed the "
                 "injected missing prices from the product catalog. Post-clean validation "
                 "confirms referential integrity, key uniqueness, completeness, and business-rule "
                 "consistency. The warehouse load may proceed only while the gate reads PASSED.")
    return "\n".join(lines)


if __name__ == "__main__":
    os.makedirs("reports", exist_ok=True)
    md = build_report()
    with open(REPORT, "w") as f:
        f.write(md)
    print(f"Data Quality Report written to {REPORT}")
    print(md.split("## 2.")[0])   # echo the header + cleaning summary
