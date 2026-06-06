# Infrastructure Repository Overview

This document provides a high-level overview of the infrastructure repository structure and how to use it.

## 📂 Repository Structure

```
macmini-infrastructure/
├── 📁 .github/workflows/           # CI/CD Pipelines
│   ├── test-infrastructure.yml     # Tests on PRs
│   └── deploy-infrastructure.yml   # Auto-deploy to Mac Mini
│
├── 📁 nginx/                       # Nginx Reverse Proxy
│   ├── docker-compose.yml
│   ├── nginx.conf                  # Main nginx config
│   ├── sites/                      # Per-application routing
│   │   ├── eduhub.conf            # EduHub routing
│   │   └── example-blog.conf.disabled
│   ├── logs/                       # Nginx logs
│   ├── .env.example
│   └── README.md
│
├── 📁 databases/                   # Database Services
│   ├── docker-compose.yml
│   ├── postgres/
│   │   └── init/
│   │       └── 01-create-databases.sql
│   ├── redis/
│   │   └── redis.conf
│   ├── .env.example
│   └── README.md
│
├── 📁 monitoring/                  # Monitoring Stack
│   ├── docker-compose.yml
│   ├── prometheus/
│   │   └── prometheus.yml
│   ├── grafana/
│   │   ├── datasources/
│   │   └── dashboards/
│   ├── .env.example
│   └── README.md
│
├── 📁 scripts/                     # Utility Scripts
│   ├── health-check.sh             # Check all services
│   ├── backup-databases.sh         # Backup databases
│   ├── init-env.sh                 # Initialize .env files
│   └── connect-db.sh               # Quick DB connection
│
├── 📁 certbot/                     # SSL Certificates
│   ├── conf/
│   └── www/
│
├── Makefile                        # Easy commands
├── README.md                       # Main documentation
├── GETTING_STARTED.md              # Setup guide
├── .env.example
└── .gitignore
```

## 🎯 Key Concepts

### 1. Separation of Concerns

Each service lives in its own directory with:
- ✅ Own `docker-compose.yml` (can run independently)
- ✅ Own `.env` file (service-specific configuration)
- ✅ Own `README.md` (service documentation)

### 2. Shared Network

All services connect via `infra_network`:
- Applications can connect to this network
- Services discover each other by container name
- Example: `postgres://infra_postgres:5432/eduhub`

### 3. Easy Management

The `Makefile` provides simple commands:
```bash
make start-databases    # Start just databases
make start-nginx        # Start just nginx
make start-all          # Start everything
make health            # Check all services
```

## 🚀 How It Works

### For QA/Separation:

Each service is **independently testable**:

```bash
# Test just nginx
cd nginx
docker compose up -d
# Test your nginx config changes
docker compose down

# Test just databases
cd databases
docker compose up -d
# Test database connectivity
docker compose down

# Test everything together
make start-all
make health
```

### For Local Development:

```bash
# Developer working on EduHub locally:

# Terminal 1: Start infrastructure
cd macmini-infrastructure
make start-databases

# Terminal 2: Start your app
cd ~/eduhub/backend
npm run dev

# Your app connects to:
# - postgres://localhost:5432/eduhub
# - redis://localhost:6379
```

### For Production:

GitHub Actions automatically:
1. Tests changes on pull requests
2. Deploys to Mac Mini on merge to main
3. Only deploys changed services
4. Runs health checks after deployment

## 🔄 Workflow Examples

### Adding a New Application (Blog)

**Step 1: Create database**
```bash
make db-connect
CREATE DATABASE blog;
CREATE USER blog_user WITH PASSWORD 'secure_pass';
GRANT ALL PRIVILEGES ON DATABASE blog TO blog_user;
```

**Step 2: Configure nginx routing**
```bash
# Copy example
cp nginx/sites/example-blog.conf.disabled nginx/sites/blog.conf

# Edit for your needs
vim nginx/sites/blog.conf

# Test and reload
make nginx-test
make nginx-reload
```

**Step 3: Configure your application**
```yaml
# blog/docker-compose.yml
services:
  blog:
    image: myblog:latest
    environment:
      DB_HOST: infra_postgres
      DB_PORT: 5432
      DB_NAME: blog
      REDIS_HOST: infra_redis
    networks:
      - infra_network

networks:
  infra_network:
    external: true
```

**Step 4: Deploy**
```bash
docker compose up -d
# Blog is now accessible via nginx!
```

### Testing Before Production

**Local Testing:**
```bash
# Start infrastructure
make start-all

# Check health
make health

# View logs
make logs

# Test your changes
curl http://localhost/api/health

# Stop when done
make stop-all
```

**CI Testing:**
- Push to feature branch
- GitHub Actions runs tests
- Review test results
- Merge when tests pass

### Monitoring Your Applications

**Step 1: Add metrics to your app**
```javascript
// In your Node.js app
const promClient = require('prom-client');
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType);
  res.end(await promClient.register.metrics());
});
```

**Step 2: Update Prometheus config**
```yaml
# monitoring/prometheus/prometheus.yml
scrape_configs:
  - job_name: 'myapp'
    static_configs:
      - targets: ['myapp:3000']
    metrics_path: '/metrics'
```

**Step 3: Restart monitoring**
```bash
make restart-monitoring
```

**Step 4: View metrics**
```bash
make open-grafana
# Import dashboard or create custom one
```

## 🎓 Learning Path

### Day 1: Setup
1. Read `GETTING_STARTED.md`
2. Run `make setup`
3. Access Grafana and Prometheus
4. Test database connectivity

### Day 2: Understanding
1. Read each service's README
2. Explore docker-compose files
3. Test stopping/starting individual services
4. View logs and health checks

### Day 3: Integration
1. Create a test database
2. Add nginx configuration for a test app
3. Connect a local app to infrastructure
4. Monitor your app with Prometheus

### Week 2: Production
1. Deploy to Mac Mini
2. Set up SSL certificates
3. Configure automated backups
4. Set up monitoring alerts

## 🔍 Troubleshooting Quick Reference

| Problem | Solution |
|---------|----------|
| Port in use | Change port in `.env` or stop conflicting service |
| Can't connect to DB | Check `make health`, ensure on `infra_network` |
| Nginx config error | Run `make nginx-test` to validate |
| Container won't start | Check logs: `make logs-<service>` |
| Need to reset everything | `make clean` (WARNING: deletes data) |

## 📊 Architecture Decision Records

### Why Separate Repos?

**Infrastructure Repo (this one):**
- Changes rarely
- Affects all applications
- Needs careful testing
- Managed by infrastructure/DevOps

**Application Repos (eduhub, blog, etc):**
- Changes frequently
- Independent deployment
- Faster iteration
- Managed by dev teams

### Why Docker Compose Instead of Kubernetes?

For a single Mac Mini server:
- ✅ Simpler to manage
- ✅ Lower resource overhead
- ✅ Faster to learn
- ✅ Easier to debug
- ❌ Kubernetes is overkill for single-server setup

### Why Makefile?

- ✅ Simple, standard tool
- ✅ Self-documenting (`make help`)
- ✅ Works everywhere (Mac, Linux, CI)
- ✅ Easy to read and modify
- ✅ No extra dependencies

## 🎯 Best Practices

### Environment Variables
- ✅ Never commit `.env` files
- ✅ Keep `.env.example` updated
- ✅ Use strong passwords in production
- ✅ Document all variables

### Database Management
- ✅ Create separate user per application
- ✅ Use least privilege principle
- ✅ Regular backups (`make db-backup`)
- ✅ Test restore procedures

### Nginx Configuration
- ✅ One file per application in `sites/`
- ✅ Always test config before reload
- ✅ Use `.disabled` suffix for disabled sites
- ✅ Keep SSL configs consistent

### Monitoring
- ✅ Add metrics to all applications
- ✅ Create dashboards for key metrics
- ✅ Set up alerts for critical issues
- ✅ Regular review of metrics

## 📚 Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## 🤝 Getting Help

1. Check `make help`
2. Read service-specific READMEs
3. Run `make health` and `make logs`
4. Check GitHub Issues
5. Review commit history for examples

---

**Remember:** This infrastructure exists to make your life easier. If something is confusing or could be improved, update the documentation or open an issue!
