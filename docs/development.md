# Development guide

> Part of the [Salienture](https://salienture.com) open tooling suite.

## Prerequisites

- Docker Desktop (or Docker Engine + Compose v2)
- Make
- Node.js 22+ (only if the app has a frontend build step)
- Git

---

## First-time setup

```bash
# Clone the workspace
git clone <workspace-repo> my-workspace
cd my-workspace

# Clone your CakePHP app into app/ — this directory is gitignored in the workspace
git clone <your-cakephp-repo> app/my-app

# Init: auto-detects app, configures .env, builds Docker, migrates
cp .env.example .env
make init
```

### How `make init` works

1. Runs `scripts/setup.sh` — scans for CakePHP apps, updates workspace `.env`, copies/patches the app's `config/app_local.php` and `config/.env`
2. Builds the FrankenPHP Docker image
3. Starts all services
4. Runs `composer install` (and `npm install` if `package.json` exists) inside the containers
5. Runs database migrations (`bin/cake migrations migrate`)

If only one CakePHP app is found it's selected automatically.
If multiple apps are present, a numbered menu is shown.

### Switching apps

```bash
make reconfigure   # re-runs setup.sh interactively
make init          # rebuilds and migrates for the new app
```

---

## Daily workflow

```bash
make up              # Start FrankenPHP, MariaDB, Redis, Mailpit, phpMyAdmin
make workers-up       # Optional: queue worker (requires cakephp/queue plugin)
```

| Service      | URL                         |
|--------------|-----------------------------|
| App          | http://localhost:8080       |
| Mailpit      | http://localhost:8025       |
| phpMyAdmin   | http://localhost:8081       |

---

## Common commands

```bash
make cake ARGS="routes"
make bake ARGS="model Users"
make composer ARGS="require vendor/package"
make test
make cs-check
make cs-fix
make migrate
make rollback
make migration-status
make fresh              # roll back all migrations, then re-migrate
make seed
make shell              # bash inside FrankenPHP container
make mysql              # MariaDB CLI
make redis-cli
make dump               # export DB to dumps/
make restore FILE=dumps/x.sql
make schema-cache-build
make schema-cache-clear
make cache-clear
make logs
make ps
make restart
```

---

## Running without Docker

You can still use the app's native scripts directly:

```bash
cd <your-app-dir>
bin/cake server    # CakePHP's built-in dev server
composer test
```

Use the workspace Docker stack when you need MariaDB, Mailpit, or FrankenPHP
parity with production.

---

## Dev Containers

Open the workspace folder in VS Code or Cursor and choose
**Reopen in Container**. The `frankenphp` service becomes your dev environment
with the app mounted at `/app`.

---

## Running multiple workspaces simultaneously

Edit `.env` to assign non-conflicting ports:

```bash
# Workspace A (default)
APP_HTTP_PORT=8080
DB_PORT=3306

# Workspace B
APP_HTTP_PORT=8090
DB_PORT=3307
```

`COMPOSE_PROJECT_NAME` (set by `make setup`) already namespaces all containers
and volumes, so data is isolated between workspaces.
