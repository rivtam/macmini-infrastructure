#!/bin/bash

# Enable HTTPS in nginx configuration after obtaining Let's Encrypt certificates
# This script uncomments the HTTPS server block and enables HTTP->HTTPS redirect

set -e

NGINX_DIR="$(cd "$(dirname "$0")" && pwd)"
NGINX_CONF="$NGINX_DIR/nginx.conf"
BACKUP_CONF="$NGINX_CONF.backup-$(date +%Y%m%d-%H%M%S)"

echo "🔐 Enabling HTTPS in nginx configuration..."

# Check if certificates exist
DOMAIN="${DOMAIN:-edu-hub.duckdns.org}"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"

# Check inside container
if docker ps | grep -q infra_nginx; then
    if ! docker exec infra_nginx test -f "$CERT_PATH"; then
        echo "❌ Certificate not found: $CERT_PATH"
        echo "   Run: cd ../certbot && ./init-letsencrypt.sh"
        exit 1
    fi
else
    echo "⚠️  nginx container not running - skipping certificate check"
fi

# Backup current config
cp "$NGINX_CONF" "$BACKUP_CONF"
echo "📋 Backup created: $BACKUP_CONF"

# Create new config with HTTPS enabled
cat > "$NGINX_CONF" << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               application/rss+xml font/truetype font/opentype
               application/vnd.ms-fontobject image/svg+xml;

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/m;

    # Include all site configurations
    include /etc/nginx/sites-enabled/*.conf;

    # HTTP server - redirect to HTTPS (except ACME challenges)
    server {
        listen 80 default_server;
        server_name _;

        # Health check endpoint
        location = /healthz {
            access_log off;
            default_type text/plain;
            return 200 'ok';
        }

        # ACME challenge for Let's Encrypt - MUST remain accessible via HTTP
        location ^~ /.well-known/acme-challenge/ {
            root /var/www/certbot;
            default_type "text/plain";
            try_files $uri =404;
        }

        # Redirect all other HTTP traffic to HTTPS
        location / {
            return 301 https://$host$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl http2 default_server;
        server_name _;

        # SSL Configuration - Let's Encrypt certificates
        ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers on;
        ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Health check
        location = /healthz {
            access_log off;
            default_type text/plain;
            return 200 'ok';
        }

        # Default response
        location / {
            default_type text/html;
            return 200 '<!DOCTYPE html>
<html>
<head>
    <title>Infrastructure Ready</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #2ecc71; }
        .icon { font-size: 64px; }
    </style>
</head>
<body>
    <div class="icon">🔒</div>
    <h1>Infrastructure Ready</h1>
    <p>SSL/TLS encryption is active.</p>
    <p><a href="/healthz">Health Check</a></p>
</body>
</html>';
        }
    }
}
EOF

# Replace DOMAIN_PLACEHOLDER with actual domain
sed -i.tmp "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" "$NGINX_CONF"
rm -f "$NGINX_CONF.tmp"

echo "✅ HTTPS configuration enabled"

# Test nginx configuration
if docker ps | grep -q infra_nginx; then
    echo "🧪 Testing nginx configuration..."
    if docker exec infra_nginx nginx -t; then
        echo "♻️  Reloading nginx..."
        docker exec infra_nginx nginx -s reload
        echo "✅ nginx reloaded with HTTPS enabled!"
        echo ""
        echo "🎉 HTTPS is now active!"
        echo "   Test your site: https://$DOMAIN"
    else
        echo "❌ nginx configuration test failed!"
        echo "   Restoring backup..."
        mv "$BACKUP_CONF" "$NGINX_CONF"
        exit 1
    fi
else
    echo "⚠️  nginx container not running"
    echo "   Configuration updated. Restart nginx to apply changes:"
    echo "   docker compose restart nginx"
fi

echo ""
echo "ℹ️  Backup saved at: $BACKUP_CONF"
