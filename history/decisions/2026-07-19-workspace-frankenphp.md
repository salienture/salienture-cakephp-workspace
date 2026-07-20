# Workspace with FrankenPHP stack

**Date:** 2026-07-19

**Context:** Needed a generic, reusable dev workspace for CakePHP applications, modeled on the existing Laravel workspace, with production-like PHP runtime and supporting services, able to manage multiple CakePHP apps without spinning up a new workspace per project.

**Decision:**

- Generic workspace; any CakePHP app is cloned into `app/<name>` and auto-detected by `scripts/setup.sh` (looks for `bin/cake` + `composer.json`).
- FrankenPHP + Caddy for HTTP, document root `webroot/` (CakePHP's public directory, not `public/`); MariaDB, Redis, Mailpit, phpMyAdmin in Compose.
- CakePHP's two-layer env config (`config/app_local.php` + optional `config/.env` via `josegonzalez/php-dotenv`) is bootstrapped from `.example` templates and patched with Docker service hostnames.
- Queue worker (`bin/cake queue run`) behind Compose profile `workers`, opt-in since not every CakePHP app installs `cakephp/queue`.
- No scheduler service — CakePHP has no built-in task scheduler equivalent to Laravel's; left out rather than fabricating one.

**Consequences:**

- Default app URL: `http://localhost:8080`
- `make env` / `scripts/patch-app-env.sh` sets `DATABASE_URL` (mariadb), `EMAIL_TRANSPORT_DEFAULT_HOST` (mailpit), `CACHE_DEFAULT_URL` (redis)
- Apps that don't use `josegonzalez/php-dotenv` need `config/app_local.php` wired to the Docker hostnames by hand — the setup script warns when this applies
- Application git history unchanged in each app's own repo
