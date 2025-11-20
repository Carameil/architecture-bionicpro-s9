-- Create user_reports mart table
-- This table stores aggregated telemetry + CRM data for user reports

USE bionicpro;

CREATE TABLE IF NOT EXISTS user_reports (
    user_id String,
    report_date Date,
    prosthesis_id String,
    
    -- Telemetry aggregations
    total_movements Int64,
    avg_response_time_ms Float64,
    max_response_time_ms Float64,
    min_response_time_ms Float64,
    battery_avg_percent Float64,
    battery_min_percent Float64,
    error_count Int64,
    total_usage_hours Float64,
    
    -- CRM data
    customer_name String,
    customer_email String,
    prosthesis_model String,
    prosthesis_manufacture_date Date,
    
    -- Metadata
    etl_updated_at DateTime DEFAULT now(),
    data_version UInt32 DEFAULT 1
    
) ENGINE = ReplacingMergeTree(etl_updated_at)
PARTITION BY toYYYYMM(report_date)
ORDER BY (user_id, report_date, prosthesis_id)
SETTINGS index_granularity = 8192;

-- Index for fast user queries
CREATE INDEX IF NOT EXISTS idx_user_date 
ON user_reports (user_id, report_date) 
TYPE minmax GRANULARITY 4;

-- Create view for latest data (handles ReplacingMergeTree deduplication)
CREATE VIEW IF NOT EXISTS user_reports_latest AS
SELECT 
    user_id,
    report_date,
    prosthesis_id,
    total_movements,
    avg_response_time_ms,
    max_response_time_ms,
    min_response_time_ms,
    battery_avg_percent,
    battery_min_percent,
    error_count,
    total_usage_hours,
    customer_name,
    customer_email,
    prosthesis_model,
    prosthesis_manufacture_date,
    etl_updated_at
FROM user_reports
FINAL;
