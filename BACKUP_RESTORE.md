# Backup and Restore Guide

Complete guide for backing up and restoring infrastructure data.

## Table of Contents

- [Quick Start](#quick-start)
- [Backup Strategy](#backup-strategy)
- [Manual Backups](#manual-backups)
- [Automated Backups](#automated-backups)
- [Restore Procedures](#restore-procedures)
- [Disaster Recovery](#disaster-recovery)
- [Testing Backups](#testing-backups)
- [Off-Site Backups](#off-site-backups)

## Quick Start

### Create a Backup

```bash
# One-time backup
make db-backup

# Or directly
./scripts/backup-databases.sh
```

### Restore from Backup

```bash
# List available backups
./scripts/restore-databases.sh

# Restore all databases
./scripts/restore-databases.sh ./backups/daily/all_databases_20240101_120000.sql.gz

# Restore single database
./scripts/restore-databases.sh ./backups/daily/eduhub_20240101_120000.sql.gz eduhub
```

## Backup Strategy

### Retention Policy

Backups are organized in three tiers:

| Type | Frequency | Retention | Storage Location |
|------|-----------|-----------|------------------|
| Daily | Every day at 2:00 AM | 7 backups | `./backups/daily/` |
| Weekly | Every Sunday | 4 backups | `./backups/weekly/` |
| Monthly | 1st of each month | 3 backups | `./backups/monthly/` |

### What Gets Backed Up

1. **PostgreSQL Databases:**
   - All databases via `pg_dumpall`
   - Individual databases for easier restoration
   - Database roles and permissions

2. **Redis Data:**
   - RDB snapshot
   - All keys and data

3. **Metadata:**
   - MD5 checksums for integrity verification
   - Timestamps for backup identification

### What Doesn't Get Backed Up

❌ Configuration files (`.env` files) - stored in version control
❌ Docker volumes (except database data)
❌ Logs
❌ Temporary files

## Manual Backups

### PostgreSQL Backup

**All Databases:**

```bash
docker exec infra_postgres pg_dumpall -U postgres | gzip > backup_all.sql.gz
```

**Single Database:**

```bash
docker exec infra_postgres pg_dump -U postgres eduhub | gzip > backup_eduhub.sql.gz
```

**With Custom Format (smaller, faster):**

```bash
docker exec infra_postgres pg_dump -U postgres -Fc eduhub > backup_eduhub.dump
```

**Specific Tables Only:**

```bash
docker exec infra_postgres pg_dump -U postgres -t users -t posts eduhub > backup_tables.sql
```

### Redis Backup

**Create Snapshot:**

```bash
# Trigger save
docker exec infra_redis redis-cli -a ${REDIS_PASSWORD} SAVE

# Copy RDB file
docker cp infra_redis:/data/dump.rdb ./backup_redis.rdb
```

**Background Save (non-blocking):**

```bash
docker exec infra_redis redis-cli -a ${REDIS_PASSWORD} BGSAVE
```

### Backup Before Major Changes

Always backup before:
- Schema migrations
- Major version upgrades
- Data transformations
- Configuration changes

```bash
# Create tagged backup
BACKUP_DIR=./backups/pre-migration-$(date +%Y%m%d)
mkdir -p "$BACKUP_DIR"
./scripts/backup-databases.sh
mv ./backups/daily/* "$BACKUP_DIR/"
```

## Automated Backups

### Setup Automated Backups

```bash
./scripts/setup-backup-cron.sh
```

This creates a cron job that runs daily at 2:00 AM.

### Verify Cron Job

```bash
# List cron jobs
crontab -l

# Check backup logs
tail -f ./logs/backup-cron.log
```

### Customize Backup Schedule

Edit crontab:

```bash
crontab -e
```

Examples:

```cron
# Every 6 hours
0 */6 * * * cd /path/to/infrastructure && ./scripts/backup-databases.sh

# Twice daily (2 AM and 2 PM)
0 2,14 * * * cd /path/to/infrastructure && ./scripts/backup-databases.sh

# Every weekday at 3 AM
0 3 * * 1-5 cd /path/to/infrastructure && ./scripts/backup-databases.sh
```

### Customize Retention Policy

Edit `scripts/backup-databases.sh`:

```bash
# At the top of the script
DAILY_RETENTION=7      # Keep 7 daily backups
WEEKLY_RETENTION=4     # Keep 4 weekly backups
MONTHLY_RETENTION=3    # Keep 3 monthly backups
```

## Restore Procedures

### Pre-Restore Checklist

Before restoring:

1. ✅ Verify backup integrity (checksums)
2. ✅ Stop application containers
3. ✅ Create a backup of current state
4. ✅ Notify users of maintenance window
5. ✅ Document the reason for restore

### Full Database Restore

```bash
# Stop applications
docker stop $(docker ps -q --filter "name=eduhub") 2>/dev/null

# Restore all databases
./scripts/restore-databases.sh ./backups/daily/all_databases_20240101_120000.sql.gz

# Verify restoration
docker exec infra_postgres psql -U postgres -l

# Restart applications
docker start $(docker ps -aq --filter "name=eduhub") 2>/dev/null
```

### Single Database Restore

```bash
# Method 1: Using restore script
./scripts/restore-databases.sh ./backups/daily/eduhub_20240101_120000.sql.gz eduhub

# Method 2: Manual restore
gunzip -c backup_eduhub.sql.gz | docker exec -i infra_postgres psql -U postgres -d eduhub
```

### Point-in-Time Recovery

PostgreSQL doesn't have PITR configured by default. To enable:

1. Enable WAL archiving in `databases/postgres/postgresql.conf`:

```conf
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/wal_archive/%f && cp %p /var/lib/postgresql/wal_archive/%f'
```

2. Create base backup:

```bash
docker exec infra_postgres pg_basebackup -U postgres -D /var/lib/postgresql/base_backup -F tar -z -P
```

3. Restore to specific time:

```conf
# recovery.conf
restore_command = 'cp /var/lib/postgresql/wal_archive/%f %p'
recovery_target_time = '2024-01-01 12:00:00'
```

### Redis Restore

```bash
# Stop Redis
docker compose -f databases/docker-compose.yml stop redis

# Copy backup file
docker cp backup_redis.rdb infra_redis:/data/dump.rdb

# Start Redis (it will load from dump.rdb)
docker compose -f databases/docker-compose.yml start redis

# Verify data
docker exec infra_redis redis-cli -a ${REDIS_PASSWORD} DBSIZE
```

## Disaster Recovery

### Complete Server Failure

1. **Provision new server**

2. **Install Docker:**

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

3. **Clone infrastructure repository:**

```bash
git clone <your-repo-url> ~/infrastructure
cd ~/infrastructure
```

4. **Restore configuration files:**

```bash
# Copy .env files from secure backup location
cp /path/to/secure/backup/databases/.env databases/.env
cp /path/to/secure/backup/monitoring/.env monitoring/.env
cp /path/to/secure/backup/nginx/.env nginx/.env
```

5. **Start infrastructure:**

```bash
make start-all
```

6. **Restore database backup:**

```bash
# Copy backup from off-site location
scp user@backup-server:/backups/latest.sql.gz ./

# Restore
./scripts/restore-databases.sh ./latest.sql.gz
```

7. **Verify and test:**

```bash
make health
```

### Partial Data Loss

If only specific data is lost:

1. **Identify affected database/table**

2. **Export specific table from backup:**

```bash
# Extract single table
pg_restore -U postgres -d eduhub -t users backup_eduhub.dump
```

3. **Or use SQL to merge data:**

```sql
-- Create temporary table from backup
CREATE TABLE users_backup AS SELECT * FROM users;

-- Merge missing data
INSERT INTO users
SELECT * FROM users_backup
WHERE id NOT IN (SELECT id FROM users);
```

## Testing Backups

### Monthly Backup Test

Perform this test monthly to ensure backups are working:

1. **Select a random backup:**

```bash
ls -la backups/daily/ | shuf -n 1
```

2. **Create test environment:**

```bash
# Use different ports
export POSTGRES_PORT=5433
export REDIS_PORT=6380
```

3. **Restore to test environment:**

```bash
# Start test database
docker run --name test_postgres -e POSTGRES_PASSWORD=test -p 5433:5432 -d postgres:16

# Restore backup
gunzip -c backups/daily/all_databases_20240101_120000.sql.gz | \
  docker exec -i test_postgres psql -U postgres

# Verify data
docker exec test_postgres psql -U postgres -c "SELECT COUNT(*) FROM users;"
```

4. **Cleanup:**

```bash
docker stop test_postgres
docker rm test_postgres
```

### Automated Backup Verification

Add to cron after backup:

```bash
# Verify backups have valid checksums
find ./backups -name "*.md5" -mtime -1 -exec md5sum -c {} \;
```

## Off-Site Backups

### S3 Backup

```bash
# Install AWS CLI
sudo apt install awscli

# Configure
aws configure

# Upload backups
aws s3 sync ./backups/ s3://your-bucket/infrastructure-backups/ \
  --exclude "*.md5" \
  --storage-class STANDARD_IA
```

### Automated S3 Sync

Add to `scripts/backup-databases.sh`:

```bash
# At the end of the script
if command -v aws &> /dev/null; then
  echo "Syncing backups to S3..."
  aws s3 sync "$BACKUP_DIR" s3://your-bucket/infrastructure-backups/ \
    --storage-class STANDARD_IA
fi
```

### rsync to Remote Server

```bash
# Setup SSH key authentication first
ssh-copy-id user@backup-server

# Sync backups
rsync -avz --delete ./backups/ user@backup-server:/backups/infrastructure/
```

### Encrypted Backups

For sensitive data:

```bash
# Encrypt backup
gpg --symmetric --cipher-algo AES256 backup.sql.gz

# Decrypt
gpg backup.sql.gz.gpg
```

## Backup Best Practices

### DO:
- ✅ Test restores regularly
- ✅ Store backups off-site
- ✅ Encrypt sensitive backups
- ✅ Monitor backup success/failure
- ✅ Document restore procedures
- ✅ Keep multiple backup generations
- ✅ Verify backup integrity with checksums
- ✅ Automate backup process

### DON'T:
- ❌ Rely on a single backup
- ❌ Store backups only on the same server
- ❌ Never test restoration
- ❌ Forget to backup configuration files
- ❌ Ignore backup failures
- ❌ Keep backups forever (storage costs)

## Troubleshooting

### Backup Fails

**Check disk space:**

```bash
df -h
```

**Check container is running:**

```bash
docker ps | grep infra_postgres
```

**Check permissions:**

```bash
ls -la ./backups/
chmod +w ./backups/
```

### Restore Fails

**Check backup integrity:**

```bash
md5sum -c backup.sql.gz.md5
```

**Try uncompressing manually:**

```bash
gunzip -t backup.sql.gz
```

**Check for conflicts:**

```bash
# Drop database before restore
docker exec infra_postgres psql -U postgres -c "DROP DATABASE eduhub;"
```

### Checksum Mismatch

If checksum doesn't match:

1. **DO NOT use this backup**
2. Try previous backup
3. Check for disk corruption
4. Review backup logs for errors

---

**Remember:** Backups are only useful if you can restore from them. Test regularly!
