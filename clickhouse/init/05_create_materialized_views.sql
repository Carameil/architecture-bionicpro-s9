-- MaterializedViews for CDC data pipeline (Assignment 4)
-- Automatically transfers data from Kafka to target tables

-- =======================
-- MATERIALIZED VIEWS (Kafka → MergeTree)
-- =======================

-- MaterializedView: customers_kafka → customers
CREATE MATERIALIZED VIEW IF NOT EXISTS bionicpro.customers_mv TO bionicpro.customers AS
SELECT
    customer_id,
    username,
    full_name,
    email,
    phone,
    created_at,
    updated_at
FROM bionicpro.customers_kafka;

-- MaterializedView: prostheses_kafka → prostheses
CREATE MATERIALIZED VIEW IF NOT EXISTS bionicpro.prostheses_mv TO bionicpro.prostheses AS
SELECT
    prosthesis_id,
    customer_id,
    model,
    manufacture_date,
    status,
    created_at,
    updated_at
FROM bionicpro.prostheses_kafka;

-- MaterializedView: orders_kafka → orders
CREATE MATERIALIZED VIEW IF NOT EXISTS bionicpro.orders_mv TO bionicpro.orders AS
SELECT
    order_id,
    customer_id,
    prosthesis_id,
    order_date,
    amount,
    status,
    created_at,
    updated_at
FROM bionicpro.orders_kafka;

-- =======================
-- REPORTING DATA MART (MaterializedView with JOIN)
-- =======================

-- Create aggregated reporting table (replaces user_reports from Assignment 2)
-- This table combines CDC data from CRM with telemetry data
CREATE TABLE IF NOT EXISTS bionicpro.user_reports_cdc (
    user_id String,
    username String,
    report_date Date,
    prosthesis_id String,
    prosthesis_model String,
    prosthesis_manufacture_date Date,
    customer_name String,
    customer_email String,
    total_movements Int64,
    avg_response_time_ms Float64,
    max_response_time_ms Float64,
    min_response_time_ms Float64,
    battery_avg_percent Float64,
    battery_min_percent Float64,
    error_count Int64,
    total_usage_hours Float64,
    _updated_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(_updated_at)
PARTITION BY toYYYYMM(report_date)
ORDER BY (user_id, report_date, prosthesis_id);

-- MaterializedView: Join CRM data (from CDC) with existing telemetry reports
-- This creates a unified data mart combining real-time CRM updates with telemetry
CREATE MATERIALIZED VIEW IF NOT EXISTS bionicpro.user_reports_enriched_mv TO bionicpro.user_reports_cdc AS
SELECT
    r.user_id,
    c.username,
    r.report_date,
    r.prosthesis_id,
    p.model AS prosthesis_model,
    p.manufacture_date AS prosthesis_manufacture_date,
    c.full_name AS customer_name,
    c.email AS customer_email,
    r.total_movements,
    r.avg_response_time_ms,
    r.max_response_time_ms,
    r.min_response_time_ms,
    r.battery_avg_percent,
    r.battery_min_percent,
    r.error_count,
    r.total_usage_hours
FROM bionicpro.user_reports AS r
LEFT JOIN bionicpro.customers AS c ON r.user_id = c.username
LEFT JOIN bionicpro.prostheses AS p ON r.prosthesis_id = p.prosthesis_id
WHERE c.username IS NOT NULL;  -- Ensure customer exists in CRM

