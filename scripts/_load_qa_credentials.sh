#!/usr/bin/env bash
# shellcheck disable=SC1091
# Optional local QA credentials for device integration tests.
# Copy .env.qa.local.example to .env.qa.local (gitignored) at repo root.

_load_qa_credentials() {
  local root="$1"
  local env_file="$root/.env.qa.local"
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
  fi
}

_require_qa_credentials_or_skip() {
  local skip_var="${1:-QA_SKIP_CREDENTIAL_PREFLIGHT}"
  if [[ -n "${!skip_var:-}" && "${!skip_var}" != "0" && "${!skip_var}" != "false" ]]; then
    return 0
  fi
  if [[ -n "${QA_EMAIL_OR_USERNAME:-}" && -n "${QA_PASSWORD:-}" ]]; then
    return 0
  fi
  cat >&2 <<'EOF'
QA credentials are required when the device is signed out.

Either:
  1. Sign in on the device once (session persists), or
  2. Export QA_EMAIL_OR_USERNAME and QA_PASSWORD, or
  3. Copy .env.qa.local.example to .env.qa.local and fill in values.

Example:
  QA_EMAIL_OR_USERNAME=you@example.com QA_PASSWORD=secret \
    DEVICES=1B031FDF6001GJ ./scripts/mobile_feed_playback_matrix.sh

To skip this check (device already signed in):
  QA_SKIP_CREDENTIAL_PREFLIGHT=1 ./scripts/mobile_feed_playback_matrix.sh
EOF
  return 1
}
