# Audit Logging & Compliance

Comprehensive audit trails for security and compliance.

## Quick Reference

```bash
# Start audit infrastructure
docker compose up -d

# Enable PostgreSQL auditing
../scripts/enable-postgres-audit.sh
docker restart infra_postgres

# Generate compliance report
../scripts/generate-audit-report.sh

# Custom date range
../scripts/generate-audit-report.sh "30 days ago" "now"

# Query audit logs
logcli query '{log_type="auth_audit"}' --limit=100
```

## What's Audited

- **Vault**: All secrets access operations
- **PostgreSQL**: Database operations (INSERT, UPDATE, DELETE, DDL)
- **Nginx**: HTTP requests, admin access
- **System**: SSH logins, authentication attempts
- **Applications**: Custom audit events

## Audit Dashboard

View real-time audit events in Grafana:
1. Open http://localhost:3000
2. Go to Dashboards → Audit & Compliance

## Compliance

Supports compliance for:
- GDPR (data access logging)
- HIPAA (PHI access monitoring)
- SOC 2 (system access, change management)
- PCI DSS (payment system access)

**Retention:** 31 days in Loki (configurable)
**Reports:** Stored in `reports/` directory

## Complete Documentation

See [../DOCUMENTATION.md](../DOCUMENTATION.md) for:
- Audit setup
- Compliance reporting
- Query examples
- Alert configuration
- Best practices
