#!/bin/bash
# Unseal Vault after restart

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
INIT_FILE="./vault-init-keys.json"

echo "🔓 Vault Unseal Script"
echo ""

# Check if Vault is running
if ! curl -sf "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; then
    echo -e "${RED}❌ Vault is not running!${NC}"
    echo "Start Vault with: cd vault && docker compose up -d"
    exit 1
fi

# Check if already unsealed
SEAL_STATUS=$(curl -sf "$VAULT_ADDR/v1/sys/seal-status" | jq -r '.sealed')

if [ "$SEAL_STATUS" = "false" ]; then
    echo -e "${GREEN}✅ Vault is already unsealed${NC}"
    exit 0
fi

# Check for init file
if [ ! -f "$INIT_FILE" ]; then
    echo -e "${RED}❌ Init keys file not found: $INIT_FILE${NC}"
    echo "You need the unseal keys to unseal Vault"
    exit 1
fi

echo "Unsealing Vault..."

# Get unseal keys
UNSEAL_KEYS=$(cat "$INIT_FILE" | jq -r '.unseal_keys_b64[]')

# Unseal with first 3 keys
counter=0
for key in $UNSEAL_KEYS; do
    RESPONSE=$(curl -sf --request PUT --data "{\"key\": \"$key\"}" "$VAULT_ADDR/v1/sys/unseal")
    PROGRESS=$(echo "$RESPONSE" | jq -r '.progress')
    THRESHOLD=$(echo "$RESPONSE" | jq -r '.t')

    echo "Progress: $PROGRESS/$THRESHOLD"

    counter=$((counter + 1))
    if [ $counter -eq 3 ]; then
        break
    fi
done

# Check if unsealed
SEAL_STATUS=$(curl -sf "$VAULT_ADDR/v1/sys/seal-status" | jq -r '.sealed')

if [ "$SEAL_STATUS" = "false" ]; then
    echo ""
    echo -e "${GREEN}✅ Vault unsealed successfully!${NC}"
else
    echo ""
    echo -e "${RED}❌ Failed to unseal Vault${NC}"
    exit 1
fi
