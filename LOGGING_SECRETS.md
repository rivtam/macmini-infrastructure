# Logging and Secrets Management Guide

Complete guide for using Loki (log aggregation) and Vault (secrets management) in the infrastructure.

## Table of Contents

- [Loki - Log Aggregation](#loki---log-aggregation)
- [Vault - Secrets Management](#vault---secrets-management)
- [Integration Examples](#integration-examples)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

# Loki - Log Aggregation

Loki is a horizontally-scalable, highly-available log aggregation system inspired by Prometheus.

## Architecture

```
┌─────────────┐
│ Application │─┐
└─────────────┘ │
                ├──> ┌───────────┐    ┌──────┐
┌─────────────┐ │    │ Promtail  │───>│ Loki │
│   Nginx     │─┤    │ (Shipper) │    └──┬───┘
└─────────────┘ │    └───────────┘       │
                │                         │
┌─────────────┐ │                         ▼
│  Databases  │─┘                    ┌─────────┐
└─────────────┘                      │ Grafana │
                                     └─────────┘
```

## What Gets Logged

### 1. **Container Logs**
All Docker containers with the label `logging=promtail`:

```yaml
services:
  myapp:
    labels:
      - "logging=promtail"
```

### 2. **Nginx Logs**
- Access logs (requests, status codes, response times)
- Error logs (application errors, configuration issues)

### 3. **System Logs**
- Syslog messages
- Application-specific logs

### 4. **Database Logs** (if configured)
- PostgreSQL query logs
- Redis operations

## Viewing Logs in Grafana

### 1. Access Grafana

```bash
# Open Grafana
make open-grafana

# Default credentials
Username: admin
Password: (from monitoring/.env)
```

### 2. Navigate to Explore

- Click "Explore" in the left sidebar
- Select "Loki" as the datasource

### 3. Query Examples

**View all logs from a specific container:**
```logql
{container="infra_postgres"}
```

**View nginx error logs:**
```logql
{job="nginx", log_type="error"}
```

**View logs with specific error level:**
```logql
{job="nginx"} |= "error"
```

**Count 5xx errors in last hour:**
```logql
sum(count_over_time({job="nginx", status=~"5.."} [1h]))
```

**View application logs with JSON parsing:**
```logql
{job="application"} | json | level="error"
```

**Rate of errors per minute:**
```logql
rate({job="nginx"} |= "error" [1m])
```

## LogQL Cheat Sheet

| Query | Description |
|-------|-------------|
| `{job="nginx"}` | All logs from nginx |
| `{container="infra_postgres"}` | All logs from PostgreSQL container |
| `{job="nginx"} \|= "error"` | Lines containing "error" |
| `{job="nginx"} \|~ "error\|warning"` | Regex match |
| `{job="nginx"} \|= "error" \| json` | Parse JSON logs |
| `rate({job="nginx"}[5m])` | Log rate over 5 minutes |
| `sum by (status) (count_over_time({job="nginx"}[1h]))` | Count by status code |

## Log Retention

Logs are retained for **31 days** (744 hours) by default.

To change retention, edit `monitoring/loki/loki-config.yml`:

```yaml
limits_config:
  retention_period: 744h  # Change this value
```

## Alerting on Logs

Create log-based alerts in Prometheus:

```yaml
# monitoring/prometheus/alerts/logs.yml
groups:
  - name: log_alerts
    interval: 1m
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate({job="nginx"} |= "error" [5m])) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
```

---

# Vault - Secrets Management

HashiCorp Vault provides secure secrets management with encryption, access control, and audit logging.

## Initial Setup

### 1. Start Vault

```bash
cd vault
docker compose up -d
```

### 2. Initialize Vault

```bash
./scripts/vault-init.sh
```

This will:
- Initialize Vault
- Generate 5 unseal keys (need 3 to unseal)
- Create root token
- Enable KV v2 secrets engine
- Create access policies
- Generate infrastructure token

**IMPORTANT:** Save the output! You need:
- `vault-init-keys.json` - Unseal keys (BACKUP SECURELY!)
- `vault-tokens.env` - Access tokens

### 3. Migrate Existing Secrets

```bash
# Ensure .env files exist in databases/ and monitoring/
./scripts/vault-migrate-secrets.sh
```

## Daily Operations

### Unsealing Vault

Vault must be unsealed after every restart:

```bash
./scripts/vault-unseal.sh
```

### Storing Secrets

```bash
# Set environment
source ./vault-tokens.env

# Store a secret
vault kv put secret/databases/postgres \
    username=postgres \
    password=secure_password_here

# Store application secret
vault kv put secret/applications/myapp \
    api_key=abc123 \
    database_url=postgresql://...
```

### Retrieving Secrets

```bash
# Get specific secret
./scripts/vault-get-secret.sh databases/postgres password

# Or with vault CLI
vault kv get -field=password secret/databases/postgres

# Get all secrets at path
vault kv get secret/databases/postgres
```

### Listing Secrets

```bash
# List all secret paths
vault kv list secret/

# List secrets in specific path
vault kv list secret/databases/
```

## Secret Organization

Secrets are organized by category:

```
secret/
├── databases/
│   ├── postgres
│   │   ├── username
│   │   ├── password
│   │   └── port
│   └── redis
│       ├── password
│       └── port
├── monitoring/
│   ├── grafana
│   │   ├── admin_user
│   │   └── admin_password
│   └── prometheus
│       └── port
└── applications/
    ├── myapp/
    │   ├── api_key
    │   └── database_url
    └── otherapp/
        └── secret_token
```

## Access Policies

### Infrastructure Policy (Read-Only)

Services use this policy to read secrets:

```hcl
# Can read all secrets
path "secret/data/*" {
  capabilities = ["read", "list"]
}
```

### Admin Policy

Administrators use this for full access:

```hcl
# Full access to secrets
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

## Using Secrets in Docker Compose

### Method 1: Environment Variables (Current)

```bash
# Source Vault token
source ./vault-tokens.env

# Get secrets and export
export DB_PASSWORD=$(./scripts/vault-get-secret.sh databases/postgres password)

# Start services
docker compose up -d
```

### Method 2: Vault Agent (Advanced)

Create a Vault Agent sidecar:

```yaml
services:
  vault-agent:
    image: hashicorp/vault:latest
    command: agent -config=/vault/agent/config.hcl
    volumes:
      - ./vault/agent:/vault/agent
    networks:
      - infra_network
```

### Method 3: Init Container Pattern

```yaml
services:
  myapp:
    image: myapp:latest
    depends_on:
      - vault-init

  vault-init:
    image: hashicorp/vault:latest
    command: /scripts/fetch-secrets.sh
    volumes:
      - secrets:/secrets
```

## Secret Rotation

### Manual Rotation

```bash
# Update secret
vault kv put secret/databases/postgres password=new_password

# Restart services that use it
docker compose restart postgres
```

### Automated Rotation (Advanced)

Set up Vault's database secrets engine:

```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/postgresql \
    plugin_name=postgresql-database-plugin \
    connection_url="postgresql://{{username}}:{{password}}@postgres:5432/" \
    allowed_roles="*" \
    username="vault" \
    password="vault_password"

# Create role with rotation
vault write database/roles/myapp \
    db_name=postgresql \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';" \
    default_ttl="1h" \
    max_ttl="24h"
```

## Backup & Disaster Recovery

### Backing Up Vault Data

```bash
# Stop Vault
cd vault && docker compose stop vault

# Backup data directory
tar -czf vault-backup-$(date +%Y%m%d).tar.gz vault/data/

# Restart Vault
docker compose start vault
./scripts/vault-unseal.sh
```

### Restoring Vault

```bash
# Stop Vault
cd vault && docker compose stop vault

# Restore data
tar -xzf vault-backup-YYYYMMDD.tar.gz

# Start and unseal
docker compose start vault
./scripts/vault-unseal.sh
```

### Disaster Recovery

Keep secure backups of:
1. `vault-init-keys.json` - Unseal keys
2. `vault/data/` directory - All secrets
3. `vault-tokens.env` - Access tokens

Store in multiple secure locations:
- Password manager (1Password, LastPass)
- Encrypted USB drive (offline)
- Secure cloud storage (encrypted)

---

# Integration Examples

## Example: PostgreSQL with Vault Secrets

```bash
#!/bin/bash
# start-postgres-with-vault.sh

# Get secrets from Vault
source ./vault-tokens.env
export POSTGRES_PASSWORD=$(./scripts/vault-get-secret.sh databases/postgres password)

# Start PostgreSQL
cd databases
docker compose up -d postgres
```

## Example: Application Configuration

```javascript
// Node.js application
const axios = require('axios');

async function getSecret(path, key) {
  const response = await axios.get(
    `${process.env.VAULT_ADDR}/v1/secret/data/${path}`,
    {
      headers: {
        'X-Vault-Token': process.env.VAULT_TOKEN
      }
    }
  );
  return response.data.data.data[key];
}

// Usage
const dbPassword = await getSecret('databases/postgres', 'password');
```

## Example: Query Logs for Specific Request

```logql
# Find all logs related to a specific request ID
{container="myapp"} |= "request_id=abc123"

# View full request flow across services
{container=~"myapp|postgres|redis"} |= "request_id=abc123"
```

---

# Best Practices

## Logging

### DO:
- ✅ Use structured logging (JSON format)
- ✅ Include correlation IDs in logs
- ✅ Log at appropriate levels (ERROR, WARN, INFO, DEBUG)
- ✅ Add context to error messages
- ✅ Create dashboards for common queries
- ✅ Set up alerts for critical log patterns

### DON'T:
- ❌ Log sensitive data (passwords, tokens, PII)
- ❌ Log excessively (creates noise and costs)
- ❌ Use only unstructured text logs
- ❌ Ignore log retention policies

### Example: Good vs Bad Logging

**❌ Bad:**
```javascript
console.log('Error happened');
console.log(userId, password);  // Never log passwords!
```

**✅ Good:**
```javascript
logger.error('Database connection failed', {
  error: err.message,
  host: dbHost,
  attempt: retryCount,
  requestId: req.id
});
```

## Secrets Management

### DO:
- ✅ Use Vault for all secrets
- ✅ Rotate secrets regularly
- ✅ Use short-lived tokens
- ✅ Backup unseal keys securely
- ✅ Use least-privilege policies
- ✅ Audit secret access

### DON'T:
- ❌ Commit secrets to version control
- ❌ Share root tokens
- ❌ Store unseal keys on the server
- ❌ Use long-lived static credentials
- ❌ Give applications more access than needed

---

# Troubleshooting

## Loki Issues

### Logs Not Appearing

**Check Promtail:**
```bash
docker logs infra_promtail
curl http://localhost:9080/ready
```

**Check Loki:**
```bash
docker logs infra_loki
curl http://localhost:3100/ready
```

**Verify log paths:**
```bash
# Check that log files exist
ls -la nginx/logs/
ls -la /var/log/
```

### Query Timeout

Reduce time range or add more specific labels:
```logql
# Too broad - might timeout
{job="nginx"}

# Better - more specific
{job="nginx", status="500"} [5m]
```

## Vault Issues

### Vault is Sealed

```bash
./scripts/vault-unseal.sh
```

### Cannot Authenticate

```bash
# Check token
echo $VAULT_TOKEN

# Source tokens
source ./vault-tokens.env

# Test connection
vault status
```

### Lost Unseal Keys

If you lose unseal keys, you **cannot** recover Vault data.
This is why backups are critical!

Recovery options:
1. Restore from backup
2. Re-initialize (loses all secrets)

### Permission Denied

```bash
# Check your token's capabilities
vault token lookup

# Use admin token for write operations
export VAULT_TOKEN=$(grep VAULT_ROOT_TOKEN vault-tokens.env | cut -d'=' -f2)
```

---

## Monitoring

### View Loki Metrics in Prometheus

Loki exposes metrics on port 3100:

```bash
curl http://localhost:3100/metrics
```

### View Vault Metrics

Vault exposes metrics:

```bash
curl http://localhost:8200/v1/sys/metrics
```

Add to Prometheus configuration to scrape these.

---

**Remember:**
- Logs are valuable for troubleshooting, not storage
- Secrets should never appear in logs
- Backup Vault keys in multiple secure locations
- Test disaster recovery procedures regularly

For more information, see:
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Vault Documentation](https://www.vaultproject.io/docs)
