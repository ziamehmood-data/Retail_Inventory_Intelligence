/* ============================================================================
   RIIP - 01 - DIMENSION TABLES  (dw schema)
   Surrogate integer PKs; business/natural keys carried as UNIQUE columns.
   ============================================================================ */

CREATE TABLE dw.dim_date (
    date_key        INTEGER      PRIMARY KEY,          -- YYYYMMDD surrogate
    full_date       DATE         NOT NULL,
    day_of_week     SMALLINT     NOT NULL,
    day_name        VARCHAR(10)  NOT NULL,
    is_weekend      BOOLEAN      NOT NULL,
    week_of_year    SMALLINT     NOT NULL,
    month_number    SMALLINT     NOT NULL,
    month_name      VARCHAR(10)  NOT NULL,
    quarter         SMALLINT     NOT NULL,
    year            SMALLINT     NOT NULL,
    fiscal_year     SMALLINT     NOT NULL,
    fiscal_quarter  VARCHAR(4)   NOT NULL,
    season          VARCHAR(10)  NOT NULL,
    is_holiday      BOOLEAN      NOT NULL DEFAULT FALSE,
    holiday_name    VARCHAR(40)
);

CREATE TABLE dw.dim_product (
    product_key          INTEGER      PRIMARY KEY,
    sku                  VARCHAR(20)  NOT NULL UNIQUE,
    product_name         VARCHAR(120) NOT NULL,
    category             VARCHAR(40)  NOT NULL,
    subcategory          VARCHAR(40)  NOT NULL,
    brand                VARCHAR(40),
    unit_cost            NUMERIC(12,2) NOT NULL,
    unit_price           NUMERIC(12,2) NOT NULL,
    standard_margin_pct  NUMERIC(5,2),
    abc_class            CHAR(1),
    xyz_class            CHAR(1),
    launch_date          DATE,
    discontinue_date     DATE,
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_dim_product_cost_price CHECK (unit_price >= unit_cost)
);

CREATE TABLE dw.dim_supplier (
    supplier_key             INTEGER      PRIMARY KEY,
    supplier_id              VARCHAR(20)  NOT NULL UNIQUE,
    supplier_name            VARCHAR(80)  NOT NULL,
    country                  VARCHAR(40),
    region                   VARCHAR(20),
    category_specialisation  VARCHAR(40),
    reliability_tier         VARCHAR(10),
    contract_start_date      DATE,
    is_active                BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE dw.dim_location (
    location_key             INTEGER      PRIMARY KEY,
    location_id              VARCHAR(20)  NOT NULL UNIQUE,
    location_type            VARCHAR(10)  NOT NULL,      -- STORE | WAREHOUSE
    location_name            VARCHAR(80)  NOT NULL,
    region                   VARCHAR(20)  NOT NULL,
    city                     VARCHAR(60),
    state                    VARCHAR(40),
    store_size_sqft          INTEGER,                    -- null for warehouses
    store_format             VARCHAR(20),                -- null for warehouses
    warehouse_capacity_units INTEGER,                    -- null for stores
    open_date                DATE,
    is_active                BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_dim_location_type CHECK (location_type IN ('STORE','WAREHOUSE'))
);

CREATE TABLE dw.dim_customer (
    customer_key       INTEGER     PRIMARY KEY,
    customer_id        VARCHAR(20) NOT NULL UNIQUE,
    loyalty_tier       VARCHAR(10),
    is_loyalty_member  BOOLEAN     NOT NULL DEFAULT FALSE,
    region             VARCHAR(20),
    signup_date        DATE
);

CREATE TABLE dw.dim_employee (
    employee_key       INTEGER     PRIMARY KEY,
    employee_id        VARCHAR(20) NOT NULL UNIQUE,
    employee_name      VARCHAR(80),
    role               VARCHAR(40),
    home_location_key  INTEGER,
    hire_date          DATE,
    is_active          BOOLEAN     NOT NULL DEFAULT TRUE
);

CREATE TABLE dw.dim_promotion (
    promotion_key     INTEGER      PRIMARY KEY,
    promotion_id      VARCHAR(20)  NOT NULL UNIQUE,
    promotion_name    VARCHAR(80),
    promotion_type    VARCHAR(20),
    discount_pct      NUMERIC(5,2),
    applies_to_level  VARCHAR(20),
    start_date        DATE,
    end_date          DATE,
    is_active         BOOLEAN      NOT NULL DEFAULT TRUE
);
