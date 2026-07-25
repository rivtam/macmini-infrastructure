#!/bin/bash
# Start infrastructure services based on tier profiles

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIER="${1:-standard}"

echo -e "${BLUE}🚀 Infrastructure Service Manager${NC}"
echo ""

# Service tier definitions
declare -A TIERS=(
    [essential]="databases monitoring/exporters:postgres-exporter,redis-exporter nginx"
    [monitoring]="monitoring/core:prometheus,grafana,node-exporter"
    [advanced-monitoring]="monitoring/logs:loki,promtail monitoring/alerts:alertmanager monitoring/metrics:cadvisor"
    [observability]="monitoring/exporters:all"
    [security]="vault certbot audit"
    [performance]="databases/pooling:pgbouncer"
)

start_tier() {
    local tier=$1
    local services=${TIERS[$tier]}

    echo -e "${GREEN}▶ Starting tier: $tier${NC}"

    for service_spec in $services; do
        IFS=':' read -r dir profile <<< "$service_spec"

        cd "$INFRA_DIR/$dir"

        if [ -n "$profile" ]; then
            echo "  Starting $dir with profile: $profile"
            COMPOSE_PROFILES=$profile docker compose up -d
        else
            echo "  Starting all services in $dir"
            docker compose up -d
        fi

        cd "$INFRA_DIR"
    done

    echo ""
}

case "$TIER" in
    minimal)
        echo -e "${YELLOW}Minimal Profile: Essential services only${NC}"
        echo "Services: PostgreSQL, Redis, Nginx"
        echo "Resources: 4 CPU, 3GB RAM"
        echo ""

        cd "$INFRA_DIR/databases"
        docker compose up -d postgres redis

        cd "$INFRA_DIR/nginx"
        docker compose up -d
        ;;

    standard)
        echo -e "${YELLOW}Standard Profile: Essential + Basic Monitoring${NC}"
        echo "Services: Essential + Prometheus, Grafana, Node Exporter"
        echo "Resources: 6.5 CPU, 4.6GB RAM"
        echo ""

        # Essential
        cd "$INFRA_DIR/databases"
        docker compose up -d postgres redis

        cd "$INFRA_DIR/nginx"
        docker compose up -d

        # Monitoring
        cd "$INFRA_DIR/monitoring"
        docker compose up -d prometheus grafana node-exporter
        ;;

    production)
        echo -e "${YELLOW}Production Profile: Standard + Security + Performance${NC}"
        echo "Services: Standard + Vault, Certbot, PgBouncer, Exporters"
        echo "Resources: ~9 CPU, ~6GB RAM"
        echo ""

        # Essential + Performance
        cd "$INFRA_DIR/databases"
        docker compose up -d postgres redis pgbouncer postgres-exporter redis-exporter

        cd "$INFRA_DIR/nginx"
        docker compose up -d

        # Monitoring
        cd "$INFRA_DIR/monitoring"
        docker compose up -d prometheus grafana node-exporter alertmanager

        # Security
        cd "$INFRA_DIR/vault"
        docker compose up -d

        cd "$INFRA_DIR/certbot"
        docker compose up -d
        ;;

    full)
        echo -e "${YELLOW}Full Profile: All services enabled${NC}"
        echo "Services: Everything"
        echo "Resources: ~12.5 CPU, ~7GB RAM"
        echo ""

        # Start everything
        cd "$INFRA_DIR/databases"
        docker compose up -d

        cd "$INFRA_DIR/nginx"
        docker compose up -d

        cd "$INFRA_DIR/monitoring"
        docker compose up -d

        cd "$INFRA_DIR/vault"
        docker compose up -d

        cd "$INFRA_DIR/certbot"
        docker compose up -d

        cd "$INFRA_DIR/audit"
        docker compose up -d
        ;;

    custom)
        echo -e "${YELLOW}Custom Profile: Interactive selection${NC}"
        echo ""

        echo "Select tiers to enable (space-separated numbers):"
        echo "1. Essential (PostgreSQL, Redis, Nginx)"
        echo "2. Monitoring (Prometheus, Grafana, Node Exporter)"
        echo "3. Advanced Monitoring (Loki, Promtail, Alertmanager)"
        echo "4. Observability (Database exporters, cAdvisor)"
        echo "5. Security (Vault, Certbot, Audit)"
        echo "6. Performance (PgBouncer)"
        echo ""
        read -p "Enter numbers (e.g., 1 2 5): " selections

        for selection in $selections; do
            case $selection in
                1)
                    cd "$INFRA_DIR/databases"
                    docker compose up -d postgres redis
                    cd "$INFRA_DIR/nginx"
                    docker compose up -d
                    ;;
                2)
                    cd "$INFRA_DIR/monitoring"
                    docker compose up -d prometheus grafana node-exporter
                    ;;
                3)
                    cd "$INFRA_DIR/monitoring"
                    docker compose up -d loki promtail alertmanager cadvisor
                    ;;
                4)
                    cd "$INFRA_DIR/databases"
                    docker compose up -d postgres-exporter redis-exporter
                    cd "$INFRA_DIR/monitoring"
                    docker compose up -d cadvisor
                    cd "$INFRA_DIR/certbot"
                    docker compose up -d certbot-exporter 2>/dev/null || true
                    ;;
                5)
                    cd "$INFRA_DIR/vault"
                    docker compose up -d
                    cd "$INFRA_DIR/certbot"
                    docker compose up -d
                    cd "$INFRA_DIR/audit"
                    docker compose up -d
                    ;;
                6)
                    cd "$INFRA_DIR/databases"
                    docker compose up -d pgbouncer
                    ;;
            esac
        done
        cd "$INFRA_DIR"
        ;;

    *)
        echo -e "${YELLOW}Usage: $0 [minimal|standard|production|full|custom]${NC}"
        echo ""
        echo "Profiles:"
        echo "  minimal     - Essential services only (4 CPU, 3GB RAM)"
        echo "  standard    - Essential + basic monitoring (6.5 CPU, 4.6GB RAM)"
        echo "  production  - Standard + security + performance (9 CPU, 6GB RAM)"
        echo "  full        - All services (12.5 CPU, 7GB RAM)"
        echo "  custom      - Interactive selection"
        echo ""
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Services started successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Show status
"$INFRA_DIR/scripts/service-status.sh"
