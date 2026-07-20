# Changelog

All notable changes to this **workspace** (not the CakePHP app in `app/`) are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.0] — 2026-07-19

### Added

- Generic workspace — clone any CakePHP app into `app/`, auto-detected by `make setup`
- `scripts/setup.sh`: scans `app/` for CakePHP projects (`bin/cake` + `composer.json`); auto-selects single app, interactive picker for multiple
- `app/` gitignored container directory; only `app/.gitkeep` is committed; each app lives in its own repo
- FrankenPHP (PHP 8.5) + MariaDB 11.4 + Redis 7 + Mailpit + phpMyAdmin Docker stack, serving CakePHP's `webroot/`
- `scripts/patch-app-env.sh`: patches the app's `config/.env` (`DATABASE_URL`, `EMAIL_TRANSPORT_DEFAULT_*`, `CACHE_DEFAULT_URL`) for Docker service hostnames, auto-detecting `export KEY="value"` vs plain `KEY=value` style
- Auto-copies `config/app_local.php` and `config/.env` from their `.example` templates if missing
- `scripts/setup.sh` auto-uncomments the `config/.env` loader in `config/bootstrap.php` (shipped commented-out by the CakePHP skeleton) so `DATABASE_URL` etc. are actually read — otherwise the app silently falls back to `localhost` and fails to connect with `SQLSTATE[HY000] [2002]`
- `scripts/patch-app-env.sh` generates a real `SECURITY_SALT` and resolves `APP_NAME`, replacing the CakePHP skeleton's unsubstituted `__SALT__` / `__APP_NAME__` install-time placeholders (normally set by `composer create-project`, which this workspace's clone-an-existing-app flow never runs) — fixes the "Security.salt too short" notice; idempotent, never rotates an already-real salt
- Optional queue worker service (`workers` compose profile) for apps using the `cakephp/queue` plugin

### Fixed

- `set_or_replace` in both scripts now uses `awk` instead of `sed` for line replacement — a literal `&` in a replacement value (e.g. `CACHE_DEFAULT_URL`'s query string) is special to `sed`'s replacement syntax and was splicing the old matched line back into the new one, corrupting the file further on every re-run
- Regex patterns switched from `\s` to POSIX `[[:space:]]` — macOS/BSD `sed -E` doesn't support `\s`, so prior substitutions against already-existing keys silently matched nothing and left stale values in place (masked because first-time keys took the append-new-line path instead)
- Makefile targets: `init`, `setup`, `reconfigure`, `cake`, `bake`, `composer`, `test`, `cs-check`, `cs-fix`, `stan`, `migrate`, `rollback`, `migration-status`, `fresh`, `seed`, `shell`, `mysql`, `redis-cli`, `dump`, `restore`, `schema-cache-build`, `schema-cache-clear`, `cache-clear`, `logs`, `destroy`
- `COMPOSE_PROJECT_NAME`, `DB_DATABASE`, `DB_USERNAME` derived from app name — multiple workspaces never collide
- Port variables in `.env` for running multiple workspaces simultaneously
- Xdebug support via `INSTALL_XDEBUG=true` build arg and `XDEBUG_MODE` runtime env
- `make destroy` confirmation prompt to prevent accidental data loss
- `make dump` / `make restore` for database backup and restore
- Dev container configuration (VS Code / Cursor)
- Claude Code (`CLAUDE.md`, `.claude/`) and Cursor (`.cursor/rules/`, `AGENTS.md`) AI assistant configuration
- Built by [Salienture](https://salienture.com)
