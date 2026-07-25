# Migration Guide: Git Clone → GHCR Deployment

**Migrate from git-based deployment to GHCR (same as EduHub)**

---

## Why Migrate?

| Before (Git Clone) | After (GHCR) |
|-------------------|--------------|
| ❌ Requires GitHub auth on server | ✅ No GitHub auth needed |
| ❌ Mac Mini builds images (~1.5GB RAM) | ✅ Mac Mini pulls images (~200MB RAM) |
| ❌ 5-15 min deployments | ✅ 30-60 sec deployments |
| ❌ Security risk (GitHub token stored) | ✅ Read-only GHCR token |
| ❌ Manual deployments | ✅ Automatic CI/CD |

---

## Migration Steps

### Step 1: Configure GitHub Secrets (5 minutes)

Go to your repo → **Settings → Secrets and variables → Actions**

Add/verify these secrets:

```bash
SSH_HOST=your-mac-mini-ip
SSH_USER=your-username
SSH_PRIVATE_KEY=<paste private key>
SSH_PORT=22
TS_AUTH_KEY=<tailscale key>
GHCR_TOKEN=<personal access token with read:packages>
```

**To create GHCR_TOKEN:**
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token
3. Select scopes: `read:packages`, `write:packages`
4. Copy token and add to GitHub secrets

---

### Step 2: Make Packages Public (Optional but Recommended)

This allows Mac Mini to pull images without authentication:

1. Push code to trigger first build (Step 4)
2. Wait for GitHub Actions to complete
3. Go to your GitHub profile → **Packages** tab
4. For each `infra-*` package:
   - Click package → **Package settings**
   - Scroll down → **Change visibility**
   - Set to **Public**

**Packages to make public:**
- `infra-nginx`
- `infra-prometheus`
- `infra-grafana`
- `infra-loki`
- `infra-promtail`
- `infra-alertmanager`

---

### Step 3: Update Mac Mini Environment (2 minutes)

```bash
# SSH to Mac Mini
ssh user@your-mac-mini

# Set GitHub username for GHCR image paths
echo 'export GITHUB_REPOSITORY_OWNER=your-github-username' >> ~/.bashrc
source ~/.bashrc

# Verify
echo $GITHUB_REPOSITORY_OWNER
# Should output: your-github-username
```

---

### Step 4: Trigger First Build (1 minute)

```bash
# On your local machine:
cd macmini-infrastructure

# Add all new files
git add .

# Commit
git commit -m "feat: migrate to GHCR deployment"

# Push to trigger CI/CD
git push origin main
```

**Watch the build:**
1. Go to GitHub → **Actions** tab
2. See "Build and Deploy Infrastructure (GHCR)" running
3. Click to watch live logs
4. Wait for all jobs to complete (~5-10 minutes first time)

**Expected output:**
```
✅ changes
✅ build-nginx
✅ build-grafana
✅ build-prometheus
✅ build-loki
✅ build-promtail
✅ build-alertmanager
✅ deploy
```

---

### Step 5: Deploy on Mac Mini (5 minutes)

```bash
# SSH to Mac Mini
ssh user@your-mac-mini

cd ~/prod/infrastructure

# Pull latest code (last time using git!)
git pull origin main

# If packages are PRIVATE, login to GHCR:
echo $GHCR_TOKEN | docker login ghcr.io -u your-github-username --password-stdin

# If packages are PUBLIC, skip login!

# Deploy infrastructure (pulls ready images, no builds!)
./scripts/deploy-ghcr.sh
```

**Select option 1** (All services) when prompted.

**Expected output:**
```
📦 Deploying Nginx...
  ⬇️  Pulling images...
  🚀 Starting services...
  ✓ nginx is healthy

📦 Deploying Databases...
  ⬇️  Pulling images...
  🚀 Starting services...
  ✓ postgres is healthy
  ✓ redis is healthy

📦 Deploying Monitoring Stack...
  ⬇️  Pulling images...
  🚀 Starting services...
  ✓ prometheus is healthy
  ✓ grafana is healthy
  ✓ loki is healthy
  ✓ promtail is running
  ✓ alertmanager is healthy

✅ DEPLOYMENT COMPLETE! 🎉
```

---

### Step 6: Verify Everything Works (3 minutes)

```bash
# Check all containers running
docker ps --filter "name=infra_"

# Should see:
# infra_nginx
# infra_postgres
# infra_redis
# infra_prometheus
# infra_grafana
# infra_loki
# infra_promtail
# infra_alertmanager
# infra_node_exporter
# infra_cadvisor

# Check Grafana
curl http://localhost:3000/api/health
# Should return: {"database":"ok"}

# Check Prometheus
curl http://localhost:9090/-/healthy
# Should return: Prometheus is Healthy.

# Check resource usage
docker stats --no-stream
```

**Access services:**
- Grafana: http://your-mac-mini-ip:3000
- Prometheus: http://your-mac-mini-ip:9090

---

### Step 7: Test Automatic Deployment (5 minutes)

Let's verify CI/CD works:

```bash
# On your local machine:
cd macmini-infrastructure

# Make a small change
echo "# GHCR Deployment Active" >> README.md

# Commit and push
git add README.md
git commit -m "test: verify CI/CD deployment"
git push origin main
```

**Watch it deploy automatically:**
1. GitHub Actions detects push
2. Builds images (if any changed)
3. SSH to Mac Mini
4. Pulls new images
5. Deploys containers
6. Health checks
7. ✅ Done!

**Check on Mac Mini:**
```bash
# Should see updated containers
docker ps --filter "name=infra_"

# Check deployment logs
docker logs infra_nginx --tail 20
```

---

## What Changed?

### File Changes

```diff
# New files added:
+ .github/workflows/deploy-infrastructure-ghcr.yml  # CI/CD workflow
+ nginx/Dockerfile                                  # Custom nginx image
+ monitoring/grafana/Dockerfile                     # Custom Grafana
+ monitoring/prometheus/Dockerfile                  # Custom Prometheus
+ monitoring/loki/Dockerfile                        # Custom Loki
+ monitoring/promtail/Dockerfile                    # Custom Promtail
+ monitoring/alertmanager/Dockerfile                # Custom Alertmanager
+ scripts/deploy-ghcr.sh                            # Deployment script
+ GHCR_DEPLOYMENT_GUIDE.md                          # Full guide
+ MIGRATION_TO_GHCR.md                              # This file
+ DEPLOYMENT_COMPARISON.md                          # Comparison doc

# Modified files:
~ nginx/docker-compose.yml                          # Now uses GHCR image
~ monitoring/docker-compose.yml                     # Now uses GHCR images
```

### Workflow Changes

**Old:**
```bash
git push → Mac Mini: git pull → docker compose build → deploy
```

**New:**
```bash
git push → GitHub Actions: build images → push to GHCR → Mac Mini: pull → deploy
```

### No Longer Needed

These old approaches are **deprecated** (don't use):

❌ `.github/workflows/deploy-infrastructure.yml` (old git clone workflow)
❌ Manual `git clone` on Mac Mini
❌ GitHub token stored on Mac Mini
❌ Local Docker builds

---

## Rollback Plan (If Something Goes Wrong)

If you need to rollback to the old approach:

```bash
# On Mac Mini:
cd ~/prod/infrastructure

# Revert to old docker-compose files
git checkout HEAD~1 nginx/docker-compose.yml
git checkout HEAD~1 monitoring/docker-compose.yml

# Redeploy using old method
cd nginx && docker compose up -d --build
cd ../monitoring && docker compose up -d --build
```

**But you won't need this!** GHCR is more reliable.

---

## Troubleshooting

### Problem: GitHub Actions fails to build images

**Solution:**
```bash
# Check workflow file syntax
cat .github/workflows/deploy-infrastructure-ghcr.yml

# Ensure all Dockerfiles exist
ls -la nginx/Dockerfile
ls -la monitoring/*/Dockerfile

# Check GitHub Actions logs for specific error
# GitHub → Actions → Failed run → Click job → Read error
```

### Problem: Mac Mini can't pull images

**Solution:**
```bash
# Option 1: Make packages public (easiest)
# GitHub → Profile → Packages → infra-* → Settings → Public

# Option 2: Login to GHCR
echo $GHCR_TOKEN | docker login ghcr.io -u your-username --password-stdin

# Verify login worked
docker pull ghcr.io/your-username/infra-nginx:latest
```

### Problem: Containers won't start

**Solution:**
```bash
# Check logs
docker logs infra_<service>

# Check if image pulled correctly
docker images | grep infra-

# Try rebuilding on GitHub
git commit --allow-empty -m "rebuild: trigger image rebuild"
git push origin main

# Wait for build to complete, then redeploy
./scripts/deploy-ghcr.sh
```

---

## Post-Migration Checklist

- [ ] All containers running: `docker ps --filter "name=infra_"`
- [ ] Grafana accessible: http://mac-mini-ip:3000
- [ ] Prometheus accessible: http://mac-mini-ip:9090
- [ ] No builds happening on Mac Mini (check RAM usage)
- [ ] CI/CD deploys automatically on push
- [ ] GHCR packages visible in GitHub profile
- [ ] Old git clone workflow disabled
- [ ] Documentation updated

---

## Benefits Achieved

After migration, you now have:

✅ **1.5GB RAM saved** on Mac Mini (no more builds!)
✅ **30-60 second deployments** (vs 5-15 minutes)
✅ **Automatic CI/CD** (push to deploy)
✅ **Secure** (no GitHub credentials on server)
✅ **Consistent** (same approach as EduHub)
✅ **Rollback-friendly** (tag-based versions)
✅ **Free** ($0 cost for public packages)

---

## Next Steps

1. ✅ Monitor first few deployments
2. ✅ Make packages public (if configs aren't secret)
3. ✅ Remove old git-based workflow file
4. ✅ Update team documentation
5. ✅ Test rollback procedure
6. ✅ Set up deployment notifications (Slack/email)

---

## Support

If you encounter issues:

1. Check [GHCR_DEPLOYMENT_GUIDE.md](GHCR_DEPLOYMENT_GUIDE.md)
2. Review GitHub Actions logs
3. Check Mac Mini logs: `docker logs infra_<service>`
4. Compare with EduHub deployment (same pattern)

**Migration complete! Your infrastructure is now GHCR-powered.** 🚀
