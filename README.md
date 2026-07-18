# Mac Mini Infrastructure

**Production-ready enterprise infrastructure - 10/10 rating**

Complete Docker-based infrastructure with monitoring, security, logging, and automation.

## 📖 Documentation

**[READ THE COMPLETE DOCUMENTATION](DOCUMENTATION.md)** ← Single source of truth

## ⚡ Quick Start

```bash
# First time setup
make setup

# Check everything is healthy
make health

# Access services
open http://localhost:3000  # Grafana (monitoring)
open http://localhost:9090  # Prometheus (metrics)
```

## 📦 What's Included

- **Databases**: PostgreSQL 16, Redis 7, PgBouncer
- **Web Server**: Nginx with SSL automation (Let's Encrypt)
- **Monitoring**: Prometheus, Grafana, Loki, Alertmanager
- **Security**: HashiCorp Vault, Fail2ban, comprehensive auditing
- **Automation**: Backups, SSL renewal, CI/CD with rollback

## 🎯 Common Tasks

```bash
# View all logs
make logs

# Backup databases
./scripts/backup-databases.sh

# Restore databases
./scripts/restore-databases.sh

# Generate compliance report
./scripts/generate-audit-report.sh

# Get SSL certificate
./scripts/certbot-obtain.sh your-domain.com your@email.com
```

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
