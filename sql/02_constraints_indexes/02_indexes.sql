/* ============================================================================
   RIIP - 02 - INDEXES
   Index the columns queries actually join and filter on. BRIN for the huge,
   append-only, time-ordered facts (tiny footprint); partial index for the
   stock-out exception path.
   ============================================================================ */

-- Fact -> dimension join indexes (B-tree)
CREATE INDEX idx_sales_product   ON dw.fact_sales(product_key);
CREATE INDEX idx_sales_location  ON dw.fact_sales(location_key);
CREATE INDEX idx_sales_date      ON dw.fact_sales(date_key);
CREATE INDEX idx_sales_promotion ON dw.fact_sales(promotion_key);

-- Dominant inventory query path (location, product, date)
CREATE INDEX idx_snap_loc_prod_date
    ON dw.fact_inventory_snapshot(location_key, product_key, snapshot_date_key);
CREATE INDEX idx_snap_product ON dw.fact_inventory_snapshot(product_key);

-- PO join + supplier analytics
CREATE INDEX idx_po_supplier ON dw.fact_purchase_order(supplier_key);
CREATE INDEX idx_po_product  ON dw.fact_purchase_order(product_key);
CREATE INDEX idx_po_dest     ON dw.fact_purchase_order(dest_location_key);

-- Returns & transfers
CREATE INDEX idx_ret_product      ON dw.fact_returns(product_key);
CREATE INDEX idx_trf_product      ON dw.fact_stock_transfer(product_key);
CREATE INDEX idx_trf_src          ON dw.fact_stock_transfer(source_location_key);
CREATE INDEX idx_trf_dst          ON dw.fact_stock_transfer(dest_location_key);

-- BRIN: cheap, effective on append-only, date-ordered facts
CREATE INDEX brin_snap_date ON dw.fact_inventory_snapshot USING BRIN (snapshot_date_key);
CREATE INDEX brin_sales_date ON dw.fact_sales USING BRIN (date_key);

-- Partial index: stock-out exception queries touch a small subset
CREATE INDEX idx_snap_stockout ON dw.fact_inventory_snapshot(product_key)
    WHERE is_stockout_flag = TRUE;

-- Update planner statistics after bulk load
ANALYZE dw.fact_sales;
ANALYZE dw.fact_inventory_snapshot;
ANALYZE dw.fact_purchase_order;
