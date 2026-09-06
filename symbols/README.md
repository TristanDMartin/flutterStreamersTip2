# Release symbol archives (Dart --split-debug-info)
#
# Each store build writes here:
#   symbols/<versionName+buildNumber>/
# Example:
#   symbols/1.0.1+2026060903/
#
# These files are required to decode obfuscated Crashlytics stack traces.
# Do not commit symbol blobs. Do not delete a release's folder until that
# build is fully retired from production / Play / App Store.
#
# Build:
#   bash scripts/build_store_release.sh android
# Upload (optional, after setting FIREBASE_*_APP_ID):
#   bash scripts/upload_crashlytics_symbols.sh
