#!/usr/bin/env bash
# Canonical store release build: obfuscated Dart + versioned split-debug-info.
#
# Usage:
#   set -a && source .env.release && set +a
#   bash scripts/build_store_release.sh android   # appbundle
#   bash scripts/build_store_release.sh android-apk
#   bash scripts/build_store_release.sh ios        # ipa (macOS + signing)
#
# Symbols land in: symbols/<versionName+buildNumber>/
# Keep that directory for every store release (Crashlytics decode).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-android}"
VERSION="$(bash scripts/release_version.sh)"
SYMBOLS_DIR="$ROOT/symbols/$VERSION"
mkdir -p "$SYMBOLS_DIR"

if [[ ! -f .env.release ]] && [[ -z "${GIPHY_API_KEY:-}" ]]; then
  echo "Missing release dart-defines. Source .env.release first:" >&2
  echo "  set -a && source .env.release && set +a" >&2
  exit 1
fi

if [[ -f .env.release ]] && [[ -z "${GIPHY_API_KEY:-}" ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.release
  set +a
fi

bash scripts/check_release_dart_defines.sh

COMMON_ARGS=(
  --release
  --obfuscate
  --split-debug-info="$SYMBOLS_DIR"
  --dart-define=GIPHY_API_KEY="${GIPHY_API_KEY}"
  --dart-define=MOBILE_BILLING_VERIFY_URL="${MOBILE_BILLING_VERIFY_URL}"
  --dart-define=TIPPY_API_BASE="${TIPPY_API_BASE:-}"
)

GIT_COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
BUILD_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
R8_STATUS="DISABLED"
if grep -Eq 'isMinifyEnabled\s*=\s*true' "$ROOT/android/app/build.gradle.kts" 2>/dev/null; then
  R8_STATUS="ENABLED"
fi

cat <<EOF

========================================
StreamersTip Store Release
========================================
Version:            $VERSION
Target:             $TARGET
Mode:               release
Dart obfuscation:   ENABLED
Split debug info:   symbols/$VERSION/
R8:                 $R8_STATUS
Source maps:        N/A (Flutter native)
Git commit:         $GIT_COMMIT
Build timestamp:    $BUILD_TIMESTAMP
========================================

EOF

case "$TARGET" in
  android|appbundle)
    flutter build appbundle "${COMMON_ARGS[@]}"
    ARTIFACT="build/app/outputs/bundle/release/app-release.aab"
    ;;
  android-apk|apk)
    flutter build apk "${COMMON_ARGS[@]}"
    ARTIFACT="build/app/outputs/flutter-apk/app-release.apk"
    ;;
  ios|ipa)
    flutter build ipa "${COMMON_ARGS[@]}"
    ARTIFACT="build/ios/ipa"
    ;;
  *)
    echo "Unknown target: $TARGET (use android | android-apk | ios)" >&2
    exit 1
    ;;
esac

SYMBOL_COUNT="$(find "$SYMBOLS_DIR" -type f ! -name 'BUILD_INFO.txt' ! -name 'RELEASE_SUMMARY.txt' 2>/dev/null | wc -l | tr -d ' ')"

cat >"$SYMBOLS_DIR/BUILD_INFO.txt" <<EOF
version=$VERSION
target=$TARGET
builtAt=$BUILD_TIMESTAMP
gitCommit=$GIT_COMMIT
artifact=$ARTIFACT
obfuscate=true
splitDebugInfo=$SYMBOLS_DIR
r8=$R8_STATUS
symbolFileCount=$SYMBOL_COUNT
EOF

cat >"$SYMBOLS_DIR/RELEASE_SUMMARY.txt" <<EOF
StreamersTip Store Release

Version: $VERSION
Target: $TARGET
Mode: release
Dart obfuscation: ENABLED
Split debug info: symbols/$VERSION/
R8: $R8_STATUS
Source maps: N/A (Flutter native)
Git commit: $GIT_COMMIT
Build timestamp: $BUILD_TIMESTAMP
Artifact: $ARTIFACT
Symbol file count: $SYMBOL_COUNT
EOF

echo
echo "✅ Release artifact: $ARTIFACT"
echo "✅ Dart symbols:     $SYMBOLS_DIR ($SYMBOL_COUNT files)"
echo
echo "----- Release summary (immutable) -----"
cat "$SYMBOLS_DIR/RELEASE_SUMMARY.txt"
echo "---------------------------------------"
echo
echo "Retain $SYMBOLS_DIR securely for Crashlytics symbolication."
echo "Upload Dart symbols (when Firebase CLI + app id configured):"
echo "  bash scripts/upload_crashlytics_symbols.sh $VERSION"
