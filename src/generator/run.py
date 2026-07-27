"""
Runner / orchestrator for the RIIP synthetic data generator.

Usage:
    python -m src.generator.run                 # uses config.active_profile
    python -m src.generator.run --profile full  # override profile

It builds dimensions first, runs the inventory simulation, derives returns,
transfers and ABC classes, injects documented dirt, and writes every table.
The order guarantees referential integrity: no fact references a key that
does not already exist in a dimension.
"""
from __future__ import annotations
import os
import sys
import time
import argparse

import pandas as pd

# allow running as `python src/generator/run.py` or `python -m src.generator.run`
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
from src.generator import generator as G


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="config/config.yaml")
    ap.add_argument("--profile", default=None, help="override active_profile")
    args = ap.parse_args()

    cfg = G.load_config(args.config)
    if args.profile:
        cfg["active_profile"] = args.profile
        cfg["p"] = cfg["profiles"][args.profile]
    rng = G.seed_everything(cfg["seed"])
    p = cfg["p"]
    t0 = time.time()
    print(f"Profile: {cfg['active_profile']}  |  seed: {cfg['seed']}")

    # ---- dimensions ----
    dim_date = G.build_dim_date(cfg["date_range"]["start"], cfg["date_range"]["end"])
    dim_product = G.build_dim_product(p["products"], rng)
    dim_supplier = G.build_dim_supplier(p["suppliers"], rng)
    dim_location = G.build_dim_location(p["stores"], p["warehouses"], rng)
    dim_employee = G.build_dim_employee(p["employees"], dim_location, rng)
    dim_customer = G.build_dim_customer(p["customers"], rng)
    dim_promotion = G.build_dim_promotion(p["promotions"], dim_date, rng)
    print("Dimensions built.")

    # ---- linkage ----
    prod_supplier = G.assign_product_supplier(dim_product, dim_supplier, rng)
    supplier_tier = dict(zip(dim_supplier["supplier_key"], dim_supplier["reliability_tier"]))
    combos = G.assign_stocking(dim_product, dim_location, p["avg_locations_per_product"], rng)
    print(f"Stocked (product,location) pairs: {len(combos):,}")

    # ---- simulation ----
    sales, po, snap = G.simulate(cfg, dim_date, dim_product, dim_location,
                                 combos, prod_supplier, supplier_tier, rng)
    print(f"Simulation done: sales={len(sales):,}  po={len(po):,}  snapshot={len(snap):,}")

    # ---- derived facts & classes ----
    returns = G.generate_returns(sales, dim_customer, rng)
    transfers = G.generate_transfers(snap, dim_location, rng)
    dim_product = G.classify_abc(dim_product, sales)

    # attach employee/customer/promotion to sales (post-hoc, FK-safe)
    sales["employee_key"] = rng.choice(dim_employee["employee_key"].values, size=len(sales))
    sales["customer_key"] = rng.choice(dim_customer["customer_key"].values, size=len(sales))
    sales["promotion_key"] = rng.choice(
        [pd.NA] * 6 + list(dim_promotion["promotion_key"].values), size=len(sales))
    sales["discount_amount"] = 0.0
    sales["net_sales_amount"] = sales["gross_sales_amount"]
    sales["gross_margin_amount"] = (sales["net_sales_amount"] - sales["cogs_amount"]).round(2)

    # ---- inject documented dirt (raw layer) ----
    sales_raw = G.inject_dirty(sales, cfg, rng)

    # ---- drop internal columns before export ----
    dim_product_out = dim_product.drop(columns=[c for c in ["_popularity"] if c in dim_product])

    tables = {
        "dim_date": dim_date, "dim_product": dim_product_out, "dim_supplier": dim_supplier,
        "dim_location": dim_location, "dim_employee": dim_employee,
        "dim_customer": dim_customer, "dim_promotion": dim_promotion,
        "fact_sales": sales_raw, "fact_inventory_snapshot": snap,
        "fact_purchase_order": po, "fact_returns": returns,
        "fact_stock_transfer": transfers,
    }

    # ---- write ----
    raw = cfg["output"]["raw_path"]
    smp = cfg["output"]["sample_path"]
    os.makedirs(raw, exist_ok=True)
    os.makedirs(smp, exist_ok=True)
    for name, df in tables.items():
        df.to_csv(os.path.join(raw, f"{name}.csv"), index=False)
        df.head(cfg["output"]["sample_rows"]).to_csv(
            os.path.join(smp, f"{name}.sample.csv"), index=False)

    # ---- run summary ----
    print("\n=== RUN SUMMARY ===")
    for name, df in tables.items():
        print(f"  {name:26s} {len(df):>10,} rows  x {df.shape[1]:>2} cols")
    print(f"Elapsed: {time.time() - t0:,.1f}s")
    return tables


if __name__ == "__main__":
    main()
