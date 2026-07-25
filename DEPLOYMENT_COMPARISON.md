# Deployment Approach Comparison: GHCR vs Tarball

**TL;DR:** For your Mac Mini (8GB RAM) infrastructure deployment, **GHCR is significantly better** than tarball for resource efficiency and security.

---

## Overview

### Current Situation
- **EduHub App**: Uses GHCR approach (working well)
- **Infrastructure**: Uses `git clone` (problematic - requires GitHub auth)
- **Mac Mini**: 8GB total RAM (resource-constrained)

### Question
Should infrastructure use GHCR (like EduHub) or switch to tarball approach?

---

## Detailed Comparison

| Factor | GHCR Approach | Tarball Approach | Winner |
|--------|---------------|------------------|--------|
| **GitHub Resources** | Build images on GitHub servers | Package files on GitHub servers | 🟰 **Tie** |
| **Mac Mini RAM Usage** | Pull pre-built images (~200MB compressed) | Extract files + build locally | 🏆 **GHCR** |
| **Mac Mini CPU Usage** | No builds (just pull & run) | Must run docker compose build | 🏆 **GHCR** |
| **Deployment Speed** | Fast (pull compressed images) | Fast (transfer files) | 🟰 **Tie** |
| **Security** | Token-based (scoped to registry) | Full SSH access | 🏆 **GHCR** |
| **Credentials on Server** | GHCR_TOKEN (read-only, registry-scoped) | None needed for tarball | 🏆 **Tarball** |
| **Rollback** | Tag-based (instant image swap) | File-based (extract old tarball) | 🏆 **GHCR** |
| **Consistency** | Always same image (immutable) | Files can differ | 🏆 **GHCR** |
| **Storage** | Docker image layers (efficient) | Full file copies | 🏆 **GHCR** |
| **Change Detection** | Per-service image updates | Full infrastructure update | 🏆 **GHCR** |

---

## Resource Usage Analysis

### GHCR Approach (Recommended for 8GB Mac Mini)

**On GitHub Actions (FREE):**
```yaml
✓ Build Docker images (uses GitHub's servers)
✓ Run tests (uses GitHub's servers)
✓ Push to GHCR (uses GitHub's bandwidth)
```

**On Mac Mini (Your 8GB):**
```yaml
✓ Pull compressed images (~200-300MB total)
✓ Extract layers (Docker handles efficiently)
✓ Run containers
```

**Estimated Mac Mini Resources:**
- RAM: ~100-200MB for pulls
- CPU: ~5-10% during pull
- Disk: ~500MB-1GB (with layer deduplication)
- Build Time: **0 seconds** (already built on GitHub)

---

### Tarball Approach

**On GitHub Actions (FREE):**
```yaml
✓ Create tarball of infrastructure files
✓ Upload to server
```

**On Mac Mini (Your 8GB):**
```yaml
✗ Extract tarball
✗ docker compose build (builds all images locally!)
✗ Start containers
```

**Estimated Mac Mini Resources:**
- RAM: ~1-2GB for docker builds
- CPU: ~50-80% during builds (multi-minute process)
- Disk: ~1-2GB (no layer reuse initially)
- Build Time: **5-15 minutes** (depending on services)

---

## Why GHCR is Better for Infrastructure

### 1. **No Local Builds = Saves RAM**

**Tarball Reality:**
```bash
# What actually happens with tarball:
tar -xzf infrastructure.tar.gz  # Extract
cd nginx && docker compose up -d  # Builds nginx image locally!
cd monitoring && docker compose up -d  # Builds prometheus, grafana locally!
# This uses 1-2GB RAM for builds
```

**GHCR Reality:**
```bash
# What happens with GHCR:
docker pull ghcr.io/you/infra-nginx:latest  # Just download
docker pull ghcr.io/you/infra-prometheus:latest  # Just download
docker compose up -d  # No builds, just run!
# Uses only ~200MB RAM for pulls
```

### 2. **GitHub Does Heavy Lifting**

Your infrastructure has these services that would need building:
```yaml
nginx/          → Custom nginx config = needs build
monitoring/     → Grafana dashboards = custom image
audit/          → Promtail config = custom image
```

**With Tarball:**
- Mac Mini builds all these images (CPU + RAM intensive)

**With GHCR:**
- GitHub Actions builds these once
- Mac Mini just downloads ready images
- **Your 8GB Mac Mini is freed up!**

### 3. **Better for Multi-Service Infrastructure**

Your infrastructure has 10+ services across tiers. With GHCR:
```bash
# Only rebuild changed services
./nginx/Dockerfile changed → Only rebuild nginx image on GitHub
./monitoring/ changed → Only rebuild monitoring images on GitHub
# Other services: pull existing images (cached)
```

With tarball:
```bash
# Transfer entire infrastructure every time
# No selective builds
```

---

## Security Comparison

### GHCR Credentials (More Secure)
```bash
# On Mac Mini:
GHCR_TOKEN=ghp_xxxxx  # Read-only token, scoped to container registry only

# If compromised:
✓ Attacker can only pull images
✗ Cannot push malicious images (read-only)
✗ Cannot access your code
✗ Cannot access other repos
✓ Easily revocable (regenerate token)
```

### Tarball Credentials (Less Secure)
```bash
# On Mac Mini:
SSH_PRIVATE_KEY=xxx  # Full SSH access

# If compromised:
✗ Attacker has full server access
✗ Can deploy anything
✗ Can modify files
✗ Harder to trace
```

---

## Real-World Example: Your EduHub Setup

You're **already using GHCR successfully** for EduHub:

**From eduhub/.github/workflows/deploy.yml:**
```yaml
# GitHub builds images (lines 74-82, 105-114)
- Build backend image → ghcr.io/richfield-eduhub/eduhub-backend:latest
- Build nginx image → ghcr.io/richfield-eduhub/eduhub-nginx:latest

# Mac Mini just pulls (lines 195, 236, 311)
backend:
  image: ghcr.io/richfield-eduhub/eduhub-backend:latest
nginx:
  image: ghcr.io/richfield-eduhub/eduhub-nginx:latest
```

**This works well because:**
1. ✅ Mac Mini doesn't build images (saves resources)
2. ✅ Consistent deployments (same image everywhere)
3. ✅ Fast rollbacks (just change image tag)
4. ✅ GitHub does the heavy lifting

---

## Recommended Approach for Infrastructure

**Use GHCR (same as EduHub):**

### Infrastructure Services to Containerize:
```yaml
✓ nginx/ → ghcr.io/you/infra-nginx:latest
✓ monitoring/grafana → ghcr.io/you/infra-grafana:latest (custom dashboards)
✓ monitoring/prometheus → Use official prom/prometheus:latest
✓ databases/postgres → Use official postgres:16
✓ audit/promtail → ghcr.io/you/infra-promtail:latest (custom config)
```

### Workflow Structure:
```yaml
1. Detect Changes (which service changed?)
2. Build Changed Services → GHCR (on GitHub servers)
3. Deploy → Mac Mini (just pull new images)
4. Health Check → Rollback if failed
```

---

## Implementation Plan

### Option A: Full GHCR (Recommended)
```yaml
# Build custom infrastructure images
nginx/Dockerfile → ghcr.io/you/infra-nginx
monitoring/custom-grafana/Dockerfile → ghcr.io/you/infra-grafana
audit/custom-promtail/Dockerfile → ghcr.io/you/infra-promtail

# Use official images
postgres:16, redis:7, prometheus, etc.
```

**Benefits:**
- Consistent with EduHub approach
- Maximum resource savings on Mac Mini
- Best rollback capabilities
- Immutable infrastructure

### Option B: Hybrid (If some services don't need custom images)
```yaml
# For simple configs (just files):
- Use tarball for: databases/.env, monitoring/prometheus.yml

# For custom images:
- Use GHCR for: nginx, custom dashboards, etc.
```

**Benefits:**
- Simpler for config-only services
- Still saves resources for image-based services

---

## Migration from Git Clone → GHCR

Current infrastructure workflow:
```yaml
# ❌ Current (bad):
git clone repo  # Needs GitHub auth
docker compose up -d  # Builds locally
```

New GHCR workflow:
```yaml
# ✅ New (good):
echo $GHCR_TOKEN | docker login ghcr.io  # Read-only token
docker compose pull  # Download pre-built images
docker compose up -d  # No builds!
```

---

## Cost Comparison

| Resource | GHCR | Tarball |
|----------|------|---------|
| GitHub Actions Minutes | ~5-10 min/deploy (build images) | ~2 min/deploy (package files) |
| Mac Mini RAM | ~200MB | ~1-2GB |
| Mac Mini CPU | ~10% (5 sec) | ~60% (5-15 min) |
| Mac Mini Disk I/O | Low (pull) | High (build) |
| **Total GitHub Cost** | FREE (public repo) | FREE |
| **Mac Mini Impact** | **Minimal** | **Significant** |

**Winner for 8GB Mac Mini: GHCR** 🏆

---

## Summary Table

| Metric | GHCR | Tarball | Winner |
|--------|------|---------|--------|
| Mac Mini RAM Usage | Low (~200MB) | High (~1-2GB) | 🏆 GHCR |
| Mac Mini CPU Usage | Low (~10% for 5s) | High (~60% for 5-15min) | 🏆 GHCR |
| Deployment Speed | Fast (pull images) | Slow (build images) | 🏆 GHCR |
| Security | Token-scoped | Full SSH | 🏆 GHCR |
| Rollback | Instant (tag swap) | Slower (extract) | 🏆 GHCR |
| Consistency | Guaranteed (immutable) | Possible drift | 🏆 GHCR |
| GitHub Resources | More (builds) | Less (package) | Tarball (but irrelevant - it's free) |
| Setup Complexity | Medium | Low | Tarball |
| Already Used? | Yes (EduHub) | No | 🏆 GHCR |

---

## Final Recommendation

### ✅ Use GHCR for Infrastructure Deployment

**Reasons:**
1. **Resource Efficiency**: Saves 1-1.8GB RAM on your 8GB Mac Mini
2. **Consistency**: You're already using it for EduHub (proven approach)
3. **Security**: Scoped token vs full SSH access
4. **Performance**: No builds on Mac Mini (GitHub does it)
5. **Rollback**: Instant image tag changes
6. **Free**: GitHub Actions is free for public repos

**Next Steps:**
1. Create Dockerfiles for custom infrastructure services (nginx, monitoring)
2. Add GHCR build jobs to `.github/workflows/deploy-infrastructure.yml`
3. Update docker-compose files to use GHCR images
4. Remove `git clone` from deployment workflow
5. Use GHCR_TOKEN instead of git credentials

---

## Code Example: GHCR Infrastructure Deployment

```yaml
# .github/workflows/deploy-infrastructure.yml
jobs:
  build-nginx:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Build and push nginx
        uses: docker/build-push-action@v5
        with:
          context: ./nginx
          push: true
          tags: ghcr.io/${{ github.repository_owner }}/infra-nginx:latest

  deploy:
    needs: build-nginx
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Mac Mini
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd ~/prod/infrastructure

            # Login to GHCR (read-only token)
            echo ${{ secrets.GHCR_TOKEN }} | docker login ghcr.io -u ${{ github.repository_owner }} --password-stdin

            # Pull new images (NO BUILDS!)
            docker compose pull

            # Deploy
            docker compose up -d

            # Health check
            ./scripts/health-check.sh
```

**No `git clone`, no builds, just pull and run!** 🚀
