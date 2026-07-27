# RIIP — DAX Measure Library

The authoritative, version-controlled copy of every measure in the semantic model
(the `.pbix` is a binary Git can't diff). Measures live on a hidden `_Measures`
table and are organised into the display folders below. Model uses single-direction
relationships (dimensions filter facts); `dim_date` is marked as the date table.

> **Naming:** measures are Title Case and business-friendly. `[Bracketed]` names
> reference other measures. Every `DIVIDE` guards against divide-by-zero.

---

## Folder: Sales

```dax
Total Revenue = SUM ( fact_sales[net_sales_amount] )
```
The single source of the revenue number every other sales measure builds on.

```dax
Total COGS = SUM ( fact_sales[cogs_amount] )
```
Cost of goods sold — the numerator of turnover and the complement of margin.

```dax
Gross Margin = SUM ( fact_sales[gross_margin_amount] )
```

```dax
Gross Margin % = DIVIDE ( [Gross Margin], [Total Revenue] )
```
Profitability ratio; `DIVIDE` returns blank (not an error) when revenue is 0.

```dax
Units Sold = SUM ( fact_sales[units_sold_qty] )
```

```dax
Total Discount = SUM ( fact_sales[discount_amount] )
```
Feeds the revenue-leakage view; large discounts erode margin invisibly.

```dax
Average Basket Value =
DIVIDE ( [Total Revenue], DISTINCTCOUNT ( fact_sales[order_id] ) )
```
Uses the `order_id` degenerate dimension to reconstruct baskets from lines.

---

## Folder: Time Intelligence

```dax
Revenue LY =
CALCULATE ( [Total Revenue], SAMEPERIODLASTYEAR ( dim_date[full_date] ) )
```
Prior-year comparison; relies on `dim_date` being a contiguous marked date table.

```dax
Revenue YoY % =
DIVIDE ( [Total Revenue] - [Revenue LY], [Revenue LY] )
```

```dax
Revenue PM =
CALCULATE ( [Total Revenue], DATEADD ( dim_date[full_date], -1, MONTH ) )
```
Previous month, for the month-over-month trend.

```dax
Revenue MoM % = DIVIDE ( [Total Revenue] - [Revenue PM], [Revenue PM] )
```

```dax
Revenue YTD = TOTALYTD ( [Total Revenue], dim_date[full_date] )
```
Year-to-date running total for the executive trend.

```dax
Revenue 3M Rolling Avg =
AVERAGEX (
    DATESINPERIOD ( dim_date[full_date], MAX ( dim_date[full_date] ), -3, MONTH ),
    [Total Revenue]
)
```
Smooths spikes so the trend line reads signal, not noise.

---

## Folder: Inventory Health  ⚠ semi-additive

> Inventory is **semi-additive**: it sums across products and locations but **not
> across dates**. These measures use closing/average patterns, never a naïve SUM
> over the snapshot's date range.

```dax
Inventory Value =
CALCULATE (
    SUM ( fact_inventory_snapshot[on_hand_value] ),
    LASTNONBLANK ( dim_date[date_key],
        CALCULATE ( COUNTROWS ( fact_inventory_snapshot ) ) )
)
```
**The single most important measure.** Takes the *closing* inventory value — the
value on the last date with data in the current filter — so it never double-counts
across days. This is the semi-additive pattern an interviewer looks for.

```dax
On Hand Units =
CALCULATE (
    SUM ( fact_inventory_snapshot[on_hand_qty] ),
    LASTNONBLANK ( dim_date[date_key],
        CALCULATE ( COUNTROWS ( fact_inventory_snapshot ) ) )
)
```

```dax
Average Inventory Value =
AVERAGEX (
    VALUES ( dim_date[date_key] ),
    CALCULATE ( SUM ( fact_inventory_snapshot[on_hand_value] ) )
)
```
Average of the *daily* inventory totals — the correct denominator for turnover
(averaging daily balances, not summing them).

```dax
Inventory Turnover = DIVIDE ( [Total COGS], [Average Inventory Value] )
```
How many times inventory sold through in the period. Higher = more efficient.

```dax
Days Inventory Outstanding = DIVIDE ( 365, [Inventory Turnover] )
```
Turnover expressed as days stock sits before selling.

```dax
GMROI = DIVIDE ( [Gross Margin], [Average Inventory Value] )
```
Gross Margin Return on Inventory — the retail gold-standard: margin earned per
dollar of inventory. A GMROI below 1.0 means the stock loses money to hold.

```dax
Stock-out SKU Count =
CALCULATE (
    DISTINCTCOUNT ( fact_inventory_snapshot[product_key] ),
    fact_inventory_snapshot[is_stockout_flag] = TRUE (),
    LASTNONBLANK ( dim_date[date_key],
        CALCULATE ( COUNTROWS ( fact_inventory_snapshot ) ) )
)
```

```dax
Stock-out Rate =
DIVIDE (
    CALCULATE ( COUNTROWS ( fact_inventory_snapshot ),
        fact_inventory_snapshot[is_stockout_flag] = TRUE () ),
    COUNTROWS ( fact_inventory_snapshot )
)
```

```dax
Below Reorder Count =
CALCULATE (
    COUNTROWS ( fact_inventory_snapshot ),
    fact_inventory_snapshot[is_below_reorder_flag] = TRUE (),
    LASTNONBLANK ( dim_date[date_key],
        CALCULATE ( COUNTROWS ( fact_inventory_snapshot ) ) )
)
```

```dax
Annual Carrying Cost = [Average Inventory Value] * 0.25
```
Working-capital cost of holding stock; 25% is the configurable carrying rate.

```dax
Dead Stock Value =
VAR LastMovementByProduct =
    ADDCOLUMNS (
        VALUES ( dim_product[product_key] ),
        "@LastSale",
            CALCULATE ( MAX ( fact_sales[date_key] ) )
    )
VAR Threshold =
    FORMAT ( MAX ( dim_date[full_date] ) - 180, "YYYYMMDD" ) + 0
RETURN
    SUMX (
        FILTER ( LastMovementByProduct,
            ISBLANK ( [@LastSale] ) || [@LastSale] < Threshold ),
        CALCULATE ( [Inventory Value] )
    )
```
Value of SKUs with no sale in 180 days — the capital-release opportunity. Handles
never-sold SKUs (`ISBLANK`) as well as long-dormant ones.

---

## Folder: Supplier

```dax
PO Line Count = COUNTROWS ( fact_purchase_order )
```

```dax
OTIF % =
DIVIDE (
    CALCULATE ( COUNTROWS ( fact_purchase_order ),
        fact_purchase_order[is_otif_flag] = TRUE () ),
    [PO Line Count]
)
```
On-Time-In-Full — the headline supplier reliability metric.

```dax
Late Delivery Rate =
DIVIDE (
    CALCULATE ( COUNTROWS ( fact_purchase_order ),
        fact_purchase_order[is_late_flag] = TRUE () ),
    [PO Line Count]
)
```

```dax
Average Lead Time = AVERAGE ( fact_purchase_order[lead_time_days] )
```

```dax
Lead Time Variability = STDEV.P ( fact_purchase_order[lead_time_days] )
```
Reliability, not just speed — a consistent slow supplier beats an erratic fast one.

```dax
PO Fill Rate =
DIVIDE (
    SUM ( fact_purchase_order[received_qty] ),
    SUM ( fact_purchase_order[ordered_qty] )
)
```

```dax
Supplier Spend = SUM ( fact_purchase_order[po_line_amount] )
```

```dax
Supplier Score =
0.5 * ( [OTIF %] * 100 )
    + 0.3 * ( [PO Fill Rate] * 100 )
    - 0.2 * [Average Lead Time]
```
A composite ranking for supplier reviews — weights reliability and fill against
lead time. Weights are a business lever, documented so they can be tuned.

---

## Folder: Store & Product

```dax
Revenue Rank =
RANKX ( ALLSELECTED ( dim_location[location_name] ), [Total Revenue],, DESC )
```
Ranks stores within the current selection for league-table visuals.

```dax
Store vs Region Avg % =
VAR RegionAvg =
    CALCULATE ( AVERAGEX ( VALUES ( dim_location[location_name] ), [Total Revenue] ),
        ALLEXCEPT ( dim_location, dim_location[region] ) )
RETURN DIVIDE ( [Total Revenue] - RegionAvg, RegionAvg )
```
How far each store sits above/below its region peers — the under-performer view.

```dax
Return Rate =
DIVIDE (
    SUM ( fact_returns[returned_qty] ),
    [Units Sold]
)
```

```dax
Category Revenue Share =
DIVIDE ( [Total Revenue],
    CALCULATE ( [Total Revenue], ALL ( dim_product[category] ) ) )
```

---

## Folder: Exceptions & Estimates

```dax
Estimated Lost Sales =
SUMX (
    fact_inventory_snapshot,
    IF ( fact_inventory_snapshot[is_stockout_flag],
         RELATED ( dim_product[unit_price] )
         * CALCULATE ( AVERAGE ( fact_sales[units_sold_qty] ) ), 0 )
)
```
Quantifies revenue leakage from stock-outs — stock-out days × avg demand × price.
Labelled *estimated* so it is never mistaken for booked revenue.

```dax
Reorder Now Count =
CALCULATE (
    [Below Reorder Count],
    fact_inventory_snapshot[on_order_qty] = 0,
    dim_product[is_active] = TRUE ()
)
```
The purchasing worklist headline: active SKUs below reorder with nothing on order.

```dax
Inventory Health Status =
SWITCH (
    TRUE (),
    [Stock-out Rate] > 0.05, "🔴 Critical",
    [Stock-out Rate] > 0.02, "🟠 Watch",
    "🟢 Healthy"
)
```
Drives KPI-card colour and the mobile summary; thresholds match the BRD targets.

---

## Row-Level Security (roles, not measures)

RLS is enforced with table filters on `dim_location`, applied to two roles:

```dax
// Role: RLS_Region  — a regional manager sees only their region.
// (USERPRINCIPALNAME() maps to a region via a security table in production;
//  shown here as a static example filter.)
[region] = LOOKUPVALUE ( dim_user_region[region],
                         dim_user_region[email], USERPRINCIPALNAME () )

// Role: RLS_Warehouse — a DC manager sees only warehouse locations.
[location_type] = "WAREHOUSE"
```
Because relationships filter one-way from `dim_location` to the facts, filtering the
dimension automatically restricts every fact — sales, inventory, transfers — to the
allowed scope. Executives get an unrestricted role.

---

*44 measures + 2 RLS roles. Every measure has a business purpose; none is decorative.*
