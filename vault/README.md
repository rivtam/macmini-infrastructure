# HashiCorp Vault - Secrets Management

Centralized secrets storage with encryption and access control.

## Quick Reference

```bash
# Start Vault
docker compose up -d

# Initialize Vault (first time only)
../scripts/vault-init.sh
# ⚠️ SAVE THE UNSEAL KEYS AND ROOT TOKEN!

# Unseal Vault (after every restart)
../scripts/vault-unseal.sh

# Check status
docker exec infra_vault vault status

# Store a secret
../scripts/vault-get-secret.sh secret/data/myapp/config -w '{"api_key":"secret123"}'

# Retrieve a secret
../scripts/vault-get-secret.sh secret/data/myapp/config

# Migrate .env secrets to Vault
../scripts/vault-migrate-secrets.sh
```

## Common Operations

**List secrets:**
```bash
docker exec -it infra_vault vault kv list secret/
```

**Read secret:**
```bash
docker exec -it infra_vault vault kv get secret/databases/postgres
```

**Write secret:**
```bash
docker exec -it infra_vault vault kv put secret/myapp/api key=value
```

**Delete secret:**
```bash
docker exec -it infra_vault vault kv delete secret/myapp/api
```

## Access Policies

**Policies defined in:** `policies/*.hcl`

- **admin-policy**: Full access to all secrets
- **infrastructure-policy**: Read-only access to infrastructure secrets

## Vault UI

Access Vault UI at http://localhost:8200/ui
Login with root token from initialization.

## Complete Documentation

See [../DOCUMENTATION.md](../DOCUMENTATION.md) for:
- Initialization & unsealing
- Secret management
- Access policies
- Integration with applications
- Troubleshooting
