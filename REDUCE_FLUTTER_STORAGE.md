# Reduce Flutter SDK Storage

Current size: **~3.8GB**

## Quick Wins (Safe to Remove)

### 1. Remove macOS Desktop Engines (~806MB)
If you're only developing for mobile (iOS/Android), you can remove macOS desktop engines:

```bash
rm -rf /Users/tristanmartin/flutter-sdk/flutter/bin/cache/artifacts/engine/darwin-x64
rm -rf /Users/tristanmartin/flutter-sdk/flutter/bin/cache/artifacts/engine/darwin-x64-profile
rm -rf /Users/tristanmartin/flutter-sdk/flutter/bin/cache/artifacts/engine/darwin-x64-release
```

**Note:** Flutter will re-download these if you run `flutter run -d macos` later.

### 2. Remove Android x86/x64 Engines (~318MB)
If you only need ARM devices (most modern Android phones), remove x86/x64:

```bash
rm -rf /Users/tristanmartin/flutter-sdk/flutter/bin/cache/artifacts/engine/android-x86
rm -rf /Users/tristanmartin/flutter-sdk/flutter/bin/cache/artifacts/engine/android-x64
rm -rf /Users/tristanmartin/flutter-sdk/flutter/bin/cache/artifacts/engine/android-x64-profile
rm -rf /Users/tristanmartin/flutter-sdk/flutter/bin/cache/artifacts/engine/android-x64-release
```

### 3. Remove Web SDK (~98MB)
If you're not developing for web:

```bash
rm -rf /Users/tristanmartin/flutter-sdk/flutter/bin/cache/flutter_web_sdk
```

### 4. Clean Project Build Artifacts
Run in your project directory:

```bash
cd /Users/tristanmartin/Desktop/flutterST
flutter clean
flutter pub cache repair
```

## Expected Savings

- macOS engines: ~806MB
- Android x86/x64: ~318MB  
- Web SDK: ~98MB
- **Total potential savings: ~1.2GB**

## All-in-One Script

Run this to remove all non-essential platforms:

```bash
#!/bin/bash
FLUTTER_CACHE="/Users/tristanmartin/flutter-sdk/flutter/bin/cache/artifacts/engine"

# Remove macOS desktop
rm -rf "$FLUTTER_CACHE/darwin-x64"*
echo "Removed macOS desktop engines"

# Remove Android x86/x64
rm -rf "$FLUTTER_CACHE/android-x86"
rm -rf "$FLUTTER_CACHE/android-x64"*
echo "Removed Android x86/x64 engines"

# Remove Web SDK
rm -rf /Users/tristanmartin/flutter-sdk/flutter/bin/cache/flutter_web_sdk
echo "Removed Web SDK"

echo "✅ Cleanup complete! Run 'du -sh ~/flutter-sdk/flutter' to check new size"
```

## Important Notes

- Flutter will automatically re-download removed engines when needed
- Keep iOS and Android ARM engines (required for mobile development)
- You can always restore by running `flutter doctor` or building for that platform
