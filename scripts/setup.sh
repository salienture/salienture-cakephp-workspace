#!/usr/bin/env bash
# Detect or interactively select a CakePHP application inside app/.
# Writes APP_NAME, APP_PATH, COMPOSE_PROJECT_NAME to workspace .env
#
# Usage:
#   bash scripts/setup.sh              # auto or interactive
#   bash scripts/setup.sh --reconfigure  # force re-selection even if already set

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPS_DIR="${WORKSPACE_ROOT}/app"
ENV_FILE="${WORKSPACE_ROOT}/.env"

# --- Terminal helpers ---
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m' "$*"; }
dim()    { printf '\033[2m%s\033[0m\n' "$*"; }

is_cakephp() { [[ -f "$1/bin/cake" && -f "$1/composer.json" ]]; }

# The CakePHP app skeleton ships config/bootstrap.php with its config/.env
# loader commented out by default. If it stays commented, DATABASE_URL and
# friends are never read and the app falls back to its hardcoded
# 'host' => 'localhost' — which PDO's mysql driver treats as "use a local
# socket", not TCP, causing SQLSTATE[HY000] [2002] against the Docker DB.
# Uncomment the block so env() actually sees config/.env.
enable_dotenv_bootstrap() {
  local bootstrap_file="$1"
  [[ -f "${bootstrap_file}" ]] || return 2
  grep -qE "^[[:space:]]*if[[:space:]]*\(!env\('APP_NAME'\)" "${bootstrap_file}" && return 1
  grep -qE "^//[[:space:]]*if[[:space:]]*\(!env\('APP_NAME'\)" "${bootstrap_file}" || return 2
  awk '
    BEGIN { in_block = 0 }
    /^\/\/[[:space:]]*if[[:space:]]*\(!env\(.APP_NAME.\)/ { in_block = 1 }
    {
      line = $0
      if (in_block == 1) {
        sub(/^\/\/[[:space:]]?/, "", line)
      }
      print line
      if (in_block == 1 && line ~ /^}/) { in_block = 0 }
    }
  ' "${bootstrap_file}" >"${bootstrap_file}.tmp" && mv "${bootstrap_file}.tmp" "${bootstrap_file}"
  return 0
}

set_or_replace() {
  local key="$1" value="$2"
  # awk, not sed: a literal `&` in a sed replacement means "the whole
  # matched text", silently corrupting the line if value ever contains one.
  if grep -q "^${key}=" "${ENV_FILE}" 2>/dev/null; then
    awk -v pat="^${key}=" -v repl="${key}=${value}" \
      '{ if ($0 ~ pat) print repl; else print }' "${ENV_FILE}" >"${ENV_FILE}.tmp" \
      && mv "${ENV_FILE}.tmp" "${ENV_FILE}"
  else
    echo "${key}=${value}" >>"${ENV_FILE}"
  fi
}

# --- Check if already configured ---
RECONFIGURE=false
[[ "${1:-}" == "--reconfigure" ]] && RECONFIGURE=true

if [[ -f "${ENV_FILE}" ]] && ! $RECONFIGURE; then
  CURRENT_APP_PATH="$(grep -s '^APP_PATH=' "${ENV_FILE}" | cut -d= -f2- || true)"
  if [[ -n "${CURRENT_APP_PATH}" && -f "${CURRENT_APP_PATH}/bin/cake" ]]; then
    green "Workspace already configured: $(basename "${CURRENT_APP_PATH}")"
    dim  "  Path: ${CURRENT_APP_PATH}"
    if [[ -t 0 ]]; then
      printf "Change application? [y/N]: "
      read -r change_ans
      if [[ ! "${change_ans}" =~ ^[Yy]$ ]]; then
        exit 0
      fi
      echo ""
    else
      dim "  To change: bash scripts/setup.sh --reconfigure"
      exit 0
    fi
  fi
fi

echo ""
bold "CakePHP Workspace Setup"
printf '\n'

# --- Ensure .env exists ---
if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${WORKSPACE_ROOT}/.env.example" "${ENV_FILE}"
  green "Created .env from .env.example"
fi

# --- Ensure app/ container exists ---
mkdir -p "${APPS_DIR}"
touch "${APPS_DIR}/.gitkeep"

# --- Scan app/ for CakePHP apps ---
declare -a APPS=()
if [[ -d "${APPS_DIR}" ]]; then
  for dir in "${APPS_DIR}"/*/; do
    [[ -d "$dir" ]] || continue
    dir="${dir%/}"
    name="$(basename "$dir")"
    [[ "$name" == .* ]] && continue
    is_cakephp "$dir" && APPS+=("$dir")
  done
fi

# --- Resolve which app to use ---
CHOSEN_APP_PATH=""

if [[ ${#APPS[@]} -eq 0 ]]; then
  yellow "No CakePHP application found in app/."
  echo ""
  echo "Clone your CakePHP app into the app/ directory:"
  dim  "  cd ${WORKSPACE_ROOT}/app"
  dim  "  git clone <your-cakephp-repo>"
  echo ""
  printf "Or enter the path to an existing CakePHP app: "
  read -r user_path
  user_path="${user_path/#\~/$HOME}"
  if [[ "${user_path}" != /* ]]; then
    user_path="${WORKSPACE_ROOT}/${user_path}"
  fi
  ABS_PATH="$(cd "${user_path}" 2>/dev/null && pwd)" || { red "Path not found: ${user_path}"; exit 1; }
  is_cakephp "${ABS_PATH}" || { red "No bin/cake found at ${ABS_PATH} — not a CakePHP app"; exit 1; }
  CHOSEN_APP_PATH="${ABS_PATH}"

elif [[ ${#APPS[@]} -eq 1 ]]; then
  CHOSEN_APP_PATH="${APPS[0]}"
  green "Found CakePHP app: $(basename "${CHOSEN_APP_PATH}")"

else
  bold "Multiple CakePHP apps found in app/:\n"
  for i in "${!APPS[@]}"; do
    printf "  \033[36m%d)\033[0m %s\n" $((i + 1)) "$(basename "${APPS[$i]}")"
  done
  echo ""
  printf "Choose [1-%d]: " "${#APPS[@]}"
  read -r choice
  idx=$((choice - 1))
  if [[ $idx -lt 0 || $idx -ge ${#APPS[@]} ]]; then
    red "Invalid choice: ${choice}"
    exit 1
  fi
  CHOSEN_APP_PATH="${APPS[$idx]}"
fi

APP_NAME="$(basename "${CHOSEN_APP_PATH}")"
COMPOSE_PROJECT_NAME="$(echo "${APP_NAME}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_-' '-' | sed 's/-$//')"

# --- Write workspace .env ---
set_or_replace APP_NAME             "${APP_NAME}"
set_or_replace APP_PATH             "${CHOSEN_APP_PATH}"
set_or_replace COMPOSE_PROJECT_NAME "${COMPOSE_PROJECT_NAME}"
set_or_replace DB_DATABASE          "${COMPOSE_PROJECT_NAME}"
set_or_replace DB_USERNAME          "${COMPOSE_PROJECT_NAME}"

# --- Ensure config/app_local.php exists (Security.salt, Datasources, EmailTransport) ---
if [[ -f "${CHOSEN_APP_PATH}/config/app_local.example.php" && ! -f "${CHOSEN_APP_PATH}/config/app_local.php" ]]; then
  cp "${CHOSEN_APP_PATH}/config/app_local.example.php" "${CHOSEN_APP_PATH}/config/app_local.php"
  green "Created ${APP_NAME}/config/app_local.php from app_local.example.php"
fi

# --- Copy and patch the app's dotenv file (config/.env) ---
APP_ENV_FILE="${CHOSEN_APP_PATH}/config/.env"
if [[ -f "${CHOSEN_APP_PATH}/config/.env.example" && ! -f "${APP_ENV_FILE}" ]]; then
  cp "${CHOSEN_APP_PATH}/config/.env.example" "${APP_ENV_FILE}"
  green "Created ${APP_NAME}/config/.env from .env.example"
fi

if [[ -f "${APP_ENV_FILE}" ]]; then
  bash "${WORKSPACE_ROOT}/scripts/patch-app-env.sh" "${APP_ENV_FILE}"
  if enable_dotenv_bootstrap "${CHOSEN_APP_PATH}/config/bootstrap.php"; then
    green "Enabled config/.env loading in ${APP_NAME}/config/bootstrap.php"
  fi
else
  yellow "No config/.env found or created for ${APP_NAME} — skipping env patch."
  dim  "  If this app uses config/app_local.php directly, set Datasources/EmailTransport there:"
  dim  "  host=mariadb, port=3306, database/username=${COMPOSE_PROJECT_NAME}, EmailTransport host=mailpit port=1025"
fi

# --- Summary ---
echo ""
bold "Workspace configured"
printf '\n'
printf "  App name : \033[36m%s\033[0m\n" "${APP_NAME}"
printf "  Path     : %s\n" "${CHOSEN_APP_PATH}"
printf "  Project  : %s\n" "${COMPOSE_PROJECT_NAME}"
printf "  Database : %s\n" "${COMPOSE_PROJECT_NAME}"
echo ""
green "Next: make init"
