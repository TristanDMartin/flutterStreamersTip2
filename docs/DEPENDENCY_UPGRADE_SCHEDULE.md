# Dependency upgrade schedule

Run `flutter pub outdated` before each phase. Ship one phase per release; run full `flutter test` and manual smoke (auth, feed, publish, IAP) after each.

## Phase 1 — Patch & low risk (weekly)
- `shared_preferences`, `path_provider`, `intl`, `uuid`, `crypto`
- Dev-only: `build_runner`, `flutter_lints`, `mockito`

## Phase 2 — Firebase stack (bi-weekly, single PR)
- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_messaging`, `firebase_crashlytics`, `firebase_analytics`
- Deploy Firestore rules + Cloud Functions to staging first

## Phase 3 — UI & media (monthly)
- `video_player`, `cached_network_image`, `camera`, `image_picker`, `google_fonts`
- Re-test feed playback, camera record, publish trim

## Phase 4 — Major bumps (quarterly, dedicated branch)
- `google_sign_in` (pinned at 6.2.2 — evaluate migration to 7.x separately)
- `flutter_riverpod` / `hooks_riverpod` major versions
- `go_router` major versions

## Release build defines
```bash
flutter build ipa --release \
  --dart-define=GIPHY_API_KEY=your_production_key

flutter build appbundle --release \
  --dart-define=GIPHY_API_KEY=your_production_key
```
