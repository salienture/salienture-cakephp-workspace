# History

Local project memory: decisions, session notes, and migration from ad-hoc docs.

## Suggested layout

```
history/
├── decisions/     # ADRs (architecture decision records)
├── sessions/      # Dated work logs (YYYY-MM-DD-topic.md)
└── migrations/    # One-off upgrade / deploy notes
```

## Conventions

- Use `YYYY-MM-DD-short-title.md` for session files.
- Keep decisions short: context, decision, consequences.
- Do not commit secrets or customer data.
- Files matching `*.local.md` are gitignored.

## Example decision record

```markdown
# 2026-07-19 — FrankenPHP over bin/cake server

**Context:** Need production-parity HTTP/2 locally, without giving up bin/cake workflows.

**Decision:** FrankenPHP via Docker, serving CakePHP's webroot/ directly.

**Consequences:** APP_URL uses port 8080; queue worker runs in compose profile `workers`.
```
