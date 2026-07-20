#!/usr/bin/env bash
# Patch a CakePHP app's config/.env with Docker Compose service hostnames and DB credentials.
# Called by scripts/setup.sh and `make env`.
#
# CakePHP's app skeleton (config/bootstrap.php) loads config/.env via the
# josegonzalez/php-dotenv package when present. Some app templates write
# entries as `export KEY="value"`, others as plain `KEY=value` — this script
# detects which style the app's own config/.env.example uses and matches it.
set -euo pipefail

ENV_FILE="${1:?Usage: patch-app-env.sh /path/to/app/config/.env}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_CONFIG_DIR="$(dirname "${ENV_FILE}")"

# Load workspace .env so DB_DATABASE, DB_USERNAME, etc. are available
if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ROOT}/.env"
  set +a
fi

# Detect export-style vs plain KEY=value, based on the app's own example file.
# The skeleton ships every line commented out (# export KEY="value"), so strip
# a leading comment marker before checking which convention is used.
EXPORT_STYLE=false
EXAMPLE_FILE="${APP_CONFIG_DIR}/.env.example"
if [[ -f "${EXAMPLE_FILE}" ]] && grep -qE '^[[:space:]]*#?[[:space:]]*export[[:space:]]+[A-Z]' "${EXAMPLE_FILE}"; then
  EXPORT_STYLE=true
fi

# NOTE: patterns below use POSIX [[:space:]] rather than \s — macOS/BSD sed's
# -E mode does not support \s (it's a GNU/PCRE extension); using it there
# silently matches nothing, so sed exits 0 having replaced zero lines. grep
# on this platform happens to accept \s, which previously masked the bug:
# set_or_replace looked like it worked (grep found the line) while the sed
# substitution beneath it quietly no-op'd, leaving stale values in place.
#
# Line replacement uses awk, not sed, on purpose: sed's `s|old|new|`
# interprets a bare `&` in the replacement text as "the whole matched
# string". CACHE_DEFAULT_URL's value contains a literal `&` (query string),
# which previously caused sed to splice the old matched line back into the
# new one instead of a literal ampersand, corrupting the file further on
# every re-run. awk's print does no such reinterpretation.
set_or_replace() {
  local key="$1"
  local value="$2"
  local line
  if $EXPORT_STYLE; then
    line="export ${key}=\"${value}\""
  else
    line="${key}=${value}"
  fi
  if grep -qE "^[[:space:]]*(export[[:space:]]+)?${key}=" "$ENV_FILE" 2>/dev/null; then
    awk -v pat="^[[:space:]]*(export[[:space:]]+)?${key}=" -v repl="${line}" \
      '{ if ($0 ~ pat) print repl; else print }' "$ENV_FILE" >"${ENV_FILE}.tmp" \
      && mv "${ENV_FILE}.tmp" "$ENV_FILE"
  else
    echo "${line}" >>"$ENV_FILE"
  fi
}

# Reads the current value of KEY from ENV_FILE (last match wins, matching
# what the dotenv loader would see), stripping export/quotes.
current_value() {
  local key="$1"
  grep -E "^[[:space:]]*(export[[:space:]]+)?${key}=" "$ENV_FILE" 2>/dev/null \
    | tail -1 \
    | sed -E "s/^[[:space:]]*(export[[:space:]]+)?${key}=//; s/^\"(.*)\"\$/\1/"
}

generate_random_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  elif command -v php >/dev/null 2>&1; then
    php -r "echo bin2hex(random_bytes(32));"
  else
    LC_ALL=C tr -dc 'a-f0-9' </dev/urandom | head -c 64
  fi
}

DB_NAME="${DB_DATABASE:-cakephp}"
DB_USER="${DB_USERNAME:-cakephp}"
DB_PASS="${DB_PASSWORD:-secret}"

# The CakePHP skeleton ships config/.env with unsubstituted installer tokens
# (__APP_NAME__, __SALT__) — normally replaced by `composer create-project`'s
# postInstall step, which never runs when cloning an existing app instead of
# scaffolding a fresh one. An unreplaced __SALT__ is only 8 chars, overrides
# app_local.php's safe 64-char fallback via env(), and triggers CakePHP's
# "Security.salt too short" notice. Generate a real one, but only if it looks
# like a placeholder or is too short — never rotate an already-real salt.
CURRENT_SALT="$(current_value SECURITY_SALT)"
if [[ -z "${CURRENT_SALT}" || "${CURRENT_SALT}" == "__SALT__" || ${#CURRENT_SALT} -lt 32 ]]; then
  set_or_replace SECURITY_SALT "$(generate_random_hex)"
fi

CURRENT_APP_NAME_VAL="$(current_value APP_NAME)"
if [[ -z "${CURRENT_APP_NAME_VAL}" || "${CURRENT_APP_NAME_VAL}" == "__APP_NAME__" ]]; then
  set_or_replace APP_NAME "${APP_NAME:-${DB_NAME}}"
fi

set_or_replace DEBUG          true
set_or_replace FULL_BASE_URL  "http://localhost:${APP_HTTP_PORT:-8080}"

set_or_replace DATABASE_URL   "mysql://${DB_USER}:${DB_PASS}@mariadb:3306/${DB_NAME}"

set_or_replace EMAIL_TRANSPORT_DEFAULT_HOST     mailpit
set_or_replace EMAIL_TRANSPORT_DEFAULT_PORT     1025
set_or_replace EMAIL_TRANSPORT_DEFAULT_USERNAME null
set_or_replace EMAIL_TRANSPORT_DEFAULT_PASSWORD null
set_or_replace EMAIL_TRANSPORT_DEFAULT_TLS      false

set_or_replace CACHE_DEFAULT_URL "redis://redis:6379/?prefix=${DB_NAME}_&duration=%2B2+minutes"

rm -f "${ENV_FILE}.bak"
echo "Patched ${ENV_FILE} for Docker services."
