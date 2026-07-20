# AGENTS.md

Instructions for AI coding agents (Cursor, Claude Code, Copilot, etc.) in the workspace.

## Repository model

- **Workspace root** — Docker, Makefile, docs, AI config (you are here)
- **`app/`** — CakePHP application; may be a symlink to another git repo

Prefer `make <target>` over raw `docker compose` or host `bin/cake` unless the user explicitly runs without Docker.

## Before changing code

1. Confirm `app/` exists and is configured (`make setup` if not)
2. Read `CLAUDE.md` and `docs/architecture.md`
3. For app-only work, follow patterns already in `app/` (Table/Entity classes, Controllers, Bake templates)

## Safe defaults

- Do not create git commits unless asked
- Do not modify app `config/.env` or `config/app_local.php` secrets directly; use the `.example` templates and `make env`
- Minimize diff scope — workspace vs app changes should not mix in one unrelated PR

## Testing

```bash
make test          # PHPUnit, inside container
make cs-check       # phpcs (if configured in the app)
```

## Key paths

| Task | Location |
|------|----------|
| Routes | `app/config/routes.php` |
| Controllers | `app/src/Controller/` |
| Models (Table/Entity) | `app/src/Model/` |
| Templates | `app/templates/` |
| Migrations | `app/config/Migrations/` |
| Docker | `docker/compose.yml` |
| Env patch script | `scripts/patch-app-env.sh` |
