# StreamersTip Flutter App

StreamersTip is a TikTok-style social video platform for content creators and their communities, built with Flutter for iOS and Android.

**Version:** 1.0.1+2026100401  
**Repository:** flutterStreamersTip2  
**Branch:** flutterStreamersTip2

---

## Table of Contents

- [Quick Start](#quick-start)
- [Architecture Overview](#architecture-overview)
- [Development Setup](#development-setup)
- [Configuration & Environment](#configuration--environment)
- [Building & Deployment](#building--deployment)
- [Testing](#testing)
- [Production Readiness](#production-readiness)
- [Key Documentation](#key-documentation)
- [Contributing](#contributing)

---

## Quick Start

### Prerequisites

- **Flutter SDK:** `>=3.0.0 <4.0.0`
- **Dart SDK:** Included with Flutter
- **Xcode:** 14.0+ (for iOS development)
- **Android Studio:** Latest stable (for Android development)
- **Firebase CLI:** For Firestore rules deployment
- **Node.js:** For Firebase emulator and scripts

### Clone & Install

```bash
git clone https://github.com/TristanDMartin/flutterStreamersTip2.git
cd flutterStreamersTip2
flutter pub get
```

### Run Development Build

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# With environment overrides
flutter run --dart-define=SITE_API_BASE=https://staging.streamerstip.com
```

---

## Architecture Overview

### Tech Stack

- **Framework:** Flutter 3.50.0 (pinned in `.fvmrc` and CI)
- **State Management:** Riverpod (with ChangeNotifier migration in progress)
- **Backend:** Firebase (Auth, Firestore, Storage, Functions, Crashlytics, Analytics)
- **Video:** Mux (transcoding, playback), FFmpeg Kit (processing)
- **Payment:** In-App Purchases (Apple App Store, Google Play)
- **Navigation:** go_router (declared, imperative migration in progress)

### Project Structure

```
lib/
├── core/              # App initialization, theme, Firebase bootstrap
├── features/          # Feature modules (home, gamification, onboarding, billing)
├── services/          # Business logic & data access (249 files)
├── widgets/           # UI components (188 files)
├── components/        # Shared UI elements
├── models/            # Data models & entities
├── providers/         # Riverpod state providers
├── repositories/      # Data persistence layer
└── utils/             # Helper functions & utilities

docs/                  # Comprehensive documentation (138 files)
firestore.rules        # Firestore security rules
storage.rules          # Cloud Storage security rules
firestore.indexes.json # Composite query indexes
```

### Key Features

- **Feed:** TikTok-style vertical video feed with autoplay
- **Publishing:** In-app video recording, editing, and upload to Mux
- **Social:** Follow, like, comment, bookmark, direct messaging
- **Gamification:** Achievements, progression, leaderboards
- **Tippy AI:** AI-powered creator assistant
- **Billing:** Subscription tiers, in-app purchases
- **Academy:** Creator education content
- **Network:** Creator discovery and collaboration

---

## Development Setup

### 1. Environment Configuration

Create a `.env.release` file (gitignored) with required secrets:

```bash
# Copy from example
cp .env.release.example .env.release

# Edit with your values
SITE_API_BASE=https://streamerstip.com
GIPHY_API_KEY=your_giphy_key_here
APPLE_BILLING_VERIFY_URL=https://streamerstip.com/api/billing/apple/verify
GOOGLE_BILLING_VERIFY_URL=https://streamerstip.com/api/billing/google/verify
TIPPY_BASE_URL=https://streamerstip.com/api/tippy
```

### 2. Firebase Setup

The app uses Firebase project `streamerstip-6cfdb`. Configuration files are committed:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

**Security Note:** Firebase client config is safe to commit. Protection comes from:
- Firestore/Storage rules (see `firestore.rules`, `storage.rules`)
- Firebase App Check (Play Integrity / DeviceCheck)
- API key restrictions in Google Cloud Console

### 3. Code Generation

After modifying Freezed/JsonSerializable models:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Deploy Firestore Rules

```bash
# Test rules locally with emulator
./scripts/ci_tests.sh

# Deploy to production (requires ALLOW_FIREBASE_RULES_DEPLOY=true)
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
```

---

## Configuration & Environment

### Compile-Time Configuration

Pass environment variables via `--dart-define`:

```bash
flutter build apk --release \
  --dart-define=SITE_API_BASE=https://streamerstip.com \
  --dart-define=GIPHY_API_KEY=your_key \
  --dart-define=DISABLE_APP_CHECK=false
```

**Key Flags:**
- `SITE_API_BASE`: Backend API base URL (default: `https://streamerstip.com`)
- `GIPHY_API_KEY`: Giphy API key for GIF support
- `DISABLE_APP_CHECK`: Disable App Check for debugging (default: `false`)
- `TIPPY_BASE_URL`: Tippy AI service base URL
- Feature flags in `lib/core/feature_flags.dart`

### Build Variants

**Currently:** Single production build pointing to `streamerstip-6cfdb`  
**Roadmap:** Add staging flavor with separate Firebase project

---

## Building & Deployment

### Android Release Build

```bash
# Using automated script (recommended)
./scripts/build_store_release.sh

# Manual build
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --dart-define=SITE_API_BASE=https://streamerstip.com
```

**Requirements:**
- `android/key.properties` with keystore credentials (gitignored, see `key.properties.example`)
- R8 minification enabled (see `android/app/build.gradle.kts`)
- ProGuard rules in `android/app/proguard-rules.pro`

**Outputs:**
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Symbols: `build/app/outputs/symbols/` (upload to Crashlytics)

### iOS Release Build

```bash
# Build archive
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/ios/symbols \
  --dart-define=SITE_API_BASE=https://streamerstip.com

# Open in Xcode for signing & submission
open build/ios/archive/Runner.xcarchive
```

**Requirements:**
- Valid Apple Developer account
- Provisioning profiles & certificates in Xcode
- Usage permission strings in `ios/Runner/Info.plist`

### Release Checklist

Before submitting to stores:

1. **Version Bump:** Update `version` in `pubspec.yaml`
2. **Preflight:** Run `./scripts/release_preflight.sh`
3. **Dart Defines:** Verify with `./scripts/check_release_dart_defines.sh`
4. **Test Release Build:** Install and smoke-test on physical devices
5. **Symbol Upload:** Ensure Crashlytics symbols uploaded
6. **Rules Deployed:** Verify `firestore.rules` matches production
7. **App Check:** Confirm App Check tokens issuing correctly
8. **Documentation:** Update `docs/RELEASE_TRACKER.md`

See `docs/PRODUCTION_LAUNCH_CHECKLIST.md` for comprehensive checklist.

---

## Testing

### Unit Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/admin_service_test.dart

# With coverage
flutter test --coverage
```

**Coverage:** ~161 test files, strong focus on:
- Playback coordinators
- Auth services
- Billing logic
- Onboarding flows
- Firestore rules (emulator-based)

### Integration Tests

```bash
# Device-based E2E
flutter drive --driver=test_driver/integration_driver.dart \
  --target=integration_test/home_feed_playback_e2e_test.dart
```

### Firestore Rules Tests

```bash
# Uses Firebase emulator
./scripts/ci_tests.sh
```

See `docs/TESTING_STRATEGY.md` for full strategy.

---

## Production Readiness

### Security Hardening (COMPLETED)

- ✅ Client-side admin allowlist removed
- ✅ Expired Firestore transitional rules closed
- ✅ `android:allowBackup="false"` set
- ✅ R8 minification enabled for Android
- ✅ LoggingService → Crashlytics integration
- ✅ debugPrint calls wrapped with `kDebugMode`

### Known Limitations

- **No staging environment:** Single Firebase project for all builds
- **Android playback:** MediaCodec `BAD_INDEX` on some devices (tracked in `docs/PRODUCTION_READINESS_SCORECARD.md`)
- **Large files:** Several 3000-4000 line widgets need refactoring
- **Navigation:** Migration to declarative `go_router` incomplete
- **Accessibility:** Sparse Semantics coverage; TalkBack/VoiceOver not systematically tested

### Production Blockers (PRE-LAUNCH)

1. ⚠️ **Android Playback Matrix:** Clear MediaCodec errors on target device matrix OR migrate to Media3
2. ⚠️ **Staging Environment:** Create separate Firebase project + app flavors
3. ⚠️ **Widget Tests:** Expand coverage for critical UI flows
4. ⚠️ **Accessibility Audit:** Full TalkBack/VoiceOver pass

### Monitoring & Observability

- **Crashlytics:** Automatic crash reporting + custom logs
- **Analytics:** Firebase Analytics event tracking
- **Performance:** Custom monitoring in `ProductionMonitoringService`
- **Logging:** `LoggingService` forwards to Crashlytics in production

---

## Key Documentation

### Critical Docs (Start Here)

- **[Production Launch Checklist](docs/PRODUCTION_LAUNCH_CHECKLIST.md)** - Pre-launch verification
- **[Production Readiness Scorecard](docs/PRODUCTION_READINESS_SCORECARD.md)** - Known issues & blockers
- **[Canonical Contracts](docs/CANONICAL_CONTRACTS.md)** - Web/Flutter data contract alignment
- **[Onboarding Experience](docs/ONBOARDING_EXPERIENCE.md)** - User activation flow
- **[App Check Setup](docs/APP_CHECK_SETUP.md)** - Firebase App Check configuration

### Architecture & Design

- **[Testing Strategy](docs/TESTING_STRATEGY.md)** - Test approach & coverage
- **[Dependency Upgrade Schedule](docs/DEPENDENCY_UPGRADE_SCHEDULE.md)** - Package management
- **[R8 Compatibility Audit](docs/R8_COMPATIBILITY_AUDIT.md)** - Android minification testing

### Operations

- **[Account Deletion Flow](docs/account_deletion/)** - GDPR compliance
- **[Deployment Process](docs/deployment/)** - Release pipeline
- **[Firebase Configuration](docs/firebase/)** - Backend setup

Browse all docs: `docs/` directory (138 files)

---

## Contributing

### Branch Strategy

- **Main branch:** `flutterStreamersTip2` (locked to this branch per workspace rules)
- **Feature branches:** Create off `flutterStreamersTip2`, prefix with `feature/`
- **Hotfix branches:** Prefix with `hotfix/`

### Code Style

- **Linter:** `flutter_lints` package (strict)
- **Formatting:** `dart format .` before committing
- **Line length:** 80 characters max
- **Naming:** `snake_case` for files, `camelCase` for variables, `PascalCase` for classes
- **Const:** Use `const` constructors wherever possible
- **Comments:** Avoid obvious comments; explain intent, not mechanics

### Pull Request Process

1. Create feature branch
2. Implement changes with tests
3. Run `flutter analyze` (must pass)
4. Run `flutter test` (must pass)
5. Update relevant docs
6. Submit PR with clear description
7. Address review feedback
8. Merge after approval

---

## Support & Contact

- **Issues:** GitHub Issues (TristanDMartin/flutterStreamersTip2)
- **Documentation:** `docs/` directory
- **Production Launch:** See `docs/PRODUCTION_LAUNCH_CHECKLIST.md`

---

## License

Proprietary - StreamersTip, Inc. All rights reserved.

---

**Last Updated:** 2026-11-04  
**Production Status:** Beta-ready (blockers identified, see Production Readiness section)
