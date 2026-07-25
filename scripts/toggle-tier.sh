#!/bin/bash
# Toggle service tiers on/off

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIER="${1}"
ACTION="${2:-on}"

if [ -z "$TIER" ]; then
    echo -e "${RED}Usage: $0 <tier> [on|off]${NC}"
    echo ""
    echo "Available tiers:"
    echo "  monitoring           - Prometheus, Grafana, Node Exporter"
    echo "  advanced-monitoring  - Loki, Promtail, Alertmanager, cAdvisor"
    echo "  observability        - All exporters (PostgreSQL, Redis, SSL)"
    echo "  security             - Vault, Certbot, Audit"
    echo "  performance          - PgBouncer connection pooling"
    echo ""
    echo "Examples:"
    echo "  $0 monitoring on"
    echo "  $0 security off"
    exit 1
fi

toggle_tier() {
    local tier=$1
    local action=$2

    case "$tier" in
        monitoring)
            cd "$INFRA_DIR/monitoring"
            if [ "$action" = "on" ]; then
                echo -e "${GREEN}▶ Starting Monitoring tier${NC}"
                docker compose up -d prometheus grafana node-exporter
            else
                echo -e "${RED}■ Stopping Monitoring tier${NC}"
                docker compose stop prometheus grafana node-exporter
            fi
            ;;

        advanced-monitoring)
            cd "$INFRA_DIR/monitoring"
            if [ "$action" = "on" ]; then
                echo -e "${GREEN}▶ Starting Advanced Monitoring tier${NC}"
                docker compose up -d loki promtail alertmanager cadvisor
            else
                echo -e "${RED}■ Stopping Advanced Monitoring tier${NC}"
                docker compose stop loki promtail alertmanager cadvisor
            fi
            ;;

        observability)
            cd "$INFRA_DIR/databases"
            if [ "$action" = "on" ]; then
                echo -e "${GREEN}▶ Starting Observability tier${NC}"
                docker compose up -d postgres-exporter redis-exporter
                cd "$INFRA_DIR/monitoring"
                docker compose up -d cadvisor
                cd "$INFRA_DIR/certbot"
                docker compose up -d certbot-exporter 2>/dev/null || echo "  (SSL exporter not configured)"
            else
                echo -e "${RED}■ Stopping Observability tier${NC}"
                docker compose stop postgres-exporter redis-exporter
                cd "$INFRA_DIR/monitoring"
                docker compose stop cadvisor
                cd "$INFRA_DIR/certbot"
                docker compose stop certbot-exporter 2>/dev/null || true
            fi
            ;;

        security)
            if [ "$action" = "on" ]; then
                echo -e "${GREEN}▶ Starting Security tier${NC}"
                cd "$INFRA_DIR/vault"
                docker compose up -d
                cd "$INFRA_DIR/certbot"
                docker compose up -d
                cd "$INFRA_DIR/audit"
                docker compose up -d
            else
                echo -e "${RED}■ Stopping Security tier${NC}"
                cd "$INFRA_DIR/vault"
                docker compose stop
                cd "$INFRA_DIR/certbot"
                docker compose stop
                cd "$INFRA_DIR/audit"
                docker compose stop
            fi
            ;;

        performance)
            cd "$INFRA_DIR/databases"
            if [ "$action" = "on" ]; then
                echo -e "${GREEN}▶ Starting Performance tier (PgBouncer)${NC}"
                docker compose up -d pgbouncer
            else
                echo -e "${RED}■ Stopping Performance tier (PgBouncer)${NC}"
                docker compose stop pgbouncer
            fi
            ;;

        *)
            echo -e "${RED}Unknown tier: $tier${NC}"
            exit 1
            ;;
    esac
}

toggle_tier "$TIER" "$ACTION"

echo ""
echo -e "${GREEN}✅ Tier toggled successfully!${NC}"
echo ""

# Show current status
cd "$INFRA_DIR"
"$INFRA_DIR/scripts/service-status.sh"
