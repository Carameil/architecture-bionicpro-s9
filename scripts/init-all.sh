#!/bin/bash
# Master initialization script for BionicPRO

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "🚀 BionicPRO - Full System Initialization"
echo "=========================================="
echo ""

# Step 1: Wait for all services
echo "📍 Step 1/5: Waiting for services to start..."
bash "$SCRIPT_DIR/wait-for-services.sh"
echo ""

# Step 2: Initialize LDAP
echo "📍 Step 2/5: Initializing LDAP..."
bash "$SCRIPT_DIR/init-ldap.sh"
echo ""

# Step 3: Check Keycloak
echo "📍 Step 3/5: Checking Keycloak..."
bash "$SCRIPT_DIR/init-keycloak.sh"
echo ""

# Step 4: Initialize ClickHouse CDC (Assignment 4)
echo "📍 Step 4/5: Initializing ClickHouse CDC tables..."
bash "$SCRIPT_DIR/init-clickhouse-cdc.sh" || echo "⚠️  ClickHouse CDC initialization had warnings"
echo ""

# Step 5: Register Debezium connector (Assignment 4)
echo "📍 Step 5/5: Registering Debezium connector..."
bash "$PROJECT_DIR/debezium/register-connector.sh" || echo "⚠️  Debezium connector registration had issues"
echo ""

echo "=========================================="
echo "✅ BionicPRO initialization complete!"
echo ""
echo "📊 Service URLs:"
echo "  Assignment 1 (Security):"
echo "  • Frontend:        http://localhost:3000"
echo "  • Keycloak:        http://localhost:8080"
echo "  • BionicPRO Auth:  http://localhost:8000"
echo "  • phpLDAPadmin:    http://localhost:6443"
echo ""
echo "  Assignment 2 (Reports & ETL):"
echo "  • Reports API:     http://localhost:8002"
echo "  • ClickHouse:      http://localhost:8123"
echo "  • Airflow UI:      http://localhost:8081 (admin/admin)"
echo ""
echo "  Assignment 3 (S3 & CDN):"
echo "  • MinIO Console:   http://localhost:9001 (minioadmin/minioadmin)"
echo "  • Nginx CDN:       http://localhost:8090"
echo ""
echo "  Assignment 4 (CDC with Debezium):"
echo "  • PostgreSQL CRM:  localhost:5434 (crmuser/crmpass)"
echo "  • Kafka Connect:   http://localhost:8083"
echo ""
echo "👤 LDAP Test Users:"
echo "  • john.doe / password (prothetic_user)"
echo "  • jane.smith / password (user)"
echo "  • alex.johnson / password (prothetic_user)"
echo ""
echo "🔐 Keycloak Admin:"
echo "  • Username: admin"
echo "  • Password: admin"
echo "  • URL: http://localhost:8080"
echo ""
echo "Run 'make check' to verify all services"

