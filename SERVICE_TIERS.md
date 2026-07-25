# Service Tier Management

Control which services run based on your needs and resources.

## Service Tiers

### Tier 1: Essential (Always On)
**Required for basic operation**
- PostgreSQL (2 CPU, 2GB RAM)
- Redis (1 CPU, 512MB RAM)
- Nginx (1 CPU, 512MB RAM)

**Total: 4 CPU, 3GB RAM**

### Tier 2: Monitoring (Optional)
**Basic monitoring and visibility**
- Prometheus (1 CPU, 1GB RAM)
- Grafana (1 CPU, 512MB RAM)
- Node Exporter (0.5 CPU, 128MB RAM)

**Total: 2.5 CPU, 1.6GB RAM**

### Tier 3: Advanced Monitoring (Optional)
**Enhanced monitoring with logs and alerts**
- Loki (1 CPU, 512MB RAM)
- Promtail (0.5 CPU, 256MB RAM)
- Alertmanager (0.5 CPU, 256MB RAM)
- cAdvisor (0.5 CPU, 256MB RAM)

**Total: 2.5 CPU, 1.2GB RAM**

### Tier 4: Observability (Optional)
**Database and service metrics exporters**
- PostgreSQL Exporter (0.5 CPU, 128MB RAM)
- Redis Exporter (0.5 CPU, 128MB RAM)
- SSL Exporter (0.5 CPU, 128MB RAM)

**Total: 1.5 CPU, 384MB RAM**

### Tier 5: Security (Optional)
**Enhanced security features**
- Vault (0.5 CPU, 256MB RAM)
- Certbot (minimal resources)
- Audit Processor (0.5 CPU, 256MB RAM)

**Total: 1 CPU, 512MB RAM**

### Tier 6: Performance (Optional)
**Performance optimization**
- PgBouncer (0.5 CPU, 256MB RAM)

**Total: 0.5 CPU, 256MB RAM**

---

## Quick Profiles

### Minimal (Development)
**Just the essentials**
```bash
./scripts/start-services.sh minimal
```
**Services:** PostgreSQL, Redis, Nginx
**Resources:** 4 CPU, 3GB RAM

### Standard (Production)
**Essential + basic monitoring**
```bash
./scripts/start-services.sh standard
```
**Services:** Essential + Prometheus, Grafana, Node Exporter
**Resources:** 6.5 CPU, 4.6GB RAM

### Full (Enterprise)
**Everything enabled**
```bash
./scripts/start-services.sh full
```
**Services:** All services
**Resources:** ~12.5 CPU, ~7GB RAM

### Custom
**Pick and choose**
```bash
./scripts/start-services.sh custom
# Interactive menu to select tiers
```

---

## Resource Comparison

| Profile | CPU | RAM | Services |
|---------|-----|-----|----------|
| Minimal | 4 | 3GB | 3 |
| Standard | 6.5 | 4.6GB | 6 |
| Full | 12.5 | 7GB | 15+ |

---

## Managing Services

### Start with a profile
```bash
# Minimal setup
./scripts/start-services.sh minimal

# Standard setup
./scripts/start-services.sh standard

# Full setup
./scripts/start-services.sh full
```

### Add/Remove tiers on the fly
```bash
# Add monitoring to running setup
./scripts/toggle-tier.sh monitoring on

# Remove advanced monitoring
./scripts/toggle-tier.sh advanced-monitoring off

# Add security features
./scripts/toggle-tier.sh security on
```

### Check what's running
```bash
./scripts/service-status.sh
```

### Enable/Disable individual services
```bash
# Disable Loki (saves 1 CPU, 512MB RAM)
docker stop infra_loki

# Enable it again
docker start infra_loki
```

---

## Use Cases

### Startup Phase (Limited Resources)
**Use: Minimal Profile**
- Focus on core functionality
- Minimal resource usage
- Add monitoring later when needed

### Production with Budget Constraints
**Use: Standard Profile**
- Core services + essential monitoring
- Good balance of features vs resources
- Can debug issues when they occur

### Enterprise/Production
**Use: Full Profile**
- Complete observability
- Security compliance
- Advanced features
- Peace of mind

---

## Tier Dependencies

```
Essential (Tier 1)
  └─> Monitoring (Tier 2)
        └─> Advanced Monitoring (Tier 3)
              └─> Observability (Tier 4)

Essential (Tier 1)
  └─> Security (Tier 5)

Essential (Tier 1)
  └─> Performance (Tier 6)
```

**Note:** You can enable any combination, but some tiers depend on others:
- Advanced Monitoring requires Monitoring
- Observability requires Monitoring
- All require Essential

---

## Environment-Based Defaults

Create `.env.tier` file:
```bash
# Options: minimal, standard, full, custom
DEFAULT_TIER=standard

# Custom tier selection (comma-separated)
# CUSTOM_TIERS=essential,monitoring,security
```

Then just run:
```bash
./scripts/start-services.sh
# Uses DEFAULT_TIER from .env.tier
```
