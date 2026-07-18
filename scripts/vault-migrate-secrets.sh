#!/bin/bash
# Migrate secrets from .env files to Vault

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"

echo "🔄 Vault Secret Migration Script"
echo ""

# Check if Vault token is set
if [ -z "$VAULT_TOKEN" ]; then
    if [ -f "./vault-tokens.env" ]; then
        source ./vault-tokens.env
    else
        echo -e "${RED}❌ VAULT_TOKEN not set${NC}"
        echo "Set it with: export VAULT_TOKEN=your_token"
        echo "Or source the tokens file: source ./vault-tokens.env"
        exit 1
    fi
fi

# Check if Vault is accessible
if ! curl -sf --header "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Vault${NC}"
    echo "Make sure Vault is running and unsealed"
    exit 1
fi

echo "Connected to Vault at $VAULT_ADDR"
echo ""

# Function to store secret in Vault
store_secret() {
    local path=$1
    local key=$2
    local value=$3

    # Get existing secrets at this path
    existing=$(curl -sf --header "X-Vault-Token: $VAULT_TOKEN" \
        "$VAULT_ADDR/v1/secret/data/$path" | jq -r '.data.data // {}')

    # Merge with new key-value
    updated=$(echo "$existing" | jq --arg key "$key" --arg value "$value" \
        '. + {($key): $value}')

    # Store back to Vault
    curl -sf --header "X-Vault-Token: $VAULT_TOKEN" \
        --request POST \
        --data "{\"data\": $updated}" \
        "$VAULT_ADDR/v1/secret/data/$path" > /dev/null
}

# Migrate database secrets
echo "📦 Migrating database secrets..."

if [ -f "databases/.env" ]; then
    source databases/.env

    store_secret "databases/postgres" "username" "${POSTGRES_USER:-postgres}"
    store_secret "databases/postgres" "password" "${POSTGRES_PASSWORD}"
    store_secret "databases/postgres" "port" "${POSTGRES_PORT:-5432}"

    store_secret "databases/redis" "password" "${REDIS_PASSWORD}"
    store_secret "databases/redis" "port" "${REDIS_PORT:-6379}"

    echo -e "${GREEN}✅ Database secrets migrated${NC}"
else
    echo -e "${YELLOW}⚠️  databases/.env not found, skipping${NC}"
fi

# Migrate monitoring secrets
echo "📊 Migrating monitoring secrets..."

if [ -f "monitoring/.env" ]; then
    source monitoring/.env

    store_secret "monitoring/grafana" "admin_user" "${GRAFANA_ADMIN_USER:-admin}"
    store_secret "monitoring/grafana" "admin_password" "${GRAFANA_ADMIN_PASSWORD}"
    store_secret "monitoring/grafana" "port" "${GRAFANA_PORT:-3000}"

    store_secret "monitoring/prometheus" "port" "${PROMETHEUS_PORT:-9090}"

    echo -e "${GREEN}✅ Monitoring secrets migrated${NC}"
else
    echo -e "${YELLOW}⚠️  monitoring/.env not found, skipping${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Secrets Migration Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# List all stored secrets
echo "Stored secrets:"
echo ""

# Database secrets
echo "📦 databases/postgres:"
curl -sf --header "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_ADDR/v1/secret/data/databases/postgres" | jq -r '.data.data | keys[]' | sed 's/^/  - /'

echo ""
echo "📦 databases/redis:"
curl -sf --header "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_ADDR/v1/secret/data/databases/redis" | jq -r '.data.data | keys[]' | sed 's/^/  - /'

echo ""
echo "📊 monitoring/grafana:"
curl -sf --header "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_ADDR/v1/secret/data/monitoring/grafana" | jq -r '.data.data | keys[]' | sed 's/^/  - /'

echo ""
echo "📊 monitoring/prometheus:"
curl -sf --header "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_ADDR/v1/secret/data/monitoring/prometheus" | jq -r '.data.data | keys[]' | sed 's/^/  - /'

echo ""
echo -e "${GREEN}✅ Secret migration complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Test retrieving secrets: ./scripts/vault-get-secret.sh databases/postgres password"
echo "2. Update docker-compose files to use Vault"
echo "3. Backup .env files and remove from server"
