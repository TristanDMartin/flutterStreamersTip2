#!/usr/bin/env bash
# Release preflight — checks that can run without secrets or devices.
# Usage: bash scripts/release_preflight.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0
WARN=0
FAIL=0

ok() { echo "  [ok] $*"; PASS=$((PASS + 1)); }
warn() { echo "  [warn] $*"; WARN=$((WARN + 1)); }
fail() { echo "  [fail] $*"; FAIL=$((FAIL + 1)); }

echo "== StreamersTip release preflight =="
echo "repo: $ROOT"
echo

echo "-- Tracker / docs --"
[[ -f docs/RELEASE_TRACKER.md ]] && ok "docs/RELEASE_TRACKER.md present" || fail "missing RELEASE_TRACKER.md"
[[ -f docs/LAUNCH_SLOS.md ]] && ok "docs/LAUNCH_SLOS.md present" || fail "missing LAUNCH_SLOS.md"
[[ -f docs/PRODUCTION_LAUNCH_CHECKLIST.md ]] && ok "launch checklist present" || warn "missing launch checklist"

echo
echo "-- Android signing --"
[[ -f android/key.properties.example ]] && ok "key.properties.example present" || fail "missing key.properties.example"
if [[ -f android/key.properties ]]; then
  if grep -q 'replace-with\|/absolute/path' android/key.properties; then
    fail "android/key.properties still has placeholder values"
  else
    ok "android/key.properties exists (non-placeholder heuristics)"
  fi
else
  warn "android/key.properties missing — create from example before signed AAB"
fi

echo
echo "-- Firebase --"
[[ -f firebase.json ]] && ok "firebase.json present" || fail "missing firebase.json"
[[ -f firestore.rules ]] && ok "firestore.rules present" || fail "missing firestore.rules"
[[ -f storage.rules ]] && ok "storage.rules present" || fail "missing storage.rules"
if command -v firebase >/dev/null 2>&1; then
  ok "firebase CLI installed"
  if firebase use >/dev/null 2>&1; then
    ok "firebase project alias readable"
  else
    warn "firebase use failed — confirm project before deploy"
  fi
else
  warn "firebase CLI not installed"
fi

echo
echo "-- Release dart-defines --"
[[ -f .env.release.example ]] && ok ".env.release.example present" || warn "missing .env.release.example"
DEFINES_OUT="$(mktemp)"
if bash scripts/check_release_dart_defines.sh >"$DEFINES_OUT" 2>&1; then
  ok "dart-define env check passed"
else
  warn "dart-define env check reported gaps (expected until secrets are exported)"
fi
sed 's/^/    /' "$DEFINES_OUT" || true
rm -f "$DEFINES_OUT"

echo
echo "-- QA matrix script --"
chmod +x scripts/mobile_feed_playback_matrix.sh scripts/release_preflight.sh scripts/check_release_dart_defines.sh 2>/dev/null || true
[[ -f scripts/mobile_feed_playback_matrix.sh ]] && ok "mobile_feed_playback_matrix.sh present" || fail "missing matrix script"
[[ -f .env.qa.local.example ]] && ok ".env.qa.local.example present" || warn "missing .env.qa.local.example"
if [[ -f .env.qa.local ]]; then
  ok ".env.qa.local present (gitignored credentials)"
else
  warn ".env.qa.local missing — copy from example for device matrix"
fi

echo
echo "-- Summary --"
echo "  pass=$PASS warn=$WARN fail=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo "Preflight FAILED — fix fail items before beta submission."
  exit 1
fi
echo "Preflight OK (warnings are expected until signing/secrets/device QA are done)."
exit 0
