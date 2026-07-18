#!/bin/bash
# Setup PgBouncer userlist with MD5 passwords

set -e

echo "🔧 PgBouncer User Setup"
echo ""

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Reading password from databases/.env"
    if [ -f "databases/.env" ]; then
        source databases/.env
    else
        echo "❌ databases/.env not found"
        exit 1
    fi
fi

USER="${POSTGRES_USER:-postgres}"
PASS="$POSTGRES_PASSWORD"

echo "Generating MD5 hash for user: $USER"

# Generate MD5 hash: md5 + md5(password + username)
HASH=$(echo -n "${PASS}${USER}" | md5sum | awk '{print "md5" $1}')

# Create userlist.txt
cat > databases/pgbouncer/userlist.txt <<EOF
"$USER" "$HASH"
EOF

chmod 600 databases/pgbouncer/userlist.txt

echo "✅ PgBouncer userlist created"
echo ""
echo "To add more users:"
echo "1. Create user in PostgreSQL"
echo "2. Add line to databases/pgbouncer/userlist.txt"
echo "3. Restart PgBouncer: docker restart infra_pgbouncer"
