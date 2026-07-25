# GHCR Deployment Guide

**Infrastructure deployment using GitHub Container Registry (same approach as EduHub)**

---

## Why GHCR?

✅ **Mac Mini saves 1-2GB RAM** - No builds on server, just pull ready images
✅ **Faster deployments** - Images pre-built on GitHub's servers
✅ **Consistent with EduHub** - Same deployment pattern
✅ **Secure** - Read-only GHCR token, no GitHub credentials needed
✅ **Rollback-friendly** - Tag-based image versions

---

## Architecture Overview

### Old Approach (Git Clone - ❌ DON'T USE)
```
GitHub → Mac Mini: git clone
         ↓
         Mac Mini builds Docker images locally (1-2GB RAM!)
         ↓
         Deploy containers
```

### New Approach (GHCR - ✅ USE THIS - Same as EduHub)
```
1. You push code to GitHub
   ↓
2. GitHub Actions (on GitHub servers):
   - Builds Docker images
   - Pushes images to GHCR
   - SSH into Mac Mini
   ↓
3. Mac Mini (orchestrated by GitHub Actions via SSH):
   - docker login ghcr.io (using GHCR_TOKEN from GitHub)
   - docker compose pull (pulls images from GHCR)
   - docker compose up -d (deploys containers)
   - Health checks run
   ↓
4. GitHub Actions (monitoring via SSH):
   - Checks container health
   - Auto-rollback if health checks fail
   - Reports success/failure
```

**Key Point:** GitHub Actions **orchestrates** the deployment via SSH. The Mac Mini **pulls** images from GHCR. GitHub Actions does NOT push images to Mac Mini directly.

---

## Custom Images (Built on GitHub, Stored in GHCR)

| Service | Image | Contains |
|---------|-------|----------|
| **Nginx** | `ghcr.io/you/infra-nginx:latest` | Custom nginx.conf, sites config, healthz endpoint |
| **Prometheus** | `ghcr.io/you/infra-prometheus:latest` | Alert rules, prometheus.yml config |
| **Grafana** | `ghcr.io/you/infra-grafana:latest` | Pre-provisioned dashboards, datasources |
| **Loki** | `ghcr.io/you/infra-loki:latest` | Log retention config |
| **Promtail** | `ghcr.io/you/infra-promtail:latest` | Infrastructure log collection config |
| **Alertmanager** | `ghcr.io/you/infra-alertmanager:latest` | Alert routing, templates |

**Official Images (Used As-Is):**
- PostgreSQL: `postgres:16`
- Redis: `redis:7-alpine`
- Node Exporter: `prom/node-exporter:latest`
- cAdvisor: `gcr.io/cadvisor/cadvisor:latest`

---

## Setup Instructions

### Step 1: Configure GitHub Repository Secrets

Go to your GitHub repo → **Settings → Secrets and variables → Actions**

Add these secrets:

#### 1. `SSH_HOST`
```
100.x.x.x  # Your Mac Mini IP (Tailscale recommended)
```

#### 2. `SSH_USER`
```
your_mac_mini_username
```

#### 3. `SSH_PRIVATE_KEY`
```bash
# On Mac Mini, generate SSH key for CI/CD:
ssh-keygen -t ed25519 -C "github-actions-infra" -f ~/.ssh/github_actions_infra
cat ~/.ssh/github_actions_infra.pub >> ~/.ssh/authorized_keys

# Copy private key for GitHub:
cat ~/.ssh/github_actions_infra
# Paste entire output (including BEGIN/END lines) into GitHub secret
```

#### 4. `SSH_PORT` (optional)
```
22  # Or your custom SSH port
```

#### 5. `TS_AUTH_KEY` (recommended for Tailscale)
```
tskey-auth-xxxxxxxxxxxxx
# Get from: https://login.tailscale.com/admin/settings/keys
```

#### 6. `GHCR_TOKEN` ⭐ **IMPORTANT**
```bash
# Create Personal Access Token (PAT) for GHCR:
# GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
#
# Scopes needed:
#   ✓ read:packages (pull images)
#   ✓ write:packages (push images - only for CI/CD)
#
# For Mac Mini server, create a READ-ONLY token:
#   ✓ read:packages ONLY
#
# Then paste token as GHCR_TOKEN secret
```

---

### Step 2: Make GitHub Packages Public (Recommended)

To avoid needing authentication to pull images:

1. Go to your GitHub profile
2. Click "Packages" tab
3. For each `infra-*` package:
   - Click package → Package settings
   - Scroll down → "Change visibility"
   - Set to **Public**

**Benefits:**
- No GHCR_TOKEN needed on Mac Mini
- Faster pulls (no auth overhead)
- Safe for infrastructure configs (not secret code)

---

### Step 3: Initial Mac Mini Setup

```bash
# SSH into Mac Mini
ssh user@your-mac-mini-ip

# Create infrastructure directory
mkdir -p ~/prod/infrastructure
cd ~/prod/infrastructure

# Clone repository (LAST TIME you'll need GitHub auth!)
git clone https://github.com/your-username/macmini-infrastructure.git .

# Set environment variable for GHCR images
echo 'export GITHUB_REPOSITORY_OWNER=your-github-username' >> ~/.bashrc
source ~/.bashrc

# Login to GHCR (if packages are private)
# Create a READ-ONLY token first!
export GHCR_TOKEN=ghp_xxxxxxxxxxxx
echo $GHCR_TOKEN | docker login ghcr.io -u your-github-username --password-stdin

# Create environment files
cd databases
cp .env.example .env
nano .env  # Set strong passwords

cd ../monitoring
cp .env.example .env
nano .env  # Set Grafana password

cd ~/prod/infrastructure

# Deploy infrastructure
./scripts/deploy-ghcr.sh
```

---

### Step 4: Trigger First CI/CD Build

```bash
# On your local machine (not Mac Mini):
cd macmini-infrastructure

# Make a small change to trigger build
echo "# GHCR Deployment" >> README.md
git add .
git commit -m "feat: migrate to GHCR deployment"
git push origin main
```

**What happens:**
1. ✅ GitHub Actions detects changes
2. ✅ Builds Docker images on GitHub servers
3. ✅ Pushes images to GHCR
4. ✅ Connects to Mac Mini via SSH
5. ✅ Mac Mini pulls ready images (NO BUILDS!)
6. ✅ Deploys containers
7. ✅ Health checks confirm success

---

## How CI/CD Works (Same as EduHub)

### Complete Deployment Flow

```yaml
# Example: You edit nginx/sites/eduhub.conf
git push origin main

# 1. GitHub Actions (on GitHub's servers):
✓ Detects nginx changed (path filter)
✓ Builds only nginx image (on GitHub servers)
✓ Pushes to ghcr.io/you/infra-nginx:latest
✓ SSHs to Mac Mini

# 2. Mac Mini (orchestrated by GitHub Actions via SSH):
✓ GitHub Actions runs: echo $GHCR_TOKEN | docker login ghcr.io
✓ GitHub Actions runs: docker compose pull nginx
✓ GitHub Actions runs: docker compose up -d nginx
✓ Container starts

# 3. GitHub Actions (monitoring via SSH):
✓ Checks nginx health status (via docker inspect)
✓ If healthy: Deployment complete! ✅
✓ If unhealthy: Rollback to previous image ❌

# Other services: Keep running (no downtime!)
```

**Important:** GitHub Actions **orchestrates everything via SSH**. The Mac Mini doesn't act independently - GitHub Actions tells it what commands to run.

### Workflow Steps

```yaml
1. Detect Changes
   ├─ nginx/** changed? → Build infra-nginx
   ├─ monitoring/grafana/** changed? → Build infra-grafana
   ├─ monitoring/prometheus/** changed? → Build infra-prometheus
   └─ etc.

2. Build Images (on GitHub servers)
   ├─ docker build nginx/Dockerfile
   ├─ docker push ghcr.io/you/infra-nginx:latest
   └─ docker push ghcr.io/you/infra-nginx:<commit-sha>

3. Deploy to Mac Mini (GitHub Actions orchestrates via SSH)
   ├─ SSH to Mac Mini
   ├─ Run on Mac Mini: docker login ghcr.io
   ├─ Run on Mac Mini: docker compose pull
   ├─ Run on Mac Mini: docker compose up -d --force-recreate
   └─ Monitor health checks via SSH

4. Rollback if Failed
   ├─ Health check failed?
   ├─ Restore previous image tag
   └─ Restart old container
```

---

## Manual Deployment (Without CI/CD)

If you want to deploy manually from Mac Mini:

```bash
cd ~/prod/infrastructure

# Deploy everything
./scripts/deploy-ghcr.sh

# Or deploy specific services
cd nginx && docker compose pull && docker compose up -d
cd monitoring && docker compose pull && docker compose up -d
```

**No builds happen!** Just pulls and runs.

---

## Updating Infrastructure

### Scenario 1: Change Nginx Config

```bash
# Edit config locally
nano nginx/sites/eduhub.conf

# Commit and push
git add nginx/
git commit -m "feat: update nginx proxy settings"
git push origin main

# CI/CD automatically:
# 1. Builds new nginx image with updated config
# 2. Pushes to GHCR
# 3. Deploys to Mac Mini
# 4. ~10 seconds downtime (nginx reload)
```

### Scenario 2: Add Grafana Dashboard

```bash
# Add dashboard
cp my-dashboard.json monitoring/grafana/dashboards/json/

# Commit and push
git add monitoring/grafana/
git commit -m "feat: add application dashboard"
git push origin main

# CI/CD automatically:
# 1. Builds new grafana image with dashboard
# 2. Deploys to Mac Mini
# 3. Dashboard available immediately
```

### Scenario 3: Update Database Password

```bash
# SSH to Mac Mini
ssh user@mac-mini

cd ~/prod/infrastructure/databases
nano .env  # Change POSTGRES_PASSWORD

# Redeploy databases
docker compose up -d --force-recreate

# No CI/CD needed (env vars not in images)
```

---

## Rollback

### Automatic Rollback (Built-in)

If health checks fail, CI/CD automatically rolls back:

```bash
# Deployment fails
→ GitHub Actions detects unhealthy container
→ Restores previous image tag
→ Restarts old container
→ Alerts you of failure
```

### Manual Rollback

```bash
# SSH to Mac Mini
cd ~/prod/infrastructure

# Check available image tags
docker images ghcr.io/tammynkuna/infra-nginx

# Rollback nginx to specific version
cd nginx
docker compose pull ghcr.io/tammynkuna/infra-nginx:<commit-sha>
docker compose up -d --force-recreate nginx
```

---

## Troubleshooting

### Problem: Can't pull images from GHCR

```bash
# Check if logged in
docker info | grep ghcr.io

# Login again
echo $GHCR_TOKEN | docker login ghcr.io -u your-username --password-stdin

# Or make packages public (easier)
# GitHub → Profile → Packages → infra-* → Settings → Change visibility → Public
```

### Problem: Image not found

```bash
# Check if image exists in GHCR
# Go to: https://github.com/your-username?tab=packages

# If not, trigger CI/CD build:
git commit --allow-empty -m "trigger: rebuild images"
git push origin main

# Wait for GitHub Actions to complete
```

### Problem: Mac Mini out of disk space

```bash
# Remove old images
docker system prune -a -f

# Remove unused volumes
docker volume prune -f

# Check disk usage
df -h
docker system df
```

### Problem: Service won't start after deployment

```bash
# Check logs
docker logs infra_<service>

# Check if image pulled correctly
docker images | grep infra-

# Redeploy specific service
cd <service-dir>
docker compose pull
docker compose up -d --force-recreate
```

---

## Resource Usage Comparison

### Before (Git Clone + Local Builds)
```
Mac Mini RAM during deployment: ~1.5-2GB
Mac Mini CPU: ~60% for 5-15 minutes
Deployment time: 5-15 minutes
Disk I/O: High (builds)
```

### After (GHCR)
```
Mac Mini RAM during deployment: ~200-300MB
Mac Mini CPU: ~10% for 10-30 seconds
Deployment time: 30-60 seconds
Disk I/O: Low (pulls only)
```

**Result: ~1.5GB RAM saved on your 8GB Mac Mini!** 🎉

---

## Security Best Practices

### ✅ DO
- Use Tailscale for secure SSH connections
- Create READ-ONLY GHCR token for Mac Mini
- Make packages public if configs aren't secret
- Use strong passwords in .env files
- Store .env files only on Mac Mini (not in git)
- Rotate SSH keys periodically

### ❌ DON'T
- Don't commit .env files to git
- Don't use write-access GHCR token on Mac Mini
- Don't expose SSH port 22 to internet (use Tailscale)
- Don't store passwords in GitHub secrets (use .env on server)

---

## Monitoring Deployments

### GitHub Actions UI

1. Go to repository → **Actions** tab
2. See all deployment runs
3. Click run → See which services deployed
4. Check logs for any issues

### Mac Mini

```bash
# Check running containers
docker ps --filter "name=infra_"

# Check recent deployments (via image tags)
docker images | grep infra-

# Check resource usage
docker stats

# View logs
docker logs infra_nginx
docker logs -f infra_grafana  # Follow logs
```

---

## Cost Analysis

| Resource | Cost |
|----------|------|
| **GitHub Actions** | FREE (2,000 min/month for private repos, unlimited for public) |
| **GHCR Storage** | FREE (public packages) |
| **GHCR Bandwidth** | FREE (unlimited pulls) |
| **Mac Mini Resources Saved** | 1.5GB RAM + CPU time = PRICELESS! |

**Total: $0/month** 🎉

---

## Comparison with EduHub

Your infrastructure now uses **the same deployment pattern** as EduHub:

| Aspect | EduHub | Infrastructure | Match? |
|--------|--------|----------------|--------|
| Build Location | GitHub Actions | GitHub Actions | ✅ |
| Image Registry | GHCR | GHCR | ✅ |
| Change Detection | Path filters | Path filters | ✅ |
| Deployment | SSH + Tailscale | SSH + Tailscale | ✅ |
| Health Checks | Built-in | Built-in | ✅ |
| Rollback | Automatic | Automatic | ✅ |
| Mac Mini Builds | NO | NO | ✅ |

**Consistent approach across all projects!** ✅

---

## Next Steps

1. ✅ Push code to trigger first CI/CD build
2. ✅ Watch GitHub Actions build images
3. ✅ Verify images appear in GHCR
4. ✅ SSH to Mac Mini and deploy
5. ✅ Check Grafana dashboards
6. ✅ Test making a config change
7. ✅ Watch automatic deployment

---

## Quick Reference

```bash
# Deploy all services (Mac Mini)
./scripts/deploy-ghcr.sh

# Deploy specific service
cd <service> && docker compose pull && docker compose up -d

# Check status
docker ps --filter "name=infra_"

# View logs
docker logs -f infra_<service>

# Check resource usage
docker stats --no-stream

# Login to GHCR (if needed)
echo $GHCR_TOKEN | docker login ghcr.io -u <username> --password-stdin

# Cleanup
docker system prune -f
```

---

## Summary

✅ **No more git clone on Mac Mini**
✅ **No more local Docker builds**
✅ **1.5GB RAM saved**
✅ **Faster deployments**
✅ **Consistent with EduHub**
✅ **Automatic CI/CD**
✅ **Secure (read-only tokens)**
✅ **Free to use**

**Your infrastructure is now production-ready with GHCR!** 🚀
