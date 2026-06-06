# Infrastructure Repository - Getting Started

This directory contains a complete infrastructure repository setup for your Mac Mini server.

## 📁 What's Inside

```
new/
├── macmini-infrastructure/     # The complete infrastructure repository
│   ├── nginx/                  # Reverse proxy configuration
│   ├── databases/              # PostgreSQL + Redis
│   ├── monitoring/             # Prometheus + Grafana
│   ├── scripts/                # Utility scripts
│   ├── .github/workflows/      # CI/CD pipelines
│   └── Documentation files
│
├── INFRASTRUCTURE_OVERVIEW.md  # High-level architecture guide
└── TEST_LOCALLY.md            # Complete testing guide
```

## 🚀 Quick Start

### 1. Navigate to the infrastructure directory

```bash
cd macmini-infrastructure
```

### 2. Read the documentation

Start with these files in order:
1. **GETTING_STARTED.md** - Step-by-step setup guide
2. **README.md** - Main documentation
3. **INFRASTRUCTURE_OVERVIEW.md** - Architecture and concepts

### 3. Test it locally

```bash
# Initialize environment files
make init

# Start all services
make start-all

# Check health
make health

# Access services:
# - Grafana: http://localhost:3000
# - Prometheus: http://localhost:9090
# - PostgreSQL: localhost:5432
# - Redis: localhost:6379
```

### 4. Explore the services

```bash
# Connect to PostgreSQL
make db-connect

# Connect to Redis
make redis-cli

# View logs
make logs

# See all commands
make help
```

## 📚 Documentation

### For Your First Time
- **macmini-infrastructure/GETTING_STARTED.md** - Start here!
- **TEST_LOCALLY.md** - Complete testing scenarios

### For Understanding Architecture
- **INFRASTRUCTURE_OVERVIEW.md** - Architecture decisions and concepts
- **macmini-infrastructure/README.md** - Complete reference

### For Specific Services
- **macmini-infrastructure/nginx/README.md** - Nginx configuration
- **macmini-infrastructure/databases/README.md** - Database management
- **macmini-infrastructure/monitoring/README.md** - Monitoring setup

## 🎯 Your Questions Answered

### Q1: How does nginx know which frontend to serve?

**Answer:** nginx uses the `server_name` directive (domain matching):

```nginx
# nginx/sites/eduhub.conf
server {
    server_name edu-hub.duckdns.org;  # Matches this domain
    location / {
        # Serve EduHub
    }
}

# nginx/sites/blog.conf
server {
    server_name blog.yourdomain.com;  # Matches this domain
    location / {
        # Serve Blog
    }
}
```

**How it works:**
1. Request comes in for `edu-hub.duckdns.org`
2. nginx checks all `server_name` directives
3. Finds matching config in `sites/eduhub.conf`
4. Routes to that backend

See: `macmini-infrastructure/nginx/sites/eduhub.conf` for a real example

### Q2: Should nginx config be in its own repo?

**Answer:** Yes! This infrastructure repo IS that repo. Here's the structure:

```
Repositories:
├── macmini-infrastructure     (This repo - nginx + shared services)
├── eduhub                     (Your EduHub application)
├── blog                       (Another application)
└── portfolio                  (Another application)

Each app repo references the infrastructure:
- Connects to infra_network
- Uses infra_postgres, infra_redis
- Nginx routes traffic to it
```

**Benefits:**
- ✅ Infrastructure changes don't affect app deployments
- ✅ One place to manage all routing
- ✅ Shared services (DB, Redis) for all apps
- ✅ Easy to add new applications

See: `INFRASTRUCTURE_OVERVIEW.md` for detailed explanation

### Q3: Do we need another repo for infrastructure like Redis and SQL DB?

**Answer:** This repo IS that infrastructure repo! Everything is organized:

```
macmini-infrastructure/
├── nginx/              # The main router
├── databases/          # PostgreSQL + Redis (shared services)
└── monitoring/         # Prometheus + Grafana

Each directory can run independently for testing:
cd databases && docker compose up -d
cd nginx && docker compose up -d
```

**This approach gives you:**
- ✅ Separation of concerns (each service in own directory)
- ✅ Easy QA (test each service independently)
- ✅ Simple deployment (deploy only what changed)
- ✅ Clear ownership (infrastructure team manages this repo)

See: `INFRASTRUCTURE_OVERVIEW.md` section "Separation of Concerns"

## 🧪 Testing Locally

Follow the comprehensive testing guide:

```bash
cd ..  # Go back to new/ directory
cat TEST_LOCALLY.md  # Read testing scenarios
```

Key tests to run:
1. **Quick Test** - 5 minutes to verify everything works
2. **Database Persistence** - Ensure data survives restarts
3. **Nginx Configuration** - Test routing changes
4. **Monitoring** - Verify metrics collection
5. **Backup/Restore** - Test disaster recovery

## 🎓 Learning Path

### Day 1: Setup and Explore
```bash
cd macmini-infrastructure
make setup                    # Initialize and start everything
make health                   # Check all services
make db-connect              # Explore database
make redis-cli               # Explore Redis
make open-grafana            # View monitoring
```

### Day 2: Understanding
```bash
# Read each service README
cat nginx/README.md
cat databases/README.md
cat monitoring/README.md

# Test individual services
cd databases && docker compose up -d
cd ../nginx && docker compose up -d
```

### Day 3: Integration
```bash
# Add test app configuration
# Test with your EduHub app
# See TEST_LOCALLY.md for scenarios
```

## 🚢 Production Deployment

Once tested locally, deploy to Mac Mini:

1. **Create GitHub repository:**
   ```bash
   cd macmini-infrastructure
   git init
   git add .
   git commit -m "Initial infrastructure setup"
   gh repo create macmini-infrastructure --private
   git push -u origin main
   ```

2. **Configure GitHub Secrets:**
   - `SSH_HOST` - Mac Mini hostname
   - `SSH_USER` - SSH username
   - `SSH_PRIVATE_KEY` - SSH private key
   - `SSH_PORT` - SSH port
   - `TS_AUTH_KEY` - Tailscale key (if using)

3. **Deploy:**
   ```bash
   git push origin main
   # GitHub Actions automatically deploys to Mac Mini
   ```

## 📋 Next Steps

### Immediate (Today)
1. ✅ Read `macmini-infrastructure/GETTING_STARTED.md`
2. ✅ Run `make setup` to start everything
3. ✅ Test database connectivity
4. ✅ Access Grafana dashboard

### This Week
1. ✅ Test each service independently
2. ✅ Connect your EduHub app to this infrastructure
3. ✅ Add nginx routing for EduHub
4. ✅ Test backup/restore procedures

### Before Production
1. ✅ Change all default passwords
2. ✅ Set up SSL certificates
3. ✅ Configure automated backups
4. ✅ Set up monitoring alerts
5. ✅ Test disaster recovery

## 🆘 Getting Help

### Quick Commands
```bash
make help              # See all available commands
make health            # Check service health
make logs              # View logs
make status            # See what's running
```

### Documentation
- **Stuck?** Check `GETTING_STARTED.md`
- **Confused?** Read `INFRASTRUCTURE_OVERVIEW.md`
- **Testing?** Follow `TEST_LOCALLY.md`
- **Service issues?** Check service-specific README

### Common Issues

**Port conflicts:**
```bash
# Change ports in .env files
vim databases/.env
# POSTGRES_PORT=5433 instead of 5432
```

**Services won't start:**
```bash
make logs-databases  # Check logs
make clean           # Reset everything (WARNING: deletes data)
make start-all       # Start fresh
```

**Can't connect to database:**
```bash
make health          # Check if running
make status          # See container status
docker network ls    # Check network exists
```

## 🎉 You're Ready!

You now have:
- ✅ Complete infrastructure repository
- ✅ Nginx reverse proxy with SSL support
- ✅ PostgreSQL and Redis databases
- ✅ Prometheus and Grafana monitoring
- ✅ Automated backups and health checks
- ✅ CI/CD pipelines for deployment
- ✅ Comprehensive documentation

**Start with:** `cd macmini-infrastructure && cat GETTING_STARTED.md`

---

**Questions?** Check the documentation files or run `make help`!
