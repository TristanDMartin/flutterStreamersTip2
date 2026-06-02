#!/usr/bin/env bash
set -euo pipefail

# Runs the mobile feed E2E twice on Android and captures logcat for the
# MediaCodec/Surface BAD_INDEX A/B:
#   1. Impeller enabled
#   2. Impeller disabled
#
# Usage:
#   QA_EMAIL_OR_USERNAME=... QA_PASSWORD=... \
#     ./scripts/android_bad_index_impeller_ab.sh emulator-5554
#
# BAD_INDEX / codec counters are telemetry for Impeller A/B comparison.
# gate_status uses the same playback-symptom policy as the Home matrix
# (not raw BAD_INDEX). Set STRICT_CODEC_GATE=1 to fail on codec noise.
#
# Artifacts are written to build/bad_index_ab/.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/_load_qa_credentials.sh
source "$ROOT/scripts/_load_qa_credentials.sh"
_load_qa_credentials "$ROOT"
_require_qa_credentials_or_skip || exit 1

DEVICE="${1:-${FLUTTER_INTEGRATION_TEST_DEVICE:-}}"
if [[ -z "$DEVICE" ]]; then
  DEVICE="$(flutter devices --machine --no-version-check | \
    python3 -c 'import json,sys; ds=json.load(sys.stdin); print(next((d["id"] for d in ds if "android" in (d.get("targetPlatform","").lower())), ""))')"
fi

if [[ -z "$DEVICE" ]]; then
  echo "No Android device found. Pass a device id from: flutter devices" >&2
  exit 1
fi

ADB="${ANDROID_HOME:-/Users/tristanmartin/Library/Android/sdk}/platform-tools/adb"
if [[ ! -x "$ADB" ]]; then
  ADB="adb"
fi

OUT_DIR="$ROOT/build/bad_index_ab/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"
STRICT_CODEC_GATE="${STRICT_CODEC_GATE:-0}"
MAX_BAD_INDEX="${MAX_BAD_INDEX:-0}"
MAX_SURFACE_BAD_INDEX="${MAX_SURFACE_BAD_INDEX:-0}"
MAX_FIRST_FRAME_FAILURES="${MAX_FIRST_FRAME_FAILURES:-0}"
MAX_VIDEO_ERRORS="${MAX_VIDEO_ERRORS:-0}"
MAX_PERMISSION_DENIED="${MAX_PERMISSION_DENIED:-0}"
MAX_UNRECOVERED_SURFACE_PLAYBACK_FAILURES="${MAX_UNRECOVERED_SURFACE_PLAYBACK_FAILURES:-0}"

count_matches() {
  local pattern="$1"
  shift
  cat "$@" 2>/dev/null | grep -Eci "$pattern" || true
}

count_unrecovered_surface_playback_failures() {
  local flutter_log="$1"
  local platform_log="$2"
  local playback_exhausted
  playback_exhausted="$(count_matches \
    'first_frame_watchdog_exhausted|RECOVERY_GIVE_UP|surface_recovery_exhausted|BLACKSCREEN_DETECTED|black screen|audio-only' \
    "$flutter_log")"
  if [[ "$playback_exhausted" -eq 0 ]]; then
    echo 0
    return
  fi
  count_matches \
    'setOutputSurface.*BAD_INDEX|setOutputSurface.*failed' \
    "$platform_log" "$flutter_log"
}

run_case() {
  local label="$1"
  shift
  local log_file="$OUT_DIR/${label}.logcat.txt"
  local flutter_file="$OUT_DIR/${label}.flutter.txt"

  echo "==> $label: clearing logcat"
  "$ADB" -s "$DEVICE" logcat -c || true

  set +e
  flutter test integration_test/home_feed_playback_e2e_test.dart \
    -d "$DEVICE" \
    --dart-define=RUN_MOBILE_FEED_E2E=true \
    --dart-define=QA_EMAIL_OR_USERNAME="${QA_EMAIL_OR_USERNAME:-}" \
    --dart-define=QA_PASSWORD="${QA_PASSWORD:-}" \
    --dart-define=STREAMERSTIP_ENABLE_TESTER_ONBOARDING_RESET=false \
    --dart-define=STREAMERSTIP_DISABLE_PRODUCT_TOUR_TARGET_KEYS=true \
    --dart-define=STREAMERSTIP_ANDROID_MEDIA3_HOME="${STREAMERSTIP_ANDROID_MEDIA3_HOME:-false}" \
    "$@" >"$flutter_file" 2>&1
  local status="$?"
  set -e

  "$ADB" -s "$DEVICE" logcat -d -v time >"$log_file" || true

  local bad_index_count codec_bad_index_count surface_bad_index_count
  codec_bad_index_count="$(count_matches 'CCodecConfig.*query failed.*BAD_INDEX' "$log_file")"
  surface_bad_index_count="$(count_matches 'setOutputSurface.*BAD_INDEX|setOutputSurface.*failed' "$log_file")"
  bad_index_count="$(count_matches 'BAD_INDEX|setOutputSurface.*failed' "$log_file")"
  local permission_denied_count playback_recovery_exhausted
  permission_denied_count="$(count_matches 'permission-denied|PERMISSION_DENIED|Missing or insufficient permissions' "$flutter_file" "$log_file")"
  local first_frame_failures
  first_frame_failures="$(count_matches 'first_frame_watchdog_exhausted|RECOVERY_GIVE_UP|BLACKSCREEN_DETECTED|black screen|audio-only' "$flutter_file" "$log_file")"
  playback_recovery_exhausted="$(count_matches 'first_frame_watchdog_exhausted|RECOVERY_GIVE_UP|surface_recovery_exhausted|BLACKSCREEN_DETECTED' "$flutter_file")"
  local unrecovered_surface_playback_failures
  unrecovered_surface_playback_failures="$(count_unrecovered_surface_playback_failures "$flutter_file" "$log_file")"
  local video_errors
  video_errors="$(count_matches 'Video player error|VideoPlayer: Video .* unplayable|missing_playback_url' "$flutter_file" "$log_file")"
  local test_failures
  test_failures="$(count_matches '\[E\]|Failed assertion|Timed out waiting|Some tests failed|Test failed' "$flutter_file")"
  local gate_status=0
  if [[ "$status" -ne 0 ]]; then
    gate_status=1
  fi
  if [[ "$test_failures" -gt 0 ]]; then
    gate_status=1
  fi
  if [[ "$permission_denied_count" -gt "$MAX_PERMISSION_DENIED" ]]; then
    gate_status=1
  fi
  if [[ "$first_frame_failures" -gt "$MAX_FIRST_FRAME_FAILURES" ]]; then
    gate_status=1
  fi
  if [[ "$video_errors" -gt "$MAX_VIDEO_ERRORS" ]]; then
    gate_status=1
  fi
  if [[ "$unrecovered_surface_playback_failures" -gt "$MAX_UNRECOVERED_SURFACE_PLAYBACK_FAILURES" ]]; then
    gate_status=1
  fi
  if [[ "$STRICT_CODEC_GATE" == "1" ]]; then
    if [[ "$bad_index_count" -gt "$MAX_BAD_INDEX" ]]; then
      gate_status=1
    fi
    if [[ "$surface_bad_index_count" -gt "$MAX_SURFACE_BAD_INDEX" ]]; then
      gate_status=1
    fi
  fi
  {
    echo "label=$label"
    echo "status=$status"
    echo "gate_status=$gate_status"
    echo "# telemetry (A/B comparison, not gated by default):"
    echo "bad_index_count=$bad_index_count"
    echo "codec_bad_index_count=$codec_bad_index_count"
    echo "surface_bad_index_count=$surface_bad_index_count"
    echo "playback_recovery_exhausted=$playback_recovery_exhausted"
    echo "# gating metrics:"
    echo "permission_denied_count=$permission_denied_count"
    echo "first_frame_failures=$first_frame_failures"
    echo "video_errors=$video_errors"
    echo "test_failures=$test_failures"
    echo "unrecovered_surface_playback_failures=$unrecovered_surface_playback_failures"
    echo "strict_codec_gate=$STRICT_CODEC_GATE"
    echo "logcat=$log_file"
    echo "flutter=$flutter_file"
  } | tee "$OUT_DIR/${label}.summary.txt"

  return "$gate_status"
}

status=0
run_case impeller_on --enable-impeller || status=$?
run_case impeller_off --no-enable-impeller || status=$?

{
  echo "Android BAD_INDEX Impeller A/B"
  echo "device=$DEVICE"
  echo
  cat "$OUT_DIR"/impeller_on.summary.txt
  echo
  cat "$OUT_DIR"/impeller_off.summary.txt
} | tee "$OUT_DIR/summary.txt"

echo "Artifacts: $OUT_DIR"
exit "$status"
