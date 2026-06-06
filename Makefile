.PHONY: help start-all stop-all start-databases start-nginx start-monitoring logs clean health ps status

help: ## Show this help message
	@echo "Mac Mini Infrastructure Management"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ============================================================================
# Starting Services
# ============================================================================

start-all: ## Start all infrastructure services
	@echo "🚀 Starting all infrastructure services..."
	@docker network create infra_network 2>/dev/null || true
	@cd databases && docker compose up -d
	@echo "⏳ Waiting for databases to be healthy..."
	@sleep 5
	@cd monitoring && docker compose up -d
	@cd nginx && docker compose up -d
	@echo "✅ All services started!"
	@make status

start-databases: ## Start database services (postgres, redis)
	@echo "🗄️  Starting databases..."
	@docker network create infra_network 2>/dev/null || true
	@cd databases && docker compose up -d
	@echo "⏳ Waiting for databases to be ready..."
	@sleep 5
	@echo "✅ Databases started:"
	@echo "   PostgreSQL: localhost:5432"
	@echo "   Redis:      localhost:6379"

start-nginx: ## Start nginx gateway
	@echo "🌐 Starting nginx gateway..."
	@docker network create infra_network 2>/dev/null || true
	@cd nginx && docker compose up -d
	@echo "✅ Nginx started:"
	@echo "   HTTP:  localhost:80"
	@echo "   HTTPS: localhost:443"

start-monitoring: ## Start monitoring stack (prometheus, grafana)
	@echo "📊 Starting monitoring stack..."
	@docker network create infra_network 2>/dev/null || true
	@cd monitoring && docker compose up -d
	@echo "✅ Monitoring started:"
	@echo "   Prometheus: http://localhost:9090"
	@echo "   Grafana:    http://localhost:3000"

# ============================================================================
# Stopping Services
# ============================================================================

stop-all: ## Stop all infrastructure services
	@echo "🛑 Stopping all services..."
	@cd nginx && docker compose down 2>/dev/null || true
	@cd monitoring && docker compose down 2>/dev/null || true
	@cd databases && docker compose down 2>/dev/null || true
	@echo "✅ All services stopped"

stop-databases: ## Stop database services
	@cd databases && docker compose down

stop-nginx: ## Stop nginx gateway
	@cd nginx && docker compose down

stop-monitoring: ## Stop monitoring stack
	@cd monitoring && docker compose down

# ============================================================================
# Restarting Services
# ============================================================================

restart-all: stop-all start-all ## Restart all services

restart-databases: ## Restart database services
	@cd databases && docker compose restart

restart-nginx: ## Restart nginx gateway
	@cd nginx && docker compose restart

restart-monitoring: ## Restart monitoring stack
	@cd monitoring && docker compose restart

# ============================================================================
# Logs
# ============================================================================

logs: ## Show logs from all services
	@docker compose -f databases/docker-compose.yml -f monitoring/docker-compose.yml -f nginx/docker-compose.yml logs -f

logs-databases: ## Show database logs
	@cd databases && docker compose logs -f

logs-nginx: ## Show nginx logs
	@cd nginx && docker compose logs -f

logs-monitoring: ## Show monitoring logs
	@cd monitoring && docker compose logs -f

# ============================================================================
# Health & Status
# ============================================================================

health: ## Check health of all services
	@./scripts/health-check.sh

status: ## Show status of all services
	@echo "📋 Infrastructure Status:"
	@echo ""
	@docker ps --filter "name=infra_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

ps: ## Show all running containers
	@docker ps --filter "name=infra_"

# ============================================================================
# Database Operations
# ============================================================================

db-connect: ## Connect to PostgreSQL (usage: make db-connect DB=eduhub)
	@docker exec -it infra_postgres psql -U postgres -d ${DB:-postgres}

db-backup: ## Backup all databases
	@./scripts/backup-databases.sh

redis-cli: ## Connect to Redis CLI
	@docker exec -it infra_redis redis-cli

# ============================================================================
# Nginx Operations
# ============================================================================

nginx-test: ## Test nginx configuration
	@cd nginx && docker compose --profile test run --rm nginx-test

nginx-reload: ## Reload nginx configuration
	@docker exec infra_nginx nginx -s reload
	@echo "✅ Nginx configuration reloaded"

# ============================================================================
# Monitoring Operations
# ============================================================================

open-grafana: ## Open Grafana in browser
	@open http://localhost:3000 || xdg-open http://localhost:3000 2>/dev/null || echo "Open http://localhost:3000 in your browser"

open-prometheus: ## Open Prometheus in browser
	@open http://localhost:9090 || xdg-open http://localhost:9090 2>/dev/null || echo "Open http://localhost:9090 in your browser"

# ============================================================================
# Cleanup
# ============================================================================

clean: ## Stop all services and remove volumes (WARNING: deletes data)
	@echo "⚠️  WARNING: This will delete all data in volumes!"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
	@sleep 5
	@cd nginx && docker compose down -v 2>/dev/null || true
	@cd monitoring && docker compose down -v 2>/dev/null || true
	@cd databases && docker compose down -v 2>/dev/null || true
	@docker network rm infra_network 2>/dev/null || true
	@echo "✅ All services stopped and data removed"

prune: ## Remove unused Docker resources
	@docker system prune -f
	@echo "✅ Docker cleanup complete"

# ============================================================================
# Setup & Configuration
# ============================================================================

init: ## Initialize infrastructure (create .env files)
	@./scripts/init-env.sh

setup: init start-all ## Full setup - create configs and start all services
	@echo "🎉 Infrastructure setup complete!"

# ============================================================================
# Development
# ============================================================================

dev: ## Start infrastructure in development mode
	@echo "🔧 Starting infrastructure in development mode..."
	@docker network create infra_network 2>/dev/null || true
	@cd databases && docker compose up -d
	@echo "✅ Development environment ready"
	@echo "   PostgreSQL: localhost:5432"
	@echo "   Redis:      localhost:6379"
