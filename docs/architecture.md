# Architecture

## Workspace layout

```
cakephp-workspace/
├── app/                 # Clone your CakePHP app(s) here — gitignored
│   └── .gitkeep         # Only committed file inside app/
├── docker/              # Compose stack + FrankenPHP image
├── docs/                # Human documentation
├── history/             # ADRs and session notes
├── scripts/             # Setup helpers
├── .devcontainer/       # VS Code / Cursor dev container
├── .cursor/rules/       # Cursor AI rules
├── .claude/             # Claude Code settings & commands
├── Makefile             # Primary dev interface
├── CLAUDE.md            # Claude Code project context
└── AGENTS.md            # Cross-agent instructions (Cursor, etc.)
```

## Design choices

1. **Generic workspace, separate app git** — `app/` is a gitignored container for any CakePHP application. Each app is committed only to its own repository; the workspace never touches app history.

2. **Auto-detected app** — `scripts/setup.sh` scans `app/` for CakePHP projects (`bin/cake` + `composer.json`). One app is selected automatically; multiple apps show a numbered picker. `APP_PATH`, `COMPOSE_PROJECT_NAME`, `DB_DATABASE`, and `DB_USERNAME` are all derived from the chosen app name.

3. **FrankenPHP in Docker** — Matches modern PHP deployment (Caddy, HTTP/2, optional worker mode) without replacing CakePHP's `bin/cake` workflow. Document root is `webroot/`, CakePHP's public directory.

4. **`config/.env` + `config/app_local.php`** — CakePHP's app skeleton keeps environment-dependent config in two places: `config/app_local.php` (Security salt, Datasources, EmailTransport — assembled from `env()` calls) and, if the app uses `josegonzalez/php-dotenv`, `config/.env` (the actual key/value pairs). `scripts/setup.sh` copies both from their `.example` templates if missing, then `scripts/patch-app-env.sh` patches `config/.env` with Docker service hostnames. The skeleton ships the `config/.env` loader **commented out** in `config/bootstrap.php`, so `setup.sh` also uncomments it (`enable_dotenv_bootstrap`) — otherwise `env('DATABASE_URL')` is always `null`, the app silently falls back to `'host' => 'localhost'`, and PDO tries a local Unix socket instead of TCP to the `mariadb` container (`SQLSTATE[HY000] [2002]`). Apps that don't use dotenv at all should have their `Datasources`/`EmailTransport` values in `config/app_local.php` pointed at the Docker hostnames manually (see `docs/docker.md`).

5. **Redis for cache** — CakePHP's core `RedisEngine` backs the default cache via `CACHE_DEFAULT_URL`, patched to point at the Docker `redis` service. Sessions default to native PHP unless the app configures otherwise.

6. **Makefile as CLI** — Single entry point for humans and AI agents; wraps `docker compose` and `bin/cake`.

7. **Multi-workspace isolation** — `COMPOSE_PROJECT_NAME` namespaces all containers and volumes. Configurable port variables in `.env` allow multiple workspaces to run simultaneously without port conflicts.

## Application stack

CakePHP apps vary more than a single-framework setup. The baseline this
workspace assumes:

- PHP 8.1+, CakePHP 5.x
- `cakephp/migrations` for schema (`bin/cake migrations migrate`)
- `bin/cake bake` for code generation
- PHPUnit for tests

Optional, only if the specific app has them installed:

- `cakephp/queue` for background jobs (`make workers-up`)
- A frontend build step (npm/Vite/webpack) — `make npm`, `make vite`

See the app's own `CLAUDE.md`, `composer.json`, or `config/app.php` for
app-specific details.
