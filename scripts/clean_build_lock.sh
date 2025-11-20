#!/bin/bash
# Clean build lock script - prevents database lock errors
# This script kills any running build processes and cleans lock files

set -e

echo "🧹 Cleaning build processes and locks..."

# Kill any running Xcode/Flutter build processes
pkill -9 xcodebuild 2>/dev/null || true
pkill -9 flutter 2>/dev/null || true
pkill -9 dart 2>/dev/null || true

# Wait a moment for processes to fully terminate
sleep 1

# Find and remove lock files from DerivedData
LOCK_DIR="$HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$LOCK_DIR" ]; then
    # Remove any build.db-wal and build.db-shm files (lock files)
    find "$LOCK_DIR" -name "build.db-wal" -delete 2>/dev/null || true
    find "$LOCK_DIR" -name "build.db-shm" -delete 2>/dev/null || true
    
    # Remove any Runner-specific DerivedData if it exists
    find "$LOCK_DIR" -name "Runner-*" -type d -exec rm -rf {} + 2>/dev/null || true
fi

echo "✅ Build cleanup complete"

