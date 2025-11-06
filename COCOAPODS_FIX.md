# CocoaPods Configuration Fix

## Problem
iOS builds were failing with `Command CodeSign failed with a nonzero exit code` error when building for simulator.

## Solution

### Code Signing Fix (`project.pbxproj`)
For iOS simulator builds, code signing is not required and was causing build failures. Fixed by:

1. **Disabled code signing for simulator builds**:
   - `"CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]" = NO;`
   - `"CODE_SIGNING_REQUIRED[sdk=iphonesimulator*]" = NO;`
   - `"CODE_SIGN_IDENTITY[sdk=iphonesimulator*]" = "";`
   - `"CODE_SIGN_STYLE[sdk=iphonesimulator*]" = Manual;`

2. **Kept code signing for physical devices**:
   - `CODE_SIGNING_ALLOWED = YES;` (for physical devices)
   - `CODE_SIGNING_REQUIRED = YES;` (for physical devices)
   - `CODE_SIGN_IDENTITY = "Apple Development";` (for physical devices)
   - `CODE_SIGN_STYLE = Automatic;` (for physical devices)

### Podfile Configuration
- ✅ Platform: iOS 15.0
- ✅ Static frameworks: `use_frameworks! :linkage => :static`
- ✅ Modular headers: `use_modular_headers!`
- ✅ Analytics disabled: `ENV['COCOAPODS_DISABLE_STATS'] = 'true'`

### Verification
- ✅ CocoaPods version: 1.16.2
- ✅ Pods installed: 65 total pods
- ✅ Dependencies: 27 from Podfile
- ✅ Firebase SDK: 12.2.0 (consistent across all Firebase pods)

## Files Changed

1. `ios/Runner.xcodeproj/project.pbxproj` - Added simulator-specific code signing overrides for Debug and Release configurations

## Testing

### Verify Pods:
```bash
cd ios && pod install
```

### Build for Simulator:
```bash
flutter run -d "iPhone 16 Pro"
```

### Build for Physical Device:
```bash
flutter run -d "iPhone (2)"
```

## Notes

- The warning about base configuration is **not critical** - CocoaPods integration works correctly
- Code signing is only disabled for simulator builds (not physical devices)
- Physical device builds will still require proper code signing and team ID

