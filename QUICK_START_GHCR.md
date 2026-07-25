# GHCR Quick Start Card

**Fast reference for GHCR deployment**

---

## 🚀 New Deployment (First Time)

### 1. Configure GitHub Secrets (5 min)

GitHub → Repo → Settings → Secrets and variables → Actions

```yaml
SSH_HOST: your-mac-mini-ip
SSH_USER: your-username
SSH_PRIVATE_KEY: <paste SSH private key>
SSH_PORT: 22
TS_AUTH_KEY: <Tailscale auth key>
GHCR_TOKEN: <GitHub PAT with read:packages, write:packages>
```

### 2. Push Code to Trigger Build (1 min)

```bash
git add .
git commit -m "feat: enable GHCR deployment"
git push origin main
```

Watch build: GitHub → Actions → Wait for ✅

### 3. Deploy on Mac Mini (3 min)

```bash
ssh user@mac-mini
cd ~/prod/infrastructure

# Set your GitHub username
export GITHUB_REPOSITORY_OWNER=your-github-username
echo 'export GITHUB_REPOSITORY_OWNER=your-github-username' >> ~/.bashrc

# Deploy (pulls images, no builds!)
./scripts/deploy-ghcr.sh
```

**Done!** ✅

---

## 🔄 Daily Usage

### Push Changes (Auto-Deploy)

```bash
# Edit files locally
nano nginx/sites/eduhub.conf

# Commit and push
git add .
git commit -m "feat: update nginx config"
git push origin main

# GitHub Actions automatically:
# 1. Builds new image
# 2. Pushes to GHCR
# 3. Deploys to Mac Mini
# 4. Health checks
# 5. Done! ✅
```

### Manual Deploy (Mac Mini)

```bash
ssh user@mac-mini
cd ~/prod/infrastructure

# Deploy all
./scripts/deploy-ghcr.sh

# Or deploy specific service
cd nginx
docker compose pull
docker compose up -d
```

---

## 📊 Check Status

```bash
# All containers
docker ps --filter "name=infra_"

# Specific service logs
docker logs -f infra_nginx
docker logs -f infra_grafana

# Resource usage
docker stats --no-stream

# Health checks
curl http://localhost:3000/api/health  # Grafana
curl http://localhost:9090/-/healthy   # Prometheus
```

---

## 🔧 Common Tasks

### Update Service Config

```bash
# 1. Edit config locally
nano monitoring/prometheus/prometheus.yml

# 2. Push (triggers rebuild)
git add monitoring/
git commit -m "feat: add new scrape target"
git push origin main

# 3. Auto-deploys via CI/CD
# OR manually on Mac Mini:
ssh user@mac-mini
cd ~/prod/infrastructure/monitoring
docker compose pull prometheus
docker compose up -d --force-recreate prometheus
```

### Rollback

```bash
# Check available images
docker images | grep infra-nginx

# Rollback to specific version
docker pull ghcr.io/you/infra-nginx:<commit-sha>
docker compose up -d --force-recreate nginx
```

### View Images

```bash
# Locally cached
docker images | grep infra-

# On GHCR
# Visit: https://github.com/your-username?tab=packages
```

---

## 🆘 Troubleshooting

### Can't Pull Images

```bash
# Solution 1: Make packages public
# GitHub → Profile → Packages → infra-* → Settings → Public

# Solution 2: Login to GHCR
echo $GHCR_TOKEN | docker login ghcr.io -u your-username --password-stdin
```

### Container Won't Start

```bash
# Check logs
docker logs infra_<service>

# Check if image exists
docker images | grep infra-

# Rebuild on GitHub
git commit --allow-empty -m "rebuild: trigger image rebuild"
git push origin main
```

### Out of Disk Space

```bash
# Cleanup
docker system prune -a -f
docker volume prune -f

# Check usage
docker system df
df -h
```

---

## 📚 Documentation

- **Full Guide:** [GHCR_DEPLOYMENT_GUIDE.md](GHCR_DEPLOYMENT_GUIDE.md)
- **Migration:** [MIGRATION_TO_GHCR.md](MIGRATION_TO_GHCR.md)
- **Comparison:** [DEPLOYMENT_COMPARISON.md](DEPLOYMENT_COMPARISON.md)

---

## 🎯 Key Points

✅ **No builds on Mac Mini** - Images pre-built on GitHub
✅ **Saves 1.5GB RAM** - Only pulls, no builds
✅ **30-60 sec deploys** - vs 5-15 min before
✅ **Auto CI/CD** - Push to deploy
✅ **Same as EduHub** - Consistent approach

---

## 🔑 Image URLs

```bash
# Your custom images:
ghcr.io/${GITHUB_REPOSITORY_OWNER}/infra-nginx:latest
ghcr.io/${GITHUB_REPOSITORY_OWNER}/infra-grafana:latest
ghcr.io/${GITHUB_REPOSITORY_OWNER}/infra-prometheus:latest
ghcr.io/${GITHUB_REPOSITORY_OWNER}/infra-loki:latest
ghcr.io/${GITHUB_REPOSITORY_OWNER}/infra-promtail:latest
ghcr.io/${GITHUB_REPOSITORY_OWNER}/infra-alertmanager:latest

# Official images (used as-is):
postgres:16
redis:7-alpine
prom/node-exporter:latest
gcr.io/cadvisor/cadvisor:latest
```

---

## ⚡ One-Liner Commands

```bash
# Check all infrastructure services
docker ps --filter "name=infra_" --format "table {{.Names}}\t{{.Status}}"

# Deploy everything
./scripts/deploy-ghcr.sh

# View logs for all services
docker compose logs -f

# Restart all services
docker compose restart

# Pull latest images
docker compose pull

# Cleanup old images
docker system prune -f

# Check resource usage
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

---

**Keep this card handy for daily operations!** 📌
