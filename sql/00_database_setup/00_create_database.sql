/* ============================================================================
   RIIP - 00 - DATABASE & SCHEMA SETUP  (PostgreSQL 15+)
   ----------------------------------------------------------------------------
   Creates the layered schemas that enforce separation of concerns:
     raw     - source extracts landed as-is (reloadable)
     staging - cleansed / conformed data
     dw      - the governed star schema (the ONLY layer BI reads)
   ============================================================================ */

-- Run once as a superuser to create the database:
-- CREATE DATABASE riip WITH ENCODING 'UTF8';
-- \c riip

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS dw;

COMMENT ON SCHEMA raw     IS 'Landing zone: source extracts, untransformed.';
COMMENT ON SCHEMA staging IS 'Cleansing/conforming layer (dedup, type-cast, validate).';
COMMENT ON SCHEMA dw      IS 'Presentation star schema consumed by Power BI / Excel.';

/* --- Roles: least privilege + RLS foundation ---------------------------------
   Analysts read dw only. The ETL role writes. Regional read roles feed the
   Row-Level Security story implemented in the Power BI model (Section 8). */
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='riip_etl')      THEN CREATE ROLE riip_etl      NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='riip_analyst')  THEN CREATE ROLE riip_analyst  NOLOGIN; END IF;
END $$;

GRANT USAGE ON SCHEMA dw TO riip_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA dw GRANT SELECT ON TABLES TO riip_analyst;
GRANT ALL ON SCHEMA raw, staging, dw TO riip_etl;
