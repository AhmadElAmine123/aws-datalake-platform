#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# load-env.sh — source this before running terraform commands.
#
# Reads .env from the project root and exports the values as TF_VAR_*
# environment variables, which Terraform reads automatically.
#
# Usage (from anywhere inside the project):
#   source scripts/load-env.sh
#   cd terraform/envs/dev
#   terraform plan
# ─────────────────────────────────────────────────────────────────────────────

# Resolve project root relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found."
  echo
  echo "  cp $PROJECT_ROOT/.env.example $ENV_FILE"
  echo "  # then edit $ENV_FILE with your values"
  return 1 2>/dev/null || exit 1
fi

# Source .env in a subshell-safe way (set -a auto-exports every variable)
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# ─── Validate required variables ─────────────────────────────────────────────
if [ -z "${ALERT_EMAIL:-}" ]; then
  echo "ERROR: ALERT_EMAIL is not set in $ENV_FILE"
  return 1 2>/dev/null || exit 1
fi

# ─── Export as TF_VAR_* ──────────────────────────────────────────────────────
export TF_VAR_alert_email="$ALERT_EMAIL"

# ─── Optional: set AWS_PROFILE if provided ───────────────────────────────────
if [ -n "${AWS_PROFILE:-}" ]; then
  export AWS_PROFILE
  echo "  AWS_PROFILE  = $AWS_PROFILE"
fi

echo "Loaded .env — TF_VAR_alert_email is set."
