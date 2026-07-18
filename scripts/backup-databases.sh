#!/bin/bash
# Backup all PostgreSQL databases with compression and retention policy

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DAILY_RETENTION=7      # Keep 7 daily backups
WEEKLY_RETENTION=4     # Keep 4 weekly backups
MONTHLY_RETENTION=3    # Keep 3 monthly backups

echo "🗄️  Starting database backup..."
echo "   Timestamp: $TIMESTAMP"
echo "   Directory: $BACKUP_DIR"
echo ""

# Create backup directory structure if it doesn't exist
mkdir -p "$BACKUP_DIR/daily"
mkdir -p "$BACKUP_DIR/weekly"
mkdir -p "$BACKUP_DIR/monthly"

# Check if PostgreSQL is running
if ! docker ps --filter "name=infra_postgres" --format '{{.Names}}' | grep -q "infra_postgres"; then
    echo "❌ PostgreSQL container is not running!"
    exit 1
fi

# Determine backup type based on day of month/week
DAY_OF_WEEK=$(date +%u)  # 1-7 (Monday-Sunday)
DAY_OF_MONTH=$(date +%d) # 01-31

if [ "$DAY_OF_MONTH" = "01" ]; then
    BACKUP_TYPE="monthly"
elif [ "$DAY_OF_WEEK" = "7" ]; then
    BACKUP_TYPE="weekly"
else
    BACKUP_TYPE="daily"
fi

echo "Backup type: $BACKUP_TYPE"
echo ""

# Backup all databases with compression
echo "Backing up all databases..."
BACKUP_FILE="$BACKUP_DIR/$BACKUP_TYPE/all_databases_$TIMESTAMP.sql.gz"

docker exec infra_postgres pg_dumpall -U postgres | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Backup created: $BACKUP_FILE"

    # Get file size
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "   Size: $SIZE (compressed)"

    # Calculate checksum for integrity verification
    CHECKSUM=$(md5sum "$BACKUP_FILE" | awk '{print $1}')
    echo "$CHECKSUM  $BACKUP_FILE" > "$BACKUP_FILE.md5"
    echo "   Checksum: $CHECKSUM"
else
    echo "❌ Backup failed!"
    exit 1
fi

# Backup individual databases (optional, for easier restoration)
echo ""
echo "Backing up individual databases..."

DATABASES=$(docker exec infra_postgres psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';")

for db in $DATABASES; do
    db=$(echo "$db" | xargs)  # Trim whitespace
    if [ -n "$db" ]; then
        echo "  - Backing up $db..."
        INDIVIDUAL_BACKUP="$BACKUP_DIR/$BACKUP_TYPE/${db}_$TIMESTAMP.sql.gz"
        docker exec infra_postgres pg_dump -U postgres "$db" | gzip > "$INDIVIDUAL_BACKUP"

        # Checksum for individual backup
        md5sum "$INDIVIDUAL_BACKUP" | awk '{print $1}' > "$INDIVIDUAL_BACKUP.md5"
    fi
done

# Backup Redis data
echo ""
echo "Backing up Redis data..."
if docker ps --filter "name=infra_redis" --format '{{.Names}}' | grep -q "infra_redis"; then
    REDIS_BACKUP="$BACKUP_DIR/$BACKUP_TYPE/redis_$TIMESTAMP.rdb.gz"
    docker exec infra_redis redis-cli SAVE >/dev/null 2>&1
    docker cp infra_redis:/data/dump.rdb - | gzip > "$REDIS_BACKUP"
    echo "✅ Redis backup created: $REDIS_BACKUP"
else
    echo "⚠️  Redis container not running, skipping Redis backup"
fi

echo ""
echo "✅ All backups complete!"
echo "   Location: $BACKUP_DIR/$BACKUP_TYPE"

# Retention policy cleanup
echo ""
echo "Applying retention policy..."
echo "  - Daily backups: keeping last $DAILY_RETENTION"
echo "  - Weekly backups: keeping last $WEEKLY_RETENTION"
echo "  - Monthly backups: keeping last $MONTHLY_RETENTION"

# Clean daily backups (keep last N files)
if [ -d "$BACKUP_DIR/daily" ]; then
    ls -t "$BACKUP_DIR/daily/"*.sql.gz 2>/dev/null | tail -n +$((DAILY_RETENTION + 1)) | xargs -r rm -f
    ls -t "$BACKUP_DIR/daily/"*.md5 2>/dev/null | tail -n +$((DAILY_RETENTION + 1)) | xargs -r rm -f
fi

# Clean weekly backups
if [ -d "$BACKUP_DIR/weekly" ]; then
    ls -t "$BACKUP_DIR/weekly/"*.sql.gz 2>/dev/null | tail -n +$((WEEKLY_RETENTION + 1)) | xargs -r rm -f
    ls -t "$BACKUP_DIR/weekly/"*.md5 2>/dev/null | tail -n +$((WEEKLY_RETENTION + 1)) | xargs -r rm -f
fi

# Clean monthly backups
if [ -d "$BACKUP_DIR/monthly" ]; then
    ls -t "$BACKUP_DIR/monthly/"*.sql.gz 2>/dev/null | tail -n +$((MONTHLY_RETENTION + 1)) | xargs -r rm -f
    ls -t "$BACKUP_DIR/monthly/"*.md5 2>/dev/null | tail -n +$((MONTHLY_RETENTION + 1)) | xargs -r rm -f
fi

echo "✅ Cleanup complete!"

# Summary
echo ""
echo "📊 Backup Summary:"
find "$BACKUP_DIR" -name "*.sql.gz" -o -name "*.rdb.gz" | while read file; do
    SIZE=$(du -h "$file" | cut -f1)
    echo "  - $(basename $file): $SIZE"
done
