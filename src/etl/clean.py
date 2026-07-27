"""
RIIP - ETL - Data Cleaning
==========================

Transforms RAW extracts into cleansed, dw-ready tables (the 'staging' step).
It fixes exactly the documented defects the generator injects, and records
everything it did in a cleaning log that the Data Quality Report consumes.

Cleaning rules applied to fact_sales:
  1. Remove exact duplicate rows           (dedupe)
  2. Impute missing unit_price             (fall back to product catalog price)
  3. Recompute price-dependent measures     (net_sales, cogs, margin stay consistent)
  4. Coerce numeric types / strip text      (defensive typing)

Design choices:
  * Raw is never mutated in place - we read raw/, write processed/.
  * Every fix is counted and returned, so the pipeline is auditable, not opaque.

Run:
    python -m src.etl.clean
"""
from __future__ import annotations
import os
import pandas as pd

RAW = "data/raw"
OUT = "data/processed"


def _load(name: str) -> pd.DataFrame:
    return pd.read_csv(os.path.join(RAW, f"{name}.csv"))


def clean_sales(sales: pd.DataFrame, products: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    """Clean the sales fact and return (clean_df, log)."""
    log = {"rows_in": len(sales)}

    # 1) exact duplicates (ignore the surrogate key when judging duplication)
    natural_cols = [c for c in sales.columns if c != "sales_key"]
    dupe_mask = sales.duplicated(subset=natural_cols, keep="first")
    log["duplicates_removed"] = int(dupe_mask.sum())
    sales = sales.loc[~dupe_mask].copy()

    # 2) impute missing unit_price from the product catalog
    log["missing_price_before"] = int(sales["unit_price"].isna().sum())
    catalog = products.set_index("product_key")["unit_price"]
    sales["unit_price"] = sales["unit_price"].fillna(
        sales["product_key"].map(catalog))
    log["missing_price_after"] = int(sales["unit_price"].isna().sum())

    # 3) keep price-dependent measures consistent after imputation
    sales["gross_sales_amount"] = (sales["units_sold_qty"] * sales["unit_price"]).round(2)
    sales["net_sales_amount"] = (sales["gross_sales_amount"]
                                 - sales["discount_amount"].fillna(0)).round(2)
    if "unit_cost" in sales:
        sales["cogs_amount"] = (sales["units_sold_qty"] * sales["unit_cost"]).round(2)
        sales["gross_margin_amount"] = (sales["net_sales_amount"] - sales["cogs_amount"]).round(2)

    # 4) defensive typing
    for col in ["units_sold_qty", "product_key", "location_key", "date_key"]:
        sales[col] = pd.to_numeric(sales[col], errors="coerce").astype("Int64")

    log["rows_out"] = len(sales)
    return sales, log


def clean_all(write: bool = True) -> dict:
    """Run the full cleaning pass; return a per-table cleaning log."""
    os.makedirs(OUT, exist_ok=True)
    products = _load("dim_product")
    sales = _load("fact_sales")
    sales_clean, sales_log = clean_sales(sales, products)

    # dimensions & other facts: light pass-through with whitespace stripping
    passthrough = ["dim_date", "dim_product", "dim_supplier", "dim_location",
                   "dim_employee", "dim_customer", "dim_promotion",
                   "fact_inventory_snapshot", "fact_purchase_order",
                   "fact_returns", "fact_stock_transfer"]
    log = {"fact_sales": sales_log}
    tables = {"fact_sales": sales_clean}
    for name in passthrough:
        df = _load(name)
        for c in df.select_dtypes(include=["object", "string"]).columns:
            df[c] = df[c].astype(str).str.strip()
        tables[name] = df
        log[name] = {"rows_in": len(df), "rows_out": len(df)}

    if write:
        for name, df in tables.items():
            df.to_csv(os.path.join(OUT, f"{name}.csv"), index=False)
    return log


if __name__ == "__main__":
    result = clean_all()
    s = result["fact_sales"]
    print("Cleaning complete.")
    print(f"  fact_sales: {s['rows_in']:,} -> {s['rows_out']:,} rows")
    print(f"  duplicates removed: {s['duplicates_removed']:,}")
    print(f"  missing prices imputed: {s['missing_price_before'] - s['missing_price_after']:,}")
    print(f"  cleaned tables written to {OUT}/")
