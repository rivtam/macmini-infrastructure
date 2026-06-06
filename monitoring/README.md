# Monitoring Infrastructure

Prometheus and Grafana stack for monitoring all services.

## Services

- **Prometheus** (port 9090) - Metrics collection and storage
- **Grafana** (port 3000) - Metrics visualization and dashboards
- **Node Exporter** (port 9100) - Host machine metrics
- **cAdvisor** (port 8080) - Container metrics

## Quick Start

```bash
# Copy environment file
cp .env.example .env

# Edit credentials
vim .env

# Start monitoring stack
docker compose up -d

# View logs
docker compose logs -f

# Access dashboards
open http://localhost:3000  # Grafana
open http://localhost:9090  # Prometheus

# Stop monitoring
docker compose down
```

## Accessing Grafana

1. Open http://localhost:3000
2. Login with credentials from `.env` (default: admin/admin)
3. Navigate to Dashboards
4. Prometheus datasource is pre-configured

## What's Being Monitored

### System Metrics (Node Exporter)
- CPU usage
- Memory usage
- Disk I/O
- Network traffic
- System load

### Container Metrics (cAdvisor)
- Container CPU usage
- Container memory usage
- Container network I/O
- Container filesystem usage
- Per-container resource limits

### Application Metrics (Manual Setup)
To monitor your applications, add metrics endpoints:

1. Add metrics endpoint to your application
2. Update `prometheus/prometheus.yml` with your app's endpoint
3. Reload Prometheus: `docker compose restart prometheus`

Example for Node.js/Express:
```javascript
// Install prom-client
const promClient = require('prom-client');
const register = promClient.register;

// Create metrics endpoint
app.get('/api/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

## Creating Dashboards

### Using Pre-built Dashboards

1. Go to Grafana → Dashboards → Import
2. Enter dashboard ID from https://grafana.com/grafana/dashboards/

Recommended dashboards:
- **1860** - Node Exporter Full
- **193** - Docker monitoring
- **405** - Node Exporter Server Metrics

### Custom Dashboards

Place JSON dashboard files in `grafana/dashboards/` and they'll be auto-loaded.

## Prometheus Queries

Common PromQL queries:

### System Metrics
```promql
# CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100
```

### Container Metrics
```promql
# Container CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Container memory usage
container_memory_usage_bytes

# Container network I/O
rate(container_network_receive_bytes_total[5m])
```

## Alerting (Optional)

To set up alerting:

1. Create alert rules in `prometheus/alerts/`
2. Set up Alertmanager
3. Configure notification channels (email, Slack, etc.)

Example alert rule:
```yaml
groups:
  - name: system
    interval: 30s
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for 5 minutes"
```

## Data Retention

- Prometheus retains data for 30 days (configurable in docker-compose.yml)
- Data is stored in Docker volumes: `prometheus_data` and `grafana_data`

## Backing Up

### Backup Grafana dashboards
```bash
# Dashboards are in grafana_data volume
docker run --rm -v monitoring_grafana_data:/data -v $(pwd):/backup alpine tar czf /backup/grafana_backup.tar.gz /data
```

### Backup Prometheus data
```bash
docker run --rm -v monitoring_prometheus_data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus_backup.tar.gz /data
```

## Troubleshooting

### Grafana not accessible
```bash
# Check if container is running
docker compose ps grafana

# Check logs
docker compose logs grafana

# Check if port is in use
lsof -i :3000
```

### Prometheus not scraping
```bash
# Check Prometheus targets
open http://localhost:9090/targets

# Verify config
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml

# Reload config
curl -X POST http://localhost:9090/-/reload
```

### Node Exporter not working on Mac
```bash
# Node Exporter has limited functionality on macOS
# Some metrics won't be available due to Docker Desktop limitations
# For full metrics, use on Linux or direct on Mac Mini
```

## Production Configuration

For production:

1. ✅ Change Grafana admin password
2. ✅ Configure authentication (LDAP, OAuth, etc.)
3. ✅ Set up SSL for Grafana (via nginx proxy)
4. ✅ Configure data retention based on disk space
5. ✅ Set up alerting with Alertmanager
6. ✅ Regular backups of Grafana dashboards
7. ✅ Monitor the monitors (meta-monitoring)

## Exposing to Internet

To access Grafana externally, add nginx configuration:

```nginx
# In nginx/sites/monitoring.conf
server {
    listen 443 ssl;
    server_name monitoring.yourdomain.com;

    location / {
        proxy_pass http://infra_grafana:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```
