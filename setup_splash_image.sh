#!/bin/bash
# Script to set up composite splash image for Android

SPLASH_IMAGE="assets/splash_composite.png"
TARGET_DIR="android/app/src/main/res/drawable"
TARGET_FILE="$TARGET_DIR/splash_composite.png"

echo "🎨 Setting up Android splash image..."

# Check if source image exists
if [ ! -f "$SPLASH_IMAGE" ]; then
    echo "❌ Error: $SPLASH_IMAGE not found!"
    echo "📝 Please create a composite splash image with:"
    echo "   - Purple background (#6137EB)"
    echo "   - White logo centered"
    echo "   - 'StreamersTip' text in white, bold, 32pt"
    echo "   - 'Connect • Create • Share' tagline in white, 16pt"
    echo "   - Save as: $SPLASH_IMAGE"
    exit 1
fi

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Copy the image
echo "📋 Copying $SPLASH_IMAGE to $TARGET_FILE..."
cp "$SPLASH_IMAGE" "$TARGET_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Splash image set up successfully!"
    echo "🚀 The Android native launch screen will now show logo + text"
else
    echo "❌ Failed to copy splash image"
    exit 1
fi

