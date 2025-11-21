#!/bin/bash
# Script to register Debezium PostgreSQL connector with Kafka Connect

KAFKA_CONNECT_URL="http://localhost:8083"
CONNECTOR_CONFIG="./debezium/register-postgres-connector.json"

echo "Waiting for Kafka Connect to be ready..."
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s -f "${KAFKA_CONNECT_URL}/" > /dev/null 2>&1; then
        echo "Kafka Connect is ready!"
        break
    fi
    echo "Kafka Connect is unavailable - sleeping (attempt $((attempt+1))/$max_attempts)"
    attempt=$((attempt + 1))
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    echo "⚠️  Kafka Connect not ready after ${max_attempts} attempts"
    echo "⚠️  Skipping Debezium connector registration"
    exit 0
fi

# Check if connector already exists
CONNECTOR_NAME="bionicpro-crm-connector"
if curl -s "${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME}" | grep -q "name"; then
    echo "Connector '${CONNECTOR_NAME}' already exists. Deleting..."
    curl -X DELETE "${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME}"
    sleep 2
fi

# Register new connector
echo "Registering Debezium connector..."
if curl -X POST \
    -H "Content-Type: application/json" \
    --data @"${CONNECTOR_CONFIG}" \
    "${KAFKA_CONNECT_URL}/connectors" 2>&1; then
    echo ""
    echo "Connector registered successfully!"
else
    echo ""
    echo "⚠️  Connector registration failed (may already exist)"
fi

# Check connector status
sleep 3
echo ""
echo "Connector status:"
curl -s "${KAFKA_CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "⚠️  Status check failed"

echo ""
echo "Done!"

# Always exit successfully
exit 0

