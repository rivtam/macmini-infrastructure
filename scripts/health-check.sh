#!/bin/bash
# Health check script for all infrastructure services

set -e

echo "🏥 Checking infrastructure health..."
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check service health
check_service() {
    local service_name=$1
    local container_name=$2
    local check_command=$3

    printf "%-20s" "$service_name"

    if ! docker ps --filter "name=$container_name" --format '{{.Names}}' | grep -q "$container_name"; then
        echo -e "${YELLOW}NOT RUNNING${NC}"
        return 1
    fi

    if eval "$check_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
        return 0
    else
        echo -e "${RED}❌ UNHEALTHY${NC}"
        return 1
    fi
}

# Check PostgreSQL
check_service "PostgreSQL" "infra_postgres" \
    "docker exec infra_postgres pg_isready -U postgres"

# Check Redis
check_service "Redis" "infra_redis" \
    "docker exec infra_redis redis-cli ping"

# Check Nginx
check_service "Nginx" "infra_nginx" \
    "curl -f http://localhost/healthz"

# Check Prometheus
check_service "Prometheus" "infra_prometheus" \
    "curl -f http://localhost:9090/-/healthy"

# Check Grafana
check_service "Grafana" "infra_grafana" \
    "curl -f http://localhost:3000/api/health"

# Check Node Exporter
check_service "Node Exporter" "infra_node_exporter" \
    "curl -f http://localhost:9100/metrics"

# Check cAdvisor
check_service "cAdvisor" "infra_cadvisor" \
    "curl -f http://localhost:8080/healthz"

echo ""
echo "Health check complete!"
