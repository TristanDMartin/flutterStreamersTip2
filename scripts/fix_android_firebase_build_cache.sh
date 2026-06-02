#!/usr/bin/env bash
# Clears Gradle build cache entries that break FlutterFire Android plugins
# (FlutterFirebaseFunctionsPlugin / FirebaseRemoteConfigPlugin missing).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Clearing Gradle build cache..."
rm -rf "${HOME}/.gradle/caches/build-cache-"*

echo "Clearing project Android build outputs..."
flutter clean
rm -rf build/cloud_functions build/firebase_remote_config build/firebase_storage

flutter pub get
echo "Done. Run: flutter run -d <device-id>"
