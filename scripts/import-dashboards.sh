#!/bin/bash
# Import community Grafana dashboards

set -e

echo "📊 Importing Grafana Dashboards"
echo ""

GRAFANA_URL="http://localhost:3000"
API_KEY=""

# Check if Grafana is running
if ! curl -sf "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
    echo "❌ Grafana is not running"
    exit 1
fi

echo "Popular community dashboards:"
echo ""
echo "1. Node Exporter Full - Dashboard ID: 1860"
echo "2. PostgreSQL Database - Dashboard ID: 9628"
echo "3. Redis Dashboard - Dashboard ID: 11835"
echo "4. Docker Container Metrics - Dashboard ID: 193"
echo "5. Nginx Metrics - Dashboard ID: 12708"
echo "6. Loki Dashboard - Dashboard ID: 13639"
echo ""
echo "To import a dashboard:"
echo "1. Go to Grafana → Dashboards → Import"
echo "2. Enter dashboard ID"
echo "3. Select Prometheus as data source"
echo "4. Click Import"
echo ""
echo "Or use the Grafana CLI:"
echo "docker exec infra_grafana grafana-cli plugins install <dashboard-id>"
