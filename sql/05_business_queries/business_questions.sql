/* ============================================================================
   Retail Inventory Intelligence Platform  -  BUSINESS QUERIES
   ----------------------------------------------------------------------------
   54 business questions, each solved with production SQL.
   Target engine: PostgreSQL 15+ (queries are ANSI-standard and portable).
   Every query answers a real stakeholder question from the BRD.

   Reads from the `dw` star schema. In production these run against
   dw.fact_* / dw.dim_*; schema-qualify as needed.
   ============================================================================ */


/* ---------------------------------------------------------------------------
   THEME A — INVENTORY HEALTH
   --------------------------------------------------------------------------- */

/* Q1 | Which SKU-locations are at or below reorder point right now?
   Value: the daily reorder worklist for purchasing.
   Technique: latest-snapshot subquery + join. */
SELECT p.sku, p.product_name, l.location_name, l.location_type,
       s.on_hand_qty, s.reorder_point, s.on_order_qty
FROM fact_inventory_snapshot s
JOIN dim_product  p ON p.product_key  = s.product_key
JOIN dim_location l ON l.location_key = s.location_key
WHERE s.snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
  AND s.is_below_reorder_flag = TRUE
  AND s.on_order_qty = 0
ORDER BY (s.reorder_point - s.on_hand_qty) DESC;

/* Q2 | Where are we currently stocked out, by region?
   Value: immediate lost-sales exposure by region.
   Technique: aggregation with FILTER. */
SELECT l.region,
       COUNT(*) FILTER (WHERE s.is_stockout_flag) AS stockout_lines,
       COUNT(*)                                   AS total_lines,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.is_stockout_flag) / COUNT(*), 2) AS stockout_pct
FROM fact_inventory_snapshot s
JOIN dim_location l ON l.location_key = s.location_key
WHERE s.snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
GROUP BY l.region
ORDER BY stockout_pct DESC;

/* Q3 | Days of supply per SKU-location (latest), flagged by risk band.
   Value: how long until we run out.
   Technique: CASE banding on a computed ratio, avg daily demand join. */
WITH demand AS (
  SELECT product_key, location_key,
         SUM(units_sold_qty) / 90.0 AS avg_daily_demand
  FROM fact_sales f
  JOIN dim_date d ON d.date_key = f.date_key
  WHERE d.full_date >= (SELECT MAX(full_date) FROM dim_date WHERE date_key <=
                        (SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)) - INTERVAL '90 days'
  GROUP BY product_key, location_key
)
SELECT p.sku, l.location_name, s.on_hand_qty,
       ROUND(dm.avg_daily_demand, 3) AS avg_daily_demand,
       ROUND(s.on_hand_qty / NULLIF(dm.avg_daily_demand, 0), 1) AS days_of_supply,
       CASE WHEN dm.avg_daily_demand IS NULL THEN 'No recent demand'
            WHEN s.on_hand_qty / NULLIF(dm.avg_daily_demand,0) < 7  THEN 'Critical (<7d)'
            WHEN s.on_hand_qty / NULLIF(dm.avg_daily_demand,0) < 21 THEN 'Watch (<21d)'
            ELSE 'Healthy' END AS supply_band
FROM fact_inventory_snapshot s
JOIN dim_product  p  ON p.product_key  = s.product_key
JOIN dim_location l  ON l.location_key = s.location_key
LEFT JOIN demand  dm ON dm.product_key = s.product_key AND dm.location_key = s.location_key
WHERE s.snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
  AND s.on_hand_qty > 0
ORDER BY days_of_supply NULLS LAST
LIMIT 200;

/* Q4 | Dead stock: SKUs holding inventory but with no sales in 180 days.
   Value: capital trapped in non-moving stock — a release opportunity.
   Technique: anti-join (LEFT JOIN ... IS NULL) + date window. */
WITH last_sale AS (
  SELECT f.product_key, MAX(d.full_date) AS last_sold_date
  FROM fact_sales f JOIN dim_date d ON d.date_key = f.date_key
  GROUP BY f.product_key
),
current_stock AS (
  SELECT product_key, SUM(on_hand_qty) AS on_hand_qty, SUM(on_hand_value) AS on_hand_value
  FROM fact_inventory_snapshot
  WHERE snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
  GROUP BY product_key
)
SELECT p.sku, p.product_name, p.category, cs.on_hand_qty,
       ROUND(cs.on_hand_value, 2) AS trapped_value, ls.last_sold_date
FROM current_stock cs
JOIN dim_product p ON p.product_key = cs.product_key
LEFT JOIN last_sale ls ON ls.product_key = cs.product_key
WHERE cs.on_hand_qty > 0
  AND (ls.last_sold_date IS NULL
       OR ls.last_sold_date < (SELECT MAX(full_date) FROM dim_date
                               WHERE date_key <= (SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot))
                              - INTERVAL '180 days')
ORDER BY trapped_value DESC;

/* Q5 | Overstock candidates: > 120 days of supply on hand.
   Value: markdown / stop-buy candidates freeing working capital.
   Technique: CTE demand + ratio threshold. */
WITH demand AS (
  SELECT product_key, SUM(units_sold_qty) / 90.0 AS avg_daily_demand
  FROM fact_sales f JOIN dim_date d ON d.date_key = f.date_key
  WHERE d.full_date >= (SELECT MAX(full_date) FROM dim_date) - INTERVAL '90 days'
  GROUP BY product_key
),
stock AS (
  SELECT product_key, SUM(on_hand_qty) AS on_hand_qty, SUM(on_hand_value) AS on_hand_value
  FROM fact_inventory_snapshot
  WHERE snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
  GROUP BY product_key
)
SELECT p.sku, p.category, st.on_hand_qty, ROUND(st.on_hand_value,2) AS on_hand_value,
       ROUND(st.on_hand_qty / NULLIF(dm.avg_daily_demand,0), 0) AS days_of_supply
FROM stock st
JOIN dim_product p ON p.product_key = st.product_key
JOIN demand dm ON dm.product_key = st.product_key
WHERE st.on_hand_qty / NULLIF(dm.avg_daily_demand,0) > 120
ORDER BY on_hand_value DESC;

/* Q6 | Aged inventory value by age band (proxy via last movement).
   Value: how much capital sits in each freshness bucket.
   Technique: CASE banding + aggregation. */
WITH last_sale AS (
  SELECT product_key, MAX(d.full_date) AS last_sold_date
  FROM fact_sales f JOIN dim_date d ON d.date_key=f.date_key GROUP BY product_key
),
stock AS (
  SELECT product_key, SUM(on_hand_value) AS on_hand_value
  FROM fact_inventory_snapshot
  WHERE snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
  GROUP BY product_key
)
SELECT CASE
         WHEN ls.last_sold_date IS NULL THEN '5. 180+ / never'
         WHEN ls.last_sold_date >= (SELECT MAX(full_date) FROM dim_date) - INTERVAL '30 days'  THEN '1. 0-30d'
         WHEN ls.last_sold_date >= (SELECT MAX(full_date) FROM dim_date) - INTERVAL '60 days'  THEN '2. 31-60d'
         WHEN ls.last_sold_date >= (SELECT MAX(full_date) FROM dim_date) - INTERVAL '90 days'  THEN '3. 61-90d'
         WHEN ls.last_sold_date >= (SELECT MAX(full_date) FROM dim_date) - INTERVAL '180 days' THEN '4. 91-180d'
         ELSE '5. 180+ / never' END AS age_band,
       ROUND(SUM(st.on_hand_value),2) AS inventory_value,
       COUNT(*) AS sku_count
FROM stock st LEFT JOIN last_sale ls ON ls.product_key = st.product_key
GROUP BY age_band ORDER BY age_band;

/* Q7 | Inventory turnover by category.
   Value: how efficiently each category converts stock to sales.
   Technique: two aggregations combined (COGS / avg inventory). */
WITH cogs AS (
  SELECT p.category, SUM(f.cogs_amount) AS total_cogs
  FROM fact_sales f JOIN dim_product p ON p.product_key=f.product_key
  GROUP BY p.category
),
avg_inv AS (
  SELECT p.category, AVG(s.on_hand_value) AS avg_inv_value
  FROM fact_inventory_snapshot s JOIN dim_product p ON p.product_key=s.product_key
  GROUP BY p.category
)
SELECT c.category, ROUND(c.total_cogs,0) AS total_cogs,
       ROUND(a.avg_inv_value,0) AS avg_inventory_value,
       ROUND(c.total_cogs / NULLIF(a.avg_inv_value,0), 2) AS inventory_turnover
FROM cogs c JOIN avg_inv a ON a.category=c.category
ORDER BY inventory_turnover DESC;

/* Q8 | Days Inventory Outstanding (DIO) by category.
   Value: average days stock sits before selling.
   Technique: derived metric from turnover. */
WITH turns AS (
  SELECT p.category,
         SUM(f.cogs_amount) AS total_cogs,
         AVG(s.on_hand_value) AS avg_inv
  FROM dim_product p
  LEFT JOIN fact_sales f ON f.product_key=p.product_key
  LEFT JOIN fact_inventory_snapshot s ON s.product_key=p.product_key
  GROUP BY p.category
)
SELECT category,
       ROUND(365.0 / NULLIF(SUM(total_cogs)/NULLIF(AVG(avg_inv),0),0), 1) AS dio_days
FROM turns GROUP BY category ORDER BY dio_days DESC;

/* Q9 | GMROI (Gross Margin Return on Inventory) — top & bottom SKUs.
   Value: the retail gold-standard — margin earned per $ of inventory.
   Technique: margin ÷ avg inventory cost. */
WITH margin AS (
  SELECT product_key, SUM(gross_margin_amount) AS gm
  FROM fact_sales GROUP BY product_key
),
avg_cost AS (
  SELECT product_key, AVG(on_hand_value) AS avg_inv_cost
  FROM fact_inventory_snapshot GROUP BY product_key
)
SELECT p.sku, p.category, ROUND(m.gm,0) AS gross_margin,
       ROUND(a.avg_inv_cost,0) AS avg_inv_cost,
       ROUND(m.gm / NULLIF(a.avg_inv_cost,0), 2) AS gmroi
FROM margin m JOIN avg_cost a ON a.product_key=m.product_key
JOIN dim_product p ON p.product_key=m.product_key
WHERE a.avg_inv_cost > 0
ORDER BY gmroi DESC
LIMIT 25;

/* Q10 | Top 20 SKUs by current inventory value (capital concentration).
   Value: where working capital is concentrated.
   Technique: latest snapshot aggregation + rank. */
SELECT p.sku, p.product_name, p.category,
       SUM(s.on_hand_qty) AS on_hand_qty,
       ROUND(SUM(s.on_hand_value),2) AS inventory_value,
       RANK() OVER (ORDER BY SUM(s.on_hand_value) DESC) AS value_rank
FROM fact_inventory_snapshot s JOIN dim_product p ON p.product_key=s.product_key
WHERE s.snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
GROUP BY p.sku, p.product_name, p.category
ORDER BY inventory_value DESC LIMIT 20;

/* Q11 | Month-end inventory value trend with month-over-month change.
   Value: is total inventory growing or shrinking?
   Technique: window LAG for period-over-period delta. */
WITH monthly AS (
  SELECT d.year, d.month_number,
         SUM(s.on_hand_value) AS inv_value
  FROM fact_inventory_snapshot s JOIN dim_date d ON d.date_key=s.snapshot_date_key
  WHERE d.date_key = (SELECT MAX(date_key) FROM dim_date d2
                      WHERE d2.year=d.year AND d2.month_number=d.month_number
                        AND d2.date_key IN (SELECT snapshot_date_key FROM fact_inventory_snapshot))
  GROUP BY d.year, d.month_number
)
SELECT year, month_number, ROUND(inv_value,0) AS inventory_value,
       ROUND(inv_value - LAG(inv_value) OVER (ORDER BY year, month_number), 0) AS mom_change
FROM monthly ORDER BY year, month_number;

/* Q12 | Most frequently stocked-out SKUs (across the period).
   Value: chronic availability failures needing policy fixes.
   Technique: count of stock-out days per SKU. */
SELECT p.sku, p.product_name, p.category,
       COUNT(*) FILTER (WHERE s.is_stockout_flag) AS stockout_days,
       COUNT(*) AS observed_days,
       ROUND(100.0*COUNT(*) FILTER (WHERE s.is_stockout_flag)/COUNT(*),1) AS stockout_rate_pct
FROM fact_inventory_snapshot s JOIN dim_product p ON p.product_key=s.product_key
GROUP BY p.sku, p.product_name, p.category
HAVING COUNT(*) FILTER (WHERE s.is_stockout_flag) > 0
ORDER BY stockout_days DESC LIMIT 25;


/* ---------------------------------------------------------------------------
   THEME B — SALES & DEMAND
   --------------------------------------------------------------------------- */

/* Q13 | Top 10 stores by net revenue. */
SELECT l.location_name, l.region,
       ROUND(SUM(f.net_sales_amount),2) AS net_revenue,
       SUM(f.units_sold_qty) AS units
FROM fact_sales f JOIN dim_location l ON l.location_key=f.location_key
WHERE l.location_type='STORE'
GROUP BY l.location_name, l.region
ORDER BY net_revenue DESC LIMIT 10;

/* Q14 | Revenue by region and category (cross-tab source). */
SELECT l.region, p.category,
       ROUND(SUM(f.net_sales_amount),2) AS revenue
FROM fact_sales f
JOIN dim_location l ON l.location_key=f.location_key
JOIN dim_product  p ON p.product_key =f.product_key
GROUP BY l.region, p.category
ORDER BY l.region, revenue DESC;

/* Q15 | Month-over-month revenue growth %.
   Technique: window LAG on aggregated series. */
WITH m AS (
  SELECT d.year, d.month_number, SUM(f.net_sales_amount) AS rev
  FROM fact_sales f JOIN dim_date d ON d.date_key=f.date_key
  GROUP BY d.year, d.month_number
)
SELECT year, month_number, ROUND(rev,0) AS revenue,
       ROUND(100.0*(rev - LAG(rev) OVER (ORDER BY year,month_number))
             / NULLIF(LAG(rev) OVER (ORDER BY year,month_number),0), 1) AS mom_growth_pct
FROM m ORDER BY year, month_number;

/* Q16 | Products with declining sales (recent 90d vs prior 90d).
   Value: candidates for review / exit before they become dead stock.
   Technique: conditional aggregation over date windows. */
WITH windows AS (
  SELECT f.product_key,
         SUM(f.units_sold_qty) FILTER (WHERE d.full_date >= (SELECT MAX(full_date) FROM dim_date) - INTERVAL '90 days')  AS recent_units,
         SUM(f.units_sold_qty) FILTER (WHERE d.full_date <  (SELECT MAX(full_date) FROM dim_date) - INTERVAL '90 days'
                                        AND d.full_date >= (SELECT MAX(full_date) FROM dim_date) - INTERVAL '180 days') AS prior_units
  FROM fact_sales f JOIN dim_date d ON d.date_key=f.date_key
  GROUP BY f.product_key
)
SELECT p.sku, p.product_name, p.category, prior_units, recent_units,
       ROUND(100.0*(recent_units-prior_units)/NULLIF(prior_units,0),1) AS change_pct
FROM windows w JOIN dim_product p ON p.product_key=w.product_key
WHERE prior_units > 0 AND recent_units < prior_units
ORDER BY change_pct ASC LIMIT 25;

/* Q17 | Best-selling products by revenue and units. */
SELECT p.sku, p.product_name, p.category,
       SUM(f.units_sold_qty) AS units,
       ROUND(SUM(f.net_sales_amount),2) AS revenue
FROM fact_sales f JOIN dim_product p ON p.product_key=f.product_key
GROUP BY p.sku, p.product_name, p.category
ORDER BY revenue DESC LIMIT 20;

/* Q18 | Gross margin % by category. */
SELECT p.category,
       ROUND(SUM(f.net_sales_amount),0) AS revenue,
       ROUND(SUM(f.gross_margin_amount),0) AS gross_margin,
       ROUND(100.0*SUM(f.gross_margin_amount)/NULLIF(SUM(f.net_sales_amount),0),2) AS margin_pct
FROM fact_sales f JOIN dim_product p ON p.product_key=f.product_key
GROUP BY p.category ORDER BY margin_pct DESC;

/* Q19 | Weekend vs weekday sales lift. */
SELECT CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
       COUNT(DISTINCT d.date_key) AS days,
       ROUND(SUM(f.net_sales_amount),0) AS revenue,
       ROUND(SUM(f.net_sales_amount)/COUNT(DISTINCT d.date_key),0) AS avg_daily_revenue
FROM fact_sales f JOIN dim_date d ON d.date_key=f.date_key
GROUP BY day_type ORDER BY avg_daily_revenue DESC;

/* Q20 | Seasonal demand pattern by month. */
SELECT d.month_number, d.month_name, d.season,
       ROUND(SUM(f.net_sales_amount),0) AS revenue,
       SUM(f.units_sold_qty) AS units
FROM fact_sales f JOIN dim_date d ON d.date_key=f.date_key
GROUP BY d.month_number, d.month_name, d.season
ORDER BY d.month_number;

/* Q21 | Promotion effectiveness: promoted vs non-promoted sales.
   Technique: CASE on nullable promotion_key. */
SELECT CASE WHEN f.promotion_key IS NULL THEN 'No Promotion' ELSE 'Promoted' END AS promo_status,
       COUNT(*) AS sale_lines,
       SUM(f.units_sold_qty) AS units,
       ROUND(AVG(f.units_sold_qty),2) AS avg_units_per_line,
       ROUND(SUM(f.net_sales_amount),0) AS revenue
FROM fact_sales f
GROUP BY promo_status;

/* Q22 | Average basket size (units and value per order). */
WITH baskets AS (
  SELECT order_id, SUM(units_sold_qty) AS units, SUM(net_sales_amount) AS value
  FROM fact_sales GROUP BY order_id
)
SELECT COUNT(*) AS baskets,
       ROUND(AVG(units),2) AS avg_units_per_basket,
       ROUND(AVG(value),2) AS avg_basket_value
FROM baskets;

/* Q23 | Sales concentration (Pareto): cumulative revenue share by SKU rank.
   Value: proves the 80/20 that justifies ABC management.
   Technique: window running total + ranking. */
WITH rev AS (
  SELECT product_key, SUM(net_sales_amount) AS revenue
  FROM fact_sales GROUP BY product_key
),
ranked AS (
  SELECT ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rev_rank,
         SUM(revenue) OVER (ORDER BY revenue DESC
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_rev,
         SUM(revenue) OVER () AS total_rev,
         COUNT(*)    OVER () AS total_skus
  FROM rev
)
SELECT rev_rank,
       ROUND(100.0*rev_rank/total_skus,1) AS sku_pct,
       ROUND(100.0*running_rev/total_rev,1) AS cumulative_revenue_pct
FROM ranked
WHERE rev_rank % CAST(GREATEST(total_skus/20, 1) AS BIGINT) = 0
ORDER BY rev_rank;

/* Q24 | Estimated lost sales from stock-outs.
   Value: quantifies revenue leakage that is otherwise invisible.
   Technique: stock-out days × avg daily demand × price. */
WITH daily_demand AS (
  SELECT f.product_key, f.location_key, AVG(f.units_sold_qty) AS avg_daily_units,
         AVG(f.unit_price) AS price
  FROM fact_sales f GROUP BY f.product_key, f.location_key
),
stockout_days AS (
  SELECT product_key, location_key, COUNT(*) AS so_days
  FROM fact_inventory_snapshot WHERE is_stockout_flag GROUP BY product_key, location_key
)
SELECT p.category,
       ROUND(SUM(so.so_days * dd.avg_daily_units * dd.price),0) AS est_lost_revenue
FROM stockout_days so
JOIN daily_demand dd ON dd.product_key=so.product_key AND dd.location_key=so.location_key
JOIN dim_product p ON p.product_key=so.product_key
GROUP BY p.category ORDER BY est_lost_revenue DESC;


/* ---------------------------------------------------------------------------
   THEME C — SUPPLIER PERFORMANCE
   --------------------------------------------------------------------------- */

/* Q25 | Supplier OTIF ranking. */
SELECT s.supplier_name, s.reliability_tier,
       COUNT(*) AS po_lines,
       ROUND(100.0*COUNT(*) FILTER (WHERE po.is_otif_flag)/COUNT(*),1) AS otif_pct
FROM fact_purchase_order po JOIN dim_supplier s ON s.supplier_key=po.supplier_key
GROUP BY s.supplier_name, s.reliability_tier
HAVING COUNT(*) >= 5
ORDER BY otif_pct ASC LIMIT 20;

/* Q26 | Worst average lead time by supplier. */
SELECT s.supplier_name, s.reliability_tier,
       ROUND(AVG(po.lead_time_days),1) AS avg_lead_days,
       COUNT(*) AS po_lines
FROM fact_purchase_order po JOIN dim_supplier s ON s.supplier_key=po.supplier_key
GROUP BY s.supplier_name, s.reliability_tier
HAVING COUNT(*) >= 5
ORDER BY avg_lead_days DESC LIMIT 20;

/* Q27 | Lead-time variability (reliability, not just speed).
   Technique: STDDEV — a slow-but-consistent supplier beats a fast-but-erratic one. */
SELECT s.supplier_name, s.reliability_tier,
       ROUND(AVG(po.lead_time_days),1) AS avg_lead,
       ROUND(STDDEV_SAMP(po.lead_time_days),2) AS lead_time_stddev
FROM fact_purchase_order po JOIN dim_supplier s ON s.supplier_key=po.supplier_key
GROUP BY s.supplier_name, s.reliability_tier
HAVING COUNT(*) >= 5
ORDER BY lead_time_stddev DESC LIMIT 20;

/* Q28 | Late delivery rate per supplier. */
SELECT s.supplier_name,
       COUNT(*) AS po_lines,
       ROUND(100.0*COUNT(*) FILTER (WHERE po.is_late_flag)/COUNT(*),1) AS late_rate_pct
FROM fact_purchase_order po JOIN dim_supplier s ON s.supplier_key=po.supplier_key
GROUP BY s.supplier_name HAVING COUNT(*) >= 5
ORDER BY late_rate_pct DESC LIMIT 20;

/* Q29 | Supplier defect proxy via product return rate.
   Technique: multi-fact join (returns ↔ sales) rolled to supplier. */
WITH sold AS (
  SELECT product_key, SUM(units_sold_qty) AS units_sold FROM fact_sales GROUP BY product_key
),
returned AS (
  SELECT product_key, SUM(returned_qty) AS units_returned FROM fact_returns GROUP BY product_key
),
prod_sup AS (
  SELECT DISTINCT product_key, supplier_key FROM fact_purchase_order
)
SELECT s.supplier_name,
       COALESCE(SUM(r.units_returned),0) AS units_returned,
       COALESCE(SUM(so.units_sold),0)    AS units_sold,
       ROUND(100.0*COALESCE(SUM(r.units_returned),0)/NULLIF(SUM(so.units_sold),0),2) AS return_rate_pct
FROM prod_sup ps
JOIN dim_supplier s ON s.supplier_key=ps.supplier_key
LEFT JOIN sold so    ON so.product_key=ps.product_key
LEFT JOIN returned r ON r.product_key =ps.product_key
GROUP BY s.supplier_name HAVING SUM(so.units_sold) > 0
ORDER BY return_rate_pct DESC LIMIT 20;

/* Q30 | PO fill rate per supplier (received ÷ ordered). */
SELECT s.supplier_name,
       SUM(po.ordered_qty) AS ordered, SUM(po.received_qty) AS received,
       ROUND(100.0*SUM(po.received_qty)/NULLIF(SUM(po.ordered_qty),0),1) AS fill_rate_pct
FROM fact_purchase_order po JOIN dim_supplier s ON s.supplier_key=po.supplier_key
GROUP BY s.supplier_name HAVING SUM(po.ordered_qty) > 0
ORDER BY fill_rate_pct ASC LIMIT 20;

/* Q31 | Suppliers linked to current stock-outs.
   Value: connects supplier unreliability to lost availability.
   Technique: join current stock-outs to their sourcing supplier. */
WITH current_stockouts AS (
  SELECT DISTINCT product_key FROM fact_inventory_snapshot
  WHERE snapshot_date_key=(SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
    AND is_stockout_flag
),
prod_sup AS (SELECT DISTINCT product_key, supplier_key FROM fact_purchase_order)
SELECT s.supplier_name, s.reliability_tier, COUNT(*) AS stocked_out_skus
FROM current_stockouts cs
JOIN prod_sup ps ON ps.product_key=cs.product_key
JOIN dim_supplier s ON s.supplier_key=ps.supplier_key
GROUP BY s.supplier_name, s.reliability_tier
ORDER BY stocked_out_skus DESC LIMIT 20;

/* Q32 | Top suppliers by spend (PO value). */
SELECT s.supplier_name, s.country,
       ROUND(SUM(po.po_line_amount),0) AS total_spend,
       COUNT(DISTINCT po.po_number) AS purchase_orders
FROM fact_purchase_order po JOIN dim_supplier s ON s.supplier_key=po.supplier_key
GROUP BY s.supplier_name, s.country
ORDER BY total_spend DESC LIMIT 20;

/* Q33 | Composite supplier scorecard (OTIF + lead + fill + spend).
   Value: one ranked table for supplier reviews.
   Technique: multiple CTEs combined into a weighted score. */
WITH perf AS (
  SELECT supplier_key,
         100.0*COUNT(*) FILTER (WHERE is_otif_flag)/COUNT(*) AS otif_pct,
         AVG(lead_time_days) AS avg_lead,
         100.0*SUM(received_qty)/NULLIF(SUM(ordered_qty),0) AS fill_pct,
         SUM(po_line_amount) AS spend
  FROM fact_purchase_order GROUP BY supplier_key HAVING COUNT(*) >= 5
)
SELECT s.supplier_name, s.reliability_tier,
       ROUND(perf.otif_pct,1) AS otif_pct,
       ROUND(perf.avg_lead,1) AS avg_lead_days,
       ROUND(perf.fill_pct,1) AS fill_pct,
       ROUND(perf.spend,0)    AS total_spend,
       ROUND(0.5*perf.otif_pct + 0.3*perf.fill_pct - 0.2*perf.avg_lead, 1) AS composite_score
FROM perf JOIN dim_supplier s ON s.supplier_key=perf.supplier_key
ORDER BY composite_score DESC;

/* Q34 | Single-source risk: products supplied by exactly one supplier. */
SELECT p.category, COUNT(*) AS single_source_skus
FROM (
  SELECT product_key FROM fact_purchase_order
  GROUP BY product_key HAVING COUNT(DISTINCT supplier_key) = 1
) ss JOIN dim_product p ON p.product_key=ss.product_key
GROUP BY p.category ORDER BY single_source_skus DESC;


/* ---------------------------------------------------------------------------
   THEME D — WAREHOUSE & NETWORK
   --------------------------------------------------------------------------- */

/* Q35 | Inventory holding cost by warehouse (25% annual carrying rate). */
SELECT l.location_name,
       ROUND(AVG(s.on_hand_value),0) AS avg_inventory_value,
       ROUND(AVG(s.on_hand_value)*0.25,0) AS annual_holding_cost
FROM fact_inventory_snapshot s JOIN dim_location l ON l.location_key=s.location_key
WHERE l.location_type='WAREHOUSE'
GROUP BY l.location_name ORDER BY annual_holding_cost DESC;

/* Q36 | Warehouse with highest current inventory value. */
SELECT l.location_name, ROUND(SUM(s.on_hand_value),0) AS inventory_value
FROM fact_inventory_snapshot s JOIN dim_location l ON l.location_key=s.location_key
WHERE s.snapshot_date_key=(SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
  AND l.location_type='WAREHOUSE'
GROUP BY l.location_name ORDER BY inventory_value DESC;

/* Q37 | Stock-transfer volume and cost by route. */
SELECT src.location_name AS source, dst.location_name AS destination,
       COUNT(*) AS transfers, SUM(t.transfer_qty) AS units,
       ROUND(SUM(t.transfer_cost),2) AS total_cost
FROM fact_stock_transfer t
JOIN dim_location src ON src.location_key=t.source_location_key
JOIN dim_location dst ON dst.location_key=t.dest_location_key
GROUP BY src.location_name, dst.location_name
ORDER BY units DESC LIMIT 20;

/* Q38 | Net transfer inflow/outflow per location.
   Technique: UNION of signed flows aggregated. */
WITH flows AS (
  SELECT source_location_key AS location_key, -transfer_qty AS qty FROM fact_stock_transfer
  UNION ALL
  SELECT dest_location_key   AS location_key,  transfer_qty AS qty FROM fact_stock_transfer
)
SELECT l.location_name, l.location_type, SUM(f.qty) AS net_units_flow
FROM flows f JOIN dim_location l ON l.location_key=f.location_key
GROUP BY l.location_name, l.location_type
ORDER BY net_units_flow DESC;

/* Q39 | Most-transferred products (rebalancing hotspots). */
SELECT p.sku, p.product_name, COUNT(*) AS transfer_events, SUM(t.transfer_qty) AS units_moved
FROM fact_stock_transfer t JOIN dim_product p ON p.product_key=t.product_key
GROUP BY p.sku, p.product_name ORDER BY units_moved DESC LIMIT 20;

/* Q40 | Warehouse capacity utilisation proxy. */
SELECT l.location_name, l.warehouse_capacity_units,
       SUM(s.on_hand_qty) AS units_on_hand,
       ROUND(100.0*SUM(s.on_hand_qty)/NULLIF(l.warehouse_capacity_units,0),1) AS utilisation_pct
FROM fact_inventory_snapshot s JOIN dim_location l ON l.location_key=s.location_key
WHERE s.snapshot_date_key=(SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
  AND l.location_type='WAREHOUSE'
GROUP BY l.location_name, l.warehouse_capacity_units
ORDER BY utilisation_pct DESC;

/* Q41 | Regional inventory vs sales share (balance check).
   Technique: two aggregations by region + share comparison. */
WITH inv AS (
  SELECT l.region, SUM(s.on_hand_value) AS inv_value
  FROM fact_inventory_snapshot s JOIN dim_location l ON l.location_key=s.location_key
  WHERE s.snapshot_date_key=(SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
  GROUP BY l.region
),
sal AS (
  SELECT l.region, SUM(f.net_sales_amount) AS revenue
  FROM fact_sales f JOIN dim_location l ON l.location_key=f.location_key
  GROUP BY l.region
)
SELECT i.region,
       ROUND(100.0*i.inv_value/SUM(i.inv_value) OVER (),1) AS inv_share_pct,
       ROUND(100.0*s.revenue /SUM(s.revenue)  OVER (),1) AS sales_share_pct
FROM inv i JOIN sal s ON s.region=i.region
ORDER BY inv_share_pct DESC;

/* Q42 | Cross-region transfers (network inefficiency signal). */
SELECT src.region AS from_region, dst.region AS to_region,
       COUNT(*) AS transfers, SUM(t.transfer_qty) AS units
FROM fact_stock_transfer t
JOIN dim_location src ON src.location_key=t.source_location_key
JOIN dim_location dst ON dst.location_key=t.dest_location_key
WHERE src.region <> dst.region
GROUP BY src.region, dst.region ORDER BY units DESC;


/* ---------------------------------------------------------------------------
   THEME E — STORE & PRODUCT PERFORMANCE
   --------------------------------------------------------------------------- */

/* Q43 | Store performance ranking (revenue, margin, units). */
SELECT l.location_name, l.region,
       ROUND(SUM(f.net_sales_amount),0) AS revenue,
       ROUND(100.0*SUM(f.gross_margin_amount)/NULLIF(SUM(f.net_sales_amount),0),1) AS margin_pct,
       RANK() OVER (ORDER BY SUM(f.net_sales_amount) DESC) AS revenue_rank
FROM fact_sales f JOIN dim_location l ON l.location_key=f.location_key
WHERE l.location_type='STORE'
GROUP BY l.location_name, l.region ORDER BY revenue DESC;

/* Q44 | Underperforming stores vs their region average.
   Technique: window AVG partitioned by region. */
WITH store_rev AS (
  SELECT l.location_name, l.region, SUM(f.net_sales_amount) AS revenue
  FROM fact_sales f JOIN dim_location l ON l.location_key=f.location_key
  WHERE l.location_type='STORE'
  GROUP BY l.location_name, l.region
),
with_avg AS (
  SELECT location_name, region, revenue,
         AVG(revenue) OVER (PARTITION BY region) AS region_avg
  FROM store_rev
)
SELECT location_name, region, ROUND(revenue,0) AS revenue,
       ROUND(region_avg,0) AS region_avg,
       ROUND(100.0*(revenue-region_avg)/NULLIF(region_avg,0),1) AS vs_region_pct
FROM with_avg
WHERE revenue < region_avg
ORDER BY vs_region_pct ASC;

/* Q45 | Product performance quadrant (sales vs margin).
   Technique: median splits via subqueries + CASE quadrant. */
WITH prod AS (
  SELECT p.product_key, p.sku, p.category,
         SUM(f.net_sales_amount) AS revenue,
         100.0*SUM(f.gross_margin_amount)/NULLIF(SUM(f.net_sales_amount),0) AS margin_pct
  FROM fact_sales f JOIN dim_product p ON p.product_key=f.product_key
  GROUP BY p.product_key, p.sku, p.category
)
SELECT sku, category, ROUND(revenue,0) AS revenue, ROUND(margin_pct,1) AS margin_pct,
       CASE
         WHEN revenue >= (SELECT AVG(revenue) FROM prod) AND margin_pct >= (SELECT AVG(margin_pct) FROM prod) THEN 'Star (high sales, high margin)'
         WHEN revenue >= (SELECT AVG(revenue) FROM prod) AND margin_pct <  (SELECT AVG(margin_pct) FROM prod) THEN 'Traffic driver (high sales, low margin)'
         WHEN revenue <  (SELECT AVG(revenue) FROM prod) AND margin_pct >= (SELECT AVG(margin_pct) FROM prod) THEN 'Niche (low sales, high margin)'
         ELSE 'Review (low sales, low margin)' END AS quadrant
FROM prod ORDER BY revenue DESC LIMIT 50;

/* Q46 | Category contribution to total revenue (share). */
SELECT p.category,
       ROUND(SUM(f.net_sales_amount),0) AS revenue,
       ROUND(100.0*SUM(f.net_sales_amount)/SUM(SUM(f.net_sales_amount)) OVER (),1) AS revenue_share_pct
FROM fact_sales f JOIN dim_product p ON p.product_key=f.product_key
GROUP BY p.category ORDER BY revenue DESC;

/* Q47 | Return rate by product (top offenders). */
WITH sold AS (SELECT product_key, SUM(units_sold_qty) u FROM fact_sales GROUP BY product_key),
     ret  AS (SELECT product_key, SUM(returned_qty)   r FROM fact_returns GROUP BY product_key)
SELECT p.sku, p.product_name, p.category, s.u AS units_sold,
       COALESCE(r.r,0) AS units_returned,
       ROUND(100.0*COALESCE(r.r,0)/NULLIF(s.u,0),2) AS return_rate_pct
FROM sold s JOIN dim_product p ON p.product_key=s.product_key
LEFT JOIN ret r ON r.product_key=s.product_key
WHERE s.u > 20
ORDER BY return_rate_pct DESC LIMIT 25;

/* Q48 | Return reasons breakdown. */
SELECT return_reason_code,
       COUNT(*) AS return_events, SUM(returned_qty) AS units,
       ROUND(SUM(refund_amount),0) AS refund_value
FROM fact_returns GROUP BY return_reason_code ORDER BY units DESC;


/* ---------------------------------------------------------------------------
   THEME F — EXECUTIVE & EXCEPTIONS
   --------------------------------------------------------------------------- */

/* Q49 | Executive KPI summary (single-row scorecard). */
SELECT
  ROUND((SELECT SUM(net_sales_amount) FROM fact_sales),0) AS total_revenue,
  ROUND(100.0*(SELECT SUM(gross_margin_amount) FROM fact_sales)
        /NULLIF((SELECT SUM(net_sales_amount) FROM fact_sales),0),1) AS gross_margin_pct,
  ROUND((SELECT SUM(on_hand_value) FROM fact_inventory_snapshot
         WHERE snapshot_date_key=(SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)),0) AS current_inventory_value,
  ROUND((SELECT SUM(cogs_amount) FROM fact_sales)
        /NULLIF((SELECT AVG(on_hand_value)*COUNT(DISTINCT product_key) FROM fact_inventory_snapshot),0),2) AS approx_turnover,
  (SELECT COUNT(*) FROM fact_inventory_snapshot
   WHERE snapshot_date_key=(SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot) AND is_stockout_flag) AS current_stockouts;

/* Q50 | EXCEPTION: reorder-now worklist (active, below reorder, nothing on order). */
SELECT p.sku, p.product_name, l.location_name,
       s.on_hand_qty, s.reorder_point, s.safety_stock_qty,
       (s.reorder_point - s.on_hand_qty) AS shortfall
FROM fact_inventory_snapshot s
JOIN dim_product  p ON p.product_key =s.product_key
JOIN dim_location l ON l.location_key=s.location_key
WHERE s.snapshot_date_key=(SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
  AND s.is_below_reorder_flag AND s.on_order_qty=0 AND p.is_active
ORDER BY shortfall DESC LIMIT 100;

/* Q51 | EXCEPTION: overstock markdown candidates (value at risk). */
WITH demand AS (
  SELECT product_key, SUM(units_sold_qty)/90.0 AS adr
  FROM fact_sales f JOIN dim_date d ON d.date_key=f.date_key
  WHERE d.full_date >= (SELECT MAX(full_date) FROM dim_date) - INTERVAL '90 days'
  GROUP BY product_key
),
stock AS (
  SELECT product_key, SUM(on_hand_value) v, SUM(on_hand_qty) q
  FROM fact_inventory_snapshot
  WHERE snapshot_date_key=(SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
  GROUP BY product_key
)
SELECT p.sku, p.category, ROUND(st.v,0) AS inventory_value,
       ROUND(st.q/NULLIF(d.adr,0),0) AS days_of_supply
FROM stock st JOIN dim_product p ON p.product_key=st.product_key
LEFT JOIN demand d ON d.product_key=st.product_key
WHERE COALESCE(st.q/NULLIF(d.adr,0), 9999) > 180
ORDER BY inventory_value DESC LIMIT 50;

/* Q52 | Capital-release opportunity: dead + overstock value combined. */
WITH last_sale AS (
  SELECT product_key, MAX(d.full_date) ls
  FROM fact_sales f JOIN dim_date d ON d.date_key=f.date_key GROUP BY product_key
),
stock AS (
  SELECT product_key, SUM(on_hand_value) v FROM fact_inventory_snapshot
  WHERE snapshot_date_key=(SELECT MAX(snapshot_date_key) FROM fact_inventory_snapshot)
  GROUP BY product_key
)
SELECT
  ROUND(SUM(st.v) FILTER (WHERE ls.ls IS NULL OR ls.ls < (SELECT MAX(full_date) FROM dim_date) - INTERVAL '180 days'),0) AS dead_stock_value,
  ROUND(SUM(st.v),0) AS total_inventory_value,
  ROUND(100.0*SUM(st.v) FILTER (WHERE ls.ls IS NULL OR ls.ls < (SELECT MAX(full_date) FROM dim_date) - INTERVAL '180 days')
        /NULLIF(SUM(st.v),0),1) AS dead_stock_pct
FROM stock st LEFT JOIN last_sale ls ON ls.product_key=st.product_key;

/* Q53 | ABC × XYZ classification matrix (counts).
   Value: how much of the assortment needs tight vs loose control. */
SELECT p.abc_class, p.xyz_class, COUNT(*) AS sku_count
FROM dim_product p
GROUP BY p.abc_class, p.xyz_class
ORDER BY p.abc_class, p.xyz_class;

/* Q54 | Revenue leakage summary (discounts + returns + est. stock-out loss). */
WITH discounts AS (SELECT SUM(discount_amount) d FROM fact_sales),
     returns   AS (SELECT SUM(refund_amount) r FROM fact_returns),
     lost AS (
       SELECT SUM(so.so_days * dd.adu * dd.price) l FROM
         (SELECT product_key, location_key, COUNT(*) so_days
          FROM fact_inventory_snapshot WHERE is_stockout_flag
          GROUP BY product_key, location_key) so
       JOIN (SELECT product_key, location_key, AVG(units_sold_qty) adu, AVG(unit_price) price
             FROM fact_sales GROUP BY product_key, location_key) dd
         ON dd.product_key=so.product_key AND dd.location_key=so.location_key
     )
SELECT ROUND((SELECT d FROM discounts),0) AS discount_leakage,
       ROUND((SELECT r FROM returns),0)   AS returns_leakage,
       ROUND((SELECT l FROM lost),0)      AS est_stockout_lost_revenue;

/* ============================================================================
   END — 54 business queries. Techniques used: CTEs, window functions
   (LAG, RANK, ROW_NUMBER, running SUM, partitioned AVG), correlated & scalar
   subqueries, anti-joins, FILTER aggregates, UNION, multi-fact joins.
   ============================================================================ */
