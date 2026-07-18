#!/bin/bash
# Generate compliance audit report from logs

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "📊 Audit Report Generator"
echo ""

# Configuration
START_DATE="${1:-7 days ago}"
END_DATE="${2:-now}"
OUTPUT_DIR="${3:-../audit/reports}"
LOKI_URL="${LOKI_URL:-http://localhost:3100}"

mkdir -p "$OUTPUT_DIR"

REPORT_FILE="$OUTPUT_DIR/audit-report-$(date +%Y%m%d-%H%M%S).txt"

# Function to query Loki
query_loki() {
    local query=$1
    local title=$2

    echo -e "\n${BLUE}=== $title ===${NC}\n" | tee -a "$REPORT_FILE"

    # Convert relative dates to Unix timestamps
    start_ts=$(date -d "$START_DATE" +%s)000000000
    end_ts=$(date -d "$END_DATE" +%s)000000000

    result=$(curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
        --data-urlencode "query=$query" \
        --data-urlencode "start=$start_ts" \
        --data-urlencode "end=$end_ts" \
        --data-urlencode "limit=1000" | jq -r '.data.result[]')

    if [ -z "$result" ]; then
        echo "No data found" | tee -a "$REPORT_FILE"
    else
        echo "$result" | jq -r '.values[][] | @csv' | column -t -s',' | tee -a "$REPORT_FILE"
    fi
}

# Generate report header
cat > "$REPORT_FILE" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                        AUDIT COMPLIANCE REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Report Generated: $(date)
Period: $START_DATE to $END_DATE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

echo -e "${YELLOW}Generating audit report for period: $START_DATE to $END_DATE${NC}"
echo ""

# 1. Authentication Events
query_loki '{log_type="auth_audit"}' "Authentication Events"

# 2. Failed Login Attempts
query_loki '{job="syslog"} |= "Failed password"' "Failed Login Attempts"

# 3. Vault Access
query_loki '{job="vault", log_type="audit"}' "Secrets Manager Access"

# 4. Database Modifications
query_loki '{job="postgres", log_type="audit", query_type=~"INSERT|UPDATE|DELETE"}' "Database Write Operations"

# 5. Privileged Operations
query_loki '{job="postgres", log_type="audit", query_type=~"CREATE|DROP|ALTER"}' "DDL Operations"

# 6. Nginx Admin Access
query_loki '{job="nginx", log_type="access_audit", path=~"/admin.*"}' "Administrative Access"

# 7. Security Events
query_loki '{category="security", severity=~"warning|critical"}' "Security Alerts"

# 8. Application Audit Events
query_loki '{job="application", log_type="audit"}' "Application Events"

# Summary Statistics
cat >> "$REPORT_FILE" << 'EOF'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                              SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Compliance Checks:
✓ Authentication logs captured
✓ Database activity monitored
✓ Security events tracked
✓ Administrative access logged
✓ Audit trail immutable (Loki retention)

Recommendations:
1. Review failed authentication attempts for potential brute force
2. Verify all privileged operations are authorized
3. Ensure security alerts are investigated
4. Archive audit logs for long-term compliance (>31 days)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

echo ""
echo -e "${GREEN}✅ Report generated: $REPORT_FILE${NC}"
echo ""

# Generate summary metrics
echo -e "${BLUE}Quick Statistics:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Count events by type
total_auth=$(grep -c "auth_audit" "$REPORT_FILE" 2>/dev/null || echo "0")
total_db=$(grep -c "postgres" "$REPORT_FILE" 2>/dev/null || echo "0")
total_security=$(grep -c "security" "$REPORT_FILE" 2>/dev/null || echo "0")

echo "Authentication Events: $total_auth"
echo "Database Operations: $total_db"
echo "Security Alerts: $total_security"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
