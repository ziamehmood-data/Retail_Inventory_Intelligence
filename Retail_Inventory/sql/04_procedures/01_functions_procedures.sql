/* ============================================================================
   RIIP - 04 - FUNCTIONS & PROCEDURES
   Two things worth automating: monthly partition provisioning, and a
   materialised executive KPI summary refreshed by the daily pipeline.
   ============================================================================ */

/* --- fn_create_snapshot_partition -------------------------------------------
   Provisions next month's partition so nightly loads never hit the DEFAULT
   partition. Call from the ETL orchestrator (e.g. on the 25th for next month). */
CREATE OR REPLACE FUNCTION dw.fn_create_snapshot_partition(p_year INT, p_month INT)
RETURNS void AS $$
DECLARE
    v_from INT := p_year*10000 + p_month*100 + 1;
    v_to   INT := CASE WHEN p_month = 12
                       THEN (p_year+1)*10000 + 0101
                       ELSE p_year*10000 + (p_month+1)*100 + 1 END;
    v_name TEXT := format('fact_inventory_snapshot_%s%s', p_year, lpad(p_month::text,2,'0'));
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = v_name) THEN
        EXECUTE format(
          'CREATE TABLE dw.%I PARTITION OF dw.fact_inventory_snapshot FOR VALUES FROM (%s) TO (%s)',
          v_name, v_from, v_to);
        RAISE NOTICE 'Created partition %', v_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

/* --- Materialised executive KPI summary -------------------------------------
   Pre-aggregates the headline numbers so the Executive dashboard card loads
   instantly instead of scanning facts on every open. */
CREATE MATERIALIZED VIEW IF NOT EXISTS dw.mv_executive_kpis AS
SELECT
    (SELECT SUM(net_sales_amount) FROM dw.fact_sales)                       AS total_revenue,
    (SELECT SUM(gross_margin_amount) FROM dw.fact_sales)                    AS total_gross_margin,
    (SELECT SUM(on_hand_value) FROM dw.fact_inventory_snapshot
     WHERE snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM dw.fact_inventory_snapshot)) AS current_inventory_value,
    (SELECT COUNT(*) FROM dw.fact_inventory_snapshot
     WHERE snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM dw.fact_inventory_snapshot)
       AND is_stockout_flag)                                                AS current_stockouts,
    (SELECT COUNT(*) FROM dw.vw_dead_stock)                                 AS dead_stock_skus;

/* --- usp_refresh_analytics --------------------------------------------------
   Called at the end of the nightly load: refresh planner stats + the MV. */
CREATE OR REPLACE PROCEDURE dw.usp_refresh_analytics()
LANGUAGE plpgsql AS $$
BEGIN
    ANALYZE dw.fact_sales;
    ANALYZE dw.fact_inventory_snapshot;
    ANALYZE dw.fact_purchase_order;
    REFRESH MATERIALIZED VIEW dw.mv_executive_kpis;
    RAISE NOTICE 'Analytics refreshed at %', now();
END;
$$;

-- Usage:
--   CALL dw.usp_refresh_analytics();
--   SELECT dw.fn_create_snapshot_partition(2026, 1);
