# Testing the Infrastructure Locally

This guide shows you how to test the infrastructure repository on your laptop before deploying to production.

## Prerequisites

✅ Docker Desktop installed and running
✅ Terminal/command line access
✅ At least 4GB free RAM

## Quick Test (5 minutes)

### 1. Navigate to the Infrastructure Directory

```bash
cd /Users/tammynkuna/rnt/school/it_project_700/code_review/new/macmini-infrastructure
```

### 2. Initialize Environment Files

```bash
make init
# This creates .env files from .env.example
```

### 3. Start All Services

```bash
make start-all
```

Expected output:
```
🚀 Starting all infrastructure services...
🗄️  Starting databases...
⏳ Waiting for databases to be healthy...
📊 Starting monitoring...
🌐 Starting nginx...
✅ All services started!
```

### 4. Check Health

```bash
make health
```

Expected output:
```
🏥 Checking infrastructure health...

PostgreSQL          ✅ HEALTHY
Redis              ✅ HEALTHY
Nginx              ✅ HEALTHY
Prometheus         ✅ HEALTHY
Grafana            ✅ HEALTHY
Node Exporter      ✅ HEALTHY
cAdvisor           ✅ HEALTHY

Health check complete!
```

### 5. Test Each Service

**PostgreSQL:**
```bash
make db-connect

# You should see:
psql (16.x)
Type "help" for help.
postgres=#

# Try:
\l                  # List databases
\q                  # Quit
```

**Redis:**
```bash
make redis-cli

# You should see:
127.0.0.1:6379>

# Try:
PING               # Should return PONG
SET test "hello"   # Set a value
GET test           # Get the value
exit
```

**Nginx:**
```bash
curl http://localhost/healthz

# Should return:
ok
```

**Grafana:**
```bash
make open-grafana
# Or manually: open http://localhost:3000

# Login with:
# Username: admin
# Password: admin (from monitoring/.env)
```

**Prometheus:**
```bash
make open-prometheus
# Or manually: open http://localhost:9090

# Try:
# Click "Status" → "Targets"
# All targets should be "UP"
```

### 6. View Logs

```bash
# All logs
make logs

# Or specific services
make logs-databases
make logs-nginx
make logs-monitoring
```

### 7. Stop Everything

```bash
make stop-all
```

## Detailed Testing Scenarios

### Scenario 1: Test Database Persistence

**Step 1: Create a database**
```bash
make start-databases
make db-connect

# In psql:
CREATE DATABASE testapp;
\c testapp
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(100));
INSERT INTO users (name) VALUES ('Test User');
SELECT * FROM users;
\q
```

**Step 2: Restart databases**
```bash
make restart-databases
```

**Step 3: Verify data persists**
```bash
make db-connect

# In psql:
\c testapp
SELECT * FROM users;
# Should still show 'Test User'
\q
```

**Step 4: Cleanup**
```bash
make db-connect
DROP DATABASE testapp;
\q
```

### Scenario 2: Test Nginx Configuration Changes

**Step 1: Create a test configuration**
```bash
cat > nginx/sites/test.conf << 'EOF'
server {
    listen 80;
    server_name test.local;

    location / {
        return 200 'Test server working!\n';
        add_header Content-Type text/plain;
    }
}
EOF
```

**Step 2: Test configuration**
```bash
make nginx-test
# Should pass without errors
```

**Step 3: Reload nginx**
```bash
make start-nginx
make nginx-reload
```

**Step 4: Test it**
```bash
# Add to /etc/hosts:
echo "127.0.0.1 test.local" | sudo tee -a /etc/hosts

# Test:
curl http://test.local
# Should return: Test server working!
```

**Step 5: Cleanup**
```bash
rm nginx/sites/test.conf
make nginx-reload
sudo sed -i '' '/test.local/d' /etc/hosts
```

### Scenario 3: Test Redis Caching

**Step 1: Start Redis**
```bash
make start-databases
```

**Step 2: Simulate caching operations**
```bash
docker exec -it infra_redis redis-cli

# Cache operations:
SET session:user123 "John Doe"
EXPIRE session:user123 300  # 5 minutes
GET session:user123
TTL session:user123  # Check remaining time

# List operations:
LPUSH queue:jobs "job1" "job2" "job3"
LRANGE queue:jobs 0 -1
LPOP queue:jobs

# Set operations:
SADD tags:article123 "docker" "devops" "tutorial"
SMEMBERS tags:article123

exit
```

### Scenario 4: Test Monitoring

**Step 1: Start all services**
```bash
make start-all
```

**Step 2: Generate some load**
```bash
# Make repeated requests to nginx
for i in {1..100}; do
  curl -s http://localhost/healthz > /dev/null
  sleep 0.1
done
```

**Step 3: View metrics in Prometheus**
```bash
make open-prometheus

# Try these queries:
# - node_cpu_seconds_total
# - container_memory_usage_bytes
# - nginx_http_requests_total (if metrics enabled)
```

**Step 4: View in Grafana**
```bash
make open-grafana

# Navigate to:
# 1. Dashboards → Import
# 2. Enter ID: 1860 (Node Exporter Full)
# 3. Select Prometheus datasource
# 4. Import
```

### Scenario 5: Test Service Dependencies

**Step 1: Start databases first**
```bash
make start-databases
make health
# Only postgres and redis should be running
```

**Step 2: Start a dependent service**
```bash
make start-monitoring
# Should work because monitoring can run independently
```

**Step 3: Test network connectivity**
```bash
# From prometheus, can it reach other services?
docker exec infra_prometheus wget -q -O - http://infra_postgres:5432 || echo "Connection test (expected to fail for postgres)"
docker exec infra_prometheus wget -q -O - http://infra_redis:6379 || echo "Connection test"
```

### Scenario 6: Test Backup and Restore

**Step 1: Create test data**
```bash
make db-connect

CREATE DATABASE backup_test;
\c backup_test
CREATE TABLE data (id SERIAL, value TEXT);
INSERT INTO data (value) VALUES ('Important data 1'), ('Important data 2');
SELECT * FROM data;
\q
```

**Step 2: Backup**
```bash
make db-backup
ls -lh backups/
```

**Step 3: Delete the database**
```bash
make db-connect
DROP DATABASE backup_test;
\l  # Verify it's gone
\q
```

**Step 4: Restore from backup**
```bash
# Find the backup file
BACKUP_FILE=$(ls -t backups/all_databases_*.sql | head -1)

# Restore
cat "$BACKUP_FILE" | docker exec -i infra_postgres psql -U postgres

# Verify
make db-connect
\c backup_test
SELECT * FROM data;  # Should show your data
\q
```

**Step 5: Cleanup**
```bash
make db-connect
DROP DATABASE backup_test;
\q
```

## Testing with Your EduHub Application

### Option 1: Connect EduHub Backend to Infrastructure

**Step 1: Start infrastructure**
```bash
cd macmini-infrastructure
make start-databases
```

**Step 2: Update EduHub .env**
```bash
cd ../eduhub/backend

# Create/edit .env
cat > .env << 'EOF'
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=changeme
DB_NAME=eduhub
REDIS_HOST=localhost
REDIS_PORT=6379
EOF
```

**Step 3: Start EduHub backend**
```bash
npm install
npm run dev
```

**Step 4: Test**
```bash
curl http://localhost:3000/api/health
```

### Option 2: Run EduHub in Docker with Infrastructure

**Step 1: Update EduHub docker-compose.yml**
```yaml
# eduhub/docker-compose.yml
services:
  backend:
    build: ./backend
    environment:
      DB_HOST: infra_postgres
      DB_PORT: 5432
      REDIS_HOST: infra_redis
      REDIS_PORT: 6379
    networks:
      - eduhub_network
      - infra_network

networks:
  eduhub_network:
  infra_network:
    external: true
```

**Step 2: Start infrastructure**
```bash
cd macmini-infrastructure
make start-all
```

**Step 3: Start EduHub**
```bash
cd ../eduhub
docker compose up -d
```

**Step 4: Test**
```bash
docker compose logs backend
curl http://localhost:3000/api/health
```

## Performance Testing

### Test 1: Database Connection Pool

```bash
# Install pgbench (comes with PostgreSQL)
# Or use docker:

docker exec -it infra_postgres pgbench -i postgres
docker exec -it infra_postgres pgbench -c 10 -j 2 -t 1000 postgres

# Results show transactions per second
```

### Test 2: Redis Performance

```bash
docker exec -it infra_redis redis-benchmark -q -n 10000
```

### Test 3: Nginx Performance

```bash
# Install apache bench:
# brew install httpd (on Mac)

ab -n 1000 -c 10 http://localhost/healthz
```

## Troubleshooting Tests

### If Health Check Fails

```bash
# Check what's running
make status

# Check logs for failed service
make logs-databases
make logs-nginx
make logs-monitoring

# Try restarting
make restart-all
```

### If Port Conflicts Occur

```bash
# Find what's using the port
lsof -i :5432
lsof -i :6379
lsof -i :80

# Either stop the conflicting service or change port in .env
cd databases
vim .env
# Change POSTGRES_PORT=5432 to POSTGRES_PORT=5433
```

### If Container Won't Start

```bash
# Remove and recreate
cd databases
docker compose down -v
docker compose up -d

# Check logs
docker compose logs -f
```

## Cleanup After Testing

### Keep Data, Stop Services

```bash
make stop-all
```

### Remove Everything (including data)

```bash
make clean
# WARNING: This deletes all databases and configurations!
```

### Remove Only Volumes

```bash
cd databases && docker compose down -v
cd ../monitoring && docker compose down -v
cd ../nginx && docker compose down
```

## Success Checklist

After running all tests, you should have:

- ✅ All services starting successfully
- ✅ All health checks passing
- ✅ Database connectivity working
- ✅ Redis connectivity working
- ✅ Nginx routing working
- ✅ Monitoring dashboards accessible
- ✅ Metrics being collected
- ✅ Logs viewable
- ✅ Backups working
- ✅ Restart working without data loss

## Next Steps

Once everything works locally:

1. ✅ Commit to Git repository
2. ✅ Push to GitHub
3. ✅ Set up GitHub Actions secrets
4. ✅ Test deploy to Mac Mini
5. ✅ Configure SSL certificates
6. ✅ Set up production passwords
7. ✅ Configure automated backups

---

**Need Help?** Run `make help` or check the service-specific READMEs!
