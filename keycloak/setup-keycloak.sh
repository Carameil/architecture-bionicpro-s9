#!/bin/bash
# Setup script for Keycloak configuration

echo "Setting up Keycloak for BionicPRO..."

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to start..."
until curl -s http://localhost:8080/auth > /dev/null; do
    echo "Waiting for Keycloak..."
    sleep 5
done

# Get admin token
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=admin" \
    -d "password=admin" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

echo "Admin token obtained"

# Create bionicpro realm if not exists
curl -s -X POST "http://localhost:8080/admin/realms" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "realm": "bionicpro",
        "enabled": true,
        "displayName": "BionicPRO",
        "accessTokenLifespan": 120,
        "ssoSessionIdleTimeout": 3600,
        "ssoSessionMaxLifespan": 36000,
        "bruteForceProtected": true,
        "permanentLockout": false,
        "maxFailureWaitSeconds": 900,
        "minimumQuickLoginWaitSeconds": 60,
        "waitIncrementSeconds": 60,
        "quickLoginCheckMilliSeconds": 1000,
        "maxDeltaTimeSeconds": 43200,
        "failureFactor": 30,
        "otpPolicyType": "totp",
        "otpPolicyAlgorithm": "HmacSHA1",
        "otpPolicyInitialCounter": 0,
        "otpPolicyDigits": 6,
        "otpPolicyLookAheadWindow": 1,
        "otpPolicyPeriod": 30
    }'

echo "Realm created/updated"

# Create bionicpro-auth client
curl -s -X POST "http://localhost:8080/admin/realms/bionicpro/clients" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "clientId": "bionicpro-auth",
        "name": "BionicPRO Auth Service",
        "enabled": true,
        "clientAuthenticatorType": "client-secret",
        "secret": "your-client-secret",
        "serviceAccountsEnabled": true,
        "authorizationServicesEnabled": true,
        "publicClient": false,
        "frontchannelLogout": false,
        "protocol": "openid-connect",
        "attributes": {
            "pkce.code.challenge.method": "S256"
        },
        "authenticationFlowBindingOverrides": {},
        "fullScopeAllowed": true,
        "nodeReRegistrationTimeout": -1,
        "defaultClientScopes": [
            "web-origins",
            "profile",
            "roles",
            "email"
        ],
        "optionalClientScopes": [
            "address",
            "phone",
            "offline_access",
            "microprofile-jwt"
        ]
    }'

echo "Client created/updated"

# Configure LDAP federation
curl -s -X POST "http://localhost:8080/admin/realms/bionicpro/components" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "ldap",
        "providerId": "ldap",
        "providerType": "org.keycloak.storage.UserStorageProvider",
        "parentId": "bionicpro",
        "config": {
            "priority": ["1"],
            "editMode": ["READ_ONLY"],
            "syncRegistrations": ["false"],
            "vendor": ["other"],
            "usernameLDAPAttribute": ["uid"],
            "rdnLDAPAttribute": ["uid"],
            "uuidLDAPAttribute": ["entryUUID"],
            "userObjectClasses": ["inetOrgPerson, organizationalPerson"],
            "connectionUrl": ["ldap://openldap:389"],
            "usersDn": ["ou=People,dc=example,dc=com"],
            "authType": ["simple"],
            "bindDn": ["cn=admin,dc=example,dc=com"],
            "bindCredential": ["admin"],
            "searchScope": ["1"],
            "useTruststoreSpi": ["ldapsOnly"],
            "connectionPooling": ["true"],
            "pagination": ["true"],
            "allowKerberosAuthentication": ["false"],
            "batchSizeForSync": ["1000"],
            "fullSyncPeriod": ["-1"],
            "changedSyncPeriod": ["-1"],
            "debug": ["false"]
        }
    }'

echo "LDAP federation configured"

# Create role mapper for LDAP
curl -s -X POST "http://localhost:8080/admin/realms/bionicpro/components" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "group-ldap-mapper",
        "providerId": "group-ldap-mapper",
        "providerType": "org.keycloak.storage.ldap.mappers.LDAPStorageMapper",
        "parentId": "bionicpro",
        "config": {
            "groups.dn": ["ou=Groups,dc=example,dc=com"],
            "group.name.ldap.attribute": ["cn"],
            "group.object.classes": ["groupOfNames"],
            "preserve.group.inheritance": ["true"],
            "membership.ldap.attribute": ["member"],
            "membership.attribute.type": ["DN"],
            "groups.ldap.filter": [],
            "mode": ["LDAP_ONLY"],
            "user.roles.retrieve.strategy": ["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"],
            "memberof.ldap.attribute": ["memberOf"],
            "mapped.group.attributes": ["ou"],
            "drop.non.existing.groups.during.sync": ["false"],
            "groups.path": ["/"]
        }
    }'

echo "LDAP role mapper configured"

# Configure Required Actions - OTP
curl -s -X PUT "http://localhost:8080/admin/realms/bionicpro/authentication/required-actions/CONFIGURE_TOTP" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "alias": "CONFIGURE_TOTP",
        "name": "Configure OTP",
        "providerId": "CONFIGURE_TOTP",
        "enabled": true,
        "defaultAction": true,
        "priority": 10
    }'

echo "MFA/OTP configured as required action"

echo "Keycloak setup complete!"

