#!/bin/bash
# Deploy infrastructure using GHCR images (no builds on Mac Mini!)

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            INFRASTRUCTURE DEPLOYMENT (GHCR)                               ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if logged into GHCR
if ! docker info 2>/dev/null | grep -q "ghcr.io"; then
    echo -e "${YELLOW}Not logged into GHCR. Please login first:${NC}"
    echo "  export GHCR_TOKEN=your_token_here"
    echo "  echo \$GHCR_TOKEN | docker login ghcr.io -u your_username --password-stdin"
    echo ""
    read -p "Have you logged in? (yes/no): " logged_in
    if [ "$logged_in" != "yes" ]; then
        echo "Please login to GHCR first."
        exit 1
    fi
fi

# Set GitHub repository owner (for GHCR image paths)
export GITHUB_REPOSITORY_OWNER="${GITHUB_REPOSITORY_OWNER:-tammynkuna}"
echo -e "${CYAN}Using GHCR images from: ghcr.io/$GITHUB_REPOSITORY_OWNER/*${NC}"
echo ""

# Ask which services to deploy
echo -e "${BLUE}━━━ Select Services to Deploy ━━━${NC}"
echo ""
echo "1. All services"
echo "2. Nginx only"
echo "3. Databases only"
echo "4. Monitoring only"
echo "5. Custom selection"
echo ""
read -p "Enter choice (1-5) [1]: " deploy_choice
deploy_choice=${deploy_choice:-1}

DEPLOY_NGINX=false
DEPLOY_DATABASES=false
DEPLOY_MONITORING=false

case $deploy_choice in
    1)
        DEPLOY_NGINX=true
        DEPLOY_DATABASES=true
        DEPLOY_MONITORING=true
        ;;
    2)
        DEPLOY_NGINX=true
        ;;
    3)
        DEPLOY_DATABASES=true
        ;;
    4)
        DEPLOY_MONITORING=true
        ;;
    5)
        read -p "Deploy Nginx? (yes/no): " nginx_choice
        [ "$nginx_choice" = "yes" ] && DEPLOY_NGINX=true

        read -p "Deploy Databases? (yes/no): " db_choice
        [ "$db_choice" = "yes" ] && DEPLOY_DATABASES=true

        read -p "Deploy Monitoring? (yes/no): " mon_choice
        [ "$mon_choice" = "yes" ] && DEPLOY_MONITORING=true
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo -e "${CYAN}Deployment Plan:${NC}"
echo "  Nginx: $DEPLOY_NGINX"
echo "  Databases: $DEPLOY_DATABASES"
echo "  Monitoring: $DEPLOY_MONITORING"
echo ""
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}━━━ Starting Deployment ━━━${NC}"
echo ""

# Function to pull and deploy a service
deploy_service() {
    SERVICE_DIR=$1
    SERVICE_NAME=$2

    echo -e "${CYAN}📦 Deploying $SERVICE_NAME...${NC}"
    cd "$INFRA_DIR/$SERVICE_DIR"

    # Pull latest images from GHCR (NO BUILDS!)
    echo "  ⬇️  Pulling images..."
    docker compose pull

    # Deploy with health checks
    echo "  🚀 Starting services..."
    docker compose up -d

    # Wait a moment for services to stabilize
    sleep 5

    # Check service health
    CONTAINERS=$(docker compose ps --services)
    for container in $CONTAINERS; do
        CONTAINER_NAME="${container}"
        if docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" | grep -q "${CONTAINER_NAME}"; then
            STATUS=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}running{{end}}' "${CONTAINER_NAME}" 2>/dev/null || echo "unknown")
            if [ "$STATUS" = "healthy" ] || [ "$STATUS" = "running" ]; then
                echo -e "  ${GREEN}✓${NC} $container is $STATUS"
            else
                echo -e "  ${YELLOW}⚠${NC}  $container status: $STATUS"
            fi
        else
            echo -e "  ${RED}✗${NC} $container is not running"
        fi
    done

    cd "$INFRA_DIR"
    echo ""
}

# Deploy Nginx
if [ "$DEPLOY_NGINX" = true ]; then
    deploy_service "nginx" "Nginx"
fi

# Deploy Databases
if [ "$DEPLOY_DATABASES" = true ]; then
    deploy_service "databases" "Databases"
fi

# Deploy Monitoring
if [ "$DEPLOY_MONITORING" = true ]; then
    deploy_service "monitoring" "Monitoring Stack"
fi

# Cleanup old images
echo -e "${CYAN}🧹 Cleaning up old images...${NC}"
docker system prune -f
echo ""

# Final status
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    DEPLOYMENT COMPLETE! 🎉                                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Running Services:${NC}"
docker ps --filter "name=infra_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo -e "${CYAN}Resource Usage:${NC}"
echo "  RAM: $(docker stats --no-stream --format "{{.MemUsage}}" | head -1 2>/dev/null || echo 'N/A')"
echo "  Images: $(docker images --filter reference='ghcr.io/*/infra-*' --format "{{.Repository}}:{{.Tag}}" | wc -l) GHCR images cached"
echo ""

echo -e "${YELLOW}Important Notes:${NC}"
echo "  • Images were pulled from GHCR (NO builds on Mac Mini!)"
echo "  • To update images: Re-run this script or 'docker compose pull' in each directory"
echo "  • All configs are baked into images (no volume mounts for configs)"
echo "  • Check logs: docker logs infra_<service>"
echo ""
