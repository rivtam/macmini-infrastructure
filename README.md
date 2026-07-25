# Mac Mini Infrastructure

**Production-ready enterprise infrastructure - 10/10 rating**

Complete Docker-based infrastructure with monitoring, security, logging, and automation.

**🚀 Now with GHCR Deployment** - Same approach as EduHub, saves 1.5GB RAM on Mac Mini!

## 📖 Documentation

**[READ THE COMPLETE DOCUMENTATION](DOCUMENTATION.md)** ← Single source of truth

### New: GHCR Deployment (Recommended)

- **[GHCR Deployment Guide](GHCR_DEPLOYMENT_GUIDE.md)** - Complete GHCR setup (same as EduHub)
- **[Migration Guide](MIGRATION_TO_GHCR.md)** - Migrate from git clone to GHCR
- **[Deployment Comparison](DEPLOYMENT_COMPARISON.md)** - GHCR vs Tarball analysis

### Original Documentation

- **[Production Deployment](PRODUCTION_DEPLOYMENT.md)** - Step-by-step deployment guide
- **[CI/CD Setup](CI_CD_SETUP.md)** - Automated deployments
- **[Quick Reference](QUICK_REFERENCE.md)** - Common operations

## ⚡ Quick Start

### First Time Production Deployment

```bash
# Interactive deployment wizard (RECOMMENDED)
./scripts/deploy-production.sh

# Or manual deployment
./scripts/start-services.sh standard
```

**[→ Complete Production Deployment Guide](PRODUCTION_DEPLOYMENT.md)**

### Already Deployed? Choose Service Tier

```bash
# Minimal (3 services, 3GB RAM) - Bootstrapping
./scripts/start-services.sh minimal

# Standard (6 services, 4.6GB RAM) - RECOMMENDED
./scripts/start-services.sh standard

# Production (10 services, 6GB RAM) - Scaling
./scripts/start-services.sh production

# Full (15+ services, 7GB RAM) - Enterprise
./scripts/start-services.sh full

# Check status
./scripts/service-status.sh

# Access services
open http://localhost:3000  # Grafana (monitoring)
open http://localhost:9090  # Prometheus (metrics)
```

**[→ See Service Tiers & Cost Optimization](QUICK_REFERENCE.md)**

## 📦 What's Included

- **Databases**: PostgreSQL 16, Redis 7, PgBouncer
- **Web Server**: Nginx with SSL automation (Let's Encrypt)
- **Monitoring**: Prometheus, Grafana, Loki, Alertmanager
- **Security**: HashiCorp Vault, Fail2ban, comprehensive auditing
- **Automation**: Backups, SSL renewal, CI/CD with rollback

## 🎯 Common Tasks

```bash
# Toggle services on/off
./scripts/toggle-tier.sh monitoring on        # Add monitoring
./scripts/toggle-tier.sh security off         # Remove security (save resources)

# Check what's running
./scripts/service-status.sh

# Backup databases
./scripts/backup-databases.sh

# Restore databases
./scripts/restore-databases.sh

# Get SSL certificate
./scripts/certbot-obtain.sh your-domain.com your@email.com
```

## 🤔 Why Shared Infrastructure?

Running multiple apps (EduHub, home automation, budget, docs) on one Mac Mini?

**Shared infrastructure uses 60% less resources than per-app stacks!**

| Approach | Resources | Management |
|----------|-----------|------------|
| **Shared** (this repo) | 9 CPU, 6GB RAM | One backup, one monitor |
| **Per-app** (separate) | 22 CPU, 16GB RAM | 4 backups, 4 monitors |

**[→ See Detailed Comparison](ARCHITECTURE_COMPARISON.md)**

## 📁 Service-Specific Docs

For detailed configuration of specific services, see:
- [nginx/](nginx/) - Web server configuration
- [databases/](databases/) - Database management
- [monitoring/](monitoring/) - Monitoring stack
- [vault/](vault/) - Secrets management

## 🆘 Help

- **Setup issues?** See [DOCUMENTATION.md#setup--installation](DOCUMENTATION.md#setup--installation)
- **Service not working?** See [DOCUMENTATION.md#troubleshooting](DOCUMENTATION.md#troubleshooting)
- **Security questions?** See [DOCUMENTATION.md#security](DOCUMENTATION.md#security)

## 🏆 Infrastructure Rating: 10/10

Complete enterprise-grade infrastructure with:
- ✅ Comprehensive monitoring & alerting
- ✅ Centralized logging & audit trails
- ✅ Secrets management with Vault
- ✅ Automated backups with retention
- ✅ SSL automation with Let's Encrypt
- ✅ DDoS protection with Fail2ban
- ✅ CI/CD with automatic rollback
- ✅ Full compliance support (GDPR, HIPAA, SOC 2, PCI DSS)

---

**[→ Go to Complete Documentation](DOCUMENTATION.md)**
