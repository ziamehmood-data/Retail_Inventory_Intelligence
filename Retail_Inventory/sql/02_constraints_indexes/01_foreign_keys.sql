/* ============================================================================
   RIIP - 02 - FOREIGN KEYS
   Enforced at the dw layer so orphan facts are impossible. Role-playing
   dimensions (dim_date, dim_location) appear as multiple FKs.
   ============================================================================ */

-- fact_sales
ALTER TABLE dw.fact_sales
  ADD CONSTRAINT fk_sales_date      FOREIGN KEY (date_key)      REFERENCES dw.dim_date(date_key),
  ADD CONSTRAINT fk_sales_product   FOREIGN KEY (product_key)   REFERENCES dw.dim_product(product_key),
  ADD CONSTRAINT fk_sales_location  FOREIGN KEY (location_key)  REFERENCES dw.dim_location(location_key),
  ADD CONSTRAINT fk_sales_customer  FOREIGN KEY (customer_key)  REFERENCES dw.dim_customer(customer_key),
  ADD CONSTRAINT fk_sales_employee  FOREIGN KEY (employee_key)  REFERENCES dw.dim_employee(employee_key),
  ADD CONSTRAINT fk_sales_promotion FOREIGN KEY (promotion_key) REFERENCES dw.dim_promotion(promotion_key);

-- fact_inventory_snapshot (FKs on a partitioned table are inherited by partitions)
ALTER TABLE dw.fact_inventory_snapshot
  ADD CONSTRAINT fk_snap_date     FOREIGN KEY (snapshot_date_key) REFERENCES dw.dim_date(date_key),
  ADD CONSTRAINT fk_snap_product  FOREIGN KEY (product_key)       REFERENCES dw.dim_product(product_key),
  ADD CONSTRAINT fk_snap_location FOREIGN KEY (location_key)      REFERENCES dw.dim_location(location_key);

-- fact_purchase_order (dim_date plays order/expected/received roles)
ALTER TABLE dw.fact_purchase_order
  ADD CONSTRAINT fk_po_order_date FOREIGN KEY (order_date_key)    REFERENCES dw.dim_date(date_key),
  ADD CONSTRAINT fk_po_exp_date   FOREIGN KEY (expected_date_key) REFERENCES dw.dim_date(date_key),
  ADD CONSTRAINT fk_po_recv_date  FOREIGN KEY (received_date_key) REFERENCES dw.dim_date(date_key),
  ADD CONSTRAINT fk_po_product    FOREIGN KEY (product_key)       REFERENCES dw.dim_product(product_key),
  ADD CONSTRAINT fk_po_supplier   FOREIGN KEY (supplier_key)      REFERENCES dw.dim_supplier(supplier_key),
  ADD CONSTRAINT fk_po_dest_loc   FOREIGN KEY (dest_location_key) REFERENCES dw.dim_location(location_key);

-- fact_returns
ALTER TABLE dw.fact_returns
  ADD CONSTRAINT fk_ret_date     FOREIGN KEY (return_date_key) REFERENCES dw.dim_date(date_key),
  ADD CONSTRAINT fk_ret_product  FOREIGN KEY (product_key)     REFERENCES dw.dim_product(product_key),
  ADD CONSTRAINT fk_ret_location FOREIGN KEY (location_key)    REFERENCES dw.dim_location(location_key),
  ADD CONSTRAINT fk_ret_customer FOREIGN KEY (customer_key)    REFERENCES dw.dim_customer(customer_key);

-- fact_stock_transfer (dim_location plays source/dest roles)
ALTER TABLE dw.fact_stock_transfer
  ADD CONSTRAINT fk_trf_date    FOREIGN KEY (transfer_date_key)   REFERENCES dw.dim_date(date_key),
  ADD CONSTRAINT fk_trf_product FOREIGN KEY (product_key)         REFERENCES dw.dim_product(product_key),
  ADD CONSTRAINT fk_trf_src     FOREIGN KEY (source_location_key) REFERENCES dw.dim_location(location_key),
  ADD CONSTRAINT fk_trf_dst     FOREIGN KEY (dest_location_key)   REFERENCES dw.dim_location(location_key);

-- dim_employee self-reference to location
ALTER TABLE dw.dim_employee
  ADD CONSTRAINT fk_emp_location FOREIGN KEY (home_location_key) REFERENCES dw.dim_location(location_key);
