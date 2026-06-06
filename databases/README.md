# Databases Infrastructure

Shared database services for all applications.

## Services

- **PostgreSQL 16** - Relational database on port 5432
- **Redis 7** - In-memory cache/queue on port 6379

## Quick Start

```bash
# Copy environment file
cp .env.example .env

# Edit with your passwords
vim .env

# Start databases
docker compose up -d

# View logs
docker compose logs -f

# Check health
docker compose ps

# Stop databases
docker compose down
```

## Connecting to PostgreSQL

### From Command Line
```bash
# Using docker exec
docker exec -it infra_postgres psql -U postgres

# Connect to specific database
docker exec -it infra_postgres psql -U postgres -d eduhub

# From host machine (if you have psql installed)
psql -h localhost -p 5432 -U postgres -d eduhub
```

### From Application
```bash
# Connection string format
postgresql://postgres:password@infra_postgres:5432/eduhub

# Environment variables
DB_HOST=infra_postgres
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=eduhub
```

## Connecting to Redis

### From Command Line
```bash
# Using docker exec
docker exec -it infra_redis redis-cli

# Test connection
docker exec -it infra_redis redis-cli ping

# From host machine (if you have redis-cli installed)
redis-cli -h localhost -p 6379
```

### From Application
```bash
# Connection format
redis://infra_redis:6379

# Environment variables
REDIS_HOST=infra_redis
REDIS_PORT=6379
```

## Database Management

### Creating New Databases

Edit `postgres/init/01-create-databases.sql` and add:
```sql
CREATE DATABASE myapp;
```

This only runs on first container creation. For existing containers:
```bash
docker exec -it infra_postgres psql -U postgres -c "CREATE DATABASE myapp;"
```

### Creating Database Users

For security, create separate users for each application:
```sql
CREATE USER myapp_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp_user;
```

### Backing Up Databases

```bash
# Backup single database
docker exec infra_postgres pg_dump -U postgres eduhub > backup_eduhub.sql

# Backup all databases
docker exec infra_postgres pg_dumpall -U postgres > backup_all.sql

# Restore database
cat backup_eduhub.sql | docker exec -i infra_postgres psql -U postgres eduhub
```

### Redis Persistence

Redis is configured with both RDB snapshots and AOF:
- Snapshots are taken periodically and stored in `/data`
- AOF logs every write operation for durability
- Data persists in Docker volume `redis_data`

## Data Persistence

Data is stored in Docker volumes:
- `postgres_data` - All PostgreSQL databases
- `redis_data` - Redis persistence files

### Backing Up Volumes
```bash
# Backup postgres volume
docker run --rm -v databases_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz /data

# Restore postgres volume
docker run --rm -v databases_postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres_backup.tar.gz -C /
```

### Removing Data (WARNING: Destructive)
```bash
# Stop and remove volumes
docker compose down -v
```

## Network Configuration

Both services are on the `infra_network` bridge network. Applications must join this network to access the databases:

```yaml
# In your application's docker-compose.yml
networks:
  infra_network:
    external: true
```

## Production Configuration

For production, make sure to:

1. ✅ Change default passwords in `.env`
2. ✅ Set up regular backups
3. ✅ Configure Redis password in `redis/redis.conf`
4. ✅ Use separate database users per application
5. ✅ Monitor disk space for volumes
6. ✅ Set up automated backup strategy

## Troubleshooting

### PostgreSQL won't start
```bash
# Check logs
docker compose logs postgres

# Check if port is already in use
lsof -i :5432

# Use different port in .env
POSTGRES_PORT=5433
```

### Redis connection refused
```bash
# Check if redis is running
docker compose ps redis

# Check logs
docker compose logs redis

# Test connectivity
docker exec -it infra_redis redis-cli ping
```

### Connection from application fails
```bash
# Make sure application is on the same network
docker network inspect infra_network

# Check if services are healthy
docker compose ps
```
