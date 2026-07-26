# HomeAssets Infrastructure Integration Guide

This document explains how HomeAssets (Asset Manager) is integrated with the macmini-infrastructure shared services.

## Overview

HomeAssets is integrated to use:
- **Nginx**: Reverse proxy for frontend and backend
- **PostgreSQL**: Shared database via PgBouncer connection pooling
- **Redis**: Shared cache and session storage
- **Monitoring**: Logs collected by Promtail and sent to Loki

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Internet / Users                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   Nginx (Port 80/443) │
         │   infra_nginx         │
         └───────────┬───────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌──────────────────┐
│  Frontend       │    │  Backend API     │
│  homeassets-    │    │  homeassets-     │
│  frontend:5173  │    │  backend:3000    │
└─────────────────┘    └────────┬─────────┘
                                │
                    ┌───────────┴──────────┐
                    │                      │
                    ▼                      ▼
          ┌──────────────────┐   ┌─────────────┐
          │  PostgreSQL      │   │   Redis     │
          │  via PgBouncer   │   │  infra_redis│
          │  infra_pgbouncer │   └─────────────┘
          └──────────────────┘
                    │
                    ▼
          ┌──────────────────┐
          │  PostgreSQL      │
          │  infra_postgres  │
          └──────────────────┘
```

## Network Configuration

### Networks Used

1. **homeassets-network** (Internal)
   - Connects HomeAssets services together
   - Frontend ↔ Backend ↔ Local DB/Redis

2. **infra_network** (Shared Infrastructure)
   - Connects HomeAssets to infrastructure services
   - Backend → PostgreSQL (via PgBouncer)
   - Backend → Redis
   - Frontend/Backend ← Nginx

### Container Connectivity

```yaml
# HomeAssets containers are connected to BOTH networks
backend:
  networks:
    - homeassets-network    # Internal communication
    - infra_network         # Infrastructure services
  labels:
    - "logging=promtail"    # Enable log collection

frontend:
  networks:
    - homeassets-network    # Internal communication
    - infra_network         # Accessible to Nginx
  labels:
    - "logging=promtail"    # Enable log collection
```

## Nginx Configuration

### Location: `nginx/sites-available/homeassets.conf`

The configuration provides:

1. **Backend API Proxy** (`/api/`)
   - Proxies to `homeassets-backend:3000`
   - Rate limiting via `api_limit` zone (10 req/s)
   - WebSocket support for real-time features

2. **Frontend Proxy** (`/`)
   - Proxies to `homeassets-frontend:5173`
   - WebSocket support for Vite HMR
   - Handles SPA routing

3. **Static Files** (`/uploads/`)
   - Proxies to backend for file uploads
   - 30-day caching with immutable flag

### Current Setup (Development)

- **HTTP only** on port 80
- Server names: `homeassets.local`, `homeassets.yourdomain.com`
- Direct IP-based upstream (172.23.0.4:3000, 172.23.0.5:5173)

### Production Setup (Future)

Uncomment HTTPS section in config for:
- SSL/TLS encryption via Let's Encrypt
- HSTS security headers
- HTTP → HTTPS redirect

## Database Integration

### Option 1: Own Database (Current Default)

HomeAssets runs its own PostgreSQL instance:
```yaml
postgres:
  image: postgres:16-alpine
  container_name: homeassets-postgres
  ports:
    - "5432:5432"
```

### Option 2: Shared Infrastructure Database (Recommended)

Use infrastructure PostgreSQL via PgBouncer:

1. **Create database**:
   ```bash
   docker exec -it infra_postgres psql -U postgres -c "CREATE DATABASE homeassets;"
   ```

2. **Update `.env`**:
   ```env
   DATABASE_URL=postgresql://postgres:changeme@infra_pgbouncer:5432/homeassets
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=changeme  # Get from infrastructure .env
   ```

3. **Benefits**:
   - Connection pooling via PgBouncer
   - Centralized backup and monitoring
   - Shared infrastructure management
   - Better resource utilization

## Redis Integration

### Option 1: Own Redis (Current Default)

```yaml
redis:
  image: redis:7-alpine
  container_name: homeassets-redis
```

### Option 2: Shared Infrastructure Redis (Recommended)

Update `.env`:
```env
REDIS_HOST=infra_redis
REDIS_PORT=6379
REDIS_PASSWORD=changeme  # Get from infrastructure .env
```

## Monitoring Integration

### Log Collection

HomeAssets containers are labeled for Promtail collection:
```yaml
labels:
  - "logging=promtail"
```

Promtail automatically collects logs from:
- `homeassets-backend` (application logs)
- `homeassets-frontend` (Vite dev server logs)
- Nginx access/error logs for HomeAssets

### Viewing Logs

1. **Via Loki/Grafana**:
   ```bash
   cd monitoring
   docker-compose up -d
   # Access Grafana at http://localhost:3001
   ```

2. **Query Examples**:
   ```logql
   # All HomeAssets backend logs
   {container="homeassets-backend"}

   # HomeAssets API errors
   {container="homeassets-backend"} |= "error"

   # Nginx access logs for HomeAssets
   {job="nginx", log_type="access"} |~ "homeassets"
   ```

## Quick Start - Automated Integration

Run the integration script:

```bash
cd /Users/tammynkuna/rnt/asset_manager
./integrate-infrastructure.sh
```

This script will:
1. ✓ Check/create `infra_network`
2. ✓ Start infrastructure databases
3. ✓ Create `homeassets` database
4. ✓ Restart HomeAssets with infrastructure connectivity
5. ✓ Rebuild nginx with HomeAssets proxy config
6. ✓ Verify connectivity

## Manual Integration Steps

### 1. Create Infrastructure Network (if not exists)

```bash
docker network create infra_network
```

### 2. Start Infrastructure Services

```bash
# Start databases
cd /Users/tammynkuna/rnt/school/it_project_700/code_review/new/macmini-infrastructure/databases
docker-compose up -d

# Start nginx
cd ../nginx
docker-compose up -d

# Optional: Start monitoring
cd ../monitoring
docker-compose up -d
```

### 3. Create HomeAssets Database

```bash
docker exec -it infra_postgres psql -U postgres -c "CREATE DATABASE homeassets;"
```

### 4. Configure HomeAssets

Copy infrastructure settings:
```bash
cd /Users/tammynkuna/rnt/asset_manager
cp .env.infrastructure .env.local
# Edit .env to include infrastructure database credentials
```

### 5. Restart HomeAssets

```bash
cd /Users/tammynkuna/rnt/asset_manager
docker-compose down
docker-compose up -d
```

### 6. Add Local DNS (Optional for Testing)

Add to `/etc/hosts`:
```
127.0.0.1  homeassets.local
```

## Access URLs

### Via Nginx Reverse Proxy
- **Frontend**: http://homeassets.local
- **Backend API**: http://homeassets.local/api
- **Health Check**: http://homeassets.local/api/health

### Direct Access (Development)
- **Frontend**: http://localhost:5173
- **Backend**: http://localhost:3000/api

### Production (After SSL Setup)
- **Frontend**: https://homeassets.yourdomain.com
- **Backend API**: https://homeassets.yourdomain.com/api

## Troubleshooting

### 1. Cannot Access via Nginx

**Check nginx is running:**
```bash
docker ps | grep infra_nginx
```

**Check nginx logs:**
```bash
docker logs infra_nginx
```

**Test nginx config:**
```bash
cd /Users/tammynkuna/rnt/school/it_project_700/code_review/new/macmini-infrastructure/nginx
docker-compose run --rm nginx-test
```

### 2. Database Connection Failed

**Verify database exists:**
```bash
docker exec -it infra_postgres psql -U postgres -l
```

**Check connectivity:**
```bash
docker exec homeassets-backend ping -c 3 infra_postgres
```

**Test database connection:**
```bash
docker exec homeassets-backend wget -O- infra_postgres:5432 2>&1 | grep -q "postgres" && echo "Connected" || echo "Failed"
```

### 3. Redis Connection Failed

**Check Redis is running:**
```bash
docker ps | grep infra_redis
docker exec infra_redis redis-cli -a changeme ping
```

**Test connectivity:**
```bash
docker exec homeassets-backend ping -c 3 infra_redis
```

### 4. Containers Not on infra_network

**Verify network connections:**
```bash
docker inspect homeassets-backend -f '{{range $net, $v := .NetworkSettings.Networks}}{{$net}} {{end}}'
# Should show: homeassets-network infra_network
```

**Reconnect to network:**
```bash
docker network connect infra_network homeassets-backend
docker network connect infra_network homeassets-frontend
```

### 5. Nginx Cannot Reach Backend

**Check container IPs:**
```bash
docker inspect homeassets-backend -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
docker inspect homeassets-frontend -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

**Update nginx config** if IPs changed:
Edit `nginx/sites-available/homeassets.conf` upstream blocks

### 6. Logs Not Appearing in Loki

**Verify Promtail is running:**
```bash
docker ps | grep promtail
```

**Check container labels:**
```bash
docker inspect homeassets-backend -f '{{.Config.Labels}}'
# Should show: logging=promtail
```

**Restart containers** to apply labels:
```bash
cd /Users/tammynkuna/rnt/asset_manager
docker-compose restart
```

## Migration Paths

### From Own DB to Infrastructure DB

1. **Backup current database**:
   ```bash
   docker exec homeassets-postgres pg_dump -U homeassets homeassets > backup.sql
   ```

2. **Create infrastructure database**:
   ```bash
   docker exec infra_postgres psql -U postgres -c "CREATE DATABASE homeassets;"
   ```

3. **Restore to infrastructure**:
   ```bash
   docker exec -i infra_postgres psql -U postgres -d homeassets < backup.sql
   ```

4. **Update .env** to use infrastructure database

5. **Restart and verify**:
   ```bash
   docker-compose restart backend
   docker-compose logs backend
   ```

### From Development to Production

1. **Obtain SSL certificates** (see `HTTPS_SETUP.md`)

2. **Update nginx config**:
   - Uncomment HTTPS server block
   - Update domain names
   - Enable HTTPS redirect

3. **Update environment variables**:
   ```env
   FRONTEND_URL=https://homeassets.yourdomain.com
   CORS_ORIGIN=https://homeassets.yourdomain.com
   ```

4. **Restart services**:
   ```bash
   docker-compose restart
   cd macmini-infrastructure/nginx && docker-compose restart
   ```

## Security Considerations

### Current Setup (Development)
- HTTP only (no encryption)
- Direct container port access (3000, 5173)
- Default credentials

### Production Recommendations
1. **Enable HTTPS**: Use Let's Encrypt SSL certificates
2. **Remove direct port access**: Only expose via nginx
3. **Update credentials**: Change default passwords
4. **Enable rate limiting**: Already configured in nginx
5. **Add authentication**: Use JWT tokens (already implemented)
6. **Enable CORS properly**: Restrict to specific domains
7. **Use secrets management**: Consider Vault integration

## Performance Optimization

### PgBouncer Connection Pooling

Current settings in `databases/docker-compose.yml`:
```yaml
POOL_MODE: transaction
MAX_CLIENT_CONN: 1000
DEFAULT_POOL_SIZE: 25
```

Adjust based on load:
- **Low traffic**: DEFAULT_POOL_SIZE=10
- **Medium traffic**: DEFAULT_POOL_SIZE=25
- **High traffic**: DEFAULT_POOL_SIZE=50+

### Nginx Caching

For production, enable caching:
```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=homeassets_cache:10m max_size=1g inactive=60m;

location /api/ {
    proxy_cache homeassets_cache;
    proxy_cache_valid 200 5m;
    proxy_cache_key "$request_uri";
}
```

### Redis Caching

Backend already uses Redis for:
- Session storage
- Rate limiting
- Application caching

Monitor usage:
```bash
docker exec infra_redis redis-cli -a changeme INFO stats
```

## Monitoring & Metrics

### Application Metrics
- Backend health: http://homeassets.local/api/health
- Database metrics: Exposed via postgres-exporter on port 9187
- Redis metrics: Exposed via redis-exporter on port 9121

### Log Aggregation
- All logs in Loki
- Grafana dashboards for visualization
- Real-time log streaming

### Alerts (Future)
Configure alerts in Grafana for:
- High error rates
- Database connection failures
- Redis connection issues
- Response time degradation

## Backup Strategy

### Database Backups

**Manual backup**:
```bash
docker exec infra_postgres pg_dump -U postgres homeassets > homeassets_backup_$(date +%Y%m%d).sql
```

**Automated backups** (recommended):
Add to crontab:
```bash
0 2 * * * docker exec infra_postgres pg_dump -U postgres homeassets | gzip > /backups/homeassets_$(date +\%Y\%m\%d).sql.gz
```

### File Uploads Backup

Backend uploads are stored in Docker volume:
```bash
docker volume inspect asset_manager_backend-uploads
# Backup the mount point shown
```

## Scaling Considerations

### Horizontal Scaling

To run multiple backend instances:

1. **Update docker-compose.yml**:
   ```yaml
   backend:
     deploy:
       replicas: 3
   ```

2. **Update nginx upstream**:
   ```nginx
   upstream homeassets_backend {
       server homeassets-backend-1:3000;
       server homeassets-backend-2:3000;
       server homeassets-backend-3:3000;
   }
   ```

3. **Session storage**: Already using Redis for sessions (stateless)

### Vertical Scaling

Increase resources in docker-compose:
```yaml
deploy:
  resources:
    limits:
      cpus: "2.0"
      memory: 2G
```

## Support & Maintenance

### Health Checks

Monitor service health:
```bash
# Backend health
curl http://localhost:3000/api/health

# Nginx health
curl http://localhost/healthz

# Database health
docker exec infra_postgres pg_isready -U postgres

# Redis health
docker exec infra_redis redis-cli -a changeme ping
```

### Regular Maintenance

1. **Weekly**: Check logs for errors
2. **Monthly**: Review and rotate logs
3. **Quarterly**: Update container images
4. **Annually**: Review and update SSL certificates

### Useful Commands

```bash
# View all HomeAssets containers
docker ps --filter "name=homeassets"

# View all logs
docker-compose -f /Users/tammynkuna/rnt/asset_manager/docker-compose.yml logs -f

# Restart all services
docker-compose -f /Users/tammynkuna/rnt/asset_manager/docker-compose.yml restart

# Check resource usage
docker stats homeassets-backend homeassets-frontend

# Clean up
docker system prune -af --volumes
```

## References

- Main Infrastructure Docs: `DOCUMENTATION.md`
- HTTPS Setup: `HTTPS_SETUP.md`
- Production Deployment: `PRODUCTION_DEPLOYMENT.md`
- Monitoring Setup: `monitoring/README.md`
- HomeAssets Repo: `/Users/tammynkuna/rnt/asset_manager`
