#!/usr/bin/env bash
# Capture Firebase App Check debug token from a connected Android device.
set -euo pipefail

ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"

if [[ ! -x "$ADB" ]]; then
  echo "adb not found. Set ADB or install Android platform-tools."
  exit 1
fi

echo "Devices:"
"$ADB" devices

echo ""
echo "Clearing logcat. Cold-start the app (force-stop → open), then watch below."
"$ADB" logcat -c

echo ""
echo "Watching for App Check debug token (Ctrl+C to stop)..."
"$ADB" logcat | grep -iE --line-buffered \
  "App Check|AppCheck|DEBUG TOKEN|FirebaseAppCheck|attestation|placeholder token"
