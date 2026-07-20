---
description: Start the Docker dev stack and show service URLs
---

Start the CakePHP workspace development environment.

1. Ensure `.env` exists at workspace root (copy from `.env.example` if missing).
2. Ensure `app/` is configured (`make setup` if `APP_PATH` is missing or invalid).
3. Run `make up`, and `make workers-up` if queue processing is needed (requires the `cakephp/queue` plugin).
4. Report URLs: app (8080), Mailpit (8025), phpMyAdmin (8081).
5. If the app has a frontend build step, remind the user to run `make npm ARGS="run dev"` in another terminal.
