# Android R8 compatibility audit (deferred enablement)

**Verdict: SAFE TO ENABLE NOW? NO**

Dart `--obfuscate` is already enforced by `scripts/build_store_release.sh`.
Java/Kotlin R8 minify remains **DISABLED** until this audit’s keep rules are
wired, Media3 versions are aligned, and a minified release smoke matrix passes.

## Current state

| Item | Status |
|------|--------|
| `isMinifyEnabled` | false (signing only) |
| `proguard-rules.pro` | draft at `android/app/proguard-rules.pro` (not wired) |
| Crashlytics Gradle plugin | applied (native mapping when R8 later enabled) |
| Dart symbols | `symbols/<version>/` via store script |

## Highest risks if enabled blindly

1. Custom Media3 PlatformView (`streamers_tip/media3_player`) — feed black screen
2. Media3 version skew (app `1.5.1` vs `video_player` plugin `1.8.0`)
3. `flutter_secure_storage` / Tink — Tippy session / auth remnants fail
4. Play Billing / Google Sign-In / Firebase reflection
5. `flutter_local_notifications` + Gson models
6. Notification icon stripped if `shrinkResources` without `keep.xml`

## Enablement sequence (when ready)

1. Align Media3 versions in `android/app/build.gradle.kts`
2. Wire draft keep rules:
   ```kotlin
   release {
     isMinifyEnabled = true
     isShrinkResources = false // first ship
     proguardFiles(
       getDefaultProguardFile("proguard-android-optimize.txt"),
       "proguard-rules.pro",
     )
   }
   ```
3. Build via `bash scripts/build_store_release.sh android` (summary must show `R8: ENABLED`)
4. Confirm `build/app/outputs/mapping/release/mapping.txt` exists
5. Physical-device smoke matrix (release AAB):
   - Cold start + Crashlytics test crash
   - Google Sign-In + session restore
   - Home feed Media3 + video_player
   - FCM / local notification icon
   - IAP query
   - Camera + QR (`mobile_scanner`)
6. Only then consider `isShrinkResources = true` + `res/raw/keep.xml`

Do not combine R8 enablement with CSP or ignoreBuildErrors changes in the same ship.
