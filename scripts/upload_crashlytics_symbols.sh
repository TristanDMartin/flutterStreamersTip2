#!/usr/bin/env bash
# Upload Flutter Dart obfuscation symbols for a release version to Crashlytics.
#
# Requires:
#   - firebase-tools logged in / CI token
#   - FIREBASE_ANDROID_APP_ID and/or FIREBASE_IOS_APP_ID
#     (Firebase console → Project settings → Your apps → App ID)
#
# Usage:
#   bash scripts/upload_crashlytics_symbols.sh 1.0.1+2026060903
#   bash scripts/upload_crashlytics_symbols.sh   # uses current pubspec version
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-$(bash scripts/release_version.sh)}"
SYMBOLS_DIR="$ROOT/symbols/$VERSION"

if [[ ! -d "$SYMBOLS_DIR" ]]; then
  echo "Symbols directory missing: $SYMBOLS_DIR" >&2
  echo "Build with: bash scripts/build_store_release.sh android" >&2
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "firebase CLI required for symbol upload" >&2
  exit 1
fi

UPLOADED=0
if [[ -n "${FIREBASE_ANDROID_APP_ID:-}" ]]; then
  echo "Uploading Android Dart symbols for $VERSION → $FIREBASE_ANDROID_APP_ID"
  firebase crashlytics:symbols:upload \
    --app="$FIREBASE_ANDROID_APP_ID" \
    "$SYMBOLS_DIR"
  UPLOADED=$((UPLOADED + 1))
fi

if [[ -n "${FIREBASE_IOS_APP_ID:-}" ]]; then
  echo "Uploading iOS Dart symbols for $VERSION → $FIREBASE_IOS_APP_ID"
  firebase crashlytics:symbols:upload \
    --app="$FIREBASE_IOS_APP_ID" \
    "$SYMBOLS_DIR"
  UPLOADED=$((UPLOADED + 1))
fi

if [[ "$UPLOADED" -eq 0 ]]; then
  echo "Set FIREBASE_ANDROID_APP_ID and/or FIREBASE_IOS_APP_ID before upload." >&2
  echo "Symbols remain at: $SYMBOLS_DIR (retain securely even without upload)." >&2
  exit 1
fi

echo "✅ Crashlytics Dart symbols uploaded for $VERSION"
