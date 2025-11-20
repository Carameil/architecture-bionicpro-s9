#!/bin/bash
# Script to wait for all services to be ready

set -e

echo "⏳ Waiting for all services to start..."

# Function to wait for HTTP service
wait_for_http() {
    local url=$1
    local service_name=$2
    local max_attempts=60
    local attempt=0

    echo "Waiting for $service_name..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302\|404"; then
            echo "✓ $service_name is ready"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    echo "❌ $service_name failed to start"
    return 1
}

# Wait for Keycloak
wait_for_http "http://localhost:8080/" "Keycloak"

# Wait for BionicPRO Auth
wait_for_http "http://localhost:8000/health" "BionicPRO Auth"

# Wait for Frontend
wait_for_http "http://localhost:3000/" "Frontend"

# Wait for LDAP
echo "Waiting for LDAP..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker exec bionicpro-ldap ldapsearch -x -b "" -s base -H ldap://localhost > /dev/null 2>&1; then
        echo "✓ LDAP is ready"
        break
    fi
    attempt=$((attempt + 1))
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ LDAP failed to start"
    exit 1
fi

echo "✅ All services are ready!"

