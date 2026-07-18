#!/bin/bash
# Retrieve secrets from Vault

set -e

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <path> <key>"
    echo ""
    echo "Examples:"
    echo "  $0 databases/postgres password"
    echo "  $0 monitoring/grafana admin_user"
    exit 1
fi

PATH_NAME=$1
KEY_NAME=$2

# Check if Vault token is set
if [ -z "$VAULT_TOKEN" ]; then
    if [ -f "./vault-tokens.env" ]; then
        source ./vault-tokens.env
    else
        echo "❌ VAULT_TOKEN not set"
        exit 1
    fi
fi

# Retrieve secret
curl -sf --header "X-Vault-Token: $VAULT_TOKEN" \
    "$VAULT_ADDR/v1/secret/data/$PATH_NAME" | jq -r ".data.data.$KEY_NAME"
