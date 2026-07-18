#!/bin/bash
# Enable PostgreSQL audit logging using pgAudit extension

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "📋 PostgreSQL Audit Logging Setup"
echo ""

POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-infra_postgres}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

# Check if container is running
if ! docker ps | grep -q "$POSTGRES_CONTAINER"; then
    echo -e "${RED}❌ PostgreSQL container is not running${NC}"
    exit 1
fi

echo "Installing pgAudit extension..."

# Install pgAudit extension
docker exec -i "$POSTGRES_CONTAINER" bash << 'EOF'
apt-get update
apt-get install -y postgresql-16-pgaudit
EOF

echo -e "${GREEN}✅ pgAudit installed${NC}"
echo ""

# Enable pgAudit in PostgreSQL configuration
echo "Enabling pgAudit in postgresql.conf..."

docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -c "ALTER SYSTEM SET shared_preload_libraries = 'pgaudit';"
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -c "ALTER SYSTEM SET pgaudit.log = 'write, ddl, role';"
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -c "ALTER SYSTEM SET pgaudit.log_catalog = off;"
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -c "ALTER SYSTEM SET pgaudit.log_parameter = on;"
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -c "ALTER SYSTEM SET pgaudit.log_relation = on;"
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -c "ALTER SYSTEM SET pgaudit.log_statement_once = off;"
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -c "ALTER SYSTEM SET log_connections = on;"
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -c "ALTER SYSTEM SET log_disconnections = on;"
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -c "ALTER SYSTEM SET log_line_prefix = '%m [%p] %q%u@%d ';"

echo -e "${GREEN}✅ pgAudit configuration applied${NC}"
echo ""

echo -e "${YELLOW}⚠️  PostgreSQL needs to be restarted for changes to take effect${NC}"
echo "Run: docker restart $POSTGRES_CONTAINER"
echo ""

# Create audit log processor script
AUDIT_LOG_DIR="../audit/logs"
mkdir -p "$AUDIT_LOG_DIR"

cat > "$AUDIT_LOG_DIR/process-postgres-logs.sh" << 'SCRIPT'
#!/bin/bash
# Process PostgreSQL logs into structured audit format

CONTAINER="${1:-infra_postgres}"
OUTPUT_FILE="${2:-/var/log/audit/postgres-audit.log}"

docker logs -f "$CONTAINER" 2>&1 | while read -r line; do
    # Parse PostgreSQL log format
    if [[ "$line" =~ AUDIT ]]; then
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # Extract user, database, and query
        user=$(echo "$line" | grep -oP '(?<=user=)[^\s,]+' || echo "unknown")
        database=$(echo "$line" | grep -oP '(?<=database=)[^\s,]+' || echo "unknown")
        statement=$(echo "$line" | grep -oP 'STATEMENT:.*' || echo "unknown")

        # Determine query type
        query_type="unknown"
        if [[ "$statement" =~ ^INSERT ]]; then query_type="INSERT"
        elif [[ "$statement" =~ ^UPDATE ]]; then query_type="UPDATE"
        elif [[ "$statement" =~ ^DELETE ]]; then query_type="DELETE"
        elif [[ "$statement" =~ ^SELECT ]]; then query_type="SELECT"
        elif [[ "$statement" =~ ^CREATE ]]; then query_type="CREATE"
        elif [[ "$statement" =~ ^DROP ]]; then query_type="DROP"
        elif [[ "$statement" =~ ^ALTER ]]; then query_type="ALTER"
        fi

        # Output as structured JSON
        echo "{\"timestamp\":\"$timestamp\",\"user\":\"$user\",\"database\":\"$database\",\"query_type\":\"$query_type\",\"query\":\"$statement\",\"client_ip\":\"container\"}" >> "$OUTPUT_FILE"
    fi
done
SCRIPT

chmod +x "$AUDIT_LOG_DIR/process-postgres-logs.sh"

echo -e "${GREEN}✅ Audit log processor created${NC}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ PostgreSQL audit logging setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "1. Restart PostgreSQL: docker restart $POSTGRES_CONTAINER"
echo "2. Start audit log processor: $AUDIT_LOG_DIR/process-postgres-logs.sh"
echo "3. Verify extension: docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -c 'SHOW shared_preload_libraries;'"
echo ""
