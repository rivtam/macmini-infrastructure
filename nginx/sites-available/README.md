# Nginx Site Configurations

This directory contains nginx site configurations for services integrated with the infrastructure.

## Available Sites

### homeassets.conf
**Service**: HomeAssets (Asset Management System)
**Status**: Configured ✓
**Enabled**: Yes (symlinked in sites-enabled/)
**Repository**: `/Users/tammynkuna/rnt/asset_manager`

**Endpoints**:
- Frontend: http://homeassets.local
- Backend API: http://homeassets.local/api
- Health Check: http://homeassets.local/api/health

**Features**:
- Reverse proxy to homeassets-frontend:5173
- API proxy to homeassets-backend:3000
- Rate limiting on API endpoints (10 req/s)
- WebSocket support for Vite HMR
- Static file caching for uploads
- HTTPS ready (commented out, uncomment after SSL setup)

**Documentation**:
- Integration Guide: `../HOMEASSETS_INTEGRATION.md`
- Service Repo: `/Users/tammynkuna/rnt/asset_manager/INTEGRATION_QUICKSTART.md`

## How to Add a New Site

1. **Create configuration file**:
   ```bash
   cp homeassets.conf yourservice.conf
   # Edit yourservice.conf with your service details
   ```

2. **Update upstream targets**:
   ```nginx
   upstream yourservice_backend {
       server yourservice-backend:port;
   }
   ```

3. **Enable the site**:
   ```bash
   cd ../sites-enabled
   ln -s ../sites-available/yourservice.conf yourservice.conf
   ```

4. **Test configuration**:
   ```bash
   cd ..
   docker-compose run --rm nginx-test
   ```

5. **Reload nginx**:
   ```bash
   docker-compose restart nginx
   ```

## Template Structure

```nginx
# Upstream definitions
upstream service_name {
    server container:port;
    keepalive 32;  # Connection pooling
}

# HTTP server (development)
server {
    listen 80;
    server_name service.local service.yourdomain.com;

    # Logging
    access_log /var/log/nginx/service-access.log;
    error_log /var/log/nginx/service-error.log;

    # Proxy to backend
    location /api/ {
        proxy_pass http://service_name;
        # Standard proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        # Rate limiting
        limit_req zone=api_limit burst=20;
    }

    # Proxy to frontend
    location / {
        proxy_pass http://service_frontend;
        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
    }
}

# HTTPS server (production - uncomment after SSL)
# server {
#     listen 443 ssl http2;
#     server_name service.yourdomain.com;
#
#     ssl_certificate /etc/letsencrypt/live/service.yourdomain.com/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/service.yourdomain.com/privkey.pem;
#
#     # Same location blocks as HTTP
# }
```

## Rate Limiting Zones

Defined in main `nginx.conf`:
- `api_limit`: 10 requests/second (for APIs)
- `auth_limit`: 5 requests/minute (for authentication endpoints)

Usage in site configs:
```nginx
location /api/ {
    limit_req zone=api_limit burst=20 nodelay;
}
```

## Testing Configurations

Before restarting nginx:
```bash
# Test syntax
docker-compose run --rm nginx-test

# Check what sites are enabled
ls -la ../sites-enabled/

# View nginx container logs
docker logs infra_nginx
```

## Troubleshooting

### 502 Bad Gateway
- Check upstream service is running: `docker ps | grep service-name`
- Verify container IPs: `docker inspect service-name`
- Test connectivity: `docker exec infra_nginx ping service-name`

### 404 Not Found
- Check server_name matches request host
- Verify sites-enabled symlink exists
- Check location blocks match request path

### Configuration Errors
- Run nginx test: `docker-compose run --rm nginx-test`
- Check logs: `docker logs infra_nginx`
- Verify syntax: look for missing semicolons, braces

## Current Services Status

Run to check which services are configured:
```bash
ls -la ../sites-enabled/
```

Currently enabled:
- ✓ homeassets.conf → HomeAssets service

## Production Checklist

Before enabling a site in production:

- [ ] HTTPS configured (SSL certificates obtained)
- [ ] Domain name configured in DNS
- [ ] Server names updated in config
- [ ] HTTPS server block uncommented
- [ ] HTTP redirect enabled
- [ ] Rate limiting configured appropriately
- [ ] Security headers added
- [ ] Logs configured
- [ ] Upstream health checks working
- [ ] Service is on infra_network
- [ ] Configuration tested with nginx-test
- [ ] Monitoring/logging enabled

## Reference

- Main nginx config: `../nginx.conf`
- Infrastructure docs: `../DOCUMENTATION.md`
- HTTPS setup: `../HTTPS_SETUP.md`
