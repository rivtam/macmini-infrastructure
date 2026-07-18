# Security Guide

This document outlines security best practices and configurations for the infrastructure.

## Table of Contents

- [Quick Security Checklist](#quick-security-checklist)
- [Network Security](#network-security)
- [Secrets Management](#secrets-management)
- [Database Security](#database-security)
- [SSL/TLS Configuration](#ssltls-configuration)
- [Monitoring & Alerting](#monitoring--alerting)
- [Regular Maintenance](#regular-maintenance)

## Quick Security Checklist

Before deploying to production, ensure you've completed these steps:

- [ ] Changed all default passwords in `.env` files
- [ ] Configured network binding to localhost for databases (production)
- [ ] Set up SSL certificates with Let's Encrypt
- [ ] Enabled Redis authentication
- [ ] Created separate database users per application
- [ ] Configured firewall rules
- [ ] Set up Alertmanager notifications
- [ ] Configured automated backups
- [ ] Reviewed and disabled unnecessary ports
- [ ] Enabled security headers in nginx
- [ ] Set resource limits on all containers

## Network Security

### Port Binding

**Production Configuration:**

In production, bind database ports only to localhost to prevent external access:

```bash
# databases/.env
POSTGRES_HOST_BINDING=127.0.0.1
REDIS_HOST_BINDING=127.0.0.1
```

This ensures databases are only accessible:
- From the host machine
- From other Docker containers on the `infra_network`
- NOT from external networks

**Development Configuration:**

For local development, you can use `0.0.0.0` to allow access from your local network:

```bash
# databases/.env
POSTGRES_HOST_BINDING=0.0.0.0
REDIS_HOST_BINDING=0.0.0.0
```

### Network Isolation

Services communicate via the `infra_network` Docker bridge network. This provides:

- ✅ Isolated network segment
- ✅ Service discovery by container name
- ✅ No exposure to host network unless explicitly configured
- ✅ Traffic encryption between containers (when TLS is enabled)

### Firewall Configuration

Configure your host firewall to only allow necessary ports:

```bash
# Example using UFW (Ubuntu)
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow Tailscale (if using)
sudo ufw allow 41641/udp

# Enable firewall
sudo ufw enable
```

## Secrets Management

### Environment Variables

**NEVER commit `.env` files to version control!**

All `.env` files are gitignored by default. To manage secrets:

1. **Development:** Use `.env.example` as template, create `.env` locally
2. **Production:** Use CI/CD secrets or a secrets manager

### GitHub Actions Secrets

Required secrets for CI/CD:

```
SSH_HOST              # Server hostname/IP
SSH_USER              # SSH username
SSH_PRIVATE_KEY       # SSH private key
SSH_PORT              # SSH port (default: 22)
TS_AUTH_KEY          # Tailscale auth key
```

### Password Guidelines

- Minimum 16 characters
- Mix of uppercase, lowercase, numbers, symbols
- Unique per service
- Rotate every 90 days
- Never reuse passwords

Example password generation:

```bash
# Generate strong random password
openssl rand -base64 32
```

### Using Docker Secrets (Advanced)

For enhanced security, consider using Docker Secrets:

```yaml
# Example docker-compose.yml
services:
  postgres:
    secrets:
      - postgres_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password

secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
```

## Database Security

### PostgreSQL

1. **Separate Users Per Application:**

```sql
-- Create dedicated user
CREATE USER myapp_user WITH PASSWORD 'strong_password';

-- Grant only necessary privileges
GRANT CONNECT ON DATABASE myapp TO myapp_user;
GRANT USAGE ON SCHEMA public TO myapp_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO myapp_user;

-- Set as database owner
ALTER DATABASE myapp OWNER TO myapp_user;
```

2. **Connection Limits:**

```sql
-- Limit concurrent connections per user
ALTER USER myapp_user CONNECTION LIMIT 20;
```

3. **Audit Logging:**

Enable PostgreSQL audit logging by adding to `databases/postgres/postgresql.conf`:

```conf
log_connections = on
log_disconnections = on
log_duration = on
log_statement = 'mod'  # Log INSERT, UPDATE, DELETE
```

### Redis

1. **Password Authentication (Already Configured):**

Redis is configured with password authentication via `.env`:

```bash
REDIS_PASSWORD=your_strong_password_here
```

2. **Disable Dangerous Commands (Already Configured):**

The following dangerous commands are disabled in `redis.conf`:

- `FLUSHDB` - Delete all keys in current database
- `FLUSHALL` - Delete all keys in all databases
- `CONFIG` - Modify configuration at runtime
- `DEBUG` - Debug commands
- `SHUTDOWN` - Shutdown server (renamed to secret)

3. **Connection Limits:**

In `redis.conf`:

```conf
maxclients 10000
timeout 300
```

## SSL/TLS Configuration

### Let's Encrypt Setup

1. **Initial Certificate Generation:**

```bash
# Install certbot
sudo apt install certbot

# Generate certificate
sudo certbot certonly --webroot \
  -w ./certbot/www \
  -d yourdomain.com \
  -d www.yourdomain.com
```

2. **Auto-Renewal:**

Add to crontab:

```bash
0 3 * * * certbot renew --quiet --post-hook "docker exec infra_nginx nginx -s reload"
```

3. **SSL Configuration (Already Configured):**

Nginx is configured with modern SSL settings:

- TLS 1.2 and 1.3 only
- Strong cipher suites
- Security headers (X-Frame-Options, X-Content-Type-Options, etc.)

### Custom SSL Certificates

For custom certificates, place them in:

```
certbot/conf/live/yourdomain.com/
  ├── fullchain.pem
  └── privkey.pem
```

## Monitoring & Alerting

### Alert Configuration

1. **Email Alerts:**

Edit `monitoring/alertmanager/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@yourdomain.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'
```

2. **Slack Alerts:**

```yaml
receivers:
  - name: 'critical-receiver'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts-critical'
```

### Security Monitoring

Monitor these metrics for security issues:

- Failed login attempts (application-level)
- Unusual network traffic patterns
- Resource exhaustion attempts
- Configuration changes
- Certificate expiration

## Regular Maintenance

### Weekly

- [ ] Review monitoring alerts
- [ ] Check disk space usage
- [ ] Review access logs for suspicious activity
- [ ] Verify backup completion

### Monthly

- [ ] Update Docker images
- [ ] Review and update firewall rules
- [ ] Audit user accounts and permissions
- [ ] Test backup restoration
- [ ] Review SSL certificate expiration

### Quarterly

- [ ] Rotate passwords
- [ ] Security audit
- [ ] Dependency updates
- [ ] Review and update documentation
- [ ] Penetration testing (if applicable)

## Incident Response

### If a Security Breach is Suspected:

1. **Isolate:** Stop affected services
   ```bash
   make stop-all
   ```

2. **Assess:** Check logs and monitoring
   ```bash
   make logs > incident-$(date +%Y%m%d-%H%M%S).log
   ```

3. **Contain:** Change all passwords and rotate secrets

4. **Investigate:** Review audit logs and metrics

5. **Recover:** Restore from known-good backup if needed
   ```bash
   ./scripts/restore-databases.sh backups/path/to/backup.sql.gz
   ```

6. **Document:** Record what happened and how it was resolved

## Security Resources

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Nginx Security Controls](https://www.nginx.com/blog/mitigating-owasp-top-10-for-nginx/)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)
- [Redis Security](https://redis.io/docs/manual/security/)

## Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** open a public issue
2. Contact the infrastructure team privately
3. Provide detailed information about the vulnerability
4. Allow time for the issue to be addressed before disclosure

---

**Remember:** Security is an ongoing process, not a one-time task. Regularly review and update your security practices.
