#!/bin/bash

# Initialize Let's Encrypt certificates for the infrastructure
# This script obtains initial certificates using HTTP-01 challenge

set -e

# Configuration
DOMAIN="${DOMAIN:-edu-hub.duckdns.org}"
EMAIL="${LETSENCRYPT_EMAIL:-admin@${DOMAIN}}"
STAGING="${STAGING:-0}"  # Set to 1 for testing

# Paths
CERTBOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_DIR="${CERTBOT_DIR}/conf"
WWW_DIR="${CERTBOT_DIR}/www"
NGINX_DIR="$(dirname "$CERTBOT_DIR")/nginx"

echo "🔐 Initializing Let's Encrypt for ${DOMAIN}"
echo "📧 Email: ${EMAIL}"

# Create necessary directories
mkdir -p "$CONF_DIR" "$WWW_DIR"

# Check if certificate already exists
if [ -d "$CONF_DIR/live/$DOMAIN" ]; then
  echo "✅ Certificate for $DOMAIN already exists"
  echo "   To renew, run: docker compose exec certbot certbot renew"
  exit 0
fi

# Staging or production
STAGING_ARG=""
if [ "$STAGING" != "0" ]; then
  echo "⚠️  Using Let's Encrypt staging environment (for testing)"
  STAGING_ARG="--staging"
fi

# Check if nginx is running
if ! docker ps | grep -q infra_nginx; then
  echo "❌ nginx container is not running"
  echo "   Start nginx first: cd ../nginx && docker compose up -d"
  exit 1
fi

# Check if certbot network exists
if ! docker network ls | grep -q infra_network; then
  echo "❌ infra_network does not exist"
  echo "   Create it first: docker network create infra_network"
  exit 1
fi

# Obtain certificate using webroot (HTTP-01 challenge)
echo "🔑 Obtaining certificate from Let's Encrypt..."
docker run --rm \
  --name certbot_init \
  -v "$CONF_DIR:/etc/letsencrypt" \
  -v "$WWW_DIR:/var/www/certbot" \
  --network infra_network \
  certbot/certbot \
  certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  $STAGING_ARG \
  -d "$DOMAIN"

if [ $? -eq 0 ]; then
  echo "✅ Certificate obtained successfully!"
  echo "📁 Certificate location: $CONF_DIR/live/$DOMAIN/"

  # Start certbot renewal service
  echo "🔄 Starting certbot renewal service..."
  cd "$CERTBOT_DIR"
  docker compose up -d certbot

  # Reload nginx to use the new certificates
  echo "♻️  Reloading nginx..."
  docker exec infra_nginx nginx -s reload

  echo ""
  echo "✅ Setup complete!"
  echo "   - Certificates are located in: $CONF_DIR/live/$DOMAIN/"
  echo "   - Auto-renewal is running via certbot service"
  echo "   - Nginx will reload certificates automatically"
  echo ""
  echo "Next steps:"
  echo "   1. Update nginx configuration to use HTTPS"
  echo "   2. Test your site: https://$DOMAIN"
else
  echo "❌ Failed to obtain certificate"
  echo "   Check that:"
  echo "   - Domain $DOMAIN points to this server"
  echo "   - Port 80 is accessible from the internet"
  echo "   - nginx is running and configured for ACME challenges"
  exit 1
fi
