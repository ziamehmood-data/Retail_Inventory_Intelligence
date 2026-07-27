"""
RIIP - Automated KPI Report
===========================

Computes the BRD headline KPIs from the cleaned data and writes
reports/kpi_report.md. This is the "one command, current numbers" report that
replaces the manual monthly spreadsheet the BRD identified as a core pain point.

KPIs: revenue, gross margin %, current inventory value, inventory turnover,
DIO, GMROI, stock-out rate, dead-stock %, OTIF %, average lead time.

Run:
    python -m src.analysis.kpi_report
"""
from __future__ import annotations
import os
from datetime import datetime
import pandas as pd

DATA = "data/processed"
REPORT = "reports/kpi_report.md"
CARRYING_RATE = 0.25
DEAD_STOCK_DAYS = 180


def _load(n): return pd.read_csv(os.path.join(DATA, f"{n}.csv"))


def compute_kpis() -> dict:
    sales = _load("fact_sales"); snap = _load("fact_inventory_snapshot")
    po = _load("fact_purchase_order"); dd = _load("dim_date")

    revenue = sales["net_sales_amount"].sum()
    margin = sales["gross_margin_amount"].sum()
    cogs = sales["cogs_amount"].sum()

    latest = snap["snapshot_date_key"].max()
    cur = snap[snap["snapshot_date_key"] == latest]
    inv_value = cur["on_hand_value"].sum()
    avg_inv = snap.groupby("snapshot_date_key")["on_hand_value"].sum().mean()

    turnover = cogs / avg_inv if avg_inv else 0
    dio = 365 / turnover if turnover else 0
    gmroi = margin / avg_inv if avg_inv else 0

    stockout_rate = cur["is_stockout_flag"].mean()

    # dead stock: value with no sale in last DEAD_STOCK_DAYS
    d = dd.set_index("date_key")["full_date"]
    sales_dates = pd.to_datetime(sales["date_key"].map(d))
    last_sale = sales.assign(dt=sales_dates).groupby("product_key")["dt"].max()
    max_date = pd.to_datetime(dd["full_date"]).max()
    dead_products = last_sale[last_sale < max_date - pd.Timedelta(days=DEAD_STOCK_DAYS)].index
    dead_value = cur[cur["product_key"].isin(dead_products)]["on_hand_value"].sum()
    never_sold = cur[~cur["product_key"].isin(last_sale.index)]["on_hand_value"].sum()
    dead_pct = (dead_value + never_sold) / inv_value if inv_value else 0

    otif = po["is_otif_flag"].mean()
    avg_lead = po["lead_time_days"].mean()

    return {
        "Total Revenue": (revenue, "${:,.0f}"),
        "Gross Margin %": (margin / revenue if revenue else 0, "{:.1%}"),
        "Current Inventory Value": (inv_value, "${:,.0f}"),
        "Inventory Turnover": (turnover, "{:.2f}x"),
        "Days Inventory Outstanding": (dio, "{:.0f} days"),
        "GMROI": (gmroi, "{:.2f}"),
        "Stock-out Rate": (stockout_rate, "{:.1%}"),
        "Dead-stock % (value)": (dead_pct, "{:.1%}"),
        "Annual Carrying Cost": (avg_inv * CARRYING_RATE, "${:,.0f}"),
        "Supplier OTIF %": (otif, "{:.1%}"),
        "Average Lead Time": (avg_lead, "{:.1f} days"),
    }


def build_report() -> str:
    k = compute_kpis()
    lines = ["# KPI Report", f"_Generated {datetime.now():%Y-%m-%d %H:%M} — RIIP automated report_\n",
             "| KPI | Value |", "|---|---:|"]
    for name, (val, fmt) in k.items():
        lines.append(f"| {name} | {fmt.format(val)} |")
    lines.append("\n> Definitions follow the BRD metric catalogue (Section 6). "
                 "Turnover = COGS ÷ average inventory value; GMROI = gross margin ÷ average "
                 "inventory cost; dead stock = value with no movement in "
                 f"{DEAD_STOCK_DAYS} days; carrying cost at {CARRYING_RATE:.0%}.")
    return "\n".join(lines)


if __name__ == "__main__":
    os.makedirs("reports", exist_ok=True)
    md = build_report()
    with open(REPORT, "w") as f:
        f.write(md)
    print(md)
