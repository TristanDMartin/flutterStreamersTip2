#!/bin/bash
# Safe Flutter run script - prevents concurrent builds and database locks
# Usage: ./scripts/safe_flutter_run.sh [device-id] [other-flutter-args...]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check for concurrent builds
echo "🔍 Checking for concurrent builds..."
"$SCRIPT_DIR/check_build_lock.sh"

# Run cleanup script first
echo "🧹 Running build cleanup..."
"$SCRIPT_DIR/clean_build_lock.sh"

# Change to project directory
cd "$PROJECT_DIR"

# Wait a moment after cleanup to ensure processes are fully terminated
sleep 2

# Verify no build processes are running
if pgrep -x "xcodebuild" > /dev/null || pgrep -x "flutter" > /dev/null; then
    echo "⚠️  Warning: Build processes still running. Waiting 3 more seconds..."
    sleep 3
    # Force kill if still running
    pkill -9 xcodebuild 2>/dev/null || true
    pkill -9 flutter 2>/dev/null || true
    sleep 1
fi

# Run Flutter with all passed arguments
echo "🚀 Starting Flutter build..."
exec flutter run "$@"

