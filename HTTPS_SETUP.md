# HTTPS Setup Guide

This guide explains how to enable HTTPS with Let's Encrypt certificates for your infrastructure.

## Overview

The infrastructure supports a two-stage HTTPS setup:

1. **Stage 1 (HTTP only)**: Initial deployment without SSL certificates
2. **Stage 2 (HTTPS enabled)**: After obtaining Let's Encrypt certificates

## Prerequisites

- Domain name pointing to your server (e.g., `edu-hub.duckdns.org`)
- Port 80 accessible from the internet (for ACME HTTP-01 challenge)
- Port 443 open for HTTPS traffic (for production use)
- Infrastructure deployed and running

## Stage 1: Initial Deployment (Current State)

The infrastructure initially deploys with HTTP only:

```
✅ Port 80 open
   - /.well-known/acme-challenge/ → Let's Encrypt verification
   - /healthz → Health check endpoint
   - / → Setup instructions page

❌ Port 443 not configured (no certificates yet)
```

## Stage 2: Enable HTTPS

### Step 1: Obtain Let's Encrypt Certificates

SSH into your server and run:

```bash
cd ~/prod/infrastructure/certbot
./init-letsencrypt.sh
```

#### Environment Variables (Optional)

```bash
# Use custom domain
DOMAIN=your-domain.com ./init-letsencrypt.sh

# Use custom email
LETSENCRYPT_EMAIL=admin@example.com ./init-letsencrypt.sh

# Test with staging first (recommended)
STAGING=1 ./init-letsencrypt.sh
```

#### What this script does:

1. Checks if nginx is running
2. Uses HTTP-01 challenge to verify domain ownership
3. Obtains SSL certificates from Let's Encrypt
4. Starts certbot auto-renewal service
5. Certificates stored in `certbot/conf/live/YOUR_DOMAIN/`

### Step 2: Enable HTTPS in nginx

After obtaining certificates, enable HTTPS:

```bash
cd ~/prod/infrastructure/nginx
./enable-https.sh
```

#### What this script does:

1. Backs up current nginx.conf
2. Updates configuration to:
   - Redirect HTTP → HTTPS (except ACME challenges)
   - Enable HTTPS server with SSL certificates
   - Add security headers (HSTS, X-Frame-Options, etc.)
3. Tests nginx configuration
4. Reloads nginx with new config

### Step 3: Verify HTTPS is Working

Test your site:

```bash
# Check HTTP redirects to HTTPS
curl -I http://your-domain.com

# Check HTTPS is working
curl -I https://your-domain.com

# Check SSL certificate
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

## Certificate Auto-Renewal

Certificates are automatically renewed by the certbot service:

- Checks for renewal twice daily
- Renews certificates 30 days before expiration
- Reloads nginx automatically after renewal

### Manual Renewal

```bash
# Dry run (test renewal)
docker compose -f ~/prod/infrastructure/certbot/docker-compose.yml exec certbot certbot renew --dry-run

# Force renewal
docker compose -f ~/prod/infrastructure/certbot/docker-compose.yml exec certbot certbot renew --force-renewal
```

## Monitoring

### Certificate Expiration

The `certbot-exporter` service exposes Prometheus metrics:

```bash
curl http://localhost:9219/metrics
```

Import Grafana dashboard (ID: 13230) to monitor certificate expiration.

### Check Certificate Status

```bash
# List all certificates
docker compose -f ~/prod/infrastructure/certbot/docker-compose.yml exec certbot certbot certificates

# Check expiration
echo | openssl s_client -connect your-domain.com:443 -servername your-domain.com 2>/dev/null | openssl x509 -noout -dates
```

## Security Considerations

### Ports Required

| Port | Purpose | Internet Access |
|------|---------|----------------|
| 80   | ACME challenges, HTTP→HTTPS redirect | Required |
| 443  | HTTPS traffic | Required for public portals |

### HTTP Port 80 Security

Port 80 **must** remain accessible from the internet for:
- Let's Encrypt ACME challenges (renewal every 60 days)
- HTTPS redirects

All actual traffic goes through HTTPS (port 443). Port 80 only serves:
1. `/.well-known/acme-challenge/` → Let's Encrypt verification
2. Everything else → 301 redirect to HTTPS

### Security Headers

The HTTPS configuration includes:

```nginx
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
```

## Troubleshooting

### Certificate Obtainment Fails

**Check domain DNS**:
```bash
dig +short your-domain.com
# Should return your server's IP
```

**Check port 80 is accessible**:
```bash
curl http://your-domain.com/.well-known/acme-challenge/test
# Should return 404 (not connection refused)
```

**Check nginx ACME endpoint**:
```bash
docker exec infra_nginx curl -I localhost/.well-known/acme-challenge/test
# Should return 404 (endpoint is configured)
```

### nginx Won't Reload After enable-https.sh

**Test configuration**:
```bash
docker exec infra_nginx nginx -t
```

**Check certificate files exist**:
```bash
docker exec infra_nginx ls -la /etc/letsencrypt/live/your-domain.com/
```

**Restore from backup**:
```bash
cd ~/prod/infrastructure/nginx
cp nginx.conf.backup-XXXXXXXX nginx.conf
docker exec infra_nginx nginx -s reload
```

### Rate Limits

Let's Encrypt has rate limits:
- 50 certificates per domain per week
- 5 duplicate certificates per week

**Solution**: Use staging environment for testing:
```bash
STAGING=1 ./init-letsencrypt.sh
```

## Rollback to HTTP-Only

If you need to disable HTTPS:

```bash
cd ~/prod/infrastructure/nginx

# Restore from backup
ls -lt nginx.conf.backup-* | head -1  # Find latest backup
cp nginx.conf.backup-XXXXXXXXX nginx.conf

# Reload nginx
docker exec infra_nginx nginx -s reload
```

## Next Steps

After enabling HTTPS:

1. **Configure service-specific nginx configs** in `nginx/sites/`
2. **Test portals** are accessible via HTTPS
3. **Monitor certificate expiration** in Grafana
4. **Set up firewall rules** to restrict access as needed

## Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
- [nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [SSL Labs Server Test](https://www.ssllabs.com/ssltest/)
