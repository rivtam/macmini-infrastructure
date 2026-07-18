#!/bin/bash
# Initialize and unseal Vault

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

VAULT_ADDR="http://localhost:8200"
INIT_FILE="./vault-init-keys.json"

echo "🔐 Vault Initialization Script"
echo ""

# Check if Vault is running
if ! curl -sf "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; then
    echo -e "${RED}❌ Vault is not running!${NC}"
    echo "Start Vault with: cd vault && docker compose up -d"
    exit 1
fi

# Check if Vault is already initialized
if curl -sf "$VAULT_ADDR/v1/sys/init" | grep -q '"initialized":true'; then
    echo -e "${YELLOW}⚠️  Vault is already initialized${NC}"
    echo ""

    if [ ! -f "$INIT_FILE" ]; then
        echo -e "${RED}❌ Init keys file not found: $INIT_FILE${NC}"
        echo "You need the init keys to unseal Vault"
        exit 1
    fi

    # Unseal Vault
    echo "Unsealing Vault..."
    UNSEAL_KEYS=$(cat "$INIT_FILE" | jq -r '.unseal_keys_b64[]')

    for key in $UNSEAL_KEYS; do
        curl -sf --request PUT --data "{\"key\": \"$key\"}" "$VAULT_ADDR/v1/sys/unseal" > /dev/null
    done

    echo -e "${GREEN}✅ Vault unsealed${NC}"
    exit 0
fi

# Initialize Vault
echo "Initializing Vault..."
echo ""

INIT_OUTPUT=$(curl -sf --request PUT \
    --data '{"secret_shares": 5, "secret_threshold": 3}' \
    "$VAULT_ADDR/v1/sys/init")

# Save init output
echo "$INIT_OUTPUT" > "$INIT_FILE"
chmod 600 "$INIT_FILE"

echo -e "${GREEN}✅ Vault initialized${NC}"
echo ""

# Extract keys
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
UNSEAL_KEYS=$(echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[]')

echo "🔑 Initial Root Token:"
echo -e "${YELLOW}$ROOT_TOKEN${NC}"
echo ""
echo "🔓 Unseal Keys (need 3 of 5):"
echo "$UNSEAL_KEYS" | nl
echo ""

# Unseal Vault
echo "Unsealing Vault..."
counter=0
for key in $UNSEAL_KEYS; do
    curl -sf --request PUT --data "{\"key\": \"$key\"}" "$VAULT_ADDR/v1/sys/unseal" > /dev/null
    counter=$((counter + 1))
    if [ $counter -eq 3 ]; then
        break
    fi
done

echo -e "${GREEN}✅ Vault unsealed${NC}"
echo ""

# Export root token for configuration
export VAULT_TOKEN="$ROOT_TOKEN"
export VAULT_ADDR="$VAULT_ADDR"

# Enable KV v2 secrets engine
echo "Enabling KV v2 secrets engine..."
curl -sf --header "X-Vault-Token: $ROOT_TOKEN" \
    --request POST \
    --data '{"type": "kv", "options": {"version": "2"}}' \
    "$VAULT_ADDR/v1/sys/mounts/secret" > /dev/null

echo -e "${GREEN}✅ Secrets engine enabled${NC}"
echo ""

# Create policies
echo "Creating policies..."

# Infrastructure policy
INFRA_POLICY=$(cat ./vault/policies/infrastructure-policy.hcl)
curl -sf --header "X-Vault-Token: $ROOT_TOKEN" \
    --request PUT \
    --data "{\"policy\": $(echo "$INFRA_POLICY" | jq -Rs .)}" \
    "$VAULT_ADDR/v1/sys/policies/acl/infrastructure" > /dev/null

# Admin policy
ADMIN_POLICY=$(cat ./vault/policies/admin-policy.hcl)
curl -sf --header "X-Vault-Token: $ROOT_TOKEN" \
    --request PUT \
    --data "{\"policy\": $(echo "$ADMIN_POLICY" | jq -Rs .)}" \
    "$VAULT_ADDR/v1/sys/policies/acl/admin" > /dev/null

echo -e "${GREEN}✅ Policies created${NC}"
echo ""

# Create infrastructure token
echo "Creating infrastructure token..."
INFRA_TOKEN_OUTPUT=$(curl -sf --header "X-Vault-Token: $ROOT_TOKEN" \
    --request POST \
    --data '{"policies": ["infrastructure"], "ttl": "768h", "renewable": true}' \
    "$VAULT_ADDR/v1/auth/token/create")

INFRA_TOKEN=$(echo "$INFRA_TOKEN_OUTPUT" | jq -r '.auth.client_token')

echo -e "${GREEN}✅ Infrastructure token created${NC}"
echo ""
echo "Infrastructure Token:"
echo -e "${YELLOW}$INFRA_TOKEN${NC}"
echo ""

# Save tokens
cat > ./vault-tokens.env <<EOF
# Vault Configuration
# IMPORTANT: Keep this file secure and never commit to version control!

VAULT_ADDR=$VAULT_ADDR
VAULT_TOKEN=$INFRA_TOKEN  # Infrastructure token (read-only)
VAULT_ROOT_TOKEN=$ROOT_TOKEN  # Root token (admin access - use sparingly)
EOF

chmod 600 ./vault-tokens.env

echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}⚠️  IMPORTANT SECURITY INFORMATION${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. Save the following files securely:"
echo "   - $INIT_FILE (unseal keys)"
echo "   - ./vault-tokens.env (access tokens)"
echo ""
echo "2. Store backup copies in a secure location (password manager, encrypted storage)"
echo ""
echo "3. Delete the root token after initial setup:"
echo "   vault token revoke $ROOT_TOKEN"
echo ""
echo "4. Vault must be unsealed after every restart"
echo "   Use: ./scripts/vault-unseal.sh"
echo ""
echo -e "${GREEN}✅ Vault initialization complete!${NC}"
