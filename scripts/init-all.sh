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
echo "📍 Step 1/3: Waiting for services to start..."
bash "$SCRIPT_DIR/wait-for-services.sh"
echo ""

# Step 2: Initialize LDAP
echo "📍 Step 2/3: Initializing LDAP..."
bash "$SCRIPT_DIR/init-ldap.sh"
echo ""

# Step 3: Check Keycloak
echo "📍 Step 3/3: Checking Keycloak..."
bash "$SCRIPT_DIR/init-keycloak.sh"
echo ""

echo "=========================================="
echo "✅ BionicPRO initialization complete!"
echo ""
echo "📊 Service URLs:"
echo "  • Frontend:        http://localhost:3000"
echo "  • Keycloak:        http://localhost:8080"
echo "  • BionicPRO Auth:  http://localhost:8000"
echo "  • phpLDAPadmin:    http://localhost:6443"
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

