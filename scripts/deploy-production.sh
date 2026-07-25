#!/bin/bash
# Interactive production deployment script

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

clear
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 PRODUCTION DEPLOYMENT WIZARD                              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if this is first deployment
if [ -f "$INFRA_DIR/.deployed" ]; then
    echo -e "${YELLOW}⚠️  Infrastructure already deployed!${NC}"
    echo ""
    read -p "Do you want to redeploy? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

echo -e "${CYAN}This wizard will help you deploy your infrastructure in production.${NC}"
echo ""

# Step 1: Choose profile
echo -e "${BLUE}━━━ Step 1: Choose Service Profile ━━━${NC}"
echo ""
echo "Select the profile based on your startup stage:"
echo ""
echo "1. Minimal      (4 CPU, 3GB RAM)    - Bootstrapping, MVP"
echo "2. Standard     (6.5 CPU, 4.6GB)    - Early traction [RECOMMENDED]"
echo "3. Production   (9 CPU, 6GB)        - Growth stage"
echo "4. Full         (12.5 CPU, 7GB)     - Enterprise/Compliance"
echo ""
read -p "Enter choice (1-4) [2]: " profile_choice
profile_choice=${profile_choice:-2}

case $profile_choice in
    1) PROFILE="minimal" ;;
    2) PROFILE="standard" ;;
    3) PROFILE="production" ;;
    4) PROFILE="full" ;;
    *) echo "Invalid choice. Using standard."; PROFILE="standard" ;;
esac

echo -e "${GREEN}✓${NC} Selected profile: $PROFILE"
echo ""

# Step 2: Environment setup
echo -e "${BLUE}━━━ Step 2: Configure Environment ━━━${NC}"
echo ""

if [ ! -f "$INFRA_DIR/databases/.env" ]; then
    echo -e "${YELLOW}Creating environment files...${NC}"

    cd "$INFRA_DIR/databases"
    cp .env.example .env

    cd "$INFRA_DIR/monitoring"
    cp .env.example .env

    echo -e "${GREEN}✓${NC} Environment files created"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT: You must edit environment files with strong passwords!${NC}"
    echo ""
    echo "Generate strong passwords:"
    echo "  openssl rand -base64 32"
    echo ""
    echo "Edit these files:"
    echo "  1. databases/.env     (PostgreSQL, Redis passwords)"
    echo "  2. monitoring/.env    (Grafana password)"
    echo ""
    read -p "Press Enter when you've updated the passwords..."
else
    echo -e "${GREEN}✓${NC} Environment files already exist"
fi

echo ""

# Step 3: Domain configuration
echo -e "${BLUE}━━━ Step 3: Domain Configuration ━━━${NC}"
echo ""
read -p "Do you have a domain name? (yes/no): " has_domain

if [ "$has_domain" = "yes" ]; then
    read -p "Enter your domain (e.g., yourdomain.com): " domain
    read -p "Enter your email for SSL certificates: " email

    echo -e "${YELLOW}Make sure your domain DNS points to this server!${NC}"
    echo "Current IP: $(curl -s ifconfig.me 2>/dev/null || echo 'Unable to detect')"
    echo ""
    read -p "Press Enter when DNS is configured..."
else
    domain=""
    email=""
    echo "Skipping domain configuration. You can add SSL later."
fi

echo ""

# Step 4: Create network
echo -e "${BLUE}━━━ Step 4: Create Docker Network ━━━${NC}"
echo ""

if docker network inspect infra_network >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Network 'infra_network' already exists"
else
    docker network create infra_network
    echo -e "${GREEN}✓${NC} Created network 'infra_network'"
fi

echo ""

# Step 5: Start services
echo -e "${BLUE}━━━ Step 5: Starting Infrastructure Services ━━━${NC}"
echo ""
echo "Starting $PROFILE profile..."
echo ""

"$INFRA_DIR/scripts/start-services.sh" "$PROFILE"

echo ""
echo -e "${GREEN}✓${NC} Services started"
echo ""

# Step 6: Wait for services to be ready
echo -e "${BLUE}━━━ Step 6: Waiting for Services to Start ━━━${NC}"
echo ""

echo -n "Waiting for PostgreSQL..."
for i in {1..30}; do
    if docker exec infra_postgres pg_isready -U postgres >/dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo -n "Waiting for Redis..."
REDIS_PASSWORD=$(grep REDIS_PASSWORD "$INFRA_DIR/databases/.env" | cut -d'=' -f2)
for i in {1..30}; do
    if docker exec infra_redis redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""

# Step 7: Initialize database user
echo -e "${BLUE}━━━ Step 7: Database Setup ━━━${NC}"
echo ""

read -p "Create application database? (yes/no) [yes]: " create_db
create_db=${create_db:-yes}

if [ "$create_db" = "yes" ]; then
    read -p "Database name: " db_name
    read -p "Database user: " db_user
    echo "Generating secure password for database user..."
    db_password=$(openssl rand -base64 24)

    echo ""
    echo "Creating database and user..."

    docker exec -i infra_postgres psql -U postgres << EOF
CREATE DATABASE $db_name;
CREATE USER $db_user WITH PASSWORD '$db_password';
GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;
\c $db_name
GRANT ALL ON SCHEMA public TO $db_user;
EOF

    echo -e "${GREEN}✓${NC} Database created"
    echo ""
    echo -e "${YELLOW}Database connection details:${NC}"
    echo "  Database: $db_name"
    echo "  User: $db_user"
    echo "  Password: $db_password"
    echo "  Connection string: postgresql://$db_user:$db_password@infra_postgres:5432/$db_name"
    echo ""
    echo -e "${RED}⚠️  SAVE THESE CREDENTIALS SECURELY!${NC}"
    echo ""
    read -p "Press Enter to continue..."
fi

echo ""

# Step 8: SSL setup
if [ -n "$domain" ]; then
    echo -e "${BLUE}━━━ Step 8: SSL Certificate Setup ━━━${NC}"
    echo ""

    read -p "Obtain Let's Encrypt SSL certificate? (yes/no) [yes]: " setup_ssl
    setup_ssl=${setup_ssl:-yes}

    if [ "$setup_ssl" = "yes" ]; then
        echo "Obtaining SSL certificate for $domain..."
        "$INFRA_DIR/scripts/certbot-obtain.sh" "$domain" "$email"

        echo ""
        echo "Starting Certbot auto-renewal..."
        cd "$INFRA_DIR/certbot"
        docker compose up -d
        cd "$INFRA_DIR"

        echo -e "${GREEN}✓${NC} SSL certificate obtained and auto-renewal enabled"
        echo ""
        echo "Update your nginx configuration to use HTTPS:"
        echo "  nano nginx/sites/eduhub.conf"
        echo "  (Add SSL configuration - see PRODUCTION_DEPLOYMENT.md for example)"
        echo ""
    fi
fi

# Step 9: Backups
echo -e "${BLUE}━━━ Step 9: Automated Backups ━━━${NC}"
echo ""

read -p "Set up automated daily backups? (yes/no) [yes]: " setup_backup
setup_backup=${setup_backup:-yes}

if [ "$setup_backup" = "yes" ]; then
    "$INFRA_DIR/scripts/setup-backup-cron.sh"
    echo -e "${GREEN}✓${NC} Automated backups configured (daily at 2 AM)"

    echo ""
    read -p "Test backup now? (yes/no) [yes]: " test_backup
    test_backup=${test_backup:-yes}

    if [ "$test_backup" = "yes" ]; then
        "$INFRA_DIR/scripts/backup-databases.sh"
        echo -e "${GREEN}✓${NC} Backup completed"
        echo "Backup location: ../backups/daily/"
    fi
fi

echo ""

# Step 10: Firewall
echo -e "${BLUE}━━━ Step 10: Firewall Configuration ━━━${NC}"
echo ""

if command -v ufw >/dev/null 2>&1; then
    read -p "Configure firewall with ufw? (yes/no) [yes]: " setup_firewall
    setup_firewall=${setup_firewall:-yes}

    if [ "$setup_firewall" = "yes" ]; then
        echo -e "${YELLOW}Configuring firewall...${NC}"
        sudo ufw allow 22/tcp    # SSH
        sudo ufw allow 80/tcp    # HTTP
        sudo ufw allow 443/tcp   # HTTPS

        echo ""
        echo -e "${RED}⚠️  About to enable firewall. Make sure SSH port 22 is allowed!${NC}"
        read -p "Enable firewall? (yes/no): " enable_fw

        if [ "$enable_fw" = "yes" ]; then
            sudo ufw --force enable
            echo -e "${GREEN}✓${NC} Firewall enabled"
            sudo ufw status
        fi
    fi
else
    echo "ufw not installed. Install with: sudo apt install ufw"
fi

echo ""

# Step 11: Fail2ban
echo -e "${BLUE}━━━ Step 11: DDoS Protection (Fail2ban) ━━━${NC}"
echo ""

read -p "Install Fail2ban for DDoS protection? (yes/no) [yes]: " setup_fail2ban
setup_fail2ban=${setup_fail2ban:-yes}

if [ "$setup_fail2ban" = "yes" ]; then
    sudo "$INFRA_DIR/scripts/setup-fail2ban.sh"
    echo -e "${GREEN}✓${NC} Fail2ban installed and configured"
fi

echo ""

# Mark as deployed
touch "$INFRA_DIR/.deployed"
echo "profile=$PROFILE" > "$INFRA_DIR/.deployed"
echo "deployed_at=$(date)" >> "$INFRA_DIR/.deployed"

# Final summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    DEPLOYMENT COMPLETED! 🎉                               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Infrastructure Summary:${NC}"
echo "  Profile: $PROFILE"
echo "  Services running: $(docker ps --filter "name=infra_" --format '{{.Names}}' | wc -l)"
echo ""

if [ -n "$domain" ]; then
    echo -e "${CYAN}Access Points:${NC}"
    echo "  Application: http://$domain (https after SSL setup)"
    echo "  Monitoring: http://$(curl -s ifconfig.me):3000"
else
    echo -e "${CYAN}Access Points:${NC}"
    echo "  Server IP: $(curl -s ifconfig.me 2>/dev/null || echo 'localhost')"
    echo "  Monitoring: http://$(curl -s ifconfig.me):3000"
fi

echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Deploy your application containers"
echo "  2. Configure application to connect to databases"
echo "  3. Set up Nginx configuration for your app"
echo "  4. Access Grafana to see monitoring dashboards"
echo "  5. Review security settings"
echo ""

echo -e "${YELLOW}Important Commands:${NC}"
echo "  Check status:    ./scripts/service-status.sh"
echo "  View logs:       docker logs infra_<service>"
echo "  Backup now:      ./scripts/backup-databases.sh"
echo "  Stop all:        cd <dir> && docker compose stop"
echo ""

echo -e "${CYAN}Documentation:${NC}"
echo "  Complete guide:  PRODUCTION_DEPLOYMENT.md"
echo "  Quick ref:       QUICK_REFERENCE.md"
echo "  Full docs:       DOCUMENTATION.md"
echo ""

echo "Deployment log saved to: $INFRA_DIR/.deployed"
echo ""
