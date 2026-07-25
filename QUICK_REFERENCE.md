# Quick Reference Guide

**One-page cheat sheet for common operations**

## 🚀 Starting Services

```bash
# Minimal (3 services, 3GB RAM)
./scripts/start-services.sh minimal

# Standard (6 services, 4.6GB RAM) - RECOMMENDED FOR STARTUPS
./scripts/start-services.sh standard

# Production (10 services, 6GB RAM)
./scripts/start-services.sh production

# Full (15+ services, 7GB RAM)
./scripts/start-services.sh full

# Custom (choose your own)
./scripts/start-services.sh custom
```

## 📊 Check Status

```bash
# See what's running
./scripts/service-status.sh

# Or use traditional Docker commands
docker ps
make health
```

## 🔧 Toggle Services On/Off

```bash
# Add monitoring to running setup
./scripts/toggle-tier.sh monitoring on

# Remove advanced monitoring (save 2.5 CPU, 1.2GB RAM)
./scripts/toggle-tier.sh advanced-monitoring off

# Toggle security features
./scripts/toggle-tier.sh security on

# Toggle PgBouncer (connection pooling)
./scripts/toggle-tier.sh performance on
```

## 💾 Service Tiers at a Glance

| Tier | Services | Resources |
|------|----------|-----------|
| **Essential** | PostgreSQL, Redis, Nginx | 4 CPU, 3GB |
| **Monitoring** | Prometheus, Grafana, Node Exporter | +2.5 CPU, +1.6GB |
| **Advanced Monitoring** | Loki, Promtail, Alertmanager, cAdvisor | +2.5 CPU, +1.2GB |
| **Observability** | DB/Redis/SSL Exporters | +1.5 CPU, +384MB |
| **Security** | Vault, Certbot, Audit | +1 CPU, +512MB |
| **Performance** | PgBouncer | +0.5 CPU, +256MB |

## 🎯 Recommended Profiles by Stage

### Bootstrapping (Limited Budget)
```bash
./scripts/start-services.sh minimal
```
✅ Core functionality only
✅ Lowest cost
❌ No monitoring
❌ Manual troubleshooting

### Early Stage (Have Some Traction)
```bash
./scripts/start-services.sh standard
```
✅ Core + basic monitoring
✅ Can see what's happening
✅ Good cost/benefit ratio
✅ **RECOMMENDED FOR MOST STARTUPS**

### Growth Stage (Scaling)
```bash
./scripts/start-services.sh production
```
✅ Everything you need
✅ Security features
✅ Performance optimization
✅ Production-ready

### Enterprise/Compliance
```bash
./scripts/start-services.sh full
```
✅ Complete observability
✅ Audit trails
✅ Maximum reliability

## 🔍 Individual Service Control

```bash
# Stop individual services to save resources
docker stop infra_loki          # Save 1 CPU, 512MB
docker stop infra_cadvisor      # Save 0.5 CPU, 256MB
docker stop infra_vault         # Save 0.5 CPU, 256MB

# Start them back when needed
docker start infra_loki
docker start infra_cadvisor
docker start infra_vault
```

## 💰 Cost Optimization Examples

### Scenario: Need to cut costs by 30%

**Option 1: Remove Advanced Monitoring**
```bash
./scripts/toggle-tier.sh advanced-monitoring off
# Saves: 2.5 CPU, 1.2GB RAM (~20% reduction)
# Keeps: Basic monitoring (Prometheus, Grafana)
```

**Option 2: Remove Observability**
```bash
./scripts/toggle-tier.sh observability off
# Saves: 1.5 CPU, 384MB RAM (~12% reduction)
# Keeps: Core monitoring, just less granular
```

**Option 3: Downgrade to Minimal**
```bash
./scripts/start-services.sh minimal
# Saves: 8.5 CPU, 4GB RAM (~65% reduction)
# Keeps: Only essential services
```

### Scenario: Preparing for Launch

**Start minimal, add monitoring when traffic comes:**
```bash
# Day 1: Launch with minimal
./scripts/start-services.sh minimal

# Day 7: Getting traction, add monitoring
./scripts/toggle-tier.sh monitoring on

# Day 30: Growing fast, add security
./scripts/toggle-tier.sh security on

# Day 60: Need better performance
./scripts/toggle-tier.sh performance on
```

## 🌙 Night Mode (Save Resources While Sleeping)

```bash
# Before going to bed (save ~50% resources)
./scripts/toggle-tier.sh advanced-monitoring off
./scripts/toggle-tier.sh observability off
./scripts/toggle-tier.sh security off

# Morning (restore full monitoring)
./scripts/toggle-tier.sh advanced-monitoring on
./scripts/toggle-tier.sh observability on
./scripts/toggle-tier.sh security on
```

## 📈 Scaling Up Path

```
[Bootstrap]
minimal (3 services, 3GB)
    ↓ Getting users?
[Early Stage]
standard (6 services, 4.6GB)
    ↓ Revenue coming in?
[Growth]
production (10 services, 6GB)
    ↓ Need compliance/audit?
[Enterprise]
full (15+ services, 7GB)
```

## 🔄 Quick Migrations

### From Minimal → Standard
```bash
./scripts/toggle-tier.sh monitoring on
```

### From Standard → Production
```bash
./scripts/toggle-tier.sh security on
./scripts/toggle-tier.sh performance on
./scripts/toggle-tier.sh observability on
```

### From Production → Full
```bash
./scripts/toggle-tier.sh advanced-monitoring on
```

### From Full → Production (downgrade)
```bash
./scripts/toggle-tier.sh advanced-monitoring off
```

## 🚨 Emergency Resource Reduction

**If your server is running out of resources:**

```bash
# Stop non-essential services immediately
docker stop infra_loki infra_promtail infra_cadvisor
docker stop infra_alertmanager infra_vault infra_audit_processor

# Frees up: ~4 CPU, ~2GB RAM

# Or use the tier system
./scripts/toggle-tier.sh advanced-monitoring off
./scripts/toggle-tier.sh security off
./scripts/toggle-tier.sh observability off
```

## 📋 Health Checks

```bash
# Quick status
./scripts/service-status.sh

# Detailed health
make health

# Check specific service
docker logs infra_postgres
docker exec infra_postgres pg_isready -U postgres
```

## 🎛️ Environment-Based Defaults

Create `.env.tier`:
```bash
DEFAULT_TIER=standard
```

Then just run:
```bash
./scripts/start-services.sh
# Uses DEFAULT_TIER from .env.tier
```

---

**See [SERVICE_TIERS.md](SERVICE_TIERS.md) for detailed tier information**
**See [DOCUMENTATION.md](DOCUMENTATION.md) for complete documentation**
