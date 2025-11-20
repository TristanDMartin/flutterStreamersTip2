#!/bin/bash
# Check if a build is already running and prevent concurrent builds

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="$PROJECT_DIR/.flutter_build_lock"

if [ -f "$LOCK_FILE" ]; then
    # Check if process is actually running
    PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo "❌ Build already running (PID: $PID)"
        echo "   Please wait for the current build to finish or kill it with: kill $PID"
        exit 1
    else
        # Stale lock file, remove it
        echo "🧹 Removing stale lock file..."
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file with current PID
echo $$ > "$LOCK_FILE"
trap "rm -f '$LOCK_FILE'" EXIT

