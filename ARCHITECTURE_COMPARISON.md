# Architecture Comparison: Shared Infrastructure vs Per-App Infrastructure

**Comparing two approaches for running multiple services on a single Mac Mini**

---

## TL;DR Recommendation

**For your use case (home automation, eduhub, budget, docs on one Mac Mini):**

### ✅ **Use Shared Infrastructure (This Repo)**

**Why:**
- **One** PostgreSQL for all apps (cheaper, easier to manage)
- **One** Redis for all apps
- **One** monitoring stack sees everything
- **One** backup system for all databases
- **One** SSL certificate manager
- Lower resource usage (important for Mac Mini)
- Easier to add new apps (just connect to existing infra)

**When to use per-app approach:**
- Different apps need different PostgreSQL versions
- Apps managed by different teams
- Need to deploy apps independently to different servers
- Security isolation required (multi-tenant SaaS)

---

## Detailed Comparison

### Architecture 1: Shared Infrastructure (This Repo)

**What it is:**
```
┌─────────────────────────────────────────────────────────────┐
│                      Mac Mini Server                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Shared Infrastructure (Always Running)             │   │
│  │  • PostgreSQL (all apps share, separate DBs)        │   │
│  │  • Redis (all apps share)                           │   │
│  │  • Nginx (routes all domains)                       │   │
│  │  • Monitoring (Prometheus, Grafana, Loki)           │   │
│  │  • Vault (secrets for all apps)                     │   │
│  │  • Certbot (SSL for all domains)                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                           ↑                                   │
│  ┌────────────────────────┼───────────────────────────┐     │
│  │  Applications (Connect to Shared Infra)            │     │
│  │                                                     │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────┐ │     │
│  │  │   EduHub     │  │ Home Auto    │  │ Budget  │ │     │
│  │  │   (Node.js)  │  │ (Python)     │  │ (React) │ │     │
│  │  │              │  │              │  │         │ │     │
│  │  │ DB: eduhub   │  │ DB: homeauto │  │ DB: bud │ │     │
│  │  └──────────────┘  └──────────────┘  └─────────┘ │     │
│  │                                                     │     │
│  │  ┌──────────────┐                                  │     │
│  │  │   Docs       │                                  │     │
│  │  │   (Ghost)    │                                  │     │
│  │  │              │                                  │     │
│  │  │ DB: docs     │                                  │     │
│  │  └──────────────┘                                  │     │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**How apps connect:**
```yaml
# eduhub/docker-compose.yml
services:
  eduhub-backend:
    environment:
      DATABASE_URL: postgresql://eduhub_user:password@infra_postgres:5432/eduhub
      REDIS_URL: redis://:password@infra_redis:6379/0
    networks:
      - infra_network  # Connect to shared infrastructure

networks:
  infra_network:
    external: true  # Use existing network
```

---

### Architecture 2: Per-App Infrastructure (EduHub Current)

**What it is:**
```
┌─────────────────────────────────────────────────────────────┐
│                      Mac Mini Server                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  EduHub Stack (All in One)                          │   │
│  │  • PostgreSQL (port 5433)                           │   │
│  │  • Backend (Node.js)                                │   │
│  │  • Nginx (port 80/443)                              │   │
│  │  • pgAdmin                                          │   │
│  │  • Certbot                                          │   │
│  │  Network: eduhub_network                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Home Automation Stack (Separate)                   │   │
│  │  • PostgreSQL (port 5434)                           │   │
│  │  • Backend (Python)                                 │   │
│  │  • Nginx (port 8080/8443)                           │   │
│  │  Network: homeauto_network                          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Budget Stack (Separate)                            │   │
│  │  • PostgreSQL (port 5435)                           │   │
│  │  • Backend (React + API)                            │   │
│  │  • Nginx (port 8081/8444)                           │   │
│  │  Network: budget_network                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Docs Stack (Separate)                              │   │
│  │  • PostgreSQL (port 5436)                           │   │
│  │  • Ghost                                            │   │
│  │  • Nginx (port 8082/8445)                           │   │
│  │  Network: docs_network                              │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Each app has:**
```yaml
# eduhub/docker-compose.yml - Everything bundled
services:
  postgres:      # Dedicated PostgreSQL
  pgadmin:       # Dedicated pgAdmin
  backend:       # App backend
  nginx:         # Dedicated Nginx
  certbot:       # Dedicated Certbot
```

---

## Side-by-Side Comparison

| Aspect | Shared Infrastructure | Per-App Infrastructure |
|--------|----------------------|------------------------|
| **Resource Usage (4 apps)** | | |
| PostgreSQL instances | 1 (ports: 5432) | 4 (ports: 5433-5436) |
| RAM for databases | ~2GB total | ~8GB total (2GB × 4) |
| CPU for databases | 2 cores | 8 cores (2 × 4) |
| Nginx instances | 1 | 4 |
| SSL certificates | 1 (wildcard or multi-domain) | 4 (separate) |
| Monitoring | 1 stack (sees all) | 4 separate (or none) |
| **Total RAM estimate** | ~7GB (full profile) | ~16GB+ |
| **Total CPU estimate** | ~12 cores | ~20+ cores |
| | | |
| **Management** | | |
| Backup systems | 1 (backs up all DBs) | 4 (separate scripts) |
| Monitoring dashboards | 1 (unified view) | 4 (or scattered) |
| SSL renewal | 1 (auto for all) | 4 (manage separately) |
| Secrets management | Vault (centralized) | Per-app .env files |
| Log aggregation | Loki (all apps) | Scattered or none |
| | | |
| **Development** | | |
| Adding new app | Connect to existing infra | Deploy full stack |
| Time to deploy new app | ~5 minutes | ~30 minutes |
| Database setup | `CREATE DATABASE myapp;` | Deploy PostgreSQL container |
| SSL for new domain | Add to nginx config | Deploy Certbot, configure |
| | | |
| **Deployment** | | |
| App updates | Deploy app only | Deploy app + dependencies |
| Infrastructure updates | Once, affects all | Per app |
| Rollback | App-level or infra-level | Per-stack |
| CI/CD complexity | Simple (app connects) | Complex (full stack) |
| | | |
| **Costs (Cloud equivalent)** | | |
| Monthly (4 apps) | ~$80/month | ~$160+/month |
| Scaling cost | Low (share resources) | High (duplicate resources) |
| | | |
| **Pros** | | |
| | ✅ Lower resource usage | ✅ Complete isolation |
| | ✅ Centralized management | ✅ Independent deployments |
| | ✅ Easier to add apps | ✅ No shared dependencies |
| | ✅ Unified monitoring | ✅ App-specific versions |
| | ✅ Single backup system | ✅ Easier to migrate single app |
| | ✅ One SSL renewal | ✅ Failure isolation |
| | | |
| **Cons** | | |
| | ❌ Shared failure point | ❌ High resource duplication |
| | ❌ All apps share PG version | ❌ Complex port management |
| | ❌ Tighter coupling | ❌ Multiple backup systems |
| | | ❌ Multiple SSL renewals |
| | | ❌ Scattered monitoring |

---

## Resource Usage Breakdown

### Shared Infrastructure (Standard Profile)

```
PostgreSQL:        2.0 CPU,  2GB    (all 4 apps share)
Redis:             1.0 CPU,  512MB  (all 4 apps share)
Nginx:             1.0 CPU,  512MB  (routes all domains)
Prometheus:        1.0 CPU,  1GB    (monitors all)
Grafana:           1.0 CPU,  512MB  (visualizes all)
Node Exporter:     0.5 CPU,  128MB  (system metrics)
─────────────────────────────────────────────────────
Infrastructure:    6.5 CPU,  4.6GB

App 1 (EduHub):    1.0 CPU,  512MB  (just the app)
App 2 (HomeAuto):  0.5 CPU,  256MB  (just the app)
App 3 (Budget):    0.5 CPU,  256MB  (just the app)
App 4 (Docs):      0.5 CPU,  256MB  (just the app)
─────────────────────────────────────────────────────
Apps:              2.5 CPU,  1.3GB

TOTAL:             9.0 CPU,  5.9GB RAM
```

### Per-App Infrastructure (EduHub Style × 4)

```
App 1 Stack:
  PostgreSQL:      2.0 CPU,  2GB
  Backend:         1.0 CPU,  512MB
  Nginx:           0.5 CPU,  256MB
  pgAdmin:         0.5 CPU,  256MB
  Certbot:         0.1 CPU,  64MB
  ─────────────────────────────────
  Subtotal:        4.1 CPU,  3GB

App 2 Stack:       4.1 CPU,  3GB
App 3 Stack:       4.1 CPU,  3GB
App 4 Stack:       4.1 CPU,  3GB

TOTAL:            16.4 CPU, 12GB RAM

No monitoring, logging, or centralized management!
Add that: +6 CPU, +4GB
Grand Total:      22.4 CPU, 16GB RAM
```

**Mac Mini typically has:**
- M2: 8 CPU cores, 8-24GB RAM
- M1: 8 CPU cores, 8-16GB RAM

**Verdict:** Shared infrastructure fits comfortably. Per-app might not!

---

## Real-World Example: Adding a New App

### Shared Infrastructure Approach

```bash
# 1. Create database (10 seconds)
docker exec -it infra_postgres psql -U postgres << EOF
CREATE DATABASE household_budget;
CREATE USER budget_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE household_budget TO budget_user;
EOF

# 2. Create app docker-compose.yml (2 minutes)
cat > budget/docker-compose.yml << 'EOF'
version: '3.8'
services:
  budget-app:
    image: mybudget:latest
    environment:
      DATABASE_URL: postgresql://budget_user:secure_password@infra_postgres:5432/household_budget
      REDIS_URL: redis://:password@infra_redis:6379/2
    networks:
      - infra_network

networks:
  infra_network:
    external: true
EOF

# 3. Add nginx route (1 minute)
cat > nginx/sites/budget.conf << 'EOF'
server {
    listen 80;
    server_name budget.yourdomain.com;

    location / {
        proxy_pass http://budget-app:3000;
        proxy_set_header Host $host;
    }
}
EOF

# 4. Start app (30 seconds)
cd budget && docker compose up -d

# 5. Reload nginx (5 seconds)
docker exec infra_nginx nginx -s reload

# Done! App is live with:
# ✅ Database (shared PostgreSQL)
# ✅ Cache (shared Redis)
# ✅ Monitoring (automatic via Prometheus)
# ✅ Logs (automatic via Loki)
# ✅ Backups (automatic via existing cron)
# ✅ SSL (add with one command: ./scripts/certbot-obtain.sh)
```

**Total time: ~5 minutes**
**Additional resources: 0.5 CPU, 256MB RAM** (just the app)

---

### Per-App Infrastructure Approach

```bash
# 1. Create full docker-compose.yml (15 minutes)
# - PostgreSQL configuration
# - pgAdmin setup
# - Nginx configuration
# - Certbot setup
# - Network configuration
# - Volume configuration

# 2. Configure environment variables (5 minutes)
# - Database passwords
# - App configuration
# - SSL email
# - Port mappings (avoid conflicts!)

# 3. Set up PostgreSQL (5 minutes)
# - Wait for container
# - Initialize database
# - Create users
# - Set permissions

# 4. Configure nginx (10 minutes)
# - Upstream configuration
# - Proxy settings
# - SSL configuration
# - Static files

# 5. Set up SSL (5 minutes)
# - Configure certbot
# - Obtain certificate
# - Configure renewal
# - Update nginx

# 6. Set up monitoring (15 minutes)
# - Deploy Prometheus (or skip)
# - Configure exporters (or skip)
# - Set up Grafana (or skip)
# - Create dashboards (or skip)

# 7. Set up backups (10 minutes)
# - Write backup script
# - Configure cron
# - Test backup
# - Test restore

# 8. Start everything (2 minutes)
docker compose up -d

# 9. Verify (3 minutes)
# - Check all containers running
# - Test database connection
# - Test app
# - Test SSL
```

**Total time: ~70 minutes** (without monitoring/backups)
**Additional resources: 4.1 CPU, 3GB RAM** (full stack)

---

## Migration Path

### Option 1: Migrate EduHub to Shared Infrastructure

**Steps:**

1. **Deploy shared infrastructure** (already done)
2. **Create EduHub database** in shared PostgreSQL
3. **Migrate data** from EduHub's PostgreSQL
4. **Update EduHub docker-compose.yml**
5. **Remove EduHub's PostgreSQL/pgAdmin/Certbot**
6. **Update nginx** to use shared instance

**Benefits:**
- Free up ~3GB RAM
- Free up ~3 CPU cores
- Unified monitoring
- Simplified management

**docker-compose.yml changes:**

```yaml
# OLD (eduhub/docker-compose.yml)
services:
  postgres:      # ← Remove
  pgadmin:       # ← Remove
  certbot:       # ← Remove
  nginx:         # ← Remove
  backend:
    environment:
      DB_HOST: postgres  # ← Change
      # ...

# NEW (eduhub/docker-compose.yml)
services:
  backend:
    environment:
      DB_HOST: infra_postgres  # ← Use shared
      DB_DATABASE: eduhub
      DB_USER: eduhub_user
      # ...
    networks:
      - infra_network  # ← Add

networks:
  infra_network:
    external: true  # ← Add
```

**Migration script:**
```bash
# 1. Backup EduHub data
docker exec eduhub-postgres pg_dump -U postgres eduhub > eduhub_backup.sql

# 2. Create database in shared PostgreSQL
docker exec -it infra_postgres psql -U postgres << EOF
CREATE DATABASE eduhub;
CREATE USER eduhub_user WITH PASSWORD 'password';
GRANT ALL PRIVILEGES ON DATABASE eduhub TO eduhub_user;
EOF

# 3. Restore data
cat eduhub_backup.sql | docker exec -i infra_postgres psql -U eduhub_user -d eduhub

# 4. Update EduHub docker-compose.yml (as shown above)

# 5. Restart EduHub with new config
cd eduhub
docker compose down
docker compose up -d

# 6. Verify
docker exec eduhub-backend npm run db:test
```

---

### Option 2: Keep Both (Hybrid)

**Use shared for new apps, keep EduHub as-is**

**When to use:**
- EduHub is production, don't want to risk changes
- Want to migrate gradually
- Test shared infrastructure first

**Setup:**
```
Shared Infrastructure:
  ├─ Home Automation (new, uses shared)
  ├─ Budget (new, uses shared)
  └─ Docs (new, uses shared)

Separate:
  └─ EduHub (existing, keeps own stack)
```

**Resource usage:**
- Shared infra: 6.5 CPU, 4.6GB
- EduHub: 4.1 CPU, 3GB
- Total: 10.6 CPU, 7.6GB

Still better than 4 separate stacks!

---

## Recommendations by Scenario

### Scenario 1: You Have Limited Resources (< 16GB RAM)

**✅ Use Shared Infrastructure**

- Mac Mini M2 with 8GB RAM? Shared is your ONLY option
- Mac Mini with 16GB RAM? Shared is still better (more room for apps)

---

### Scenario 2: All Apps Use PostgreSQL 16

**✅ Use Shared Infrastructure**

- No version conflicts
- Maximum resource efficiency
- Easier management

---

### Scenario 3: Apps Need Different PostgreSQL Versions

**⚠️ Consider Hybrid or Per-App**

- App 1 needs PostgreSQL 16
- App 2 needs PostgreSQL 14
- Solution: Run 2 PostgreSQL instances in shared infrastructure

```yaml
# monitoring/docker-compose.yml (add to shared)
postgres-14:
  image: postgres:14
  ports:
    - "5434:5432"
  # ... configuration
```

---

### Scenario 4: Apps Managed by Different Teams

**⚠️ Consider Per-App**

- Each team wants full control
- Independent deployment schedules
- Different security requirements

But consider: Shared infra with separate app repos
- Infrastructure team manages shared resources
- App teams deploy apps that connect to shared infra

---

### Scenario 5: You Want to Learn/Best Practices

**✅ Use Shared Infrastructure**

- More aligned with Kubernetes/cloud-native practices
- Teaches you service mesh concepts
- Better for portfolio/resume
- Industry standard for microservices

---

## Cost Analysis (Cloud Equivalent)

### DigitalOcean Droplets

**Shared Infrastructure (Standard):**
```
Infrastructure: 4 vCPU, 8GB RAM = $48/month
Apps: 2 vCPU, 4GB RAM = $24/month
Total: $72/month
```

**Per-App Infrastructure (4 apps):**
```
App 1: 4 vCPU, 8GB RAM = $48/month
App 2: 4 vCPU, 8GB RAM = $48/month
App 3: 4 vCPU, 8GB RAM = $48/month
App 4: 4 vCPU, 8GB RAM = $48/month
Total: $192/month
```

**Savings: $120/month = $1,440/year**

---

## Final Recommendation

### For Your Use Case (4 Apps on Mac Mini)

**Use Shared Infrastructure**

**Why:**
1. ✅ **Resource Efficiency**: 9 CPU / 6GB vs 22 CPU / 16GB
2. ✅ **Cost**: Would save $1,440/year in cloud
3. ✅ **Management**: One place to monitor, backup, secure
4. ✅ **Scalability**: Easy to add app #5, #6, etc.
5. ✅ **Consistency**: All apps monitored, backed up, secured the same way

**Migration Plan:**

```
Week 1: Deploy shared infrastructure (done!)
Week 2: Deploy home automation (uses shared)
Week 3: Deploy budget app (uses shared)
Week 4: Deploy docs (uses shared)
Week 5-6: Migrate EduHub to shared (optional)
```

**Start using the shared infrastructure now for new apps. Keep EduHub as-is if you prefer. You'll still save resources and simplify management for the new apps!**

---

## Quick Decision Matrix

Choose **Shared Infrastructure** if:
- ✅ Limited RAM (< 16GB)
- ✅ Multiple small apps
- ✅ Want centralized monitoring
- ✅ Same PostgreSQL version OK
- ✅ You manage all apps
- ✅ Cost conscious
- ✅ Want to learn modern practices

Choose **Per-App Infrastructure** if:
- ✅ Plenty of resources (32GB+ RAM)
- ✅ Apps need different PostgreSQL versions
- ✅ Different teams manage apps
- ✅ Strict isolation required
- ✅ Apps deploy to different servers later
- ✅ Maximum failure isolation needed

**For 4 apps on a Mac Mini: Shared Infrastructure is the clear winner! 🏆**
