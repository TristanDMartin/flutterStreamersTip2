#!/usr/bin/env bash
# Validates release dart-defines are present in the environment (or .env.release).
# Does not print secret values.
# Usage: bash scripts/check_release_dart_defines.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env.release ]]; then
  # shellcheck disable=SC1091
  set -a
  # Prefer KEY=VALUE lines; ignore comments.
  # shellcheck disable=SC1090
  source <(grep -E '^[A-Z0-9_]+=.' .env.release | sed 's/\r$//')
  set +a
fi

MISSING=0
WARN=0

check_required() {
  local key="$1"
  local val="${!key:-}"
  if [[ -z "$val" ]]; then
    echo "missing: $key"
    MISSING=$((MISSING + 1))
  elif [[ "$val" == *"YOUR_"* || "$val" == *"<PROJECT"* || "$val" == *"replace-with"* ]]; then
    echo "placeholder: $key"
    MISSING=$((MISSING + 1))
  else
    echo "set: $key"
  fi
}

check_optional() {
  local key="$1"
  local val="${!key:-}"
  if [[ -z "$val" ]]; then
    echo "optional-unset: $key"
    WARN=$((WARN + 1))
  else
    echo "set: $key"
  fi
}

echo "Checking release dart-define env vars..."
check_required GIPHY_API_KEY
check_required MOBILE_BILLING_VERIFY_URL
check_optional TIPPY_API_BASE
check_optional GIPHY_FALLBACK_API_KEY
check_optional FIREBASE_APP_CHECK_DEBUG_TOKEN

echo "missing_or_placeholder=$MISSING optional_unset=$WARN"
if [[ "$MISSING" -gt 0 ]]; then
  echo "Export vars or copy .env.release.example → .env.release before release builds."
  exit 1
fi
exit 0
