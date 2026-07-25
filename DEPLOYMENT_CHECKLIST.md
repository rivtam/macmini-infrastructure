# GHCR Deployment Checklist

**Follow this checklist to deploy infrastructure using GHCR**

---

## Pre-Deployment Status

Current repository: `________________________`
Mac Mini IP: `________________________`
GitHub username: `________________________`

---

## Step 1: Configure GitHub Secrets ⏱️ 5 minutes

Go to: `GitHub Repo → Settings → Secrets and variables → Actions → New repository secret`

### Secrets to Add:

| Secret Name | Value | Status |
|-------------|-------|--------|
| SSH_HOST | Your Mac Mini IP (Tailscale or local) | [ ] |
| SSH_USER | Your Mac Mini username | [ ] |
| SSH_PRIVATE_KEY | SSH private key (see below) | [ ] |
| SSH_PORT | 22 (or custom port) | [ ] |
| TS_AUTH_KEY | Tailscale auth key (optional) | [ ] |
| GHCR_TOKEN | GitHub Personal Access Token | [ ] |

**Generate SSH key on Mac Mini:**
```bash
ssh-keygen -t ed25519 -C "github-actions-infra" -f ~/.ssh/github_actions_infra
cat ~/.ssh/github_actions_infra.pub >> ~/.ssh/authorized_keys
cat ~/.ssh/github_actions_infra  # Copy this to SSH_PRIVATE_KEY secret
```

**Generate GHCR_TOKEN:**
- GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
- Generate new token
- Scopes: ✅ read:packages, ✅ write:packages
- Copy token to GHCR_TOKEN secret

---

## Step 2: Push Code to GitHub ⏱️ 2 minutes

```bash
cd /path/to/macmini-infrastructure
git add .
git commit -m "feat: migrate to GHCR deployment"
git push origin main
```

**Status:** [ ]

---

## Step 3: Monitor First Build ⏱️ 10 minutes

1. GitHub → Actions → Watch "Build and Deploy Infrastructure (GHCR)"
2. Expected jobs: changes, build-*, deploy
3. Deploy will likely fail (Mac Mini not ready yet) - that's OK!

**Build completed:** [ ]

---

## Step 4: Make Packages Public ⏱️ 2 minutes (Optional)

GitHub → Profile → Packages → For each infra-* package:
- Package settings → Change visibility → Public

**Packages:** [ ] infra-nginx [ ] infra-grafana [ ] infra-prometheus [ ] infra-loki [ ] infra-promtail [ ] infra-alertmanager

---

## Step 5: Configure Mac Mini ⏱️ 5 minutes

```bash
ssh YOUR_USERNAME@YOUR_MAC_MINI_IP
mkdir -p ~/prod/infrastructure
cd ~/prod/infrastructure

# Clone repo (last time!)
git clone https://github.com/YOUR_USERNAME/macmini-infrastructure.git .

# Set environment variable
export GITHUB_REPOSITORY_OWNER=your-github-username
echo 'export GITHUB_REPOSITORY_OWNER=your-github-username' >> ~/.bashrc

# Create Docker network
docker network create infra_network
```

**Status:** [ ]

---

## Step 6: Configure Environment Files ⏱️ 5 minutes

```bash
cd ~/prod/infrastructure/databases
POSTGRES_PASS=$(openssl rand -base64 32)
REDIS_PASS=$(openssl rand -base64 32)

cat > .env << EOF
POSTGRES_PASSWORD=$POSTGRES_PASS
POSTGRES_USER=postgres
POSTGRES_PORT=5432
POSTGRES_HOST_BINDING=127.0.0.1

REDIS_PASSWORD=$REDIS_PASS
REDIS_PORT=6379
REDIS_HOST_BINDING=127.0.0.1

PGBOUNCER_PORT=6432
EOF

echo "Save these passwords!"
echo "PostgreSQL: $POSTGRES_PASS"
echo "Redis: $REDIS_PASS"

cd ../monitoring
GRAFANA_PASS=$(openssl rand -base64 24)

cat > .env << EOF
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASS
GRAFANA_ROOT_URL=http://localhost:3000
PROMETHEUS_PORT=9090
EOF

echo "Grafana password: $GRAFANA_PASS"
```

**Passwords saved:** [ ]

---

## Step 7: Deploy Infrastructure ⏱️ 3 minutes

```bash
cd ~/prod/infrastructure

# Login to GHCR (skip if packages are public)
echo $GHCR_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Deploy
chmod +x scripts/deploy-ghcr.sh
./scripts/deploy-ghcr.sh
# Select option 1 (All services)
```

**Deployment successful:** [ ]

---

## Step 8: Verify Services ⏱️ 3 minutes

```bash
# Check containers
docker ps --filter "name=infra_"

# Test health
docker exec infra_postgres pg_isready -U postgres
curl http://localhost:3000/api/health
curl http://localhost:9090/-/healthy
```

**All services healthy:** [ ]

---

## Step 9: Test Automatic Deployment ⏱️ 5 minutes

```bash
# On local machine
cd macmini-infrastructure
echo "# Test" >> README.md
git add README.md
git commit -m "test: verify CI/CD"
git push origin main

# Watch GitHub Actions → Should deploy automatically
```

**CI/CD works:** [ ]

---

## ✅ Deployment Complete!

**Completion date:** `_________________`

**Access URLs:**
- Grafana: http://YOUR_MAC_MINI_IP:3000
- Prometheus: http://YOUR_MAC_MINI_IP:9090

**Next steps:**
- [ ] Configure nginx sites
- [ ] Set up SSL certificates
- [ ] Configure backups
- [ ] Test rollback procedure

