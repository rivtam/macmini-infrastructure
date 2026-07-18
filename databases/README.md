# Database Services

PostgreSQL 16, Redis 7, and PgBouncer connection pooling.

## Quick Reference

```bash
# Start databases
docker compose up -d

# Connect to PostgreSQL (direct)
docker exec -it infra_postgres psql -U postgres

# Connect via PgBouncer (pooled)
psql -h localhost -p 6432 -U postgres

# Connect to Redis
docker exec -it infra_redis redis-cli -a <REDIS_PASSWORD>

# Health check
docker exec infra_postgres pg_isready -U postgres
docker exec infra_redis redis-cli -a <REDIS_PASSWORD> ping
```

## Configuration

**Environment:** `.env` file
```bash
POSTGRES_PASSWORD=         # Set strong password
REDIS_PASSWORD=            # Set strong password
POSTGRES_HOST_BINDING=127.0.0.1  # Production: localhost only
REDIS_HOST_BINDING=127.0.0.1     # Production: localhost only
```

## Complete Documentation

See [../DOCUMENTATION.md](../DOCUMENTATION.md) for:
- Setup instructions
- Connection pooling (PgBouncer)
- Backup & restore procedures
- Performance tuning
- Troubleshooting
