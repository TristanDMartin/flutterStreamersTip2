#!/usr/bin/env bash
# Resolve pubspec versionName+buildNumber → e.g. 1.0.1+2026060903
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_LINE="$(grep -E '^version:' "$ROOT/pubspec.yaml" | head -1 | awk '{print $2}')"
if [[ -z "$VERSION_LINE" ]]; then
  echo "Could not read version from pubspec.yaml" >&2
  exit 1
fi
echo "$VERSION_LINE"
