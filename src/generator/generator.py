"""
Retail Inventory Intelligence Platform - Synthetic Data Generator
=================================================================

Design philosophy
------------------
The facts are NOT faked independently. They are the OUTPUT of a day-by-day
inventory simulation. For every stocked (product, location) pair we roll a
ledger forward one day at a time:

    on_hand(t) = on_hand(t-1)
               + receipts(t)          # purchase orders arriving
               - sales(t)             # capped by available stock
               + returns feedback     # (handled downstream)

Because the ledger is real, the business problems the BRD describes are
EMERGENT, not scripted:
  * stock-outs happen when demand outruns replenishment,
  * dead stock accumulates on low-velocity SKUs,
  * late deliveries come from unreliable suppliers (reliability tier),
  * seasonality and weekend lift come from demand multipliers.

Everything is driven by config.yaml and a fixed seed => reproducible.

Generation order respects foreign keys: dimensions first, then the
simulation that emits fact rows referencing only keys that already exist.
"""

from __future__ import annotations
import os
import math
import random
from datetime import date, timedelta

import numpy as np
import pandas as pd
import yaml

# -----------------------------------------------------------------------------
# Reference data (kept small & readable; expand freely)
# -----------------------------------------------------------------------------
REGIONS = ["North", "South", "East", "West"]

CATEGORIES = {
    "Home & Kitchen":      ["Cookware", "Storage", "Small Appliances", "Decor", "Bedding"],
    "Electronics":         ["Audio", "Accessories", "Smart Home", "Cables", "Chargers"],
    "Apparel":             ["Menswear", "Womenswear", "Kidswear", "Footwear", "Accessories"],
    "Health & Beauty":     ["Skincare", "Haircare", "Wellness", "Fragrance", "Grooming"],
    "Sports & Outdoors":   ["Fitness", "Camping", "Cycling", "Team Sports", "Apparel"],
    "Toys & Games":        ["Board Games", "Building", "Outdoor Play", "Educational", "Plush"],
    "Grocery":             ["Snacks", "Beverages", "Pantry", "Confectionery", "Breakfast"],
    "Office & Stationery": ["Writing", "Paper", "Desk", "Organisation", "Printing"],
    "Pet Supplies":        ["Food", "Toys", "Grooming", "Bedding", "Accessories"],
    "Automotive":          ["Care", "Accessories", "Tools", "Electronics", "Fluids"],
    "Garden & DIY":        ["Tools", "Planting", "Furniture", "Lighting", "Storage"],
    "Baby & Nursery":      ["Feeding", "Nursery", "Travel", "Clothing", "Toys"],
}

RELIABILITY_TIERS = {
    # tier: (base_lead_time_days, late_probability, lead_time_std)
    "Gold":   (7,  0.05, 1.5),
    "Silver": (12, 0.18, 3.0),
    "Bronze": (20, 0.38, 6.0),
}

RETURN_REASONS = ["Defective", "Wrong Item", "Not As Described",
                  "Changed Mind", "Damaged in Transit", "Better Price Elsewhere"]

PROMO_TYPES = ["PERCENT_OFF", "BOGO", "MARKDOWN", "BUNDLE"]
STORE_FORMATS = ["Flagship", "Standard", "Express"]
EMP_ROLES = ["Cashier", "Sales Associate", "Shift Lead", "Store Manager"]
LOYALTY_TIERS = ["None", "Silver", "Gold"]


# =============================================================================
# Config & seeding
# =============================================================================
def load_config(path: str = "config/config.yaml") -> dict:
    with open(path, "r") as f:
        cfg = yaml.safe_load(f)
    profile = cfg["profiles"][cfg["active_profile"]]
    cfg["p"] = profile          # convenience handle to the active profile
    return cfg


def seed_everything(seed: int) -> np.random.Generator:
    random.seed(seed)
    np.random.seed(seed)
    return np.random.default_rng(seed)


# =============================================================================
# DIMENSIONS
# =============================================================================
def build_dim_date(start: str, end: str) -> pd.DataFrame:
    """One row per calendar day with fiscal, seasonal and holiday attributes."""
    days = pd.date_range(start, end, freq="D")
    df = pd.DataFrame({"full_date": days})
    df["date_key"] = df["full_date"].dt.strftime("%Y%m%d").astype(int)
    df["day_of_week"] = df["full_date"].dt.dayofweek + 1
    df["day_name"] = df["full_date"].dt.day_name()
    df["is_weekend"] = df["day_of_week"] >= 6
    df["week_of_year"] = df["full_date"].dt.isocalendar().week.astype(int)
    df["month_number"] = df["full_date"].dt.month
    df["month_name"] = df["full_date"].dt.month_name()
    df["quarter"] = df["full_date"].dt.quarter
    df["year"] = df["full_date"].dt.year
    # Fiscal year starting in February (arbitrary but realistic for retail)
    df["fiscal_year"] = np.where(df["month_number"] >= 2, df["year"], df["year"] - 1)
    df["fiscal_quarter"] = ((df["month_number"] - 2) % 12 // 3 + 1)
    df["fiscal_quarter"] = "FQ" + df["fiscal_quarter"].astype(str)
    seasons = {12: "Winter", 1: "Winter", 2: "Winter", 3: "Spring", 4: "Spring",
               5: "Spring", 6: "Summer", 7: "Summer", 8: "Summer",
               9: "Autumn", 10: "Autumn", 11: "Autumn"}
    df["season"] = df["month_number"].map(seasons)
    # A few fixed annual holidays for holiday-uplift realism
    hol = df["full_date"].dt.strftime("%m-%d")
    holidays = {"01-01": "New Year", "07-04": "Summer Sale",
                "11-28": "Black Friday", "12-25": "Christmas", "12-26": "Boxing Day"}
    df["holiday_name"] = hol.map(holidays)
    df["is_holiday"] = df["holiday_name"].notna()
    return df[["date_key", "full_date", "day_of_week", "day_name", "is_weekend",
               "week_of_year", "month_number", "month_name", "quarter", "year",
               "fiscal_year", "fiscal_quarter", "season", "is_holiday", "holiday_name"]]


def build_dim_product(n: int, rng) -> pd.DataFrame:
    """SKUs with realistic cost/price margins and a latent popularity that
    drives demand. ABC/XYZ are assigned after we know realised behaviour, but
    we seed a velocity class here to shape demand."""
    cats = list(CATEGORIES.keys())
    cat = rng.choice(cats, size=n)
    subcat = [rng.choice(CATEGORIES[c]) for c in cat]
    # Latent popularity: lognormal => a few blockbusters, a long slow tail
    popularity = rng.lognormal(mean=0.0, sigma=1.1, size=n)
    unit_cost = np.round(rng.uniform(1.5, 220, size=n), 2)
    margin = rng.uniform(0.25, 0.65, size=n)             # 25%-65% target margin
    unit_price = np.round(unit_cost / (1 - margin), 2)
    df = pd.DataFrame({
        "product_key": np.arange(1, n + 1),
        "sku": [f"SKU-{i:06d}" for i in range(1, n + 1)],
        "product_name": [f"{s} Item {i}" for i, s in enumerate(subcat, 1)],
        "category": cat,
        "subcategory": subcat,
        "brand": [f"Brand-{rng.integers(1, 400):03d}" for _ in range(n)],
        "unit_cost": unit_cost,
        "unit_price": unit_price,
        "standard_margin_pct": np.round(margin * 100, 2),
        "_popularity": popularity,                       # internal, dropped on export
    })
    # XYZ (demand variability) assigned now; ABC assigned post-simulation by revenue
    df["xyz_class"] = rng.choice(["X", "Y", "Z"], size=n, p=[0.3, 0.4, 0.3])
    # Lifecycle: most active; some launched late, some discontinued (dead-stock seed)
    df["launch_date"] = pd.NaT
    df["discontinue_date"] = pd.NaT
    df["is_active"] = True
    disc_idx = rng.choice(n, size=int(n * 0.08), replace=False)   # 8% discontinued
    df.loc[disc_idx, "is_active"] = False
    return df


def build_dim_supplier(n: int, rng) -> pd.DataFrame:
    tiers = rng.choice(list(RELIABILITY_TIERS.keys()), size=n, p=[0.35, 0.45, 0.20])
    df = pd.DataFrame({
        "supplier_key": np.arange(1, n + 1),
        "supplier_id": [f"SUP-{i:04d}" for i in range(1, n + 1)],
        "supplier_name": [f"Supplier {i}" for i in range(1, n + 1)],
        "country": rng.choice(["USA", "China", "Germany", "Vietnam", "Mexico", "India"], size=n),
        "region": rng.choice(REGIONS, size=n),
        "category_specialisation": rng.choice(list(CATEGORIES.keys()), size=n),
        "reliability_tier": tiers,
        "is_active": True,
    })
    return df


def build_dim_location(n_stores: int, n_wh: int, rng) -> pd.DataFrame:
    rows = []
    for i in range(1, n_stores + 1):
        rows.append({
            "location_id": f"STR-{i:03d}", "location_type": "STORE",
            "location_name": f"Store {i}", "region": REGIONS[i % 4],
            "store_size_sqft": int(rng.integers(4000, 45000)),
            "store_format": rng.choice(STORE_FORMATS, p=[0.15, 0.6, 0.25]),
            "warehouse_capacity_units": None,
        })
    for i in range(1, n_wh + 1):
        rows.append({
            "location_id": f"WH-{i:02d}", "location_type": "WAREHOUSE",
            "location_name": f"Distribution Centre {i}", "region": REGIONS[i % 4],
            "store_size_sqft": None, "store_format": None,
            "warehouse_capacity_units": int(rng.integers(200000, 900000)),
        })
    df = pd.DataFrame(rows)
    df.insert(0, "location_key", np.arange(1, len(df) + 1))
    df["open_date"] = pd.NaT
    df["is_active"] = True
    return df


def build_dim_employee(n: int, stores: pd.DataFrame, rng) -> pd.DataFrame:
    store_keys = stores.loc[stores["location_type"] == "STORE", "location_key"].values
    df = pd.DataFrame({
        "employee_key": np.arange(1, n + 1),
        "employee_id": [f"EMP-{i:05d}" for i in range(1, n + 1)],
        "employee_name": [f"Employee {i}" for i in range(1, n + 1)],
        "role": rng.choice(EMP_ROLES, size=n, p=[0.5, 0.3, 0.12, 0.08]),
        "home_location_key": rng.choice(store_keys, size=n),
        "is_active": True,
    })
    return df


def build_dim_customer(n: int, rng) -> pd.DataFrame:
    loyalty = rng.choice(LOYALTY_TIERS, size=n, p=[0.55, 0.3, 0.15])
    df = pd.DataFrame({
        "customer_key": np.arange(1, n + 1),
        "customer_id": [f"CUST-{i:06d}" for i in range(1, n + 1)],
        "loyalty_tier": loyalty,
        "is_loyalty_member": loyalty != "None",
        "region": rng.choice(REGIONS, size=n),
    })
    return df


def build_dim_promotion(n: int, dates: pd.DataFrame, rng) -> pd.DataFrame:
    starts = rng.choice(dates["full_date"].values, size=n)
    durations = rng.integers(7, 28, size=n)
    df = pd.DataFrame({
        "promotion_key": np.arange(1, n + 1),
        "promotion_id": [f"PROMO-{i:04d}" for i in range(1, n + 1)],
        "promotion_name": [f"Campaign {i}" for i in range(1, n + 1)],
        "promotion_type": rng.choice(PROMO_TYPES, size=n),
        "discount_pct": np.round(rng.choice([10, 15, 20, 25, 30, 40], size=n), 2),
        "applies_to_level": rng.choice(["SKU", "CATEGORY", "STORE"], size=n),
        "start_date": pd.to_datetime(starts),
        "is_active": True,
    })
    df["end_date"] = df["start_date"] + pd.to_timedelta(durations, unit="D")
    return df


# =============================================================================
# LINKAGE: product -> supplier, product -> stocking locations
# =============================================================================
def assign_product_supplier(products, suppliers, rng) -> dict:
    """Each product is primarily sourced from one supplier (same-ish category)."""
    sup_keys = suppliers["supplier_key"].values
    return {pk: int(rng.choice(sup_keys)) for pk in products["product_key"].values}


def assign_stocking(products, locations, avg_locs, rng) -> list:
    """Return active (product_key, location_key) pairs with demand parameters.
    Not every SKU is stocked everywhere - that realism keeps the snapshot
    tractable and produces genuine assortment differences by location."""
    loc_keys = locations["location_key"].values
    loc_type = dict(zip(locations["location_key"], locations["location_type"]))
    combos = []
    for _, p in products.iterrows():
        k = max(1, int(rng.poisson(avg_locs)))
        chosen = rng.choice(loc_keys, size=min(k, len(loc_keys)), replace=False)
        # Discontinued SKUs go fully dormant -> stock lingers -> genuine dead stock
        life_factor = 1.0 if p["is_active"] else 0.0
        for lk in chosen:
            # Warehouses hold more; stores hold selling quantities
            loc_factor = 3.5 if loc_type[lk] == "WAREHOUSE" else 1.0
            base_daily = p["_popularity"] * 0.06 * loc_factor * life_factor
            combos.append((int(p["product_key"]), int(lk), float(base_daily)))
    return combos


# =============================================================================
# SIMULATION: the inventory ledger that emits sales / POs / snapshots
# =============================================================================
def simulate(cfg, dim_date, products, locations, combos, prod_supplier,
             supplier_tier, rng):
    """Roll each (product, location) forward day by day.

    Emits three fact streams:
      * sales     (one row per product/location/day with sales > 0)
      * purchase_orders (accumulating snapshot: order + received)
      * inventory_snapshot (daily state)
    """
    p_active = cfg["p"]
    # Simulation window (demo shortens it for speed; full uses config date range)
    all_dates = dim_date.sort_values("date_key").reset_index(drop=True)
    if cfg["active_profile"] == "demo":
        all_dates = all_dates.tail(int(p_active["demo_days"])).reset_index(drop=True)

    date_keys = all_dates["date_key"].to_numpy()
    real_dates = all_dates["full_date"].to_numpy()
    n_days = len(all_dates)

    # Precompute daily demand multipliers (seasonal + weekend + holiday)
    month = all_dates["month_number"].to_numpy()
    season_mult = np.select(
        [np.isin(month, [11, 12]), np.isin(month, [6, 7, 8]), np.isin(month, [1, 2])],
        [1.45, 1.15, 0.80], default=1.0)
    weekend_mult = np.where(all_dates["is_weekend"].to_numpy(), 1.25, 1.0)
    holiday_mult = np.where(all_dates["is_holiday"].to_numpy(), 1.6, 1.0)
    day_mult = season_mult * weekend_mult * holiday_mult

    # Snapshot retention: DAILY for the recent window, MONTH-END for older history.
    # This preserves 5 years of sales history while keeping the snapshot fact
    # bounded (directly implements the retention strategy from the DB design).
    months = int(p_active.get("daily_snapshot_months", 18))
    cutoff = pd.Timestamp(real_dates.max()) - pd.DateOffset(months=months)
    is_recent = pd.to_datetime(real_dates) >= cutoff
    mon = all_dates["month_number"].to_numpy()
    is_month_end = np.append(mon[:-1] != mon[1:], True)
    record_snap = np.asarray(is_recent) | is_month_end

    prod_lookup = products.set_index("product_key")[["unit_cost", "unit_price"]].to_dict("index")

    sales_rows, po_rows, snap_rows = [], [], []
    po_counter, order_counter = 0, 0

    # supplier tier resolver
    from_supplier = prod_supplier  # product_key -> supplier_key

    for (pk, lk, base_daily) in combos:
        cost = prod_lookup[pk]["unit_cost"]
        price = prod_lookup[pk]["unit_price"]

        # Demand rate can be 0 (dormant SKU); sizing uses a small floor so
        # policy numbers stay sane without forcing phantom sales.
        avg_daily = base_daily
        size_daily = max(base_daily, 0.02)
        supplier_key = from_supplier[pk]
        # Lateness is driven by the supplier's ACTUAL assigned reliability tier,
        # so dim_supplier.reliability_tier and OTIF stay consistent.
        tier_name = supplier_tier[supplier_key]
        base_lead, late_prob, lead_std = RELIABILITY_TIERS[tier_name]

        reorder_point = int(math.ceil(size_daily * base_lead * 1.3)) + 2
        safety_stock = int(math.ceil(size_daily * 3))
        order_qty = max(int(size_daily * 30), 10)          # ~1 month cover
        on_hand = int(order_qty * rng.uniform(0.4, 1.0))  # random opening stock
        pending = []                                      # list of (arrival_idx, qty)

        for t in range(n_days):
            # 1) receive any POs arriving today
            arrivals = [q for (a, q) in pending if a == t]
            if arrivals:
                on_hand += sum(arrivals)
            pending = [(a, q) for (a, q) in pending if a > t]

            on_order = sum(q for (_, q) in pending)

            # 2) demand & sales (capped by on_hand)
            lam = avg_daily * day_mult[t]
            demand = rng.poisson(lam)
            sold = int(min(demand, on_hand))
            if sold > 0:
                gross = round(sold * price, 2)
                cogs = round(sold * cost, 2)
                sales_rows.append((date_keys[t], pk, lk, sold, price, gross, cost, cogs))
                on_hand -= sold

            # 3) replenishment: if at/under reorder point and nothing pending, order
            if on_hand <= reorder_point and not pending:
                po_counter += 1
                lead = max(1, int(rng.normal(base_lead, lead_std)))
                late = rng.random() < late_prob
                if late:
                    lead += int(rng.integers(3, 12))
                arrival_idx = t + lead
                pending.append((arrival_idx, order_qty))
                exp_idx = t + base_lead
                po_rows.append({
                    "po_number": f"PO-{po_counter:07d}",
                    "order_date_key": int(date_keys[t]),
                    "expected_offset": exp_idx,
                    "received_offset": arrival_idx,
                    "product_key": pk, "supplier_key": supplier_key,
                    "dest_location_key": lk, "ordered_qty": order_qty,
                    "unit_cost": cost, "is_late": late, "lead_time_days": lead,
                })

            # 4) snapshot row (subject to retention window: daily recent / month-end older)
            if record_snap[t]:
                snap_rows.append((
                    int(date_keys[t]), pk, lk, on_hand, round(on_hand * cost, 2),
                    on_order, reorder_point, safety_stock,
                    on_hand <= reorder_point, on_hand == 0))

    # ---- assemble sales ----
    sales = pd.DataFrame(sales_rows, columns=[
        "date_key", "product_key", "location_key", "units_sold_qty",
        "unit_price", "gross_sales_amount", "unit_cost", "cogs_amount"])
    sales.insert(0, "sales_key", np.arange(1, len(sales) + 1))
    # basket / order id: group sales within a store-day into a few baskets
    sales["order_id"] = ("ORD-" + sales["location_key"].astype(str) + "-"
                         + sales["date_key"].astype(str) + "-"
                         + (sales.index % 7).astype(str))

    # ---- assemble purchase orders (resolve offsets to real date_keys) ----
    po = pd.DataFrame(po_rows)
    if len(po):
        idx_to_key = {i: int(date_keys[i]) for i in range(n_days)}
        po["expected_date_key"] = po["expected_offset"].map(
            lambda i: idx_to_key.get(i, int(date_keys[-1])))
        po["received_date_key"] = po["received_offset"].map(
            lambda i: idx_to_key.get(i))     # None if not yet received in window
        po["po_line_amount"] = (po["ordered_qty"] * po["unit_cost"]).round(2)
        # received qty: complete unless late-and-partial (occasionally short)
        short = np.random.random(len(po)) < 0.06
        po["received_qty"] = np.where(short,
                                      (po["ordered_qty"] * 0.85).astype(int),
                                      po["ordered_qty"])
        po.loc[po["received_date_key"].isna(), "received_qty"] = 0
        po["is_complete_flag"] = po["received_qty"] >= po["ordered_qty"]
        po["is_late_flag"] = po["is_late"]
        po["is_otif_flag"] = (~po["is_late_flag"]) & po["is_complete_flag"]
        po.insert(0, "po_line_key", np.arange(1, len(po) + 1))
        po = po[["po_line_key", "po_number", "order_date_key", "expected_date_key",
                 "received_date_key", "product_key", "supplier_key",
                 "dest_location_key", "ordered_qty", "received_qty", "unit_cost",
                 "po_line_amount", "lead_time_days", "is_late_flag",
                 "is_complete_flag", "is_otif_flag"]]

    # ---- assemble snapshot ----
    snap = pd.DataFrame(snap_rows, columns=[
        "snapshot_date_key", "product_key", "location_key", "on_hand_qty",
        "on_hand_value", "on_order_qty", "reorder_point", "safety_stock_qty",
        "is_below_reorder_flag", "is_stockout_flag"])
    snap.insert(0, "snapshot_key", np.arange(1, len(snap) + 1))
    # days_of_supply added downstream (needs avg demand); approximate here
    snap["days_of_supply"] = np.nan

    return sales, po, snap


# =============================================================================
# RETURNS & TRANSFERS (derived from sales / network)
# =============================================================================
def generate_returns(sales, customers, rng, rate=0.04):
    """A subset of sales come back, concentrated on certain reasons."""
    n = int(len(sales) * rate)
    if n == 0:
        return pd.DataFrame()
    picks = sales.sample(n=n, random_state=int(rng.integers(1e6)))
    cust = customers["customer_key"].sample(n=n, replace=True,
                                            random_state=int(rng.integers(1e6))).values
    df = pd.DataFrame({
        "return_key": np.arange(1, n + 1),
        "return_id": [f"RET-{i:07d}" for i in range(1, n + 1)],
        "return_date_key": picks["date_key"].values,
        "product_key": picks["product_key"].values,
        "location_key": picks["location_key"].values,
        "customer_key": cust,
        "original_order_id": picks["order_id"].values,
        "returned_qty": np.maximum(1, (picks["units_sold_qty"].values * 0.5).astype(int)),
        "refund_amount": (picks["unit_price"].values *
                          np.maximum(1, (picks["units_sold_qty"].values * 0.5).astype(int))).round(2),
        "return_reason_code": rng.choice(RETURN_REASONS, size=n,
                                         p=[0.22, 0.12, 0.10, 0.36, 0.12, 0.08]),
    })
    return df


def generate_transfers(snap, locations, rng, n_transfers=None):
    """Inter-location rebalancing: move stock from a source to a destination."""
    if n_transfers is None:
        n_transfers = max(50, len(snap) // 400)
    loc_keys = locations["location_key"].values
    date_keys = snap["snapshot_date_key"].unique()
    prod_keys = snap["product_key"].unique()
    src = rng.choice(loc_keys, size=n_transfers)
    dst = rng.choice(loc_keys, size=n_transfers)
    mask = src == dst                      # avoid self-transfers
    dst[mask] = (dst[mask] % len(loc_keys)) + 1
    df = pd.DataFrame({
        "transfer_key": np.arange(1, n_transfers + 1),
        "transfer_id": [f"TRF-{i:06d}" for i in range(1, n_transfers + 1)],
        "transfer_date_key": rng.choice(date_keys, size=n_transfers),
        "product_key": rng.choice(prod_keys, size=n_transfers),
        "source_location_key": src,
        "dest_location_key": dst,
        "transfer_qty": rng.integers(5, 120, size=n_transfers),
    })
    df["transfer_cost"] = (df["transfer_qty"] * rng.uniform(0.5, 3.0, size=n_transfers)).round(2)
    return df


# =============================================================================
# ABC classification (post-simulation, by realised revenue - true Pareto)
# =============================================================================
def classify_abc(products, sales):
    rev = sales.groupby("product_key")["gross_sales_amount"].sum().sort_values(ascending=False)
    cum = rev.cumsum() / rev.sum()
    abc = pd.Series("C", index=rev.index)
    abc[cum <= 0.80] = "A"
    abc[(cum > 0.80) & (cum <= 0.95)] = "B"
    products = products.copy()
    products["abc_class"] = products["product_key"].map(abc).fillna("C")
    return products


# =============================================================================
# Deliberate dirty-data injection (RAW layer only)
# =============================================================================
def inject_dirty(sales, cfg, rng):
    """Add documented, cleanable defects so ETL has real work to do."""
    dq = cfg["data_quality"]
    s = sales.copy()
    # 1) missing values in a nullable-ish column
    n_missing = int(len(s) * dq["inject_missing_pct"])
    if n_missing:
        idx = rng.choice(len(s), size=n_missing, replace=False)
        s.loc[s.index[idx], "unit_price"] = np.nan
    # 2) duplicate rows
    n_dupe = int(len(s) * dq["inject_duplicate_pct"])
    if n_dupe:
        dupes = s.sample(n=n_dupe, random_state=cfg["seed"])
        s = pd.concat([s, dupes], ignore_index=True)
    return s
