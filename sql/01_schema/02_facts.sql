/* ============================================================================
   RIIP - 01 - FACT TABLES  (dw schema)
   Three Kimball fact types: transaction, periodic snapshot, accumulating.
   ============================================================================ */

/* --- Transaction fact: one row per sales order line ----------------------- */
CREATE TABLE dw.fact_sales (
    sales_key            BIGINT       PRIMARY KEY,
    order_id             VARCHAR(40)  NOT NULL,          -- degenerate dimension
    date_key             INTEGER      NOT NULL,
    product_key          INTEGER      NOT NULL,
    location_key         INTEGER      NOT NULL,
    customer_key         INTEGER,
    employee_key         INTEGER,
    promotion_key        INTEGER,                        -- null => no promo
    units_sold_qty       INTEGER      NOT NULL,
    unit_price           NUMERIC(12,2),
    gross_sales_amount   NUMERIC(14,2),
    discount_amount      NUMERIC(14,2) DEFAULT 0,
    net_sales_amount     NUMERIC(14,2),
    unit_cost            NUMERIC(12,2),
    cogs_amount          NUMERIC(14,2),
    gross_margin_amount  NUMERIC(14,2),
    CONSTRAINT ck_fact_sales_qty CHECK (units_sold_qty > 0)
);

/* --- Periodic snapshot: product x location x day (PARTITIONED) -------------
   Partitioned by month on snapshot_date_key so queries prune to relevant
   months and old partitions can be dropped cheaply (retention). The partition
   key must participate in the primary key, hence the composite PK. */
CREATE TABLE dw.fact_inventory_snapshot (
    snapshot_key           BIGINT      NOT NULL,
    snapshot_date_key      INTEGER     NOT NULL,
    product_key            INTEGER     NOT NULL,
    location_key           INTEGER     NOT NULL,
    on_hand_qty            INTEGER     NOT NULL,
    on_hand_value          NUMERIC(14,2),
    on_order_qty           INTEGER     DEFAULT 0,
    reorder_point          INTEGER,
    safety_stock_qty       INTEGER,
    days_of_supply         NUMERIC(8,2),
    is_below_reorder_flag  BOOLEAN,
    is_stockout_flag       BOOLEAN,
    PRIMARY KEY (snapshot_key, snapshot_date_key)
) PARTITION BY RANGE (snapshot_date_key);

-- Example monthly partitions (auto-created in production via fn below).
CREATE TABLE dw.fact_inventory_snapshot_202501
    PARTITION OF dw.fact_inventory_snapshot
    FOR VALUES FROM (20250101) TO (20250201);
CREATE TABLE dw.fact_inventory_snapshot_202502
    PARTITION OF dw.fact_inventory_snapshot
    FOR VALUES FROM (20250201) TO (20250301);
-- Catch-all so loads never fail on an unprovisioned month:
CREATE TABLE dw.fact_inventory_snapshot_default
    PARTITION OF dw.fact_inventory_snapshot DEFAULT;

/* --- Accumulating snapshot: one PO line, dates fill in over its lifecycle -- */
CREATE TABLE dw.fact_purchase_order (
    po_line_key        BIGINT       PRIMARY KEY,
    po_number          VARCHAR(40)  NOT NULL,            -- degenerate dimension
    order_date_key     INTEGER      NOT NULL,
    expected_date_key  INTEGER,
    received_date_key  INTEGER,                          -- null until received
    product_key        INTEGER      NOT NULL,
    supplier_key       INTEGER      NOT NULL,
    dest_location_key  INTEGER      NOT NULL,
    ordered_qty        INTEGER      NOT NULL,
    received_qty       INTEGER      DEFAULT 0,
    unit_cost          NUMERIC(12,2),
    po_line_amount     NUMERIC(14,2),
    lead_time_days     INTEGER,
    is_late_flag       BOOLEAN,
    is_complete_flag   BOOLEAN,
    is_otif_flag       BOOLEAN
);

/* --- Transaction fact: returns -------------------------------------------- */
CREATE TABLE dw.fact_returns (
    return_key          BIGINT       PRIMARY KEY,
    return_id           VARCHAR(40)  NOT NULL,
    return_date_key     INTEGER      NOT NULL,
    product_key         INTEGER      NOT NULL,
    location_key        INTEGER      NOT NULL,
    customer_key        INTEGER,
    original_order_id   VARCHAR(40),
    returned_qty        INTEGER      NOT NULL,
    refund_amount       NUMERIC(14,2),
    return_reason_code  VARCHAR(40)
);

/* --- Transaction fact: stock transfers (role-played locations) ------------ */
CREATE TABLE dw.fact_stock_transfer (
    transfer_key         BIGINT       PRIMARY KEY,
    transfer_id          VARCHAR(40)  NOT NULL,
    transfer_date_key    INTEGER      NOT NULL,
    product_key          INTEGER      NOT NULL,
    source_location_key  INTEGER      NOT NULL,
    dest_location_key    INTEGER      NOT NULL,
    transfer_qty         INTEGER      NOT NULL,
    transfer_cost        NUMERIC(14,2),
    CONSTRAINT ck_transfer_distinct CHECK (source_location_key <> dest_location_key)
);
