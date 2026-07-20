# Docker stack

## Services

| Service | Image | Purpose |
|---------|-------|---------|
| `frankenphp` | Custom (`docker/frankenphp`) | PHP 8.5 app server (Caddy + FrankenPHP), serves `webroot/` |
| `mariadb` | `mariadb:11.4` | Primary database |
| `phpmyadmin` | `phpmyadmin:5` | DB admin UI |
| `mailpit` | `axllent/mailpit` | SMTP catch-all + web UI |
| `redis` | `redis:7-alpine` | Cache (via CakePHP's `RedisEngine`) |
| `queue` | Same as FrankenPHP | `bin/cake queue run` (profile: `workers`) — requires `cakephp/queue` |

## Ports (defaults)

Configure in workspace `.env`:

| Variable | Default | Service |
|----------|---------|---------|
| `APP_HTTP_PORT` | 8080 | FrankenPHP HTTP |
| `APP_HTTPS_PORT` | 8443 | FrankenPHP HTTPS |
| `DB_PORT` | 3306 | MariaDB |
| `PMA_PORT` | 8081 | phpMyAdmin |
| `MAILPIT_SMTP_PORT` | 1025 | Mail SMTP |
| `MAILPIT_UI_PORT` | 8025 | Mail UI |
| `REDIS_PORT` | 6379 | Redis |

## Volumes

- `mariadb_data` — database files
- `redis_data` — Redis AOF
- `caddy_data` / `caddy_config` — TLS and Caddy state

## FrankenPHP / Caddy

- Caddyfile: `docker/frankenphp/Caddyfile`
- Document root: `/app/webroot` (CakePHP)
- If the app has a frontend build step, run it on the host (`make npm ARGS="run build"` or `make vite`) — there's no bundler assumption baked into the image.

## Environment wiring

CakePHP app config resolves in two layers:

1. `config/app_local.php` — copied from `config/app_local.example.php` by `make setup` if missing. Contains `Security.salt`, `Datasources.default`, `EmailTransport.default`, usually built from `env()` calls.
2. `config/.env` — copied from `config/.env.example` if the app ships one, and patched by `scripts/patch-app-env.sh` with:
   - `DATABASE_URL` → `mysql://<user>:<pass>@mariadb:3306/<database>`
   - `EMAIL_TRANSPORT_DEFAULT_HOST` / `_PORT` → `mailpit` / `1025`
   - `CACHE_DEFAULT_URL` → `redis://redis:6379/...`
   - `FULL_BASE_URL` → `http://localhost:<APP_HTTP_PORT>`
   - `SECURITY_SALT` / `APP_NAME` → a freshly generated 64-char random salt / the real app name, replacing the CakePHP skeleton's unsubstituted `__SALT__` / `__APP_NAME__` install-time placeholders (see note below). Already-real values are left alone on re-runs, so sessions aren't invalidated.

**Important:** the stock CakePHP app skeleton ships `config/bootstrap.php`
with its `config/.env` loader **commented out**. If it stays commented,
`env('DATABASE_URL')` returns `null`, `Datasources.default.url` is never set,
and the app falls back to `app_local.php`'s hardcoded `'host' => 'localhost'`
— which PDO's mysql driver treats as "connect via local Unix socket," not
TCP, producing `SQLSTATE[HY000] [2002] No such file or directory` since no
such socket exists in the container. `scripts/setup.sh` automatically
uncomments that loader block (`enable_dotenv_bootstrap`) whenever it
provisions `config/.env`, so this should never surface — but if you hand-edit
`config/bootstrap.php` afterwards, keep that block enabled.

If an app doesn't use `josegonzalez/php-dotenv` (no `config/.env.example`),
edit `config/app_local.php` directly with the same hostnames — the patch
script will tell you to when it can't find a dotenv file.

**Also important:** `composer create-project cakephp/app` normally runs a
postInstall step that replaces install-time placeholders — `__SALT__` in
`config/.env`'s `SECURITY_SALT`, `__APP_NAME__` in `APP_NAME` — with a real
random salt and the app's name. Since this workspace clones an *existing*
app rather than scaffolding a fresh one, that step never runs, and those
placeholders stay literal. An unreplaced `__SALT__` is only 8 characters —
short enough to trip CakePHP's `Security.salt` notice, and it silently wins
over `app_local.php`'s safe fallback because `env('SECURITY_SALT')` is
non-empty. `scripts/patch-app-env.sh` detects and replaces both placeholders
(never touching an already-real value, so re-running it doesn't rotate the
salt and invalidate sessions).

## Troubleshooting

**App shows 502 / empty**

- Ensure `app/` is linked and contains `vendor/` (`make app-install`)
- Check logs: `make logs`

**Database connection refused**

- Wait for MariaDB healthcheck: `make ps`
- Confirm the app's `DATABASE_URL` (or `Datasources.default.host`) points at `mariadb`, not `localhost` (run `make env` to re-patch)

**`SQLSTATE[HY000] [2002] No such file or directory`**

- This means the app is trying a local Unix socket instead of TCP to `mariadb` — i.e. `config/.env` isn't being loaded. Check that `config/bootstrap.php`'s dotenv block (just after the `josegonzalez/php-dotenv` comment) is uncommented; re-run `make setup` to have it fixed automatically. No image rebuild needed — just retry the failing command.

**Notice: "Please change the value of `Security.salt`..."**

- The app's `config/.env` still has the literal `__SALT__` placeholder instead of a real one (see "Environment wiring" above). Run `make env` (or `make setup`) to have `scripts/patch-app-env.sh` generate and set a real one.

**Queue worker exits immediately / errors**

- The `queue` service assumes the `cakephp/queue` plugin is installed and loaded (`bin/cake plugin load Queue`). If the app doesn't use it, ignore `make workers-up`.

**Reset everything**

```bash
make destroy   # removes volumes — deletes DB data
make init
```
