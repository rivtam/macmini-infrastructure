# Nginx Gateway

This directory contains the nginx reverse proxy configuration that acts as the main gateway for all services.

## Quick Start

```bash
# Copy environment file
cp .env.example .env

# Test nginx configuration
docker compose --profile test run --rm nginx-test

# Start nginx
docker compose up -d

# View logs
docker compose logs -f

# Reload configuration (after changes)
docker compose exec nginx nginx -s reload

# Stop nginx
docker compose down
```

## Configuration Structure

- `nginx.conf` - Main nginx configuration
- `sites/` - Individual site/application configurations
- `logs/` - Nginx access and error logs

## Adding a New Site

1. Create a new configuration file in `sites/`:
   ```bash
   cp sites/example-blog.conf.disabled sites/myapp.conf
   ```

2. Edit the configuration for your application

3. Test the configuration:
   ```bash
   docker compose --profile test run --rm nginx-test
   ```

4. Reload nginx:
   ```bash
   docker compose exec nginx nginx -s reload
   ```

## Routing

Nginx routes traffic based on the `server_name` directive:

- `edu-hub.duckdns.org` → EduHub application
- `blog.yourdomain.com` → Blog application (example)

## Health Check

Nginx exposes a `/healthz` endpoint on all domains for health checking:
```bash
curl http://localhost/healthz
```

## SSL/TLS

SSL certificates are managed by certbot and mounted from `../certbot/conf/`.

## Frontend Static Files

### Option 1: Mount from Host (Development/Small Apps)

Mount your built frontend files directly into nginx:

```yaml
# nginx/docker-compose.yml
services:
  nginx:
    volumes:
      - /path/to/your/app/dist:/usr/share/nginx/html/myapp:ro
```

### Option 2: Build Custom Nginx Image (Production)

Create a Dockerfile that includes your frontend:

```dockerfile
# In your application repo
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html/myapp/
COPY nginx.conf /etc/nginx/nginx.conf
```

Then reference this image in your app's docker-compose:

```yaml
services:
  myapp-nginx:
    build: ./frontend
    networks:
      - infra_network
```

### Option 3: Shared Volume (Multi-Stage)

Build frontend in CI/CD and copy to shared volume:

```yaml
# In your app's docker-compose.yml
services:
  frontend-builder:
    image: node:18
    volumes:
      - frontend-dist:/app/dist
    command: sh -c "npm ci && npm run build"

volumes:
  frontend-dist:
```

Then mount this volume in the infrastructure nginx.

**Recommended Approach:** Option 2 for production (self-contained), Option 1 for development.

## Local Development

For local development without SSL:

1. Edit your `/etc/hosts` file:
   ```
   127.0.0.1 edu-hub.local
   127.0.0.1 blog.local
   ```

2. Create local configuration files in `sites/` that don't require SSL

3. Use different ports in `.env`:
   ```
   NGINX_HTTP_PORT=8080
   NGINX_HTTPS_PORT=8443
   ```

4. Mount your frontend build directory (see Frontend Static Files above)
