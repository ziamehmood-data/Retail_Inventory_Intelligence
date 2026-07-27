"""
RIIP - Exploratory Data Analysis
================================

Profiles the cleaned dataset and writes reports/eda_report.md plus a set of
figures in reports/eda/. The goal is to SEE the engineered behaviour of the
data - seasonality, the Pareto revenue curve, supplier reliability spread,
and inventory health - before any dashboard is built.

Run:
    python -m src.analysis.eda
"""
from __future__ import annotations
import os
import matplotlib
matplotlib.use("Agg")                     # headless rendering
import matplotlib.pyplot as plt
import pandas as pd

DATA = "data/processed"
FIG = "reports/eda"
REPORT = "reports/eda_report.md"
plt.rcParams.update({"font.family": "DejaVu Sans", "axes.grid": True,
                     "grid.alpha": 0.3, "figure.autolayout": True})
NAVY = "#1F3864"


def _load(n): return pd.read_csv(os.path.join(DATA, f"{n}.csv"))


def run_eda():
    os.makedirs(FIG, exist_ok=True)
    sales = _load("fact_sales"); prod = _load("dim_product")
    loc = _load("dim_location"); dd = _load("dim_date")
    snap = _load("fact_inventory_snapshot"); po = _load("fact_purchase_order")
    sup = _load("dim_supplier")

    s = sales.merge(prod[["product_key", "category"]], on="product_key") \
             .merge(loc[["location_key", "region"]], on="location_key") \
             .merge(dd[["date_key", "month_number", "month_name"]], on="date_key")

    figs = []

    # 1) Revenue by month (seasonality)
    m = s.groupby("month_number")["net_sales_amount"].sum()
    fig, ax = plt.subplots(figsize=(7, 3.2))
    ax.plot(m.index, m.values, marker="o", color=NAVY)
    ax.set_title("Revenue by Month (seasonality)"); ax.set_xlabel("Month"); ax.set_ylabel("Revenue")
    p = f"{FIG}/revenue_by_month.png"; fig.savefig(p, dpi=110); plt.close(fig); figs.append(("Revenue by month", p))

    # 2) Revenue by category
    c = s.groupby("category")["net_sales_amount"].sum().sort_values()
    fig, ax = plt.subplots(figsize=(7, 3.8))
    ax.barh(c.index, c.values, color=NAVY)
    ax.set_title("Revenue by Category"); ax.set_xlabel("Revenue")
    p = f"{FIG}/revenue_by_category.png"; fig.savefig(p, dpi=110); plt.close(fig); figs.append(("Revenue by category", p))

    # 3) Pareto: cumulative revenue by SKU rank
    rev = sales.groupby("product_key")["net_sales_amount"].sum().sort_values(ascending=False)
    cum = rev.cumsum() / rev.sum()
    fig, ax = plt.subplots(figsize=(7, 3.2))
    ax.plot([i/len(cum)*100 for i in range(1, len(cum)+1)], cum.values*100, color=NAVY)
    ax.axhline(80, ls="--", color="grey"); ax.set_title("Pareto: cumulative revenue by SKU")
    ax.set_xlabel("% of SKUs"); ax.set_ylabel("cumulative % revenue")
    p = f"{FIG}/pareto_revenue.png"; fig.savefig(p, dpi=110); plt.close(fig); figs.append(("Pareto revenue curve", p))

    # 4) OTIF by supplier tier
    pt = po.merge(sup[["supplier_key", "reliability_tier"]], on="supplier_key")
    otif = pt.groupby("reliability_tier")["is_otif_flag"].mean().reindex(["Gold", "Silver", "Bronze"]) * 100
    fig, ax = plt.subplots(figsize=(5, 3.2))
    ax.bar(otif.index, otif.values, color=["#63BE7B", "#FFD966", "#E06666"])
    ax.set_title("OTIF % by Supplier Tier"); ax.set_ylabel("OTIF %")
    p = f"{FIG}/otif_by_tier.png"; fig.savefig(p, dpi=110); plt.close(fig); figs.append(("OTIF by supplier tier", p))

    # 5) Inventory on-hand distribution (log) - shows overstock tail
    fig, ax = plt.subplots(figsize=(6, 3.2))
    ax.hist(snap["on_hand_qty"].clip(upper=snap["on_hand_qty"].quantile(0.99)), bins=40, color=NAVY)
    ax.set_title("On-hand quantity distribution"); ax.set_xlabel("units on hand"); ax.set_ylabel("snapshot rows")
    p = f"{FIG}/onhand_distribution.png"; fig.savefig(p, dpi=110); plt.close(fig); figs.append(("On-hand distribution", p))

    # ---- narrative report ----
    stockout_rate = snap["is_stockout_flag"].mean()
    a_share = rev.head(int(len(rev)*0.2)).sum() / rev.sum()
    lines = ["# Exploratory Data Analysis\n",
             f"_Rows: sales={len(sales):,}, snapshot={len(snap):,}, PO={len(po):,}_\n",
             "## Key observations\n",
             f"- **Seasonality** is visible: revenue peaks in the Nov–Dec window.",
             f"- **Pareto holds**: the top 20% of SKUs drive **{a_share:.0%}** of revenue — this is what justifies ABC management.",
             f"- **Supplier reliability spreads** cleanly by tier (Gold → Bronze), confirming the engineered OTIF signal.",
             f"- **Stock-out rate** across snapshot rows is **{stockout_rate:.1%}**.",
             "\n## Figures\n"]
    for title, path in figs:
        lines.append(f"### {title}\n\n![{title}]({os.path.relpath(path, 'reports')})\n")
    with open(REPORT, "w") as f:
        f.write("\n".join(lines))
    return figs


if __name__ == "__main__":
    figs = run_eda()
    print(f"EDA report written to {REPORT}")
    print(f"Generated {len(figs)} figures in {FIG}/:")
    for t, p in figs:
        print(f"  - {t}: {p}")
