#!/usr/bin/env bash
# Proves the staging guard fails on this repo's packaged configs and passes
# on a temporary tree whose project id is streamerstip-stg.
# Does not install configs, call Firebase, or start a device test.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/scripts/require_staging_isolation.sh"

run_guard() {
  local root="$1"
  local project="$2"
  local site="$3"
  local billing="$4"
  local retention="$5"
  local worker="$6"
  FIREBASE_PROJECT_ID="$project" \
    SITE_API_BASE="$site" \
    MOBILE_BILLING_VERIFY_URL="$billing" \
    RETENTION_TRACK_URL="$retention" \
    CLOUDFLARE_WORKER_BASE_URL="$worker" \
    STAGING_FIREBASE_API_KEY="staging-placeholder" \
    STAGING_FIREBASE_APP_ID="staging-placeholder" \
    STAGING_FIREBASE_MESSAGING_SENDER_ID="staging-placeholder" \
    "$GUARD" "$root"
}

set +e
run_guard \
  "$ROOT" \
  "streamerstip-stg" \
  "https://staging.streamerstip.com" \
  "https://us-central1-streamerstip-stg.cloudfunctions.net/verifyMobilePurchase" \
  "https://staging.streamerstip.com/api/track" \
  "https://staging-worker.invalid" \
  >/tmp/staging-guard-repo.out 2>/tmp/staging-guard-repo.err
repo_status="$?"
set -e
if [[ "$repo_status" -eq 0 ]]; then
  echo "REFUSING: packaged configs in this checkout passed the staging guard." >&2
  exit 1
fi
if ! grep -q "packaged Firebase configs are not streamerstip-stg" /tmp/staging-guard-repo.err; then
  echo "REFUSING: repo guard failed for an unexpected reason." >&2
  cat /tmp/staging-guard-repo.err >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/android/app" "$tmp/ios/Runner"
cat >"$tmp/android/app/google-services.json" <<'JSON'
{"project_info":{"project_id":"streamerstip-stg"}}
JSON
cat >"$tmp/ios/Runner/GoogleService-Info.plist" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>PROJECT_ID</key><string>streamerstip-stg</string></dict></plist>
XML

run_guard \
  "$tmp" \
  "streamerstip-stg" \
  "https://staging.streamerstip.com" \
  "https://us-central1-streamerstip-stg.cloudfunctions.net/verifyMobilePurchase" \
  "https://staging.streamerstip.com/api/track" \
  "https://staging-worker.invalid" \
  >/tmp/staging-guard-temp.out 2>/tmp/staging-guard-temp.err

set +e
run_guard \
  "$tmp" \
  "streamerstip-stg" \
  "https://staging.streamerstip.com" \
  "https://us-central1-streamerstip-stg.cloudfunctions.net/verifyMobilePurchase" \
  "https://staging.streamerstip.com/api/track" \
  "https://streamerstip-mux-api.streamerstip.workers.dev" \
  >/tmp/staging-guard-worker.out 2>/tmp/staging-guard-worker.err
worker_status="$?"
set -e
if [[ "$worker_status" -eq 0 ]]; then
  echo "REFUSING: production Cloudflare worker was accepted." >&2
  exit 1
fi
if ! grep -q "CLOUDFLARE_WORKER_BASE_URL must be a staging worker" /tmp/staging-guard-worker.err; then
  echo "REFUSING: production worker guard failed for an unexpected reason." >&2
  cat /tmp/staging-guard-worker.err >&2
  exit 1
fi

echo "packaged-repo-guard=refused"
echo "temporary-staging-tree-guard=passed"
echo "production-worker-guard=refused"
