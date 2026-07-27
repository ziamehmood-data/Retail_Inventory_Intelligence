"""
RIIP - Data Validation
======================

A suite of checks that run on the CLEANED data before it is trusted by the
warehouse / BI layer. Checks fall into four families:

  * Referential integrity - every fact FK exists in its dimension
  * Uniqueness            - surrogate & natural keys are unique
  * Completeness          - required columns have no nulls
  * Domain / business rule - values are in valid ranges and internally consistent

Each check returns a CheckResult; the suite aggregates them into an overall
pass/fail gate (default: fail if any CRITICAL check has violations, or if the
overall pass rate < 99%).

Run:
    python -m src.quality.validate
"""
from __future__ import annotations
import os
from dataclasses import dataclass, field
import pandas as pd

DATA = "data/processed"       # validate the CLEANED data


@dataclass
class CheckResult:
    name: str
    critical: bool
    violations: int
    total: int
    sample: list = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return self.violations == 0

    @property
    def pass_rate(self) -> float:
        return 1.0 if self.total == 0 else 1 - self.violations / self.total


def _load(name):
    return pd.read_csv(os.path.join(DATA, f"{name}.csv"))


def run_checks() -> list[CheckResult]:
    dim_product  = _load("dim_product")
    dim_location = _load("dim_location")
    dim_supplier = _load("dim_supplier")
    sales        = _load("fact_sales")
    snap         = _load("fact_inventory_snapshot")
    po           = _load("fact_purchase_order")

    results: list[CheckResult] = []

    def ref_check(name, fact, fk, dim, dim_key, critical=True):
        valid = set(dim[dim_key])
        bad = fact.loc[~fact[fk].isin(valid) & fact[fk].notna(), fk]
        results.append(CheckResult(name, critical, int(bad.shape[0]),
                                   int(fact.shape[0]), bad.head(5).tolist()))

    # --- Referential integrity ---
    ref_check("sales.product_key -> dim_product",  sales, "product_key",  dim_product,  "product_key")
    ref_check("sales.location_key -> dim_location", sales, "location_key", dim_location, "location_key")
    ref_check("snapshot.product_key -> dim_product", snap, "product_key",  dim_product,  "product_key")
    ref_check("po.supplier_key -> dim_supplier",    po,    "supplier_key", dim_supplier, "supplier_key")

    # --- Uniqueness ---
    dup_sku = int(dim_product["sku"].duplicated().sum())
    results.append(CheckResult("dim_product.sku unique", True, dup_sku, len(dim_product)))
    dup_pk = int(dim_product["product_key"].duplicated().sum())
    results.append(CheckResult("dim_product.product_key unique", True, dup_pk, len(dim_product)))

    # --- Completeness (required columns non-null after cleaning) ---
    miss_price = int(sales["unit_price"].isna().sum())
    results.append(CheckResult("sales.unit_price not null", True, miss_price, len(sales),
                               [] if miss_price == 0 else ["nulls remain"]))

    # --- Domain / business rules ---
    neg_qty = int((sales["units_sold_qty"] <= 0).sum())
    results.append(CheckResult("sales.units_sold_qty > 0", True, neg_qty, len(sales)))

    bad_margin = int((dim_product["unit_price"] < dim_product["unit_cost"]).sum())
    results.append(CheckResult("product price >= cost", False, bad_margin, len(dim_product)))

    neg_onhand = int((snap["on_hand_qty"] < 0).sum())
    results.append(CheckResult("snapshot.on_hand_qty >= 0", True, neg_onhand, len(snap)))

    # OTIF consistency: is_otif must equal (not late AND complete)
    if {"is_otif_flag", "is_late_flag", "is_complete_flag"}.issubset(po.columns):
        expected = (~po["is_late_flag"].astype(bool)) & po["is_complete_flag"].astype(bool)
        inconsistent = int((po["is_otif_flag"].astype(bool) != expected).sum())
        results.append(CheckResult("po.OTIF = (on-time AND in-full)", False, inconsistent, len(po)))

    # received qty should not exceed ordered qty
    over_recv = int((po["received_qty"] > po["ordered_qty"]).sum())
    results.append(CheckResult("po.received_qty <= ordered_qty", False, over_recv, len(po)))

    return results


def gate(results: list[CheckResult], min_pass_rate: float = 0.99) -> bool:
    """Return True if data passes: no critical violations AND overall rate >= threshold."""
    critical_fail = any(r.critical and not r.passed for r in results)
    total = sum(r.total for r in results)
    viol = sum(r.violations for r in results)
    overall = 1.0 if total == 0 else 1 - viol / total
    return (not critical_fail) and (overall >= min_pass_rate)


if __name__ == "__main__":
    import sys
    res = run_checks()
    print(f"{'CHECK':45s} {'CRIT':5s} {'VIOL':>6s} {'RATE':>7s}  RESULT")
    for r in res:
        print(f"{r.name:45s} {'yes' if r.critical else 'no':5s} "
              f"{r.violations:>6d} {r.pass_rate:>6.1%}  {'PASS' if r.passed else 'FAIL'}")
    ok = gate(res)
    print(f"\nVALIDATION GATE: {'PASSED' if ok else 'FAILED'}")
    sys.exit(0 if ok else 1)     # non-zero on failure so CI can block the merge
