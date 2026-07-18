#!/bin/bash
# Obtain SSL certificate with Let's Encrypt

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔐 Let's Encrypt Certificate Obtainer"
echo ""

if [ $# -lt 2 ]; then
    echo "Usage: $0 <domain> <email>"
    echo ""
    echo "Example:"
    echo "  $0 edu-hub.duckdns.org admin@example.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

echo "Domain: $DOMAIN"
echo "Email:  $EMAIL"
echo ""

# Check if nginx is running
if ! docker ps --filter "name=infra_nginx" --format '{{.Names}}' | grep -q "infra_nginx"; then
    echo -e "${RED}❌ Nginx is not running!${NC}"
    echo "Start nginx with: make start-nginx"
    exit 1
fi

# Check if certbot directory exists
if [ ! -d "certbot" ]; then
    echo -e "${RED}❌ Certbot directory not found!${NC}"
    exit 1
fi

echo "Obtaining certificate..."
echo ""

# Obtain certificate
docker compose -f certbot/docker-compose.yml run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d "$DOMAIN"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Certificate obtained successfully!${NC}"
    echo ""
    echo "Certificate location:"
    echo "  certbot/conf/live/$DOMAIN/"
    echo ""
    echo "Next steps:"
    echo "1. Update nginx configuration to use this certificate"
    echo "2. Reload nginx: make nginx-reload"
    echo "3. Test HTTPS: https://$DOMAIN"
else
    echo ""
    echo -e "${RED}❌ Failed to obtain certificate${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Ensure domain points to this server"
    echo "2. Check nginx is serving /.well-known/acme-challenge/"
    echo "3. Verify port 80 is accessible from internet"
    exit 1
fi
