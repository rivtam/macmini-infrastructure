#!/bin/bash
# Setup automated backups via cron

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

echo "🕒 Setting up automated database backups..."
echo ""
echo "Infrastructure directory: $INFRA_DIR"
echo ""

# Create cron job entry
CRON_ENTRY="0 2 * * * cd $INFRA_DIR && ./scripts/backup-databases.sh >> $INFRA_DIR/logs/backup-cron.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "backup-databases.sh"; then
    echo "⚠️  Backup cron job already exists!"
    echo ""
    echo "Current cron job:"
    crontab -l | grep "backup-databases.sh"
    echo ""
    read -p "Replace existing cron job? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "Setup cancelled"
        exit 0
    fi

    # Remove old cron job
    crontab -l | grep -v "backup-databases.sh" | crontab -
    echo "✅ Old cron job removed"
fi

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

echo "✅ Backup cron job installed!"
echo ""
echo "Schedule: Daily at 2:00 AM"
echo "Log file: $INFRA_DIR/logs/backup-cron.log"
echo ""
echo "Current crontab:"
crontab -l | grep "backup-databases.sh"
echo ""
echo "To view logs:"
echo "  tail -f $INFRA_DIR/logs/backup-cron.log"
echo ""
echo "To remove automated backups:"
echo "  crontab -l | grep -v 'backup-databases.sh' | crontab -"
echo ""
echo "Note: Make sure the backup script has execute permissions:"
echo "  chmod +x $INFRA_DIR/scripts/backup-databases.sh"
