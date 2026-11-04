# Code Refactoring Plan - Production Quality

**Status:** 🔴 **HIGH PRIORITY** - Technical debt blocking maintainability  
**Created:** 2026-11-04  
**Target:** Before expanding team / adding major features

---

## Overview

The codebase has several "god files" (3000-4800 lines) that violate single responsibility principle and make code review, testing, and maintenance difficult. This plan outlines a systematic approach to split these files while maintaining functionality.

---

## Priority 1: Critical God Files

### 1. `lib/widgets/video_publishing_screen.dart` (4,883 lines)

**Current Structure:**
- Single StatefulWidget handling entire publishing flow
- Mixed concerns: UI, business logic, video processing, upload management
- 200+ methods in one class

**Refactoring Plan:**

```
lib/features/publish/
├── presentation/
│   ├── video_publishing_screen.dart (main coordinator, ~200 lines)
│   ├── widgets/
│   │   ├── camera_preview_section.dart
│   │   ├── video_editor_section.dart
│   │   ├── caption_input_section.dart
│   │   ├── category_selector_section.dart
│   │   ├── hashtag_input_section.dart
│   │   ├── privacy_settings_section.dart
│   │   ├── thumbnail_selector_section.dart
│   │   └── publish_button_section.dart
│   └── state/
│       ├── publishing_state.dart (Freezed)
│       └── publishing_state_notifier.dart (Riverpod)
├── domain/
│   ├── models/
│   │   ├── draft_video.dart
│   │   ├── publish_settings.dart
│   │   └── upload_progress.dart
│   └── use_cases/
│       ├── validate_video_use_case.dart
│       ├── compress_video_use_case.dart
│       ├── generate_thumbnail_use_case.dart
│       └── publish_video_use_case.dart
└── data/
    ├── repositories/
    │   └── video_upload_repository.dart
    └── services/
        ├── video_compression_service.dart (move from lib/services/)
        └── video_upload_service.dart (move from lib/services/)
```

**Migration Steps:**
1. Extract UI sections into separate widget files (no business logic)
2. Create Freezed state classes for publishing state
3. Create Riverpod StateNotifier to manage publishing flow
4. Extract compression/upload logic into use cases
5. Create repository layer for video upload
6. Wire everything back together
7. Update tests to cover each component
8. Delete old monolithic file

**Testing Requirements:**
- Unit tests for each use case
- Widget tests for each UI section
- Integration test for full publishing flow

**Estimated Effort:** 3-4 days (careful refactoring to avoid regressions)

---

### 2. `lib/widgets/video_player_view_optimized.dart` (4,806 lines)

**Current Structure:**
- Single StatefulWidget handling video playback, UI controls, social features
- Mixed concerns: player lifecycle, gesture handling, like/bookmark/comment actions
- Tightly coupled to GlobalPlaybackManager

**Refactoring Plan:**

```
lib/features/video_player/
├── presentation/
│   ├── video_player_screen.dart (main coordinator, ~200 lines)
│   ├── widgets/
│   │   ├── video_surface.dart (actual player surface)
│   │   ├── video_controls_overlay.dart (play/pause, progress)
│   │   ├── video_info_overlay.dart (caption, username, stats)
│   │   ├── video_actions_panel.dart (like, comment, share, bookmark)
│   │   ├── video_gesture_detector.dart (double-tap, swipe)
│   │   └── video_loading_indicator.dart
│   └── state/
│       ├── player_state.dart (Freezed: playing/paused/buffering/error)
│       └── player_state_notifier.dart (Riverpod)
├── domain/
│   ├── models/
│   │   ├── video_metadata.dart
│   │   ├── playback_position.dart
│   │   └── player_error.dart
│   └── use_cases/
│       ├── play_video_use_case.dart
│       ├── pause_video_use_case.dart
│       ├── seek_video_use_case.dart
│       └── preload_video_use_case.dart
└── data/
    └── coordinators/
        ├── playback_coordinator.dart (move from lib/coordinators/)
        └── playback_pool_policy.dart
```

**Migration Steps:**
1. Extract gesture handling into separate widget
2. Extract video controls into separate widget
3. Extract social actions panel into separate widget
4. Create Freezed state for player state
5. Create Riverpod StateNotifier for player lifecycle
6. Extract playback coordinator usage into use cases
7. Wire everything back together
8. Update tests for each component
9. Test on Android devices (MediaCodec BAD_INDEX issues)

**Testing Requirements:**
- Unit tests for playback coordinator usage
- Widget tests for UI components
- Integration tests for playback matrix (iOS + Android devices)
- Performance tests for memory/battery usage

**Estimated Effort:** 4-5 days (includes Android playback matrix testing)

---

### 3. `lib/widgets/discover_view.dart` (3,355 lines)

**Current Structure:**
- Single StatefulWidget handling discovery feed, trending creators, categories
- Mixed concerns: data fetching, UI rendering, navigation, caching
- Multiple nested ListViews and complex scroll behavior

**Refactoring Plan:**

```
lib/features/discover/
├── presentation/
│   ├── discover_screen.dart (main coordinator, ~200 lines)
│   ├── widgets/
│   │   ├── discover_search_bar.dart
│   │   ├── discover_hero_section.dart
│   │   ├── trending_creators_section.dart (already exists, enhance)
│   │   ├── categories_grid_section.dart
│   │   ├── recommended_videos_section.dart
│   │   ├── discover_empty_state.dart
│   │   └── discover_error_state.dart
│   └── state/
│       ├── discover_state.dart (Freezed: loading/loaded/error/empty)
│       └── discover_state_notifier.dart (Riverpod)
├── domain/
│   ├── models/
│   │   ├── discover_content.dart
│   │   ├── trending_creator.dart (already exists)
│   │   └── discover_category.dart
│   └── use_cases/
│       ├── fetch_trending_creators_use_case.dart
│       ├── fetch_categories_use_case.dart
│       ├── fetch_recommended_videos_use_case.dart
│       └── search_discover_use_case.dart
└── data/
    └── repositories/
        └── discover_repository.dart
```

**Migration Steps:**
1. Extract search bar into separate widget
2. Extract hero section into separate widget
3. Extract each content section into separate widgets
4. Create Freezed state for discover screen state
5. Create Riverpod StateNotifier for data fetching
6. Extract data fetching logic into repository
7. Add ScreenEmptyState and ScreenErrorState
8. Wire everything back together
9. Update tests

**Testing Requirements:**
- Unit tests for discover repository
- Widget tests for each section
- Integration test for discover flow

**Estimated Effort:** 3-4 days

---

## Priority 2: Additional Large Files

### 4. `lib/services/robust_auth_service.dart` (2,558 lines)
- **Issue:** Mixed authentication flows, session management, error handling
- **Recommendation:** Split into separate services per auth method (email, Google, Apple, etc.)

### 5. `lib/services/video_service.dart` (2,372 lines)
- **Issue:** CRUD operations, analytics, feed filtering, recommendations all in one
- **Recommendation:** Move to feature-based architecture with repositories

### 6. `lib/services/global_playback_manager.dart` (2,120 lines)
- **Issue:** Audio session management, coordinator lifecycle, background playback
- **Recommendation:** Split into AudioSessionManager, CoordinatorPool, BackgroundPlaybackService

---

## Priority 3: UI Error/Empty States

### Missing Error/Empty States

#### `lib/widgets/discover_view.dart`
- ❌ No ScreenEmptyState when no trending creators
- ❌ No ScreenEmptyState when no categories
- ❌ No ScreenErrorState for fetch failures
- ❌ Errors shown in console, not to user

**Required Changes:**
```dart
// When fetching fails
if (state.hasError) {
  return ScreenErrorState(
    message: state.error ?? 'Failed to load discover content',
    onRetry: () => ref.read(discoverProvider.notifier).refresh(),
  );
}

// When content is empty
if (state.trendingCreators.isEmpty && !state.isLoading) {
  return ScreenEmptyState(
    icon: Icons.explore_outlined,
    title: 'No trending creators yet',
    message: 'Check back soon to discover new creators',
  );
}
```

#### `lib/widgets/network_view.dart`
- ⚠️ Partial error handling (some ScreenErrorState usage)
- ❌ No empty state for "No followers" / "No following"
- ❌ Network request errors not surfaced to UI

**Required Changes:**
```dart
// Empty followers
if (followers.isEmpty && !isLoading) {
  return ScreenEmptyState(
    icon: Icons.people_outline,
    title: 'No followers yet',
    message: 'Share your profile to grow your audience',
  );
}

// Empty following
if (following.isEmpty && !isLoading) {
  return ScreenEmptyState(
    icon: Icons.person_add_outlined,
    title: 'Not following anyone',
    message: 'Discover and follow creators you love',
  );
}
```

#### `lib/widgets/inbox_view_optimized.dart`
- ❌ No ScreenEmptyState for empty inbox
- ❌ No ScreenErrorState for message fetch failures
- ❌ Loading state is basic spinner, no skeleton

**Required Changes:**
```dart
// Empty inbox
if (conversations.isEmpty && !isLoading) {
  return ScreenEmptyState(
    icon: Icons.inbox_outlined,
    title: 'No messages yet',
    message: 'Start a conversation with creators you follow',
  );
}

// Fetch error
if (error != null) {
  return ScreenErrorState(
    message: 'Failed to load messages: $error',
    onRetry: () => _refreshConversations(),
  );
}
```

---

## Implementation Priority

### Phase 1: Quick Wins (1-2 days)
1. ✅ Add ScreenEmptyState to discover, network, inbox views
2. ✅ Add ScreenErrorState to discover, network, inbox views
3. Document refactoring plans in this file

### Phase 2: Core Refactoring (2-3 weeks)
1. Refactor `discover_view.dart` (3 days)
2. Refactor `video_player_view_optimized.dart` (4-5 days)
3. Refactor `video_publishing_screen.dart` (3-4 days)

### Phase 3: Service Layer Cleanup (1-2 weeks)
1. Split `robust_auth_service.dart`
2. Split `video_service.dart`
3. Split `global_playback_manager.dart`

---

## Success Metrics

### Code Quality
- ✅ No files >1000 lines (except generated code)
- ✅ Average file size <300 lines
- ✅ Cyclomatic complexity <15 per method
- ✅ Widget nesting depth <6 levels

### Testing
- ✅ Unit test coverage >70% for refactored modules
- ✅ Widget test coverage >50% for UI components
- ✅ Integration tests for all critical flows

### Performance
- ✅ No regressions in frame timing
- ✅ No increases in memory usage
- ✅ Faster build times (smaller files = faster incremental builds)

---

## Migration Safety

### Pre-Refactoring Checklist
- [ ] Create feature branch for refactoring
- [ ] Run all existing tests and ensure they pass
- [ ] Create integration tests for the area being refactored
- [ ] Document current behavior and edge cases
- [ ] Get code review on refactoring plan

### During Refactoring
- [ ] Keep old file until new structure is fully working
- [ ] Use feature flags to toggle between old/new implementations
- [ ] Test on physical devices after each major change
- [ ] Update tests incrementally as files are split
- [ ] Monitor Crashlytics for new errors

### Post-Refactoring
- [ ] Run full test suite
- [ ] Manual QA on physical devices (iOS + Android)
- [ ] Monitor production metrics for 1 week
- [ ] Delete old files once stability confirmed
- [ ] Update documentation

---

## Notes

- **DO NOT** refactor multiple god files in the same PR
- **DO** refactor incrementally with frequent testing
- **DO** keep old code as fallback during migration
- **DO** update tests as you refactor
- **DO NOT** change behavior during refactoring (behavior changes = separate PR)

---

**Last Updated:** 2026-11-04  
**Status:** 📋 Plan documented, ready for execution  
**Owner:** Engineering team lead
