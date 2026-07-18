# Monitoring Stack

Prometheus, Grafana, Loki, Promtail, and Alertmanager.

## Quick Access

- **Grafana**: http://localhost:3000 (dashboards)
- **Prometheus**: http://localhost:9090 (metrics)
- **Alertmanager**: http://localhost:9093 (alerts)
- **Loki**: http://localhost:3100 (logs - API only)

## Quick Reference

```bash
# Start monitoring stack
docker compose up -d

# View logs
logcli query '{job="postgres"}' --limit=100

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# View Grafana dashboards
open http://localhost:3000
```

## Configuration

**Environment:** `.env` file
```bash
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=    # Set strong password
```

**Alert Rules:** `prometheus/alerts/*.yml`
**Dashboards:** `grafana/dashboards/json/*.json`

## Complete Documentation

See [../DOCUMENTATION.md](../DOCUMENTATION.md) for:
- Monitoring setup
- Alert configuration
- Dashboard creation
- Log queries (LogQL)
- Metrics queries (PromQL)
