---
description: Run the CakePHP test suite in Docker
---

Run application tests from the workspace:

1. Ensure containers are up (`make up`).
2. Run `make test`.
3. If failures mention database, suggest `make migrate` or `make fresh`.
4. Summarize failing tests and likely fixes — do not skip reading failure output.
