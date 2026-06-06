#!/bin/bash
# Backup all PostgreSQL databases

set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "🗄️  Starting database backup..."
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if PostgreSQL is running
if ! docker ps --filter "name=infra_postgres" --format '{{.Names}}' | grep -q "infra_postgres"; then
    echo "❌ PostgreSQL container is not running!"
    exit 1
fi

# Backup all databases
echo "Backing up all databases..."
docker exec infra_postgres pg_dumpall -U postgres > "$BACKUP_DIR/all_databases_$TIMESTAMP.sql"

if [ $? -eq 0 ]; then
    echo "✅ Backup created: $BACKUP_DIR/all_databases_$TIMESTAMP.sql"

    # Get file size
    SIZE=$(du -h "$BACKUP_DIR/all_databases_$TIMESTAMP.sql" | cut -f1)
    echo "   Size: $SIZE"
else
    echo "❌ Backup failed!"
    exit 1
fi

# Backup individual databases
echo ""
echo "Backing up individual databases..."

DATABASES=$(docker exec infra_postgres psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';")

for db in $DATABASES; do
    echo "  - Backing up $db..."
    docker exec infra_postgres pg_dump -U postgres "$db" > "$BACKUP_DIR/${db}_$TIMESTAMP.sql"
done

echo ""
echo "✅ All backups complete!"
echo "   Location: $BACKUP_DIR"

# Optional: Keep only last 7 days of backups
echo ""
echo "Cleaning up old backups (keeping last 7 days)..."
find "$BACKUP_DIR" -name "*.sql" -type f -mtime +7 -delete
echo "✅ Cleanup complete!"
