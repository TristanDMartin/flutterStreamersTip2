#!/usr/bin/env bash
set -euo pipefail

# CI entrypoint for Firestore rules + follows E2E (emulator)
# Requires Firebase CLI and Java (for emulator).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Running Firestore rules tests (follows)..."
npm --prefix "$ROOT/cloud_functions" run test:rules:follows

echo "Running Firestore E2E tests (follows)..."
npm --prefix "$ROOT/cloud_functions" run test:e2e:follows

echo "✅ CI tests completed successfully."
