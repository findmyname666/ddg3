.PHONY: help dev-up dev-down dev-logs sqlc test clean

COMPOSE_DEV_FILE := docker-compose.dev.yml

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Docker Compose Development Environment
dev-up: ## Start development environment (PostgreSQL, web app, nginx)
	docker compose -f "$(COMPOSE_DEV_FILE)" up -d --build
	@echo ""
	@echo "✓ Development environment started!"
	@echo ""
	@echo "Services (from the host):"
	@echo "  - PostgreSQL: not exposed on localhost (use docker exec into feedduck-postgres-dev)"
	@echo "  - Web app (direct): http://127.0.0.1:8080"
	@echo "  - Web app (via nginx): https://localhost or https://feedduck.localhost"
	@echo "  - Nginx: 127.0.0.1:443 (HTTPS only, no port 80)"
	@echo ""
	@echo "View logs: make dev-logs"

dev-down: ## Stop development environment
	docker compose -f "$(COMPOSE_DEV_FILE)" down

dev-down-volumes: ## Stop development environment and remove volumes
	docker compose -f "$(COMPOSE_DEV_FILE)" down -v
	@echo "✓ Development environment stopped and volumes removed"

dev-logs: ## Show logs from development environment
	docker compose -f "$(COMPOSE_DEV_FILE)" logs -f

dev-restart: ## Restart development environment
	docker compose -f "$(COMPOSE_DEV_FILE)" restart

# Code generation
sqlc: ## Generate Go code from SQL queries using sqlc
	cd app/feedback && sqlc generate
	@echo "✓ Generated Go code in app/feedback/pkgs/db/"

# Go Development
go-deps: ## Install Go dependencies
	@echo "Installing Go dependencies..."
	cd app/feedback && go mod tidy
	@echo "✓ Dependencies installed"

go-test: ## Run Go tests
	cd app/feedback && go test -v ./...

go-build: ## Build feedback application binary
	@echo "Building feedback application..."
	cd app/feedback && go build -o ../../bin/feedback ./cmd/feedback
	@echo "✓ Build complete: bin/feedback"
	@echo ""
	@echo "Usage:"
	@echo "  bin/feedback web       - Run web server"
	@echo "  bin/feedback analysis  - Run analysis job"
	@echo "  bin/feedback migrate   - Run database migrations"

go-lint: ## Run Go linters
	cd app/feedback && golangci-lint run ./...

go-fmt: ## Format Go code
	cd app/feedback && go fmt ./...

# Clean
clean: ## Clean build artifacts
	rm -rf bin/
	@echo "✓ Build artifacts cleaned"

# Markdown Linting
lint-md: ## Lint all markdown files
	@echo "Linting markdown files..."
	@find . -name "*.md" -not -path "*/node_modules/*" -not -path "*/.terraform/*" -not -path "*/vendor/*" | xargs markdownlint --config=markdownlint.yaml
	@echo "✓ Markdown files passed linting"

# SSL Certificate Generation
ssl-dev: ## Generate self-signed SSL certificate for development
	@echo "Generating self-signed SSL certificate for development..."
	@mkdir -p app/nginx/ssl
	@openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
		-keyout app/nginx/ssl/privkey.pem \
		-out app/nginx/ssl/fullchain.pem \
		-subj "/C=US/ST=State/L=City/O=FeedDuck Dev/CN=localhost" \
		-addext "subjectAltName=DNS:localhost,DNS:feedduck.localhost,IP:127.0.0.1"
	@chmod 644 app/nginx/ssl/*.pem
	@echo "✓ Self-signed certificate generated in app/nginx/ssl/"
	@echo "  - Certificate: app/nginx/ssl/fullchain.pem"
	@echo "  - Private key: app/nginx/ssl/privkey.pem"
	@echo "  - Valid for: 30 days"
	@echo "  - Domains: localhost, feedduck.localhost, 127.0.0.1"
