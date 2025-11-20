#!/bin/bash
# Script to manually trigger LDAP user synchronization in Keycloak

set -e

echo "🔄 Syncing LDAP users with Keycloak..."

# Get admin access token
echo "⏳ Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=admin" \
    -d "password=admin" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -z "$ADMIN_TOKEN" ]; then
    echo "❌ Failed to get admin token. Is Keycloak running?"
    exit 1
fi

echo "✓ Got admin token"

# Get LDAP component ID
echo "⏳ Finding LDAP component..."
LDAP_COMPONENTS=$(curl -s -X GET "http://localhost:8080/admin/realms/reports-realm/components" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json")

LDAP_ID=$(echo "$LDAP_COMPONENTS" | grep -o '"id":"[^"]*"[^}]*"name":"ldap-bionicpro-foreign"' | grep -o '"id":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -z "$LDAP_ID" ]; then
    echo "❌ LDAP component 'ldap-bionicpro-foreign' not found!"
    echo "ℹ️  Available components:"
    echo "$LDAP_COMPONENTS" | grep -o '"name":"[^"]*"' | cut -d'"' -f4
    exit 1
fi

echo "✓ Found LDAP component: $LDAP_ID"

# Trigger full sync
echo "⏳ Triggering full LDAP sync..."
SYNC_RESULT=$(curl -s -X POST "http://localhost:8080/admin/realms/reports-realm/user-storage/$LDAP_ID/sync?action=triggerFullSync" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json")

echo "📊 Sync result:"
echo "$SYNC_RESULT" | grep -o '"[^"]*":[^,}]*' | sed 's/"//g' || echo "$SYNC_RESULT"

# Check if sync was successful
if echo "$SYNC_RESULT" | grep -q '"status":"success"' || echo "$SYNC_RESULT" | grep -q '"added"'; then
    echo "✅ LDAP sync completed successfully!"
    
    # List synced users
    echo ""
    echo "📋 Checking synced users..."
    USERS=$(curl -s -X GET "http://localhost:8080/admin/realms/reports-realm/users?briefRepresentation=true" \
        -H "Authorization: Bearer $ADMIN_TOKEN")
    
    echo "Users in Keycloak:"
    echo "$USERS" | grep -o '"username":"[^"]*"' | cut -d'"' -f4 || echo "No users found"
else
    echo "⚠️  Sync may have failed. Check Keycloak logs: make logs-keycloak"
fi


