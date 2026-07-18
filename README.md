# Mac Mini Infrastructure

**Production-ready enterprise infrastructure - 10/10 rating**

Centralized infrastructure repository for managing shared services on Mac Mini server with comprehensive monitoring, security, logging, and automation.

## 🚀 Quick Start

```bash
# Initialize environment files and start everything
make setup

# Or step by step:
make init        # Create .env files
make start-all   # Start all services
make health      # Check service health
```

**First time here?** Read [GETTING_STARTED.md](GETTING_STARTED.md) for detailed setup instructions.

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[QUICK_START.md](QUICK_START.md)** | Overview and quick reference |
| **[GETTING_STARTED.md](GETTING_STARTED.md)** | Step-by-step setup guide |
| **[INFRASTRUCTURE_OVERVIEW.md](INFRASTRUCTURE_OVERVIEW.md)** | Architecture and concepts |
| **[TEST_LOCALLY.md](TEST_LOCALLY.md)** | Complete testing scenarios |
| **[SECURITY.md](SECURITY.md)** | Security best practices and configuration |
| **[BACKUP_RESTORE.md](BACKUP_RESTORE.md)** | Comprehensive backup and restore guide |
| **[LOGGING_SECRETS.md](LOGGING_SECRETS.md)** | Loki logging and Vault secrets management |

### Service-Specific Docs
- [nginx/README.md](nginx/README.md) - Nginx configuration
- [databases/README.md](databases/README.md) - Database management
- [monitoring/README.md](monitoring/README.md) - Monitoring setup
- [vault/README.md](vault/README.md) - Secrets management with Vault
- [audit/README.md](audit/README.md) - Audit logging and compliance

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│          Mac Mini Server (Physical)             │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │   Nginx Gateway (Port 80/443)            │ │
│  │   Routes by domain:                      │ │
│  │   - edu-hub.duckdns.org → EduHub        │ │
│  │   - blog.domain.com → Blog              │ │
│  │   - monitoring.domain.com → Grafana     │ │
│  └───────────────────────────────────────────┘ │
│                     │                           │
│  ┌──────────────────┴──────────────────┐       │
│  │         Application Containers       │       │
│  │  ┌─────────────┐    ┌─────────────┐ │       │
│  │  │ EduHub App  │    │  Blog App   │ │       │
│  │  └──────┬──────┘    └──────┬──────┘ │       │
│  └─────────┼──────────────────┼────────┘       │
│            │                  │                 │
│  ┌─────────┴──────────────────┴─────────────┐  │
│  │   Shared Infrastructure (infra_network)  │  │
│  │  ┌──────────┐  ┌───────┐  ┌───────────┐ │  │
│  │  │ Postgres │  │ Redis │  │ Prometheus│ │  │
│  │  │   :5432  │  │ :6379 │  │   :9090   │ │  │
│  │  └──────────┘  └───────┘  └───────────┘ │  │
│  │  ┌──────────┐                           │  │
│  │  │ Grafana  │                           │  │
│  │  │  :3000   │                           │  │
│  │  └──────────┘                           │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
```

## 📦 Services

### Core Infrastructure
- **Nginx** - Reverse proxy and SSL termination (ports 80, 443)
- **PostgreSQL 16** - Shared database server (port 5432)
- **Redis 7** - Cache and message broker (port 6379)
- **PgBouncer** - Connection pooling (port 6432)

### Monitoring & Observability
- **Prometheus** - Metrics collection (port 9090)
- **Grafana** - Metrics visualization and dashboards (port 3000)
- **Loki** - Centralized log aggregation (port 3100)
- **Promtail** - Log shipping agent
- **Alertmanager** - Alert routing and notifications (port 9093)
- **Node Exporter** - Host metrics (port 9100)
- **cAdvisor** - Container metrics (port 8080)
- **PostgreSQL Exporter** - Database metrics (port 9187)
- **Redis Exporter** - Cache metrics (port 9121)

### Security & Compliance
- **HashiCorp Vault** - Secrets management (port 8200)
- **Fail2ban** - DDoS protection and rate limiting (host-based)
- **Certbot** - SSL certificate automation
- **Audit System** - Comprehensive audit logging for compliance

### Automation
- **Automated Backups** - Daily backups with retention policies
- **SSL Renewal** - Automatic certificate renewal
- **CI/CD Pipeline** - GitHub Actions with rollback capabilities

## 🎯 Common Questions

### How does nginx know which frontend to serve?

nginx uses `server_name` (domain matching):

```nginx
# nginx/sites/eduhub.conf
server {
    server_name edu-hub.duckdns.org;
    location / {
        # Routes to EduHub
    }
}

# nginx/sites/blog.conf
server {
    server_name blog.yourdomain.com;
    location / {
        # Routes to Blog
    }
}
```

See [INFRASTRUCTURE_OVERVIEW.md](INFRASTRUCTURE_OVERVIEW.md) for detailed explanation.

### Why separate infrastructure repo?

**Infrastructure Repo (this one):**
- Contains: nginx, databases, monitoring
- Changes: Rarely
- Affects: All applications
- Managed by: Infrastructure/DevOps team

**Application Repos (eduhub, blog):**
- Contains: Application code
- Changes: Frequently
- Affects: Only that application
- Managed by: Development teams

### How do applications connect?

Applications join the `infra_network`:

```yaml
# In your application's docker-compose.yml
services:
  your-app:
    environment:
      DB_HOST: infra_postgres
      REDIS_HOST: infra_redis
    networks:
      - your-app_network
      - infra_network

networks:
  your-app_network:
  infra_network:
    external: true
```

## 🛠️ Quick Commands

```bash
# Start/Stop
make start-all          # Start everything
make start-databases    # Start only databases
make start-nginx        # Start only nginx
make start-monitoring   # Start only monitoring
make stop-all           # Stop everything

# Status & Health
make health             # Health check all services
make status             # Show container status
make ps                 # List running containers

# Databases
make db-connect         # Connect to PostgreSQL
make db-backup          # Backup databases
make redis-cli          # Connect to Redis

# Nginx
make nginx-test         # Test configuration
make nginx-reload       # Reload configuration

# Monitoring
make open-grafana       # Open Grafana
make open-prometheus    # Open Prometheus

# Logs
make logs               # All logs
make logs-databases     # Database logs
make logs-nginx         # Nginx logs
make logs-monitoring    # Monitoring logs

# Development
make dev                # Start for local development
make clean              # Clean everything (WARNING!)
make help               # Show all commands
```

## 📁 Repository Structure

```
macmini-infrastructure/
├── 📄 Documentation
│   ├── README.md                   # This file
│   ├── QUICK_START.md              # Quick reference
│   ├── GETTING_STARTED.md          # Setup guide
│   ├── INFRASTRUCTURE_OVERVIEW.md  # Architecture
│   └── TEST_LOCALLY.md             # Testing guide
│
├── 🌐 Nginx (Reverse Proxy)
│   ├── docker-compose.yml
│   ├── nginx.conf
│   ├── sites/                      # Per-app configs
│   └── README.md
│
├── 🗄️ Databases
│   ├── docker-compose.yml
│   ├── postgres/init/
│   ├── redis/
│   └── README.md
│
├── 📊 Monitoring
│   ├── docker-compose.yml
│   ├── prometheus/
│   ├── grafana/
│   └── README.md
│
├── 🔧 Infrastructure Tools
│   ├── scripts/                    # Helper scripts
│   ├── .github/workflows/          # CI/CD
│   ├── Makefile                    # Easy commands
│   └── .gitignore
│
└── 🔒 Configuration
    └── .env.example
```

## 🌐 Adding New Applications

### 1. Create Database

```bash
make db-connect

CREATE DATABASE myapp;
CREATE USER myapp_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp_user;
```

### 2. Add Nginx Configuration

Create `nginx/sites/myapp.conf`:

```nginx
server {
    listen 443 ssl;
    server_name myapp.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/myapp.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/myapp.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://myapp:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Reload: `make nginx-reload`

### 3. Configure Application

```yaml
# myapp/docker-compose.yml
services:
  myapp:
    image: myapp:latest
    environment:
      DB_HOST: infra_postgres
      REDIS_HOST: infra_redis
    networks:
      - infra_network

networks:
  infra_network:
    external: true
```

## 🧪 Testing

### Quick Health Check

```bash
make health
```

### Test Individual Services

```bash
# Test databases
cd databases && docker compose up -d
docker compose ps
docker compose down

# Test nginx
cd nginx && docker compose --profile test run --rm nginx-test

# Test monitoring
cd monitoring && docker compose up -d
curl http://localhost:9090/-/healthy
```

### Full Testing Guide

See [TEST_LOCALLY.md](TEST_LOCALLY.md) for comprehensive testing scenarios.

## 🚀 Deployment

### Local Development

```bash
make dev
# Starts only databases on localhost:5432 and localhost:6379
# Your app connects to localhost
```

### Production Deployment

1. Push to GitHub:
   ```bash
   git push origin main
   ```

2. GitHub Actions automatically:
   - Tests all services
   - Deploys to Mac Mini via Tailscale
   - Runs health checks
   - Rolls back on failure

### Required GitHub Secrets

```
SSH_HOST              # Mac Mini hostname/IP
SSH_USER              # SSH username
SSH_PRIVATE_KEY       # SSH private key
SSH_PORT              # SSH port (default: 22)
TS_AUTH_KEY          # Tailscale auth key
```

## 🔒 Security Checklist

- [ ] Change all passwords in `.env` files
- [ ] Set up SSL certificates with Let's Encrypt
- [ ] Configure Redis password
- [ ] Use separate database users per application
- [ ] Enable firewall on Mac Mini
- [ ] Set up automated backups
- [ ] Configure log rotation
- [ ] Review nginx security headers

## 🐛 Troubleshooting

### Services Won't Start

```bash
make logs-<service>     # Check logs
make status             # Check container status
docker network ls       # Verify network exists
```

### Port Conflicts

```bash
# Check what's using the port
lsof -i :5432

# Change port in .env file
vim databases/.env
# POSTGRES_PORT=5433
```

### Database Connection Issues

```bash
# Verify database is healthy
make health

# Test connection
make db-connect

# Check if app is on infra_network
docker network inspect infra_network
```

### Reset Everything

```bash
make clean  # WARNING: Deletes all data
make setup  # Start fresh
```

## 📊 Monitoring

### Access Dashboards

- **Grafana**: http://localhost:3000 (admin / password from monitoring/.env)
- **Prometheus**: http://localhost:9090

### Add Application Metrics

1. Add metrics endpoint to your app
2. Update `monitoring/prometheus/prometheus.yml`
3. Restart: `make restart-monitoring`

See [monitoring/README.md](monitoring/README.md) for details.

## 💾 Backups

### Automated Backup

```bash
make db-backup
# Saves to ./backups/ with timestamp
```

### Manual Backup

```bash
# Single database
docker exec infra_postgres pg_dump -U postgres eduhub > backup.sql

# All databases
docker exec infra_postgres pg_dumpall -U postgres > backup_all.sql
```

### Restore

```bash
cat backup.sql | docker exec -i infra_postgres psql -U postgres eduhub
```

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Test locally: `make start-all && make health`
4. Commit and push
5. Create pull request
6. CI tests run automatically

## 📝 License

[Your License Here]

## 🆘 Support

1. Check `make help`
2. Read service-specific READMEs
3. Run `make health` and `make logs`
4. Review [INFRASTRUCTURE_OVERVIEW.md](INFRASTRUCTURE_OVERVIEW.md)
5. Check GitHub Issues

---

**Quick Start:** `make setup` → `make health` → You're running! 🚀
