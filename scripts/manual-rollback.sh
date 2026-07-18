#!/bin/bash
# Manual rollback script for infrastructure deployments

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔄 Infrastructure Rollback Utility"
echo ""

# Check if we're in the infrastructure directory
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Not in a git repository!${NC}"
    echo "Please run this script from the infrastructure directory"
    exit 1
fi

# List available backup tags
echo "Available deployment backups:"
echo ""
git tag -l "pre-deploy-*" | sort -r | nl

echo ""
read -p "Enter the number of the backup to rollback to (or 'cancel'): " choice

if [ "$choice" = "cancel" ]; then
    echo "Rollback cancelled"
    exit 0
fi

# Get the selected tag
TAG=$(git tag -l "pre-deploy-*" | sort -r | sed -n "${choice}p")

if [ -z "$TAG" ]; then
    echo -e "${RED}❌ Invalid selection${NC}"
    exit 1
fi

CURRENT_COMMIT=$(git rev-parse HEAD)
TARGET_COMMIT=$(git rev-parse "$TAG")

echo ""
echo "Rollback Details:"
echo "  Current commit: $CURRENT_COMMIT"
echo "  Target commit:  $TARGET_COMMIT"
echo "  Backup tag:     $TAG"
echo ""

# Show what changed
echo "Changes that will be rolled back:"
git log --oneline "$TARGET_COMMIT..$CURRENT_COMMIT"
echo ""

# Confirmation
echo -e "${RED}⚠️  WARNING: This will rollback all infrastructure changes!${NC}"
read -p "Type 'ROLLBACK' to continue: " confirm

if [ "$confirm" != "ROLLBACK" ]; then
    echo "Rollback cancelled"
    exit 0
fi

# Create a tag for current state before rollback
CURRENT_TAG="pre-rollback-$(date +%Y%m%d-%H%M%S)"
git tag "$CURRENT_TAG" "$CURRENT_COMMIT"
echo -e "${GREEN}✅ Created safety tag: $CURRENT_TAG${NC}"

# Perform rollback
echo ""
echo "Rolling back to $TAG..."
git reset --hard "$TAG"

# Reinitialize environment
chmod +x scripts/*.sh
./scripts/init-env.sh

# Restart all services
echo ""
echo "Restarting all services..."

if [ -d "databases" ]; then
    echo "  Restarting databases..."
    cd databases && docker compose up -d --force-recreate && cd ..
fi

if [ -d "monitoring" ]; then
    echo "  Restarting monitoring..."
    cd monitoring && docker compose up -d --force-recreate && cd ..
fi

if [ -d "nginx" ]; then
    echo "  Restarting nginx..."
    cd nginx && docker compose up -d --force-recreate && cd ..
fi

# Wait for services to stabilize
echo ""
echo "Waiting for services to stabilize..."
sleep 15

# Health check
echo ""
echo "Running health checks..."
if ./scripts/health-check.sh; then
    echo ""
    echo -e "${GREEN}✅ Rollback completed successfully!${NC}"
    echo ""
    echo "Recovery information:"
    echo "  If you need to undo this rollback, use tag: $CURRENT_TAG"
    echo "  Command: git reset --hard $CURRENT_TAG"
else
    echo ""
    echo -e "${RED}❌ Health checks failed after rollback!${NC}"
    echo "Please investigate manually"
    exit 1
fi
