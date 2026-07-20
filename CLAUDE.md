# CLAUDE.md — CakePHP Workspace

Guidance for Claude Code when working in this repository.

## What this repo is

A **generic development workspace** for CakePHP applications. Infrastructure
lives here; the CakePHP app lives in a subdirectory detected by `make setup`
(stored as `APP_PATH` in `.env`).

Do not confuse workspace root with the CakePHP app root — run PHP/`bin/cake`/Composer
**via Make** or from `/app` inside the `frankenphp` container.

## Essential commands

```bash
make help              # All targets
make init              # First-time: auto-detect app, build, migrate
make setup              # Detect / select CakePHP app only
make reconfigure        # Re-select the active app

make up                 # Start Docker stack
make down

make cake ARGS="migrations migrate"
make bake ARGS="model Users"
make composer ARGS="install"
make test
make cs-check
make shell              # Bash in FrankenPHP container
make workers-up          # Queue worker container (requires cakephp/queue plugin)
```

## Service URLs (defaults)

| Service     | URL                       |
|-------------|---------------------------|
| App         | http://localhost:8080     |
| Mailpit     | http://localhost:8025     |
| phpMyAdmin  | http://localhost:8081     |

## Layout

| Path           | Role                                                            |
|----------------|-----------------------------------------------------------------|
| `app/`         | CakePHP app container — gitignored, never committed to workspace |
| `app/.gitkeep` | Only tracked file inside app/; apps are committed to their own repos |
| `docker/`      | Compose, FrankenPHP Dockerfile, Caddyfile                       |
| `scripts/`     | setup.sh, patch-app-env.sh                                      |
| `docs/`        | Human documentation                                             |
| `history/`     | ADRs and session notes                                          |
| `Makefile`     | Primary CLI                                                     |

## Active app

The active app is configured in workspace `.env`:

```
APP_NAME=my-app
APP_PATH=/absolute/path/to/workspace/app/my-app
COMPOSE_PROJECT_NAME=my-app
```

Read `APP_PATH` to know where the CakePHP application code lives.
All apps live inside `app/` — that directory is gitignored in the workspace.

## Application stack

CakePHP apps vary more than a single-framework Laravel setup, but the common
baseline this workspace assumes:

- CakePHP 5.x, PHP 8.1+
- `cakephp/migrations` for schema migrations (`bin/cake migrations ...`)
- `bin/cake bake` for code generation
- PHPUnit for tests (`composer test` inside the app, or `make test`)
- Optional `cakephp/queue` plugin for background jobs (`make workers-up`)

Check the specific app's `composer.json` and `config/app.php` for what's
actually installed before assuming a plugin (e.g. queue, DebugKit) is present.

## Docker conventions

- CakePHP's `config/.env` (loaded via `josegonzalez/php-dotenv` in
  `config/bootstrap.php`, if the app uses it) is patched automatically by
  `make setup` / `make env` with Docker service hostnames:
  `DATABASE_URL` → `mariadb`, `EMAIL_TRANSPORT_DEFAULT_HOST` → `mailpit`,
  `CACHE_DEFAULT_URL` → `redis`.
- `config/app_local.php` is copied from `config/app_local.example.php` if
  missing — this is where `Security.salt`, `Datasources`, and
  `EmailTransport` ultimately resolve from env vars.
- The CakePHP skeleton ships `config/bootstrap.php` with its `config/.env`
  loader commented out. `scripts/setup.sh` auto-uncomments it; if that's ever
  missed, `env('DATABASE_URL')` is `null`, the app falls back to
  `'host' => 'localhost'`, and PDO tries a Unix socket instead of TCP —
  `SQLSTATE[HY000] [2002] No such file or directory`.
- FrankenPHP serves `webroot/` (CakePHP's public document root, not `public/`).
- Queue worker is optional compose profile `workers` and assumes the
  `cakephp/queue` plugin is installed in the app.

## When editing

1. **Workspace-only changes** — `docker/`, `Makefile`, `docs/`, `scripts/`,
   `.devcontainer/`, this file
2. **Application changes** — the app directory (respect existing CakePHP/ORM patterns)
3. **Never commit** — `.env`, app `config/.env`, `config/app_local.php`, secrets, `vendor/`, `node_modules/`

## Docs

- [docs/development.md](docs/development.md)
- [docs/docker.md](docs/docker.md)
- [docs/architecture.md](docs/architecture.md)
