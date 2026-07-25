# Let's Encrypt / Certbot

Automatic SSL/TLS certificate management using Let's Encrypt.

## Overview

This directory contains the certbot configuration for obtaining and automatically renewing SSL/TLS certificates using Let's Encrypt.

## Initial Setup

### 1. Prerequisites

- Domain name pointing to your server (e.g., edu-hub.duckdns.org)
- Port 80 accessible from the internet (for HTTP-01 challenge)
- nginx container running with ACME challenge endpoint configured

### 2. Obtain Initial Certificates

```bash
cd certbot
./init-letsencrypt.sh
```

#### Environment Variables

- `DOMAIN` - Your domain name (default: `edu-hub.duckdns.org`)
- `LETSENCRYPT_EMAIL` - Email for Let's Encrypt notifications (default: `admin@DOMAIN`)
- `STAGING` - Use Let's Encrypt staging environment for testing (default: `0`)

#### Testing First (Recommended)

Test with Let's Encrypt staging to avoid rate limits:

```bash
STAGING=1 ./init-letsencrypt.sh
```

Once successful, obtain production certificates:

```bash
./init-letsencrypt.sh
```

### 3. Multiple Domains

To add additional domains, use certbot directly:

```bash
docker run --rm \
  -v $(pwd)/conf:/etc/letsencrypt \
  -v $(pwd)/www:/var/www/certbot \
  --network infra_network \
  certbot/certbot certonly \
  --webroot --webroot-path=/var/www/certbot \
  --email admin@example.com \
  --agree-tos \
  -d example.com -d www.example.com
```

## Auto-Renewal

The certbot service runs continuously and checks for certificate renewal twice daily. Renewal happens automatically when certificates are within 30 days of expiration.

### Check Renewal Status

```bash
docker compose exec certbot certbot renew --dry-run
```

### Force Renewal

```bash
docker compose exec certbot certbot renew --force-renewal
```

## Manual Certificate Operations

### List Certificates

```bash
docker compose exec certbot certbot certificates
```

### Revoke Certificate

```bash
docker compose exec certbot certbot revoke --cert-path /etc/letsencrypt/live/DOMAIN/cert.pem
```

### Delete Certificate

```bash
docker compose exec certbot certbot delete --cert-name DOMAIN
```

## Directory Structure

```
certbot/
├── conf/           # Let's Encrypt certificates and configuration
│   ├── live/      # Symlinks to latest certificates
│   ├── archive/   # All certificates (including old ones)
│   └── renewal/   # Renewal configuration files
├── www/           # Webroot for ACME HTTP-01 challenges
└── logs/          # Certbot logs
```

## Monitoring

The `certbot-exporter` service exposes Prometheus metrics on port 9219 for monitoring certificate expiration.

### Prometheus Metrics

```
http://localhost:9219/metrics
```

### Grafana Dashboard

Import the SSL Certificate Exporter dashboard (ID: 13230) to monitor certificate expiration.

## Troubleshooting

### Certificate Obtainment Fails

1. **Check DNS**: Ensure domain points to your server
   ```bash
   dig +short edu-hub.duckdns.org
   ```

2. **Check Port 80**: Ensure it's accessible from internet
   ```bash
   curl -I http://edu-hub.duckdns.org/.well-known/acme-challenge/test
   ```

3. **Check nginx**: Ensure ACME challenge location is configured
   ```bash
   docker exec infra_nginx curl localhost/.well-known/acme-challenge/test
   ```

### Rate Limits

Let's Encrypt has rate limits:
- 50 certificates per domain per week
- 5 duplicate certificates per week

Use staging environment for testing to avoid hitting limits.

### Certificate Not Loading

1. **Check certificate exists**:
   ```bash
   ls -la conf/live/YOUR_DOMAIN/
   ```

2. **Reload nginx**:
   ```bash
   docker exec infra_nginx nginx -s reload
   ```

3. **Check nginx logs**:
   ```bash
   docker logs infra_nginx
   ```

## Security

- Certificates are automatically renewed 30 days before expiration
- Private keys are stored in `conf/` directory - keep this secure
- Never commit the `conf/` directory to version control
- Set appropriate file permissions:
  ```bash
  chmod 600 conf/archive/*/privkey*.pem
  ```

## Integration with nginx

nginx mounts the certbot volumes:

```yaml
volumes:
  - ../certbot/conf:/etc/letsencrypt:ro
  - ../certbot/www:/var/www/certbot:ro
```

nginx configuration references certificates:

```nginx
ssl_certificate /etc/letsencrypt/live/DOMAIN/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/DOMAIN/privkey.pem;
```

## Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
- [Rate Limits](https://letsencrypt.org/docs/rate-limits/)
