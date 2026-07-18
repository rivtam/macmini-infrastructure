#!/bin/bash
# Restore PostgreSQL databases from backup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BACKUP_DIR="${BACKUP_DIR:-./backups}"

echo "🔄 Database Restore Utility"
echo ""

# Check if PostgreSQL is running
if ! docker ps --filter "name=infra_postgres" --format '{{.Names}}' | grep -q "infra_postgres"; then
    echo -e "${RED}❌ PostgreSQL container is not running!${NC}"
    exit 1
fi

# Function to list available backups
list_backups() {
    echo "Available backups:"
    echo ""

    for type in daily weekly monthly; do
        if [ -d "$BACKUP_DIR/$type" ]; then
            echo -e "${YELLOW}$type backups:${NC}"
            find "$BACKUP_DIR/$type" -name "all_databases_*.sql.gz" | sort -r | while read file; do
                SIZE=$(du -h "$file" | cut -f1)
                BASENAME=$(basename "$file")
                echo "  - $BASENAME ($SIZE)"
            done
            echo ""
        fi
    done
}

# Function to verify backup integrity
verify_backup() {
    local backup_file=$1
    local md5_file="${backup_file}.md5"

    if [ -f "$md5_file" ]; then
        echo "Verifying backup integrity..."
        STORED_MD5=$(cat "$md5_file" | awk '{print $1}')
        CURRENT_MD5=$(md5sum "$backup_file" | awk '{print $1}')

        if [ "$STORED_MD5" = "$CURRENT_MD5" ]; then
            echo -e "${GREEN}✅ Backup integrity verified${NC}"
            return 0
        else
            echo -e "${RED}❌ Backup integrity check failed!${NC}"
            echo "   Stored MD5:  $STORED_MD5"
            echo "   Current MD5: $CURRENT_MD5"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  No checksum file found, skipping verification${NC}"
        return 0
    fi
}

# Function to restore from backup
restore_backup() {
    local backup_file=$1

    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ Backup file not found: $backup_file${NC}"
        exit 1
    fi

    echo "Backup file: $backup_file"

    # Verify integrity
    if ! verify_backup "$backup_file"; then
        read -p "Continue anyway? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "Restore cancelled"
            exit 1
        fi
    fi

    # Warning
    echo ""
    echo -e "${RED}⚠️  WARNING: This will DROP and recreate all databases!${NC}"
    echo -e "${RED}   All existing data will be lost!${NC}"
    echo ""
    read -p "Type 'RESTORE' to continue: " confirm

    if [ "$confirm" != "RESTORE" ]; then
        echo "Restore cancelled"
        exit 1
    fi

    echo ""
    echo "Starting restore..."

    # Restore
    gunzip -c "$backup_file" | docker exec -i infra_postgres psql -U postgres

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Restore completed successfully!${NC}"
    else
        echo ""
        echo -e "${RED}❌ Restore failed!${NC}"
        exit 1
    fi
}

# Function to restore individual database
restore_individual() {
    local backup_file=$1
    local database=$2

    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ Backup file not found: $backup_file${NC}"
        exit 1
    fi

    echo "Backup file: $backup_file"
    echo "Database: $database"

    # Verify integrity
    verify_backup "$backup_file"

    # Warning
    echo ""
    echo -e "${YELLOW}⚠️  This will restore to database: $database${NC}"
    read -p "Continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "Restore cancelled"
        exit 1
    fi

    echo ""
    echo "Starting restore..."

    # Create database if it doesn't exist
    docker exec infra_postgres psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$database'" | grep -q 1 || \
        docker exec infra_postgres psql -U postgres -c "CREATE DATABASE $database"

    # Restore
    gunzip -c "$backup_file" | docker exec -i infra_postgres psql -U postgres -d "$database"

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Restore completed successfully!${NC}"
    else
        echo ""
        echo -e "${RED}❌ Restore failed!${NC}"
        exit 1
    fi
}

# Main menu
if [ $# -eq 0 ]; then
    list_backups
    echo ""
    echo "Usage:"
    echo "  $0 <backup-file>                    # Restore all databases"
    echo "  $0 <backup-file> <database-name>    # Restore single database"
    echo ""
    echo "Examples:"
    echo "  $0 ./backups/daily/all_databases_20240101_120000.sql.gz"
    echo "  $0 ./backups/daily/eduhub_20240101_120000.sql.gz eduhub"
    exit 0
fi

BACKUP_FILE=$1
DATABASE=$2

if [ -n "$DATABASE" ]; then
    restore_individual "$BACKUP_FILE" "$DATABASE"
else
    restore_backup "$BACKUP_FILE"
fi
