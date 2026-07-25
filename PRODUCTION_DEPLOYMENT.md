# Production Deployment Guide

**First-time production deployment checklist**

## 🎯 Pre-Deployment Checklist

### System Requirements
- [ ] Mac Mini with macOS (or Linux server)
- [ ] Docker & Docker Compose installed
- [ ] Minimum 8GB RAM available
- [ ] 50GB+ free disk space
- [ ] Domain name configured (optional but recommended)
- [ ] SSH access to server
- [ ] Root/sudo access

### Network Requirements
- [ ] Ports 80, 443 open (web traffic)
- [ ] Port 22 open (SSH)
- [ ] Static IP or dynamic DNS configured
- [ ] Router port forwarding configured (if behind NAT)

---

## 📋 Step-by-Step Production Deployment

### Step 1: Choose Your Service Profile

Based on your startup stage and budget:

```bash
# Option A: Bootstrapping (< $5k MRR)
# 3 services, 4 CPU, 3GB RAM
PROFILE=minimal

# Option B: Early Stage ($5k-$20k MRR) - RECOMMENDED
# 6 services, 6.5 CPU, 4.6GB RAM
PROFILE=standard

# Option C: Growth Stage ($20k-$100k MRR)
# 10 services, 9 CPU, 6GB RAM
PROFILE=production

# Option D: Enterprise/Compliance
# 15+ services, 12.5 CPU, 7GB RAM
PROFILE=full
```

---

### Step 2: Clone Repository

```bash
# SSH into your server
ssh user@your-server-ip

# Clone infrastructure repository to the expected path
mkdir -p ~/prod
cd ~/prod
git clone <your-repo-url> infrastructure
cd infrastructure

# IMPORTANT: CI/CD expects repo at ~/prod/infrastructure
# If you clone elsewhere, update .github/workflows/deploy-infrastructure.yml
```

**For CI/CD automation:**
After initial deployment, pushing to the `main` branch will automatically redeploy!
See [CI_CD_SETUP.md](CI_CD_SETUP.md) for configuration.

---

### Step 3: Configure Environment Variables

**IMPORTANT: Use strong passwords in production!**

```bash
# Generate strong passwords (save these in a password manager!)
openssl rand -base64 32  # For PostgreSQL
openssl rand -base64 32  # For Redis
openssl rand -base64 32  # For Grafana

# Create environment files
cd databases
cp .env.example .env
nano .env
```

**databases/.env:**
```bash
# PostgreSQL Configuration
POSTGRES_PASSWORD=<strong-password-from-above>
POSTGRES_USER=postgres
POSTGRES_PORT=5432
POSTGRES_HOST_BINDING=127.0.0.1  # IMPORTANT: localhost only in production!

# Redis Configuration
REDIS_PASSWORD=<strong-password-from-above>
REDIS_PORT=6379
REDIS_HOST_BINDING=127.0.0.1     # IMPORTANT: localhost only in production!

# PgBouncer (if using production/full profile)
PGBOUNCER_PORT=6432
```

**monitoring/.env:**
```bash
cd ../monitoring
cp .env.example .env
nano .env

# Grafana Configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=<strong-password-from-above>
GRAFANA_ROOT_URL=https://monitoring.yourdomain.com  # Or http://your-ip:3000

# Alertmanager (optional - for notifications)
ALERTMANAGER_EMAIL=alerts@yourdomain.com
# ALERTMANAGER_SMTP_HOST=smtp.gmail.com
# ALERTMANAGER_SMTP_PORT=587
# ALERTMANAGER_SMTP_USER=your-email@gmail.com
# ALERTMANAGER_SMTP_PASSWORD=your-app-password
```

**vault/.env (if using production/full profile):**
```bash
cd ../vault
cp .env.example .env
# Vault will be initialized in later steps
```

---

### Step 4: Configure Nginx for Your Domain

```bash
cd ../nginx/sites

# Edit the site configuration
nano eduhub.conf
```

**Replace with your domain:**
```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;  # Change this!

    # For Let's Encrypt certificate validation
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect HTTP to HTTPS (after SSL is set up)
    # location / {
    #     return 301 https://$server_name$request_uri;
    # }

    # Temporary: proxy to your app (before SSL)
    location / {
        proxy_pass http://your-app:3000;  # Change to your app container
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

### Step 5: Create Docker Network

```bash
cd ~/infrastructure

# Create the shared network
docker network create infra_network
```

---

### Step 6: Start Infrastructure Services

```bash
# Start services based on your chosen profile
./scripts/start-services.sh $PROFILE

# Examples:
./scripts/start-services.sh minimal      # Bootstrapping
./scripts/start-services.sh standard     # Recommended
./scripts/start-services.sh production   # Growth stage
./scripts/start-services.sh full         # Enterprise
```

Wait for services to start (30-60 seconds)...

---

### Step 7: Verify Services are Running

```bash
# Check service status
./scripts/service-status.sh

# All essential services should show "Running"
# Expected output:
# ● PostgreSQL       Running    Tier 1
# ● Redis           Running    Tier 1
# ● Nginx           Running    Tier 1
# ... (more based on profile)

# Check Docker containers
docker ps

# Should see containers: infra_postgres, infra_redis, infra_nginx, etc.
```

---

### Step 8: Secure the Database

**Create application-specific database users (don't use postgres superuser!):**

```bash
# Connect to PostgreSQL
docker exec -it infra_postgres psql -U postgres

# In PostgreSQL prompt:
CREATE DATABASE myapp;
CREATE USER myapp_user WITH PASSWORD 'another-strong-password';
GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp_user;

# Grant schema permissions
\c myapp
GRANT ALL ON SCHEMA public TO myapp_user;

# Exit
\q
```

**Test the connection:**
```bash
docker exec -it infra_postgres psql -U myapp_user -d myapp -c "SELECT 1;"
# Should return: 1
```

---

### Step 9: Set Up SSL Certificates (If you have a domain)

**Option A: Let's Encrypt (Free, Automated)**

```bash
# Make sure DNS is pointing to your server!
# Check: dig yourdomain.com
# Should return your server's IP

# Obtain certificate
./scripts/certbot-obtain.sh yourdomain.com your-email@example.com

# Start Certbot for auto-renewal
cd certbot
docker compose up -d
cd ..
```

**Update Nginx to use SSL:**
```bash
nano nginx/sites/eduhub.conf

# Add HTTPS server block:
server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://your-app:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}

# Reload nginx
docker exec infra_nginx nginx -s reload
```

**Option B: Self-Signed Certificate (Testing/Internal)**

```bash
./scripts/generate-default-ssl.sh
# Follow prompts
```

---

### Step 10: Set Up Automated Backups

```bash
# Configure automated daily backups
./scripts/setup-backup-cron.sh

# Test backup manually
./scripts/backup-databases.sh

# Verify backup was created
ls -lh ../backups/daily/
# Should see postgres and redis backup files with timestamps
```

---

### Step 11: Initialize Vault (If using production/full profile)

```bash
# Start Vault
cd vault
docker compose up -d
cd ..

# Initialize Vault (FIRST TIME ONLY)
./scripts/vault-init.sh

# ⚠️ CRITICAL: Save the output!
# You will receive:
# - 5 unseal keys
# - 1 root token
#
# Store these in a PASSWORD MANAGER immediately!
# Without these, you cannot access Vault!

# Unseal Vault (required after every restart)
./scripts/vault-unseal.sh
# Enter 3 of the 5 unseal keys when prompted

# Verify Vault is ready
docker exec infra_vault vault status
# Should show: Sealed = false
```

**Migrate secrets to Vault (optional):**
```bash
./scripts/vault-migrate-secrets.sh
# Migrates passwords from .env files to Vault
```

---

### Step 12: Set Up Fail2ban (DDoS Protection)

```bash
# Install Fail2ban on host system
sudo ./scripts/setup-fail2ban.sh

# Verify it's running
sudo fail2ban-client status

# Expected output:
# |- Number of jail:      8
# `- Jail list:   sshd, nginx-http-auth, nginx-404, ...
```

---

### Step 13: Configure Firewall

```bash
# Install ufw (if not already installed)
sudo apt install ufw  # Ubuntu/Debian
# or
brew install ufw      # macOS (requires additional setup)

# Allow SSH (IMPORTANT: Do this first!)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Verify rules
sudo ufw status
```

---

### Step 14: Access Monitoring (If using standard/production/full)

```bash
# Get your server IP
curl ifconfig.me

# Access Grafana
# Open browser: http://your-server-ip:3000
# OR if you set up domain: https://monitoring.yourdomain.com

# Login:
# Username: admin
# Password: <from monitoring/.env>

# You should see:
# - Infrastructure Overview dashboard
# - All services showing as "UP"
# - Metrics being collected
```

**Secure Grafana (optional but recommended):**
```nginx
# Add to nginx/sites/monitoring.conf
server {
    listen 443 ssl;
    server_name monitoring.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://infra_grafana:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

### Step 15: Deploy Your Application

**Connect your application to infrastructure:**

```yaml
# In your application's docker-compose.yml
version: '3.8'

services:
  myapp:
    image: your-app:latest
    container_name: myapp
    restart: unless-stopped
    environment:
      # Database connection
      DATABASE_URL: postgresql://myapp_user:password@infra_postgres:5432/myapp
      # Or via PgBouncer (if using production/full):
      # DATABASE_URL: postgresql://myapp_user:password@infra_pgbouncer:6432/myapp

      # Redis connection
      REDIS_URL: redis://:redis-password@infra_redis:6379

      # Get secrets from Vault (if configured)
      # VAULT_ADDR: http://infra_vault:8200
      # VAULT_TOKEN: <get-from-vault>

    networks:
      - infra_network

    depends_on:
      - infra_postgres
      - infra_redis

networks:
  infra_network:
    external: true
```

**Start your application:**
```bash
cd ~/your-application
docker compose up -d
```

---

## ✅ Post-Deployment Verification

### 1. Health Checks

```bash
cd ~/infrastructure

# Check all services
./scripts/service-status.sh

# Check individual services
docker exec infra_postgres pg_isready -U postgres
docker exec infra_redis redis-cli -a <password> ping
curl http://localhost/healthz  # Nginx health

# Check application can connect to database
docker exec myapp psql postgresql://myapp_user:password@infra_postgres:5432/myapp -c "SELECT 1;"
```

### 2. Test Backup & Restore

```bash
# Create a test backup
./scripts/backup-databases.sh

# Verify backup files exist
ls -lh ../backups/daily/

# Test restore (OPTIONAL - only if you want to verify)
# WARNING: This will overwrite current data!
# ./scripts/restore-databases.sh
```

### 3. Test Monitoring

```bash
# Open Grafana
open http://your-server-ip:3000

# Check:
# ✓ All services show as "UP" in Prometheus targets
# ✓ Infrastructure Overview dashboard shows metrics
# ✓ No alerts firing in Alertmanager
```

### 4. Test SSL (if configured)

```bash
# Test HTTPS
curl -I https://yourdomain.com
# Should return: HTTP/2 200

# Check certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com < /dev/null | grep -A 2 "Verify return code"
# Should show: Verify return code: 0 (ok)
```

### 5. Test Application

```bash
# Access your application
curl http://yourdomain.com
# OR
curl https://yourdomain.com

# Should return your application's response
```

---

## 🔒 Security Hardening (Recommended)

### Change Default SSH Port

```bash
sudo nano /etc/ssh/sshd_config
# Change: Port 22 → Port 2222
sudo systemctl restart sshd

# Update firewall
sudo ufw delete allow 22/tcp
sudo ufw allow 2222/tcp
```

### Disable Root Login

```bash
sudo nano /etc/ssh/sshd_config
# Change: PermitRootLogin yes → PermitRootLogin no
sudo systemctl restart sshd
```

### Set Up Key-Based Authentication

```bash
# On your local machine:
ssh-copy-id user@your-server-ip

# On server, disable password auth:
sudo nano /etc/ssh/sshd_config
# Change: PasswordAuthentication yes → PasswordAuthentication no
sudo systemctl restart sshd
```

---

## 📊 Monitoring & Maintenance

### Daily
- [ ] Check `./scripts/service-status.sh` for service health
- [ ] Review Grafana dashboards for anomalies
- [ ] Check disk space: `df -h`

### Weekly
- [ ] Review Grafana metrics for trends
- [ ] Check backup logs: `tail -f /var/log/backup.log`
- [ ] Review Fail2ban bans: `sudo fail2ban-client status`

### Monthly
- [ ] Review resource usage trends
- [ ] Test database restore from backup
- [ ] Update service images: `docker compose pull && docker compose up -d`
- [ ] Review and rotate logs if needed

---

## 🚨 Troubleshooting

### Services Won't Start

```bash
# Check logs
docker compose logs <service-name>

# Common issues:
# 1. Port already in use
sudo lsof -i :5432  # Check PostgreSQL port
sudo lsof -i :6379  # Check Redis port

# 2. Permission issues
sudo chown -R $(whoami) ~/infrastructure

# 3. Network issues
docker network ls
docker network inspect infra_network
```

### Can't Connect to Database

```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# Check logs
docker logs infra_postgres

# Test connection
docker exec -it infra_postgres psql -U postgres -c "SELECT 1;"

# Check if bound to localhost only (correct for production)
grep POSTGRES_HOST_BINDING databases/.env
# Should be: 127.0.0.1
```

### Monitoring Not Working

```bash
# Check Prometheus targets
curl http://localhost:9090/targets

# Check Grafana
docker logs infra_grafana

# Restart monitoring stack
cd monitoring
docker compose restart
```

### SSL Certificate Issues

```bash
# Check Certbot logs
docker logs infra_certbot

# Verify domain DNS
dig yourdomain.com
# Should return your server IP

# Test certificate renewal
./scripts/certbot-renew.sh --dry-run
```

---

## 📈 Scaling Up

As your startup grows:

### Add More Resources
```bash
# Currently on minimal? Add monitoring
./scripts/toggle-tier.sh monitoring on

# Need security? Add it
./scripts/toggle-tier.sh security on

# Need better performance? Add connection pooling
./scripts/toggle-tier.sh performance on
```

### Upgrade Profile
```bash
# From standard to production
./scripts/toggle-tier.sh security on
./scripts/toggle-tier.sh performance on
./scripts/toggle-tier.sh observability on
```

---

## 🎉 Deployment Complete!

Your production infrastructure is now running!

### What You Have:
- ✅ Production databases (PostgreSQL, Redis)
- ✅ Reverse proxy with SSL (Nginx)
- ✅ Monitoring (based on profile)
- ✅ Automated backups
- ✅ Security hardening
- ✅ DDoS protection (Fail2ban)

### Next Steps:
1. Deploy your application containers
2. Set up CI/CD for automatic deployments
3. Configure alerting notifications (Slack/email)
4. Set up off-site backup replication
5. Monitor and optimize based on metrics

### Important URLs:
- Application: https://yourdomain.com
- Grafana: http://your-ip:3000 (or https://monitoring.yourdomain.com)
- Prometheus: http://your-ip:9090 (internal only)

### Important Files to Backup:
- `databases/.env` - Database passwords
- `monitoring/.env` - Grafana credentials
- Vault unseal keys (in password manager)
- SSL certificates (auto-renewed by Certbot)

---

**Need help?** See [DOCUMENTATION.md](DOCUMENTATION.md) or [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
