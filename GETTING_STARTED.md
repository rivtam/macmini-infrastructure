# Getting Started Guide

This guide will walk you through setting up the infrastructure for the first time.

## Prerequisites

Make sure you have these installed:
- Docker (20.10 or later)
- Docker Compose (2.0 or later)
- Git
- Make (optional but recommended)

## First-Time Setup

### 1. Clone the Repository

```bash
git clone <your-repo-url> macmini-infrastructure
cd macmini-infrastructure
```

### 2. Initialize Environment Files

```bash
# This creates .env files from .env.example in all service directories
make init

# Or manually:
cp databases/.env.example databases/.env
cp nginx/.env.example nginx/.env
cp monitoring/.env.example monitoring/.env
```

### 3. Configure Passwords

Edit the `.env` files and update sensitive values:

**databases/.env:**
```bash
POSTGRES_PASSWORD=your_secure_password_here  # CHANGE THIS!
```

**monitoring/.env:**
```bash
GRAFANA_ADMIN_PASSWORD=your_secure_password_here  # CHANGE THIS!
```

### 4. Start Infrastructure

```bash
# Start all services
make start-all

# Or start individually:
make start-databases   # Start postgres and redis first
make start-monitoring  # Then monitoring
make start-nginx       # Finally nginx
```

### 5. Verify Everything is Running

```bash
# Check health of all services
make health

# Or check status
make status

# Should show all containers as healthy
```

### 6. Access Services

Open your browser:

- **Grafana**: http://localhost:3000
  - Username: `admin`
  - Password: (from monitoring/.env)

- **Prometheus**: http://localhost:9090

- **Nginx**: http://localhost

### 7. Test Database Connectivity

```bash
# Connect to PostgreSQL
make db-connect

# You should see:
psql (16.x)
Type "help" for help.
postgres=#

# List databases
\l

# Exit
\q
```

```bash
# Connect to Redis
make redis-cli

# Test it
127.0.0.1:6379> PING
PONG
127.0.0.1:6379> exit
```

## Next Steps

### For Local Development

If you're developing applications locally and want to connect to this infrastructure:

```bash
# Start only databases (lightest option)
make dev

# Your local app can now connect to:
# - PostgreSQL: localhost:5432
# - Redis: localhost:6379
```

In your application's `.env`:
```bash
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=eduhub

REDIS_HOST=localhost
REDIS_PORT=6379
```

### Adding Your First Application

1. **Create a database for your app:**
   ```bash
   make db-connect

   CREATE DATABASE myapp;
   CREATE USER myapp_user WITH PASSWORD 'secure_password';
   GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp_user;
   ```

2. **Configure your app to use the infrastructure:**

   Add to your app's `docker-compose.yml`:
   ```yaml
   services:
     myapp:
       # ... your app config
       networks:
         - myapp_network
         - infra_network  # Add this

   networks:
     myapp_network:
     infra_network:
       external: true  # Connect to infrastructure
   ```

3. **Configure nginx routing:**

   Create `nginx/sites/myapp.conf`:
   ```nginx
   server {
       listen 80;
       server_name myapp.local;

       location / {
           proxy_pass http://myapp:3000;
           proxy_set_header Host $host;
       }
   }
   ```

4. **Reload nginx:**
   ```bash
   make nginx-reload
   ```

5. **Test it:**
   ```bash
   # Add to /etc/hosts:
   127.0.0.1 myapp.local

   # Visit http://myapp.local
   ```

## Common Tasks

### View Logs
```bash
# All logs
make logs

# Specific service
make logs-databases
make logs-nginx
make logs-monitoring
```

### Restart Services
```bash
# Restart everything
make restart-all

# Restart specific service
make restart-databases
make restart-nginx
make restart-monitoring
```

### Stop Services
```bash
# Stop all
make stop-all

# Stop specific
make stop-databases
make stop-nginx
make stop-monitoring
```

### Backup Database
```bash
make db-backup
# Backups saved to ./backups/
```

## Troubleshooting

### Port Already in Use

If you get "port already in use" errors:

```bash
# Find what's using the port
lsof -i :5432  # or whatever port

# Option 1: Stop the conflicting service
# Option 2: Change the port in the .env file
vim databases/.env
# Change POSTGRES_PORT=5432 to POSTGRES_PORT=5433
```

### Container Won't Start

```bash
# Check logs
make logs-databases  # or whatever service

# Try recreating
cd databases
docker compose down -v  # WARNING: This deletes data!
docker compose up -d
```

### Can't Connect to Database

```bash
# Make sure it's running
make status

# Check if healthy
make health

# Try connecting
make db-connect

# Check docker network
docker network ls | grep infra
```

### Reset Everything

If you want to start fresh:

```bash
# WARNING: This deletes all data!
make clean

# Then start again
make start-all
```

## Production Deployment

When deploying to production (Mac Mini):

1. **Update domain names** in nginx configs
2. **Set up SSL certificates** (Let's Encrypt)
3. **Change all default passwords**
4. **Configure firewall rules**
5. **Set up automated backups**
6. **Configure GitHub Actions secrets**

See [README.md](README.md) for full production setup guide.

## Getting Help

- Run `make help` to see all available commands
- Check service-specific READMEs:
  - [nginx/README.md](nginx/README.md)
  - [databases/README.md](databases/README.md)
  - [monitoring/README.md](monitoring/README.md)
- Check logs: `make logs`
- Run health check: `make health`

## Quick Reference

```bash
# Start/Stop
make start-all          # Start everything
make stop-all           # Stop everything
make restart-all        # Restart everything

# Status
make health             # Health check
make status             # Show status
make ps                 # List containers

# Databases
make db-connect         # Connect to postgres
make db-backup          # Backup databases
make redis-cli          # Connect to redis

# Nginx
make nginx-test         # Test config
make nginx-reload       # Reload config

# Monitoring
make open-grafana       # Open Grafana
make open-prometheus    # Open Prometheus

# Logs
make logs               # All logs
make logs-databases     # Database logs
make logs-nginx         # Nginx logs
make logs-monitoring    # Monitoring logs

# Development
make dev                # Start for local dev
make clean              # Clean everything (WARNING!)
```

Happy infrastructure managing! 🚀
