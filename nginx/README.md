# Nginx Reverse Proxy

SSL termination, domain routing, and rate limiting.

## Quick Reference

```bash
# Start nginx
docker compose up -d

# Reload configuration (without downtime)
docker exec infra_nginx nginx -s reload

# Test configuration
docker exec infra_nginx nginx -t

# View access logs
tail -f logs/access.log

# View error logs
tail -f logs/error.log
```

## Configuration

**Main config:** `nginx.conf`
**Virtual hosts:** `sites/*.conf`
**SSL certificates:** Managed by Certbot (see `../certbot/`)

## Adding a New Site

1. Create `sites/myapp.conf`:
```nginx
server {
    listen 80;
    server_name myapp.example.com;

    location / {
        proxy_pass http://myapp:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

2. Reload nginx:
```bash
docker exec infra_nginx nginx -s reload
```

## SSL Setup

```bash
# Obtain certificate
../scripts/certbot-obtain.sh myapp.example.com admin@example.com

# Add HTTPS to site config
server {
    listen 443 ssl;
    server_name myapp.example.com;

    ssl_certificate /etc/letsencrypt/live/myapp.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/myapp.example.com/privkey.pem;

    location / {
        proxy_pass http://myapp:3000;
    }
}
```

## Complete Documentation

See [../DOCUMENTATION.md](../DOCUMENTATION.md) for:
- SSL automation
- Rate limiting configuration
- Security best practices
- Troubleshooting
