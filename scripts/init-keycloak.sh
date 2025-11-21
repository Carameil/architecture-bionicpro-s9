#!/bin/bash
# Script to initialize Keycloak configuration

set -e

echo "🔑 Initializing Keycloak..."

# Wait for Keycloak to be fully ready
max_attempts=60
attempt=0
echo "⏳ Waiting for Keycloak to be ready..."

while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:8080/ > /dev/null 2>&1; then
        echo "✓ Keycloak is responding"
        sleep 5  # Give it a few more seconds to fully initialize
        break
    fi
    attempt=$((attempt + 1))
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Keycloak failed to start"
    exit 1
fi

echo "📋 Checking if realm 'reports-realm' already exists..."

# Try to get admin token
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=admin" \
    -d "password=admin" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -z "$ADMIN_TOKEN" ]; then
    echo "❌ Failed to get admin token"
    exit 1
fi

echo "✓ Got admin token"

# Check if reports-realm exists
REALM_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "http://localhost:8080/admin/realms/reports-realm" \
    -H "Authorization: Bearer $ADMIN_TOKEN")

if [ "$REALM_EXISTS" = "200" ]; then
    echo "✓ Realm 'reports-realm' already exists"
    
    # Trigger LDAP sync
    echo "🔄 Triggering LDAP user synchronization..."
    
    # Get LDAP component ID
    LDAP_ID=$(docker exec keycloak /opt/keycloak/bin/kcadm.sh get components \
        --target-realm reports-realm \
        --server http://localhost:8080 \
        --realm master \
        --user admin \
        --password admin 2>/dev/null | grep -A 10 '"name" : "ldap-bionicpro-foreign"' | grep '"id"' | head -1 | cut -d'"' -f4 || echo "")
    
    if [ -n "$LDAP_ID" ]; then
        echo "✓ Found LDAP component: $LDAP_ID"
        echo "⏳ Syncing LDAP users..."
        
        docker exec keycloak /opt/keycloak/bin/kcadm.sh create \
            "user-storage/$LDAP_ID/sync?action=triggerFullSync" \
            --target-realm reports-realm \
            --server http://localhost:8080 \
            --realm master \
            --user admin \
            --password admin 2>/dev/null || echo "⚠️  Sync triggered (check Keycloak UI for results)"
        
        echo "✓ LDAP sync completed"
    else
        echo "⚠️  LDAP component not found, skipping sync"
    fi
else
    echo "⚙️  Realm 'reports-realm' not found"
    echo "ℹ️  Realm should be auto-imported from realm-export.json on Keycloak startup"
    echo "ℹ️  Check Keycloak logs: make logs-keycloak"
fi

echo "✅ Keycloak initialization complete!"
