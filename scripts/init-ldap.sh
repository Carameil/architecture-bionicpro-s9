#!/bin/bash
# Script to initialize LDAP with data

echo "🔄 Waiting for LDAP to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker exec bionicpro-ldap ldapsearch -x -b "" -s base -H ldap://localhost > /dev/null 2>&1; then
        echo "✓ LDAP is ready"
        break
    fi
    attempt=$((attempt + 1))
    echo "Waiting for LDAP... ($attempt/$max_attempts)"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ LDAP failed to start"
    exit 1
fi

echo "📦 Creating base structure..."
cat > /tmp/base.ldif << 'EOF'
dn: dc=example,dc=com
objectClass: top
objectClass: dcObject
objectClass: organization
o: BionicPRO
dc: example
EOF

# Add base structure (ignore error if already exists)
cat /tmp/base.ldif | docker exec -i bionicpro-ldap ldapadd -x -D "cn=admin,dc=example,dc=com" -w admin -H ldap://localhost 2>&1 | grep -v "Already exists" || true

echo "👥 Loading LDAP data from config.ldif..."
if [ -f "ldap/config.ldif" ]; then
    # Add data, continue even if entries already exist (exit code 68)
    cat ldap/config.ldif | docker exec -i bionicpro-ldap ldapadd -c -x -D "cn=admin,dc=example,dc=com" -w admin -H ldap://localhost 2>&1 | tee /tmp/ldap_load.log || true
    
    # Check if there were real errors (not "Already exists")
    if grep -qE "ldap_add:.*(Invalid|No such|Undefined|Constraint|Type or value)" /tmp/ldap_load.log; then
        echo "❌ Error loading LDAP data"
        cat /tmp/ldap_load.log
        exit 1
    fi
    
    echo "✓ LDAP data loaded (existing entries skipped)"
else
    echo "❌ File ldap/config.ldif not found"
    exit 1
fi

echo "🔍 Verifying LDAP data..."
echo "Users:"
docker exec bionicpro-ldap ldapsearch -x -D "cn=admin,dc=example,dc=com" -w admin -b "ou=People,dc=example,dc=com" -H ldap://localhost uid 2>/dev/null | grep "uid:" || echo "No users found"

echo ""
echo "Groups:"
docker exec bionicpro-ldap ldapsearch -x -D "cn=admin,dc=example,dc=com" -w admin -b "ou=Groups,dc=example,dc=com" -H ldap://localhost cn 2>/dev/null | grep "cn:" || echo "No groups found"

echo ""
echo "✅ LDAP initialization complete!"