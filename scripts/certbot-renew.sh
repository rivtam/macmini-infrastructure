#!/bin/bash
# Renew SSL certificates

set -e

echo "🔄 Renewing SSL Certificates"
echo ""

# Check if certbot is available
if ! docker compose -f certbot/docker-compose.yml config > /dev/null 2>&1; then
    echo "❌ Certbot not configured"
    exit 1
fi

# Renew certificates
docker compose -f certbot/docker-compose.yml run --rm certbot renew --webroot -w /var/www/certbot

# Reload nginx if renewal was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Certificates renewed"
    echo "Reloading nginx..."

    if docker ps --filter "name=infra_nginx" --format '{{.Names}}' | grep -q "infra_nginx"; then
        docker exec infra_nginx nginx -s reload
        echo "✅ Nginx reloaded"
    fi
else
    echo "❌ Certificate renewal failed"
    exit 1
fi
