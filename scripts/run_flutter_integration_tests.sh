#!/usr/bin/env bash
set -euo pipefail
# Runs StreamersTip integration tests on a device you choose, or auto-picks
# plugged hardware before falling back to desktop/web.
#
# Usage:
#   ./scripts/run_flutter_integration_tests.sh              # auto
#   ./scripts/run_flutter_integration_tests.sh emulator-5554   # explicit id
#
# Env:
#   FLUTTER_INTEGRATION_TEST_DEVICE   Force device id (same as first arg).
#   PREFER_INTEGRATION_DEVICE          android | ios (default android) when
#                                      both physical phones are plugged.
#
# Pick order: physical Android → physical iOS (or ios first if PREFER…=ios),
# then Android emulator → iOS simulator, then linux → macos → windows.
# (Chrome is omitted: integration_test does not support web yet.)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pick_mobile_id() {
  export ROOT
  python3 <<'PY'
import json
import os
import subprocess
import sys

def main() -> None:
    root = os.environ.get("ROOT", ".")
    prefer = os.environ.get("PREFER_INTEGRATION_DEVICE", "android").lower()
    try:
        out = subprocess.check_output(
            [
                "flutter",
                "devices",
                "--machine",
                "--no-version-check",
            ],
            text=True,
            cwd=root,
        )
    except (OSError, subprocess.CalledProcessError):
        sys.exit(2)
    devices = json.loads(out)

    def is_desktop_or_web(device: dict) -> bool:
        dev_id = device.get("id") or ""
        if dev_id in ("macos", "windows", "linux", "chrome"):
            return True
        tp = (device.get("targetPlatform") or "").lower()
        return "web" in tp or tp == "darwin"

    def is_android(device: dict) -> bool:
        return "android" in (device.get("targetPlatform") or "").lower()

    def is_ios(device: dict) -> bool:
        if is_android(device):
            return False
        tp = (device.get("targetPlatform") or "").lower()
        return tp == "ios" or "ios" in tp

    def is_physical_phone(device: dict) -> bool:
        if not device.get("isSupported", True):
            return False
        if device.get("emulator", False):
            return False
        if is_desktop_or_web(device):
            return False
        return is_android(device) or is_ios(device)

    def is_emulator_phone(device: dict) -> bool:
        if not device.get("isSupported", True):
            return False
        if not device.get("emulator", False):
            return False
        if is_desktop_or_web(device):
            return False
        return is_android(device) or is_ios(device)

    physical = [d for d in devices if is_physical_phone(d)]
    emulators = [d for d in devices if is_emulator_phone(d)]

    def pick_from(pool: list, want_android: bool):
        for d in pool:
            if want_android and is_android(d):
                return str(d["id"])
            if not want_android and is_ios(d):
                return str(d["id"])
        return None

    if prefer == "ios":
        rounds = [
            (physical, False),
            (physical, True),
            (emulators, False),
            (emulators, True),
        ]
    else:
        rounds = [
            (physical, True),
            (physical, False),
            (emulators, True),
            (emulators, False),
        ]
    for pool, want_android in rounds:
        found = pick_from(pool, want_android)
        if found:
            print(found)
            return
    sys.exit(1)

if __name__ == "__main__":
    main()
PY
}

pick_device() {
  local explicit="${1:-}"
  explicit="${explicit:-${FLUTTER_INTEGRATION_TEST_DEVICE:-}}"
  if [[ -n "$explicit" ]]; then
    echo "$explicit"
    return
  fi
  local mobile_id=""
  if mobile_id="$(pick_mobile_id 2>/dev/null)"; then
    if [[ -n "$mobile_id" ]]; then
      echo "$mobile_id"
      return
    fi
  fi
  local list
  list="$(flutter devices --no-version-check 2>/dev/null || true)"
  if echo "$list" | grep -qiF 'linux (desktop)'; then
    echo linux
    return
  fi
  if echo "$list" | grep -qiF 'macos (desktop)'; then
    echo macos
    return
  fi
  if echo "$list" | grep -qiF 'windows (desktop)'; then
    echo windows
    return
  fi
  echo ""
}

DEVICE="$(pick_device "${1:-}")"
if [[ -z "$DEVICE" ]]; then
  echo "No device found. Plug a phone, start a simulator, or pass id:" >&2
  echo "  flutter devices" >&2
  echo "  ./scripts/run_flutter_integration_tests.sh <device_id>" >&2
  exit 1
fi

echo "Running: flutter test integration_test -d $DEVICE"
exec flutter test integration_test -d "$DEVICE"
