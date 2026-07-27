/* ============================================================================
   RIIP - 03 - ANALYTICAL VIEWS
   Reusable business logic, so queries (and Power BI) don't re-implement it.
   ============================================================================ */

/* Enriched sales: one wide, analysis-ready row per sale line. */
CREATE OR REPLACE VIEW dw.vw_sales_enriched AS
SELECT f.sales_key, f.order_id, d.full_date, d.year, d.month_number, d.season,
       p.sku, p.product_name, p.category, p.subcategory, p.abc_class,
       l.location_name, l.location_type, l.region,
       f.units_sold_qty, f.net_sales_amount, f.cogs_amount, f.gross_margin_amount,
       (f.promotion_key IS NOT NULL) AS is_promoted
FROM dw.fact_sales f
JOIN dw.dim_date     d ON d.date_key     = f.date_key
JOIN dw.dim_product  p ON p.product_key  = f.product_key
JOIN dw.dim_location l ON l.location_key = f.location_key;

/* Current inventory position (latest snapshot). */
CREATE OR REPLACE VIEW dw.vw_current_inventory AS
SELECT s.product_key, s.location_key, p.sku, p.category,
       l.location_name, l.location_type, l.region,
       s.on_hand_qty, s.on_hand_value, s.on_order_qty,
       s.reorder_point, s.safety_stock_qty,
       s.is_below_reorder_flag, s.is_stockout_flag
FROM dw.fact_inventory_snapshot s
JOIN dw.dim_product  p ON p.product_key  = s.product_key
JOIN dw.dim_location l ON l.location_key = s.location_key
WHERE s.snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM dw.fact_inventory_snapshot);

/* Supplier scorecard: OTIF, lead time, fill rate, spend in one place. */
CREATE OR REPLACE VIEW dw.vw_supplier_scorecard AS
SELECT s.supplier_key, s.supplier_name, s.reliability_tier,
       COUNT(*) AS po_lines,
       ROUND(100.0*COUNT(*) FILTER (WHERE po.is_otif_flag)/COUNT(*),1) AS otif_pct,
       ROUND(AVG(po.lead_time_days),1)                       AS avg_lead_days,
       ROUND(STDDEV_SAMP(po.lead_time_days),2)               AS lead_time_stddev,
       ROUND(100.0*SUM(po.received_qty)/NULLIF(SUM(po.ordered_qty),0),1) AS fill_rate_pct,
       ROUND(SUM(po.po_line_amount),0)                       AS total_spend
FROM dw.fact_purchase_order po
JOIN dw.dim_supplier s ON s.supplier_key = po.supplier_key
GROUP BY s.supplier_key, s.supplier_name, s.reliability_tier;

/* Reorder worklist: active SKUs below reorder point with nothing on order. */
CREATE OR REPLACE VIEW dw.vw_reorder_worklist AS
SELECT ci.sku, ci.category, ci.location_name, ci.region,
       ci.on_hand_qty, ci.reorder_point,
       (ci.reorder_point - ci.on_hand_qty) AS shortfall_qty
FROM dw.vw_current_inventory ci
JOIN dw.dim_product p ON p.sku = ci.sku
WHERE ci.is_below_reorder_flag AND ci.on_order_qty = 0 AND p.is_active;

/* Dead stock: holding inventory but no sale in 180 days. */
CREATE OR REPLACE VIEW dw.vw_dead_stock AS
WITH last_sale AS (
  SELECT f.product_key, MAX(d.full_date) AS last_sold_date
  FROM dw.fact_sales f JOIN dw.dim_date d ON d.date_key = f.date_key
  GROUP BY f.product_key
)
SELECT ci.product_key, ci.sku, ci.category,
       SUM(ci.on_hand_qty)   AS on_hand_qty,
       SUM(ci.on_hand_value) AS trapped_value,
       ls.last_sold_date
FROM dw.vw_current_inventory ci
LEFT JOIN last_sale ls ON ls.product_key = ci.product_key
WHERE ci.on_hand_qty > 0
  AND (ls.last_sold_date IS NULL
       OR ls.last_sold_date < (SELECT MAX(full_date) FROM dw.dim_date
                               WHERE date_key <= (SELECT MAX(snapshot_date_key) FROM dw.fact_inventory_snapshot))
                              - INTERVAL '180 days')
GROUP BY ci.product_key, ci.sku, ci.category, ls.last_sold_date;
