#!/bin/bash
# Show status of all infrastructure services

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 Infrastructure Service Status${NC}"
echo ""

# Count running/total
total=0
running=0

check_service() {
    local name=$1
    local container=$2
    local tier=$3

    total=$((total + 1))

    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        status="${GREEN}●${NC} Running"
        running=$((running + 1))
    else
        status="${RED}○${NC} Stopped"
    fi

    printf "  %-25s %-25s %s\n" "$name" "$status" "$tier"
}

echo -e "${YELLOW}Essential Services:${NC}"
check_service "PostgreSQL" "infra_postgres" "Tier 1"
check_service "Redis" "infra_redis" "Tier 1"
check_service "Nginx" "infra_nginx" "Tier 1"
echo ""

echo -e "${YELLOW}Performance:${NC}"
check_service "PgBouncer" "infra_pgbouncer" "Tier 6"
echo ""

echo -e "${YELLOW}Monitoring:${NC}"
check_service "Prometheus" "infra_prometheus" "Tier 2"
check_service "Grafana" "infra_grafana" "Tier 2"
check_service "Node Exporter" "infra_node_exporter" "Tier 2"
echo ""

echo -e "${YELLOW}Advanced Monitoring:${NC}"
check_service "Loki" "infra_loki" "Tier 3"
check_service "Promtail" "infra_promtail" "Tier 3"
check_service "Alertmanager" "infra_alertmanager" "Tier 3"
check_service "cAdvisor" "infra_cadvisor" "Tier 3"
echo ""

echo -e "${YELLOW}Observability:${NC}"
check_service "PostgreSQL Exporter" "infra_postgres_exporter" "Tier 4"
check_service "Redis Exporter" "infra_redis_exporter" "Tier 4"
check_service "SSL Exporter" "infra_certbot_exporter" "Tier 4"
echo ""

echo -e "${YELLOW}Security:${NC}"
check_service "Vault" "infra_vault" "Tier 5"
check_service "Certbot" "infra_certbot" "Tier 5"
check_service "Audit Processor" "infra_audit_processor" "Tier 5"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Status: ${GREEN}${running}${NC}/${total} services running"

# Calculate approximate resource usage
cpu_usage=0
mem_usage=0

# Essential (if running)
docker ps --format '{{.Names}}' | grep -q "^infra_postgres$" && cpu_usage=$(echo "$cpu_usage + 2.0" | bc) && mem_usage=$(echo "$mem_usage + 2048" | bc)
docker ps --format '{{.Names}}' | grep -q "^infra_redis$" && cpu_usage=$(echo "$cpu_usage + 1.0" | bc) && mem_usage=$(echo "$mem_usage + 512" | bc)
docker ps --format '{{.Names}}' | grep -q "^infra_nginx$" && cpu_usage=$(echo "$cpu_usage + 1.0" | bc) && mem_usage=$(echo "$mem_usage + 512" | bc)

# Monitoring
docker ps --format '{{.Names}}' | grep -q "^infra_prometheus$" && cpu_usage=$(echo "$cpu_usage + 1.0" | bc) && mem_usage=$(echo "$mem_usage + 1024" | bc)
docker ps --format '{{.Names}}' | grep -q "^infra_grafana$" && cpu_usage=$(echo "$cpu_usage + 1.0" | bc) && mem_usage=$(echo "$mem_usage + 512" | bc)
docker ps --format '{{.Names}}' | grep -q "^infra_node_exporter$" && cpu_usage=$(echo "$cpu_usage + 0.5" | bc) && mem_usage=$(echo "$mem_usage + 128" | bc)

# Advanced Monitoring
docker ps --format '{{.Names}}' | grep -q "^infra_loki$" && cpu_usage=$(echo "$cpu_usage + 1.0" | bc) && mem_usage=$(echo "$mem_usage + 512" | bc)
docker ps --format '{{.Names}}' | grep -q "^infra_promtail$" && cpu_usage=$(echo "$cpu_usage + 0.5" | bc) && mem_usage=$(echo "$mem_usage + 256" | bc)
docker ps --format '{{.Names}}' | grep -q "^infra_alertmanager$" && cpu_usage=$(echo "$cpu_usage + 0.5" | bc) && mem_usage=$(echo "$mem_usage + 256" | bc)
docker ps --format '{{.Names}}' | grep -q "^infra_cadvisor$" && cpu_usage=$(echo "$cpu_usage + 0.5" | bc) && mem_usage=$(echo "$mem_usage + 256" | bc)

# Exporters
docker ps --format '{{.Names}}' | grep -q "^infra_postgres_exporter$" && cpu_usage=$(echo "$cpu_usage + 0.5" | bc) && mem_usage=$(echo "$mem_usage + 128" | bc)
docker ps --format '{{.Names}}' | grep -q "^infra_redis_exporter$" && cpu_usage=$(echo "$cpu_usage + 0.5" | bc) && mem_usage=$(echo "$mem_usage + 128" | bc)

# Security
docker ps --format '{{.Names}}' | grep -q "^infra_vault$" && cpu_usage=$(echo "$cpu_usage + 0.5" | bc) && mem_usage=$(echo "$mem_usage + 256" | bc)
docker ps --format '{{.Names}}' | grep -q "^infra_audit_processor$" && cpu_usage=$(echo "$cpu_usage + 0.5" | bc) && mem_usage=$(echo "$mem_usage + 256" | bc)

# Performance
docker ps --format '{{.Names}}' | grep -q "^infra_pgbouncer$" && cpu_usage=$(echo "$cpu_usage + 0.5" | bc) && mem_usage=$(echo "$mem_usage + 256" | bc)

# Convert MB to GB
mem_gb=$(echo "scale=1; $mem_usage / 1024" | bc)

echo -e "Estimated resources: ${YELLOW}~${cpu_usage} CPU${NC}, ${YELLOW}~${mem_gb}GB RAM${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Suggestions based on what's running
if [ "$running" -eq 3 ]; then
    echo -e "${YELLOW}💡 Tip: Running minimal profile. Add monitoring with:${NC}"
    echo "   ./scripts/toggle-tier.sh monitoring on"
elif [ "$running" -ge 4 ] && [ "$running" -le 6 ]; then
    echo -e "${YELLOW}💡 Tip: Running standard profile. Your setup looks good!${NC}"
elif [ "$running" -ge 7 ] && [ "$running" -le 12 ]; then
    echo -e "${YELLOW}💡 Tip: Running production profile. Nice!${NC}"
elif [ "$running" -ge 13 ]; then
    echo -e "${YELLOW}💡 Tip: Running full profile. Maximum observability!${NC}"
fi

echo ""
