#!/usr/bin/env bash
set -euo pipefail

# Runs the Home feed production-gate integration test on one or more attached
# mobile devices and writes Flutter/platform logs plus a concise summary.
#
# Usage:
#   QA_EMAIL_OR_USERNAME=... QA_PASSWORD=... \
#     ./scripts/mobile_feed_playback_matrix.sh
#
# Optional:
#   DEVICES="emulator-5554 00008110-000A01DE3400401E" ./scripts/mobile_feed_playback_matrix.sh
#   ./scripts/mobile_feed_playback_matrix.sh emulator-5554
#   IOS_PREINSTALL=1 FLUTTER_TEST_TIMEOUT=15m ./scripts/mobile_feed_playback_matrix.sh 00008110-...
#
# Production gate (default): user-visible playback symptoms only — not raw Codec2
# BAD_INDEX noise. Informational metrics: bad_index_count, codec_bad_index_count,
# surface_bad_index_count (reported in summary, not gated unless strict).
#
# Gate env (defaults are strict production values for playback symptoms):
#   MAX_FIRST_FRAME_FAILURES=0
#   MAX_VIDEO_ERRORS=0
#   MAX_PERMISSION_DENIED=0
#   MAX_UNRECOVERED_SURFACE_PLAYBACK_FAILURES=0  (surface errors only when
#     flutter log shows recovery/first-frame exhaustion; see script)
#   STRICT_CODEC_GATE=1  — also fail on MAX_BAD_INDEX / MAX_SURFACE_BAD_INDEX
#   MAX_BAD_INDEX=0 MAX_SURFACE_BAD_INDEX=0  — only when STRICT_CODEC_GATE=1
#
# iOS physical devices often hang on VM Service / Xcode install during the first
# `flutter test` attach. IOS_PREINSTALL=1 (default for iOS) runs `flutter install`
# first so the test runner reuses an on-device build.
#
# Artifacts are written to build/mobile_feed_matrix/.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/_load_qa_credentials.sh
source "$ROOT/scripts/_load_qa_credentials.sh"
_load_qa_credentials "$ROOT"
_require_qa_credentials_or_skip || exit 1

TARGET="${FLUTTER_INTEGRATION_TEST_TARGET:-integration_test/home_feed_playback_e2e_test.dart}"
OUT_DIR="$ROOT/build/mobile_feed_matrix/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"
STRICT_CODEC_GATE="${STRICT_CODEC_GATE:-0}"
MAX_BAD_INDEX="${MAX_BAD_INDEX:-0}"
MAX_SURFACE_BAD_INDEX="${MAX_SURFACE_BAD_INDEX:-0}"
MAX_FIRST_FRAME_FAILURES="${MAX_FIRST_FRAME_FAILURES:-0}"
MAX_VIDEO_ERRORS="${MAX_VIDEO_ERRORS:-0}"
MAX_PERMISSION_DENIED="${MAX_PERMISSION_DENIED:-0}"
MAX_UNRECOVERED_SURFACE_PLAYBACK_FAILURES="${MAX_UNRECOVERED_SURFACE_PLAYBACK_FAILURES:-0}"
TEST_TIMEOUT="${FLUTTER_TEST_TIMEOUT:-10m}"
OUTER_TEST_TIMEOUT_SECONDS="${FLUTTER_TEST_OUTER_TIMEOUT_SECONDS:-900}"
IOS_PREINSTALL="${IOS_PREINSTALL:-1}"

ADB="${ANDROID_HOME:-/Users/tristanmartin/Library/Android/sdk}/platform-tools/adb"
if [[ ! -x "$ADB" ]]; then
  ADB="adb"
fi

discover_devices() {
  flutter devices --machine --no-version-check | python3 -c '
import json, sys
devices = json.load(sys.stdin)
for d in devices:
    platform = (d.get("targetPlatform") or "").lower()
    if "android" in platform or "ios" in platform:
        print(d["id"])
'
}

if [[ "$#" -gt 0 ]]; then
  DEVICES_LIST=("$@")
elif [[ -n "${DEVICES:-}" ]]; then
  # shellcheck disable=SC2206
  DEVICES_LIST=(${DEVICES})
else
  mapfile -t DEVICES_LIST < <(discover_devices)
fi

if [[ "${#DEVICES_LIST[@]}" -eq 0 ]]; then
  echo "No Android/iOS devices found. Pass device ids from: flutter devices" >&2
  exit 1
fi

is_android_device() {
  local device="$1"
  flutter devices --machine --no-version-check | python3 -c '
import json, sys
target = sys.argv[1]
devices = json.load(sys.stdin)
for d in devices:
    if d.get("id") == target:
        print("android" in (d.get("targetPlatform") or "").lower())
        break
' "$device" | grep -q True
}

is_ios_device() {
  local device="$1"
  flutter devices --machine --no-version-check | python3 -c '
import json, sys
target = sys.argv[1]
devices = json.load(sys.stdin)
for d in devices:
    if d.get("id") == target:
        tp = (d.get("targetPlatform") or "").lower()
        print(tp == "ios" or "ios" in tp)
        break
' "$device" | grep -q True
}

capture_ios_logs() {
  local device="$1"
  local platform_log="$2"
  if command -v idevicesyslog >/dev/null 2>&1; then
    idevicesyslog -u "$device" >"$platform_log" 2>/dev/null &
    echo "$!"
    return
  fi
  log show --style syslog --last 15m >"$platform_log" 2>/dev/null || true
  echo ""
}

count_matches() {
  local pattern="$1"
  shift
  grep -Eih "$pattern" "$@" 2>/dev/null | wc -l | tr -d ' '
}

# Surface BAD_INDEX in logcat alone is not a ship blocker; only count it toward
# the gate when flutter logs show playback recovery was exhausted.
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

run_device() {
  local device="$1"
  local safe_device="${device//[^A-Za-z0-9_.-]/_}"
  local flutter_log="$OUT_DIR/${safe_device}.flutter.txt"
  local platform_log="$OUT_DIR/${safe_device}.platform.txt"
  local summary="$OUT_DIR/${safe_device}.summary.txt"
  local is_android=false
  local is_ios=false
  local ios_log_pid=""
  local device_test_timeout="$TEST_TIMEOUT"

  echo "==> $device: starting Home feed matrix run"

  if is_android_device "$device"; then
    is_android=true
    "$ADB" -s "$device" logcat -c || true
  elif is_ios_device "$device"; then
    is_ios=true
  fi
  : >"$platform_log"
  if [[ "$is_ios" == true ]]; then
    device_test_timeout="${IOS_FLUTTER_TEST_TIMEOUT:-15m}"
    if [[ "$IOS_PREINSTALL" == "1" ]]; then
      echo "==> $device: pre-installing iOS debug build (avoids VM Service / install hang)"
      flutter install --debug -d "$device" >>"$flutter_log" 2>&1 || true
    fi
    ios_log_pid="$(capture_ios_logs "$device" "$platform_log")"
  fi

  set +e
  (
    flutter test "$TARGET" \
      -d "$device" \
      --timeout "$device_test_timeout" \
      --dart-define=RUN_MOBILE_FEED_E2E=true \
      --dart-define=QA_EMAIL_OR_USERNAME="${QA_EMAIL_OR_USERNAME:-}" \
      --dart-define=QA_PASSWORD="${QA_PASSWORD:-}" \
      --dart-define=STREAMERSTIP_ENABLE_TESTER_ONBOARDING_RESET=false \
      --dart-define=STREAMERSTIP_DISABLE_PRODUCT_TOUR_TARGET_KEYS=true \
      --dart-define=STREAMERSTIP_ANDROID_MEDIA3_HOME="${STREAMERSTIP_ANDROID_MEDIA3_HOME:-false}"
  ) >"$flutter_log" 2>&1 &
  local flutter_pid="$!"
  local status=""
  local deadline=$((SECONDS + OUTER_TEST_TIMEOUT_SECONDS))
  while kill -0 "$flutter_pid" 2>/dev/null; do
    if [[ "$SECONDS" -ge "$deadline" ]]; then
      echo "Matrix outer timeout after ${OUTER_TEST_TIMEOUT_SECONDS}s; terminating flutter test." >>"$flutter_log"
      kill "$flutter_pid" 2>/dev/null || true
      sleep 5
      kill -9 "$flutter_pid" 2>/dev/null || true
      status=124
      break
    fi
    sleep 2
  done
  if [[ -z "$status" ]]; then
    wait "$flutter_pid"
    status="$?"
  else
    wait "$flutter_pid" 2>/dev/null || true
  fi
  set -e

  if [[ "$is_android" == true ]]; then
    "$ADB" -s "$device" logcat -d -v time >"$platform_log" 2>/dev/null || true
  elif [[ "$is_ios" == true ]]; then
    if [[ -n "$ios_log_pid" ]]; then
      kill "$ios_log_pid" 2>/dev/null || true
      wait "$ios_log_pid" 2>/dev/null || true
    fi
    if [[ ! -s "$platform_log" ]]; then
      log show --style syslog --last 15m >"$platform_log" 2>/dev/null || true
    fi
  fi

  local bad_index_count codec_bad_index_count surface_bad_index_count
  local permission_denied_count first_frame_failures video_errors test_failures
  local playback_recovery_exhausted unrecovered_surface_playback_failures
  codec_bad_index_count="$(count_matches 'CCodecConfig.*query failed.*BAD_INDEX' "$platform_log" "$flutter_log")"
  surface_bad_index_count="$(count_matches 'setOutputSurface.*BAD_INDEX|setOutputSurface.*failed' "$platform_log" "$flutter_log")"
  bad_index_count="$(count_matches 'BAD_INDEX|setOutputSurface.*failed' "$platform_log" "$flutter_log")"
  permission_denied_count="$(count_matches 'PERMISSION_DENIED|Missing or insufficient permissions' "$platform_log" "$flutter_log")"
  first_frame_failures="$(count_matches 'first_frame_watchdog_exhausted|RECOVERY_GIVE_UP|BLACKSCREEN_DETECTED|black screen|audio-only' "$platform_log" "$flutter_log")"
  playback_recovery_exhausted="$(count_matches 'first_frame_watchdog_exhausted|RECOVERY_GIVE_UP|surface_recovery_exhausted|BLACKSCREEN_DETECTED' "$flutter_log")"
  unrecovered_surface_playback_failures="$(count_unrecovered_surface_playback_failures "$flutter_log" "$platform_log")"
  video_errors="$(count_matches 'Video player error|VideoPlayer: Video .* unplayable|missing_playback_url' "$platform_log" "$flutter_log")"
  test_failures="$(count_matches '\[E\]|Failed assertion|Timed out waiting|Some tests failed|Test failed' "$flutter_log")"

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
    echo "device=$device"
    echo "status=$status"
    echo "gate_status=$gate_status"
    echo "# informational (not gated by default):"
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
    echo "max_first_frame_failures=$MAX_FIRST_FRAME_FAILURES"
    echo "max_video_errors=$MAX_VIDEO_ERRORS"
    echo "max_permission_denied=$MAX_PERMISSION_DENIED"
    echo "max_unrecovered_surface_playback_failures=$MAX_UNRECOVERED_SURFACE_PLAYBACK_FAILURES"
    if [[ "$STRICT_CODEC_GATE" == "1" ]]; then
      echo "max_bad_index=$MAX_BAD_INDEX"
      echo "max_surface_bad_index=$MAX_SURFACE_BAD_INDEX"
    fi
    echo "flutter_log=$flutter_log"
    echo "platform_log=$platform_log"
  } | tee "$summary"

  return "$gate_status"
}

status=0
for device in "${DEVICES_LIST[@]}"; do
  run_device "$device" || status=$?
done

{
  echo "Mobile Home Feed Playback Matrix"
  echo "target=$TARGET"
  echo
  cat "$OUT_DIR"/*.summary.txt
} | tee "$OUT_DIR/summary.txt"

echo "Artifacts: $OUT_DIR"
exit "$status"
