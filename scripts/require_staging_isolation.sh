#!/usr/bin/env bash
# Fail closed unless this device run is aimed at streamerstip-stg.
# Does not print secret values.
set -euo pipefail

require_staging_isolation() {
  local root="${1:-.}"
  local project="${FIREBASE_PROJECT_ID:-}"
  local site="${SITE_API_BASE:-}"
  local billing="${MOBILE_BILLING_VERIFY_URL:-}"
  local retention="${RETENTION_TRACK_URL:-}"

  if [[ "$project" != "streamerstip-stg" ]]; then
    echo "REFUSING device matrix: FIREBASE_PROJECT_ID must be streamerstip-stg." >&2
    echo "This script will not sign into streamerstip-6cfdb." >&2
    return 2
  fi
  if [[ "$site" != "https://staging.streamerstip.com" ]]; then
    echo "REFUSING device matrix: SITE_API_BASE must be https://staging.streamerstip.com." >&2
    return 2
  fi
  if [[ -z "$billing" || "$billing" == *streamerstip-6cfdb* ]]; then
    echo "REFUSING device matrix: MOBILE_BILLING_VERIFY_URL must target streamerstip-stg." >&2
    return 2
  fi
  if [[ -z "$retention" || "$retention" == *streamerstip-6cfdb* ]]; then
    echo "REFUSING device matrix: RETENTION_TRACK_URL must target streamerstip-stg." >&2
    return 2
  fi

  local name
  for name in STAGING_FIREBASE_API_KEY STAGING_FIREBASE_APP_ID STAGING_FIREBASE_MESSAGING_SENDER_ID; do
    if [[ -z "${!name:-}" ]]; then
      echo "REFUSING device matrix: ${name} is required and is not set." >&2
      return 2
    fi
  done

  python3 - "$root" <<'PY'
import json, plistlib, sys
from pathlib import Path
root = Path(sys.argv[1])
android = json.loads((root / "android/app/google-services.json").read_text())
android_project = android.get("project_info", {}).get("project_id", "")
with (root / "ios/Runner/GoogleService-Info.plist").open("rb") as handle:
    ios_project = plistlib.load(handle).get("PROJECT_ID", "")
if android_project != "streamerstip-stg" or ios_project != "streamerstip-stg":
    sys.stderr.write(
        "REFUSING device matrix: packaged Firebase configs are not streamerstip-stg.\n"
        "Replace google-services.json and GoogleService-Info.plist with the staging "
        "apps before any device test. Do not point this script at production.\n"
    )
    sys.exit(2)
PY
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  require_staging_isolation "${1:-.}"
fi
