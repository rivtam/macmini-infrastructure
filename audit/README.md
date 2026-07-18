# Audit Logging System

Comprehensive audit logging for compliance, security monitoring, and forensic analysis.

## Overview

The audit logging system provides:
- **Centralized audit trail** for all system activities
- **Structured logging** with consistent JSON format
- **Compliance reporting** for regulatory requirements
- **Security monitoring** with real-time alerts
- **Long-term retention** for forensic analysis

## Components

### 1. Audit Log Processor
- Collects logs from all infrastructure components
- Enriches logs with metadata (timestamps, user info, IP addresses)
- Forwards to Loki for storage and analysis
- Located: `audit/docker-compose.yml`

### 2. Audit Exporter
- Exposes audit metrics to Prometheus
- Provides counts and rates for compliance dashboards
- Monitors audit pipeline health

### 3. Log Sources

#### Vault Audit Logs
- All secrets access operations
- Authentication attempts
- Policy changes
- Configuration modifications

#### PostgreSQL Audit Logs
- Database connections/disconnections
- All write operations (INSERT, UPDATE, DELETE)
- DDL operations (CREATE, DROP, ALTER)
- User privilege changes

#### Nginx Access Logs
- HTTP requests with user context
- Admin endpoint access
- Failed authentication attempts
- Suspicious request patterns

#### System Authentication
- SSH login attempts
- Sudo command execution
- User account changes
- System service access

## Setup

### 1. Enable Audit Logging

Start the audit infrastructure:
```bash
cd audit
docker compose up -d
```

### 2. Enable PostgreSQL Auditing

Run the PostgreSQL audit setup script:
```bash
./scripts/enable-postgres-audit.sh
docker restart infra_postgres
```

### 3. Enable Vault Auditing

Vault audit logging is enabled by default. Logs are stored in `/vault/logs/` and automatically processed.

### 4. Configure Nginx Audit Logging

Nginx access logs are already configured. For enhanced audit logging, add to your nginx config:
```nginx
log_format audit '$remote_addr - $remote_user [$time_local] '
                 '"$request" $status $body_bytes_sent '
                 '"$http_referer" "$http_user_agent" '
                 'rt=$request_time';
access_log /var/log/nginx/audit.log audit;
```

## Usage

### Generate Audit Reports

Generate compliance report for the last 7 days:
```bash
./scripts/generate-audit-report.sh
```

Generate report for custom date range:
```bash
./scripts/generate-audit-report.sh "30 days ago" "now" "./reports"
```

### Query Audit Logs

Using Loki CLI:
```bash
# All authentication events
logcli query '{log_type="auth_audit"}' --limit=100

# Failed login attempts
logcli query '{log_type="auth_audit"} |= "Failed"' --since=24h

# Database write operations
logcli query '{job="postgres", query_type=~"INSERT|UPDATE|DELETE"}' --since=1h

# Vault access by specific user
logcli query '{job="vault", auth_display_name="admin"}' --since=24h
```

Using Grafana:
1. Navigate to Explore
2. Select Loki datasource
3. Use LogQL queries (see examples above)

### View Audit Dashboard

1. Open Grafana: http://localhost:3000
2. Navigate to Dashboards → Audit & Compliance Dashboard
3. View real-time audit metrics and events

## Audit Events

### Authentication Events
```json
{
  "timestamp": "2024-01-15T14:30:00Z",
  "event_type": "authentication",
  "result": "success|failure",
  "user": "username",
  "source_ip": "192.168.1.100",
  "method": "password|ssh-key|token"
}
```

### Database Operations
```json
{
  "timestamp": "2024-01-15T14:30:00Z",
  "user": "app_user",
  "database": "eduhub",
  "query_type": "INSERT|UPDATE|DELETE",
  "query": "INSERT INTO users...",
  "client_ip": "172.18.0.5"
}
```

### Vault Access
```json
{
  "time": "2024-01-15T14:30:00Z",
  "type": "request",
  "auth": {
    "display_name": "admin",
    "token_type": "service"
  },
  "request": {
    "operation": "read|write|delete",
    "path": "secret/data/databases/postgres"
  }
}
```

### Application Events
```json
{
  "timestamp": "2024-01-15T14:30:00Z",
  "event_type": "resource_access",
  "user_id": "12345",
  "action": "create|read|update|delete",
  "resource": "user_profile",
  "result": "success|denied",
  "ip_address": "192.168.1.100"
}
```

## Compliance

### Supported Standards
- **GDPR**: Data access logging and user consent tracking
- **HIPAA**: PHI access monitoring and audit trails
- **SOC 2**: System access and change management
- **PCI DSS**: Payment system access and modifications

### Retention Policy
- **Loki**: 31 days (configurable in `monitoring/loki/loki-config.yml`)
- **Archived Reports**: Indefinite (manual archival required)
- **Compliance Requirement**: Adjust retention based on regulatory needs

### Report Types

#### Daily Reports
```bash
./scripts/generate-audit-report.sh "1 day ago" "now"
```

#### Weekly Reports
```bash
./scripts/generate-audit-report.sh "7 days ago" "now"
```

#### Monthly Reports
```bash
./scripts/generate-audit-report.sh "30 days ago" "now"
```

#### Custom Compliance Reports
Modify `scripts/generate-audit-report.sh` to add custom queries for specific compliance requirements.

## Alerts

Audit-related alerts are configured in `monitoring/prometheus/alerts/audit.yml`:

- **ExcessiveFailedLogins**: More than 10 failed logins in 10 minutes
- **PrivilegedDatabaseOperation**: Multiple DROP/ALTER operations
- **UnauthorizedAdminAccess**: Failed auth on admin endpoints
- **VaultAccessAnomaly**: High rate of Vault errors
- **MassDataDeletion**: More than 100 DELETEs in 5 minutes
- **PrivilegeEscalation**: Multiple GRANT/ROLE changes
- **AfterHoursAccess**: System access outside business hours
- **SuspiciousQueryPattern**: SQL queries with attack patterns
- **ConfigurationChange**: System configuration modifications
- **AuditLogDelay**: Audit log processing delays

## Monitoring Audit Health

### Check Audit Processor
```bash
docker logs infra_audit_processor
```

### Check Loki Ingestion
```bash
curl http://localhost:3100/metrics | grep loki_ingester_appends_total
```

### Verify PostgreSQL Auditing
```bash
docker exec infra_postgres psql -U postgres -c "SHOW shared_preload_libraries;"
# Should show: pgaudit
```

## Security Considerations

1. **Access Control**: Restrict access to audit logs to authorized personnel only
2. **Immutability**: Loki provides immutable log storage - logs cannot be modified
3. **Encryption**: Consider encrypting audit log volumes at rest
4. **Separation**: Audit infrastructure runs in separate containers
5. **Retention**: Ensure logs are retained per compliance requirements
6. **Alerting**: Configure alerts for suspicious patterns and access anomalies

## Troubleshooting

### Audit logs not appearing
1. Check audit processor is running: `docker ps | grep audit`
2. Verify Loki is accessible: `curl http://localhost:3100/ready`
3. Check log file permissions
4. Review processor logs: `docker logs infra_audit_processor`

### PostgreSQL audit not working
1. Verify pgAudit is installed: `docker exec infra_postgres dpkg -l | grep pgaudit`
2. Check configuration: `docker exec infra_postgres psql -U postgres -c "SHOW shared_preload_libraries;"`
3. Restart PostgreSQL: `docker restart infra_postgres`

### Missing Vault logs
1. Check Vault container logs: `docker logs infra_vault`
2. Verify log volume mount: `docker inspect infra_vault | grep vault/logs`
3. Ensure Vault is initialized and unsealed

## Application Integration

To add audit logging to your application, write structured JSON logs to `/var/log/audit/app-audit.log`:

```python
import json
import logging
from datetime import datetime

def audit_log(event_type, user_id, action, resource, result, ip_address):
    audit_event = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "event_type": event_type,
        "user_id": user_id,
        "action": action,
        "resource": resource,
        "result": result,
        "ip_address": ip_address
    }

    with open('/var/log/audit/app-audit.log', 'a') as f:
        f.write(json.dumps(audit_event) + '\n')

# Usage
audit_log("resource_access", "12345", "update", "user_profile", "success", "192.168.1.100")
```

## Performance Impact

- **Audit Processor**: Minimal CPU/memory overhead (<1% typical)
- **PostgreSQL**: pgAudit adds ~2-5% overhead depending on workload
- **Storage**: ~100MB-500MB per day depending on activity level
- **Network**: Negligible impact (<1 Mbps typical)

## Best Practices

1. **Regular Reviews**: Review audit reports weekly
2. **Alert Tuning**: Adjust alert thresholds based on baseline activity
3. **Retention Management**: Archive old reports before Loki retention expires
4. **Access Logging**: Log all privileged operations
5. **Incident Response**: Use audit logs for forensic analysis
6. **Compliance**: Map audit events to compliance requirements
7. **Testing**: Regularly test audit log generation and alerting
