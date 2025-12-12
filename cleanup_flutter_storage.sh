#!/bin/bash

# Flutter Storage Cleanup Script
# This script helps reduce Flutter SDK storage by removing unused platform artifacts

FLUTTER_DIR="/Users/tristanmartin/flutter-sdk/flutter"
CACHE_DIR="$FLUTTER_DIR/bin/cache"
ARTIFACTS_DIR="$CACHE_DIR/artifacts/engine"

echo "🧹 Flutter Storage Cleanup"
echo "=========================="
echo ""

# Show current size
CURRENT_SIZE=$(du -sh "$FLUTTER_DIR" | cut -f1)
echo "Current Flutter SDK size: $CURRENT_SIZE"
echo ""

# Function to remove directory with confirmation
remove_if_exists() {
  local dir=$1
  local description=$2
  local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
  
  if [ -d "$dir" ]; then
    echo "Found: $description ($size)"
    read -p "Remove $description? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$dir"
      echo "✅ Removed $description"
      return 0
    else
      echo "⏭️  Skipped $description"
      return 1
    fi
  fi
}

echo "📦 Platform Engines:"
echo ""

# macOS Desktop engines (if not developing for macOS desktop)
remove_if_exists "$ARTIFACTS_DIR/darwin-x64" "macOS Desktop engine"
remove_if_exists "$ARTIFACTS_DIR/darwin-x64-profile" "macOS Desktop profile engine"
remove_if_exists "$ARTIFACTS_DIR/darwin-x64-release" "macOS Desktop release engine"

echo ""
echo "📱 Android Architectures:"
echo ""

# Android x86/x64 (if only ARM is needed)
remove_if_exists "$ARTIFACTS_DIR/android-x86" "Android x86 engine"
remove_if_exists "$ARTIFACTS_DIR/android-x64" "Android x64 engine"
remove_if_exists "$ARTIFACTS_DIR/android-x64-profile" "Android x64 profile engine"
remove_if_exists "$ARTIFACTS_DIR/android-x64-release" "Android x64 release engine"

echo ""
echo "🌐 Web SDK:"
echo ""

# Web SDK (if not using web)
remove_if_exists "$CACHE_DIR/flutter_web_sdk" "Flutter Web SDK"

echo ""
echo "🧹 Additional Cleanup:"
echo ""

# Clean Flutter build cache
read -p "Run 'flutter clean' in current project? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  flutter clean
  echo "✅ Project cleaned"
fi

# Clean pub cache
read -p "Clean pub cache? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  flutter pub cache repair
  echo "✅ Pub cache repaired"
fi

echo ""
echo "📊 Final Size:"
FINAL_SIZE=$(du -sh "$FLUTTER_DIR" | cut -f1)
echo "Flutter SDK size: $FINAL_SIZE"
echo ""
echo "✨ Cleanup complete!"
