# CakePHP workspace — development commands
# Run `make help` for all targets

SHELL := /bin/bash
ROOT  := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Read APP_PATH from workspace .env at parse time.
# After `make setup` writes it, a fresh make invocation picks it up.
APP_DIR := $(shell grep -s '^APP_PATH=' '$(ROOT).env' 2>/dev/null | cut -d= -f2-)
ifeq ($(APP_DIR),)
  APP_DIR := $(ROOT)app
endif

DOCKER_DIR  := $(ROOT)docker
COMPOSE     := docker compose --env-file $(ROOT).env -f $(DOCKER_DIR)/compose.yml
FRANKENPHP  := $(COMPOSE) exec frankenphp

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# --- Workspace setup ---

.PHONY: setup reconfigure init env
setup: ## Detect / select CakePHP app; offers to switch if already configured
	@bash "$(ROOT)scripts/setup.sh"

reconfigure: ## Force re-selection of the active CakePHP app (non-interactive-safe)
	@bash "$(ROOT)scripts/setup.sh" --reconfigure

init: ## First-time setup: configure app, build containers, install deps, migrate
	@bash "$(ROOT)scripts/setup.sh"
	@$(MAKE) --no-print-directory _init

.PHONY: _init
_init:
	@APP_DIR=$$(grep -s '^APP_PATH=' '$(ROOT).env' | cut -d= -f2-); \
	test -n "$$APP_DIR" || (echo "ERROR: APP_PATH not set. Run: make setup"; exit 1); \
	test -f "$$APP_DIR/bin/cake" || (echo "ERROR: App not found at $$APP_DIR. Run: make setup"; exit 1)
	$(COMPOSE) build
	$(COMPOSE) up -d
	$(MAKE) --no-print-directory app-install
	$(MAKE) --no-print-directory migrate
	@echo ""
	@echo "  App        http://localhost:$${APP_HTTP_PORT:-8080}"
	@echo "  Mailpit    http://localhost:$${MAILPIT_UI_PORT:-8025}"
	@echo "  phpMyAdmin http://localhost:$${PMA_PORT:-8081}"
	@echo ""
	@echo "  Run 'make vite' in a second terminal if the app has a frontend build step."
	@echo ""

env: ## Copy .env templates and patch app config/.env for Docker services
	@test -f "$(ROOT).env" || cp "$(ROOT).env.example" "$(ROOT).env"
	@if [ -f "$(APP_DIR)/config/app_local.example.php" ] && [ ! -f "$(APP_DIR)/config/app_local.php" ]; then \
		cp "$(APP_DIR)/config/app_local.example.php" "$(APP_DIR)/config/app_local.php"; \
	fi
	@if [ -f "$(APP_DIR)/config/.env.example" ] && [ ! -f "$(APP_DIR)/config/.env" ]; then \
		cp "$(APP_DIR)/config/.env.example" "$(APP_DIR)/config/.env"; \
	fi
	@bash "$(ROOT)scripts/patch-app-env.sh" "$(APP_DIR)/config/.env"

# --- Docker ---

.PHONY: up down restart build logs ps
up: ## Start all core services
	$(COMPOSE) up -d

down: ## Stop and remove containers
	$(COMPOSE) down

restart: ## Restart FrankenPHP
	$(COMPOSE) restart frankenphp

build: ## Rebuild FrankenPHP image
	$(COMPOSE) build --no-cache

logs: ## Follow container logs
	$(COMPOSE) logs -f

ps: ## Show running services
	$(COMPOSE) ps

.PHONY: workers-up workers-down
workers-up: ## Start queue worker (compose profile: workers; requires cakephp/queue plugin)
	$(COMPOSE) --profile workers up -d queue

workers-down: ## Stop queue worker
	$(COMPOSE) --profile workers stop queue

# --- CakePHP (inside FrankenPHP container) ---

.PHONY: shell cake composer npm
shell: ## Open shell in FrankenPHP container
	$(FRANKENPHP) bash

cake: ## Run bin/cake (ARGS="migrations migrate")
	$(FRANKENPHP) bin/cake $(ARGS)

composer: ## Run composer in app (ARGS="install")
	$(FRANKENPHP) composer $(ARGS)

npm: ## Run npm on host (ARGS="run dev") — only if the app has a JS build step
	cd "$(APP_DIR)" && npm $(ARGS)

.PHONY: app-install migrate rollback migration-status seed fresh bake test cs-check cs-fix stan
app-install: ## composer install (+ npm install if package.json exists)
	$(FRANKENPHP) composer install --no-interaction
	@if [ -f "$(APP_DIR)/package.json" ]; then cd "$(APP_DIR)" && npm install; fi

migrate: ## Run database migrations (cakephp/migrations)
	$(FRANKENPHP) bin/cake migrations migrate

rollback: ## Roll back the last migration
	$(FRANKENPHP) bin/cake migrations rollback

migration-status: ## Show migration status
	$(FRANKENPHP) bin/cake migrations status

seed: ## Run migration seeders
	$(FRANKENPHP) bin/cake migrations seed

fresh: ## Roll back all migrations and re-migrate (drops and rebuilds schema)
	$(FRANKENPHP) bin/cake migrations rollback --target=0 --force
	$(FRANKENPHP) bin/cake migrations migrate

bake: ## Run bin/cake bake (ARGS="model Users")
	$(FRANKENPHP) bin/cake bake $(ARGS)

test: ## Run PHPUnit
	$(FRANKENPHP) vendor/bin/phpunit

cs-check: ## Check coding standards (phpcs, if configured)
	$(FRANKENPHP) vendor/bin/phpcs --colors -p src/ tests/

cs-fix: ## Auto-fix coding standards (phpcbf, if configured)
	$(FRANKENPHP) vendor/bin/phpcbf src/ tests/

stan: ## Run PHPStan (if configured)
	$(FRANKENPHP) vendor/bin/phpstan analyse

.PHONY: cache-clear schema-cache-build schema-cache-clear
cache-clear: ## Clear all CakePHP caches
	$(FRANKENPHP) bin/cake cache clear_all

schema-cache-build: ## Build ORM schema cache
	$(FRANKENPHP) bin/cake orm_cache build

schema-cache-clear: ## Clear ORM schema cache
	$(FRANKENPHP) bin/cake orm_cache clear

# --- Dev workflow ---

.PHONY: dev vite
dev: up workers-up ## Start stack + queue worker (run npm separately if needed)
	@echo "If the app has a frontend build step, run it in another terminal (e.g. make npm ARGS=\"run dev\")."

vite: ## Start npm dev server on host (only if the app has a JS build step)
	cd "$(APP_DIR)" && npm run dev

# --- Database ---

.PHONY: mysql redis-cli dump restore
mysql: ## MariaDB CLI
	$(COMPOSE) exec mariadb mariadb -u$${DB_USERNAME} -p$${DB_PASSWORD} $${DB_DATABASE}

redis-cli: ## Redis CLI
	$(COMPOSE) exec redis redis-cli

dump: ## Dump database to dumps/YYYY-MM-DD_HH-MM-SS.sql
	@mkdir -p "$(ROOT)dumps"
	@FILE="$(ROOT)dumps/$$(date +%Y-%m-%d_%H-%M-%S).sql"; \
	$(COMPOSE) exec -T mariadb mariadb-dump -u$${DB_USERNAME} -p$${DB_PASSWORD} $${DB_DATABASE} > "$$FILE" && \
	echo "Saved: $$FILE"

restore: ## Restore database from FILE=dumps/x.sql
	@test -n "$(FILE)" || (echo "Usage: make restore FILE=dumps/x.sql"; exit 1)
	$(COMPOSE) exec -T mariadb mariadb -u$${DB_USERNAME} -p$${DB_PASSWORD} $${DB_DATABASE} < "$(FILE)"
	@echo "Restored: $(FILE)"

# --- Cleanup ---

.PHONY: clean destroy
clean: ## Remove stopped containers and dangling images
	$(COMPOSE) down --remove-orphans
	docker image prune -f

destroy: ## Stop containers and delete all volumes — DELETES ALL DATA
	@if [ -t 0 ]; then \
		printf "This will permanently delete all database data and volumes. Continue? [y/N] "; \
		read ans; \
		[ "$$ans" = "y" ] || [ "$$ans" = "Y" ] || (echo "Aborted."; exit 1); \
	fi
	$(COMPOSE) down -v --remove-orphans
