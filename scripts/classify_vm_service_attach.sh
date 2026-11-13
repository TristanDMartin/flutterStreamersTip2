#!/usr/bin/env bash
# Classify a Flutter device-test log for iOS Dart VM attach failure.
# Prints "failed", "ok", or "unknown". Does not start a device test.
set -euo pipefail

classify_vm_service_attach() {
  local log="${1:-}"
  if [[ -z "$log" || ! -f "$log" ]]; then
    echo "unknown"
    return 0
  fi
  if grep -Eiq 'Dart VM Service was not discovered|Error waiting for a debug connection|VM Service not discovered' "$log"; then
    echo "failed"
    return 0
  fi
  echo "ok"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  classify_vm_service_attach "${1:-}"
fi
