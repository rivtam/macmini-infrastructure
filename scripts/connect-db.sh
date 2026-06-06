#!/bin/bash
# Quick script to connect to a PostgreSQL database

DB=${1:-postgres}

echo "🗄️  Connecting to database: $DB"

docker exec -it infra_postgres psql -U postgres -d "$DB"
