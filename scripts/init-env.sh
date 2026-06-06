#!/bin/bash
# Initialize environment files for all services

set -e

echo "🔧 Initializing infrastructure environment files..."
echo ""

# Function to create .env from .env.example if it doesn't exist
init_env() {
    local dir=$1
    local service_name=$2

    if [ -f "$dir/.env" ]; then
        echo "✅ $service_name: .env already exists"
    else
        if [ -f "$dir/.env.example" ]; then
            cp "$dir/.env.example" "$dir/.env"
            echo "✅ $service_name: Created .env from .env.example"
        else
            echo "⚠️  $service_name: No .env.example found"
        fi
    fi
}

# Initialize each service
init_env "databases" "Databases"
init_env "nginx" "Nginx"
init_env "monitoring" "Monitoring"

echo ""
echo "🔐 IMPORTANT: Update passwords in the following files:"
echo "   - databases/.env (POSTGRES_PASSWORD)"
echo "   - monitoring/.env (GRAFANA_ADMIN_PASSWORD)"
echo ""
echo "✅ Environment initialization complete!"
