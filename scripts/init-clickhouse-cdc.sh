#!/bin/bash
# Initialize ClickHouse CDC tables for Assignment 4
# This script executes after ClickHouse is running

CLICKHOUSE_CONTAINER="bionicpro-clickhouse"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "⏳ Waiting for ClickHouse to be ready..."
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker exec "$CLICKHOUSE_CONTAINER" clickhouse-client --query "SELECT 1" > /dev/null 2>&1; then
        echo "✅ ClickHouse is ready"
        break
    fi
    attempt=$((attempt + 1))
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "⚠️  ClickHouse not ready after ${max_attempts} attempts, continuing anyway..."
fi

echo ""

echo "📋 Creating KafkaEngine tables for CDC..."
docker exec -i "$CLICKHOUSE_CONTAINER" clickhouse-client --multiquery < "${PROJECT_ROOT}/clickhouse/init/04_create_kafka_tables.sql" 2>&1 || {
    echo "⚠️  KafkaEngine tables creation error (may already exist)"
}

echo "✅ KafkaEngine tables step complete"

echo ""
echo "📋 Creating MaterializedViews for CDC pipeline..."
docker exec -i "$CLICKHOUSE_CONTAINER" clickhouse-client --multiquery < "${PROJECT_ROOT}/clickhouse/init/05_create_materialized_views.sql" 2>&1 || {
    echo "⚠️  MaterializedViews creation error (may already exist)"
}

echo "✅ MaterializedViews step complete"

echo ""
echo "🔍 Checking CDC tables..."
docker exec "$CLICKHOUSE_CONTAINER" clickhouse-client --query "
    SELECT 
        name as table_name,
        engine
    FROM system.tables 
    WHERE database = 'bionicpro' 
      AND (engine LIKE '%Kafka%' OR name LIKE '%_mv' OR name IN ('customers', 'prostheses', 'orders', 'user_reports_cdc'))
    ORDER BY name
" 2>/dev/null || echo "⚠️  Could not list tables (may not be created yet)"

echo ""
echo "✅ ClickHouse CDC initialization complete"

# Always exit successfully
exit 0

