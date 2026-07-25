# CI/CD Setup Guide

**Automated deployments to your Mac Mini on every git push**

## Overview

The infrastructure includes GitHub Actions workflows that automatically deploy changes when you push to the `main` branch.

**How it works:**
1. You push code to GitHub (main branch)
2. GitHub Actions detects which services changed
3. Connects to your Mac Mini via SSH
4. Pulls latest code
5. Redeploys only changed services
6. Runs health checks
7. Auto-rollback if anything fails

---

## Prerequisites

- [ ] GitHub repository for this infrastructure
- [ ] Mac Mini server deployed and running
- [ ] SSH access to Mac Mini
- [ ] GitHub account with repository access

---

## Setup Steps

### Step 1: Generate SSH Key for GitHub Actions

**On your Mac Mini server:**

```bash
# Generate dedicated SSH key for CI/CD
ssh-keygen -t ed25519 -C "github-actions-ci" -f ~/.ssh/github_actions_key

# This creates:
# - Private key: ~/.ssh/github_actions_key
# - Public key: ~/.ssh/github_actions_key.pub

# Add public key to authorized_keys
cat ~/.ssh/github_actions_key.pub >> ~/.ssh/authorized_keys

# Set proper permissions
chmod 600 ~/.ssh/github_actions_key
chmod 644 ~/.ssh/github_actions_key.pub
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

**Copy the PRIVATE key (you'll need this for GitHub):**
```bash
cat ~/.ssh/github_actions_key
```

**IMPORTANT:** Copy the entire output (including `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----`)

---

### Step 2: Configure GitHub Secrets

Go to your GitHub repository:

**Settings → Secrets and variables → Actions → New repository secret**

Add these secrets:

#### 1. SSH_PRIVATE_KEY
```
Paste the private key from Step 1
```

#### 2. SSH_HOST
```
your-mac-mini-ip-address
# or if using Tailscale: 100.x.x.x
# or if using domain: server.yourdomain.com
```

#### 3. SSH_USER
```
your-server-username
# Example: tammynkuna
```

#### 4. SSH_PORT (optional)
```
22
# Or your custom SSH port if you changed it
```

#### 5. TS_AUTH_KEY (optional - for Tailscale)

**Only needed if using Tailscale for secure connections**

Generate at: https://login.tailscale.com/admin/settings/keys

```
tskey-auth-xxxxxxxxxxxxx
```

---

### Step 3: Test SSH Connection from GitHub

**Create a test workflow:**

Create `.github/workflows/test-connection.yml`:

```yaml
name: Test SSH Connection
on: workflow_dispatch

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          port: ${{ secrets.SSH_PORT || 22 }}
          script: |
            echo "✅ SSH connection successful!"
            echo "Server: $(hostname)"
            echo "User: $(whoami)"
            echo "Path: $(pwd)"
            docker ps --format 'table {{.Names}}\t{{.Status}}'
```

**Run the test:**
1. Go to GitHub → Actions tab
2. Select "Test SSH Connection"
3. Click "Run workflow"
4. Watch the output

**Expected result:** ✅ Connection successful, shows running containers

---

### Step 4: Configure Repository Clone Path

**On your Mac Mini, ensure the infrastructure is in the correct location:**

The CI/CD expects the repo at: `~/prod/infrastructure`

```bash
# If you cloned it elsewhere, move it:
mkdir -p ~/prod
mv ~/infrastructure ~/prod/infrastructure

# Or create a symlink:
ln -s ~/infrastructure ~/prod/infrastructure
```

**Update the workflow if needed:**

Edit `.github/workflows/deploy-infrastructure.yml` line 58:
```yaml
INFRA_DIR="${HOME}/prod/infrastructure"
# Change to your preferred path
```

---

### Step 5: Ensure Environment Files Persist

**IMPORTANT:** `.env` files are gitignored (for security), but CI/CD needs them.

**Option A: Manual (Secure)**

After initial deployment, `.env` files stay on the server.
The workflow will NOT overwrite them.

**Option B: Use GitHub Secrets for Environment Variables**

Store environment variables as GitHub secrets, then create `.env` files during deployment.

Edit `.github/workflows/deploy-infrastructure.yml`:

```yaml
# Add after "Pull latest changes"
- name: Create environment files from secrets
  run: |
    cat > databases/.env << EOF
    POSTGRES_PASSWORD=${{ secrets.POSTGRES_PASSWORD }}
    REDIS_PASSWORD=${{ secrets.REDIS_PASSWORD }}
    # ... other vars
    EOF
```

**Recommendation:** Use Option A for production (more secure)

---

### Step 6: Enable Auto-Deployment

**Push to main branch triggers deployment automatically**

```bash
# Make a change
echo "# Test change" >> README.md

# Commit and push
git add .
git commit -m "test: trigger CI/CD deployment"
git push origin main
```

**Watch it deploy:**
1. Go to GitHub → Actions tab
2. You'll see "Deploy Infrastructure" workflow running
3. Click to see real-time logs

**What happens:**
1. ✅ Detects which services changed (nginx/databases/monitoring)
2. ✅ Creates backup tag for rollback
3. ✅ Pulls latest code
4. ✅ Redeploys changed services
5. ✅ Runs health checks
6. ✅ Auto-rollbacks if anything fails

---

## Understanding the Workflow

### Change Detection

Only deploys what changed:

```yaml
# Example: If you edit nginx/sites/eduhub.conf
# → Only nginx service restarts
# → Databases and monitoring stay running
```

**Paths monitored:**
- `nginx/**` → Redeploys nginx
- `databases/**` → Redeploys PostgreSQL, Redis, PgBouncer
- `monitoring/**` → Redeploys Prometheus, Grafana, Loki, etc.
- `vault/**` → Redeploys Vault
- `certbot/**` → Redeploys Certbot
- `audit/**` → Redeploys Audit logging

### Rollback Protection

**Automatic rollback if:**
- Docker compose fails
- Health checks fail
- Service won't start

**Manual rollback:**
```bash
# On server
./scripts/manual-rollback.sh --list
./scripts/manual-rollback.sh pre-deploy-20240119-143000
```

### Deployment Workflow

```
┌─────────────────────────────────────┐
│  1. Git Push to main                │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  2. GitHub Actions Triggered        │
│     • Detect changed paths          │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  3. Connect to Mac Mini (SSH)       │
│     • Via direct SSH                │
│     • Or via Tailscale (secure)     │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  4. Create Backup Tag               │
│     • Tag: pre-deploy-YYYYMMDD      │
│     • For rollback if needed        │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  5. Pull Latest Code                │
│     • git fetch origin main         │
│     • git reset --hard origin/main  │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  6. Deploy Changed Services         │
│     • docker compose pull           │
│     • docker compose up -d          │
│     • Only changed services         │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  7. Health Check                    │
│     • Test database connections     │
│     • Check service status          │
│     • Verify nginx config           │
└─────────────────────────────────────┘
              ↓
      ┌───────────────┐
      │  Success?     │
      └───────────────┘
         │        │
     Yes │        │ No
         ↓        ↓
    ┌───────┐  ┌──────────┐
    │ Done! │  │ Rollback │
    └───────┘  └──────────┘
                    ↓
              Restore backup tag
              Restart old version
```

---

## Security Considerations

### SSH Key Security

**DO:**
- ✅ Use dedicated SSH key for CI/CD
- ✅ Store private key ONLY in GitHub secrets
- ✅ Use ed25519 keys (more secure)
- ✅ Rotate keys periodically

**DON'T:**
- ❌ Don't share private key anywhere else
- ❌ Don't commit private key to git
- ❌ Don't use your personal SSH key

### Network Security

**Option 1: Direct SSH (Simple)**
```yaml
# Requires:
# - Public IP or port forwarding
# - Firewall rule for GitHub IPs
# - Strong SSH key
```

**Option 2: Tailscale (Recommended for Production)**
```yaml
# Requires:
# - Tailscale account
# - Tailscale installed on Mac Mini
# - TS_AUTH_KEY in GitHub secrets

# Benefits:
# - No open ports
# - Encrypted tunnel
# - No public exposure
```

### Environment Variables

**Never commit:**
- ❌ `.env` files with passwords
- ❌ SSH private keys
- ❌ API tokens
- ❌ Vault unseal keys

**Always use:**
- ✅ GitHub Secrets for sensitive data
- ✅ `.env.example` files (templates only)
- ✅ `.gitignore` for `.env`

---

## Deployment Scenarios

### Scenario 1: Update Nginx Configuration

```bash
# Edit nginx config
nano nginx/sites/eduhub.conf

# Commit and push
git add nginx/sites/eduhub.conf
git commit -m "feat: update nginx proxy settings"
git push origin main

# GitHub Actions will:
# 1. Detect nginx changed
# 2. Deploy only nginx
# 3. Test nginx config
# 4. Reload nginx
# 5. Health check
```

**Downtime:** ~5 seconds (graceful reload)

### Scenario 2: Update Database Configuration

```bash
# Edit PostgreSQL config
nano databases/postgres/init/01-create-databases.sql

# Commit and push
git add databases/
git commit -m "feat: add new database"
git push origin main

# GitHub Actions will:
# 1. Detect database changed
# 2. Pull new images
# 3. Restart database services
# 4. Wait for readiness
# 5. Health check
```

**Downtime:** ~15 seconds (database restart)

### Scenario 3: Update Monitoring Dashboards

```bash
# Add new Grafana dashboard
cp my-dashboard.json monitoring/grafana/dashboards/json/

# Commit and push
git add monitoring/
git commit -m "feat: add application dashboard"
git push origin main

# GitHub Actions will:
# 1. Detect monitoring changed
# 2. Restart Grafana
# 3. Load new dashboard
# 4. Health check
```

**Downtime:** 0 (dashboard hot-reload)

---

## Monitoring Deployments

### GitHub Actions UI

**View deployments:**
1. Go to GitHub repository
2. Click "Actions" tab
3. See all deployment runs

**Check specific deployment:**
1. Click on deployment run
2. See detailed logs
3. Check which services deployed
4. View health check results

### On Server

**Check deployment tags:**
```bash
git tag -l "pre-deploy-*"
# Shows all deployment backups
```

**View current version:**
```bash
git log -1 --oneline
```

**Check service status:**
```bash
./scripts/service-status.sh
```

---

## Troubleshooting

### Deployment Fails

**Check GitHub Actions logs:**
1. GitHub → Actions → Failed deployment
2. Expand failed step
3. Read error message

**Common issues:**

#### SSH Connection Failed
```
Fix:
1. Check SSH_HOST is correct
2. Verify SSH_PRIVATE_KEY matches public key on server
3. Check firewall allows GitHub IPs
4. Test: ssh -i ~/.ssh/github_actions_key user@host
```

#### Health Check Failed
```
Fix:
1. Check which service failed in logs
2. SSH to server: ssh user@host
3. Check service: docker logs infra_<service>
4. Fix issue and push again
```

#### Rollback Triggered
```
No action needed - automatic rollback restored previous version.
Check logs to see why deployment failed.
```

### Manual Intervention Needed

**If automatic deployment fails completely:**

```bash
# SSH to server
ssh user@your-server

cd ~/prod/infrastructure

# Check what's running
docker ps

# View recent deployments
git tag -l "pre-deploy-*"

# Manually rollback
./scripts/manual-rollback.sh pre-deploy-20240119-120000

# Or manually restart services
cd databases && docker compose restart
cd ../monitoring && docker compose restart
```

---

## Advanced Configuration

### Custom Deployment Hooks

**Add pre-deployment scripts:**

Edit `.github/workflows/deploy-infrastructure.yml`:

```yaml
# Before deployment
- name: Pre-deployment checks
  run: |
    ./scripts/pre-deploy-checks.sh

# After deployment
- name: Post-deployment tasks
  run: |
    ./scripts/post-deploy-tasks.sh
    ./scripts/notify-team.sh
```

### Notifications

**Add Slack notifications:**

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Multiple Environments

**Deploy to staging first:**

```yaml
# .github/workflows/deploy-staging.yml
on:
  push:
    branches:
      - develop

# Deploy to staging server
```

**Then promote to production:**

```yaml
# .github/workflows/deploy-production.yml
on:
  push:
    branches:
      - main

# Deploy to production server
```

---

## Summary

### What You Get

✅ **Zero-downtime deployments**
- Only changed services restart
- Graceful reloads where possible
- Automatic rollback on failure

✅ **Safe deployments**
- Backup tag before each deploy
- Health checks after deployment
- Manual rollback available

✅ **Visibility**
- GitHub Actions UI shows all deployments
- Detailed logs for troubleshooting
- Deployment history via git tags

✅ **Simple workflow**
```bash
git add .
git commit -m "your changes"
git push origin main
# That's it! Auto-deploys.
```

---

## Quick Start

1. **Setup SSH key** → Add to GitHub secrets
2. **Configure secrets** → SSH_HOST, SSH_USER, SSH_PRIVATE_KEY
3. **Test connection** → Run test workflow
4. **Push to main** → Automatic deployment!

**See also:**
- [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md) - Initial deployment
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Common operations
- [DOCUMENTATION.md](DOCUMENTATION.md) - Complete reference
