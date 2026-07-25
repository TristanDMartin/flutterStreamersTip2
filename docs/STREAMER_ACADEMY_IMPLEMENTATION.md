# Streamer Academy — Implementation Report

## Shared content source

**Primary source of truth:** Firestore collections shared by the website and Flutter app:

| Collection | Purpose |
|------------|---------|
| `academyCategories` | Published category metadata |
| `academyGuides` | Guide summaries (no full lesson bodies on home load) |
| `academyLessons` | Full lesson content loaded on demand |
| `academyPaths` | Quest-style learning paths |
| `academyUserProgress` | Per-user reading/completion/saved state |
| `academyConfig/xpRewards` | Configurable XP reward values |

**Website API parity:** `https://streamerstip.com/api/academy/*` is not deployed yet (404). The app reads Firestore directly; when the website API is live, both platforms should continue using the same collections (or the API should proxy Firestore).

## Collections / services added or changed

### Firestore
- Rules added for all Academy collections in `firestore.rules`
- Recommended composite indexes (add to `firestore.indexes.json` before production scale):
  - `academyGuides`: `isPublished` + `sortOrder`
  - `academyGuides`: `categoryId` + `isPublished` + `sortOrder`
  - `academyLessons`: `guideId` + `isPublished` + `sortOrder`
  - `academyUserProgress`: `userId` + `isSaved`

### Flutter module (`lib/features/academy/`)
- `models/academy_models.dart`
- `data/academy_repository.dart` — Firestore + SharedPreferences cache
- `services/academy_xp_service.dart` — trusted gamification events
- `services/academy_search_service.dart` — debounced client search on summaries
- `academy_providers.dart` — Riverpod providers
- Views: home, search, category, path, guide, lesson, saved, progress
- Widgets: `academy_widgets.dart`

### App integration
- `lib/widgets/discover_view.dart` — Creator Match hero replaced with Streamer Academy card
- `lib/routing/app_routes.dart` — Academy routes
- `lib/routing/app_navigator.dart` — `openAcademy*` helpers
- `lib/services/enhanced_deep_linking_service.dart` — `/academy/*` deep links

## Flutter routes

| Route | Screen |
|-------|--------|
| `/academy` | Academy home |
| `/academy/search` | Search |
| `/academy/saved` | Saved guides |
| `/academy/progress` | Progress summary |
| `/academy/category` | Category browse (args: `categoryId`) |
| `/academy/path` | Learning path (args: `pathId`) |
| `/academy/guide` | Guide detail (args: `guideId`) |
| `/academy/lesson` | Lesson reader (args: `lessonId`, optional `guideId`) |

## Gamification events

Emitted via `createGamificationEvent` / `POST /gamification/events`:

| Action | Event type | Idempotency key |
|--------|------------|-----------------|
| First guide open of day | `academy.guide_viewed` | `academy_first_guide_day_{uid}_{YYYYMMDD}` |
| Lesson complete | `academy.lesson_completed` | `academy_lesson_completed:{uid}:{lessonId}` |
| Quiz complete | `academy.lesson_completed` | `academy_quiz_completed:{uid}:{lessonId}` |
| Path complete | `academy.track_completed` | `academy_path_completed:{uid}:{pathId}` |
| Category complete | `academy.module_completed` | `academy_category_completed:{uid}:{categoryId}` |
| Guide bookmark | `academy.guide_bookmarked` | `academy_guide_saved:{uid}:{guideId}` |
| Apply to planner | `content.plan_item_created` | `academy_planner_apply:{uid}:{lessonId}` |

XP amounts are read from `academyConfig/xpRewards` (not hard-coded in UI).

## XP duplication protections

1. Stable `eventId` per user + lesson/action
2. Server-side `gamification_events/{eventId}` create-only dedupe
3. `users/{uid}/gamification_audit/{eventId}` mission audit guard
4. Firestore rules block clients from setting `xpAwarded: true`
5. Lesson completion checks existing `academyUserProgress` before re-emitting
6. First-guide-of-day guarded via `SharedPreferences` + stable event id

## Search implementation

- Client-side debounced search (250ms) over loaded guide summaries
- Matches: title, description, tags, platforms, keywords, difficulty, category, lesson titles
- Empty state: “Tippy could not find a lesson for that yet…”
- Full lesson bodies are not downloaded for search (performance requirement)

## Website parity findings (audit)

| Area | Status |
|------|--------|
| Academy Firestore collections in this repo | **Added (app-side); website must publish into same collections** |
| `/api/academy/*` on streamerstip.com | **Not deployed** |
| Website Academy UI in flutterST repo | **Not present** (external website repo) |
| Gamification mission templates for lessons | **Already existed; now emitters added in app** |
| In-app external browser Academy link | **Replaced by native experience** |
| Saved guides sync | **Via `academyUserProgress.isSaved`** |
| Progress sync | **Via `academyUserProgress`** |

## Deep-link handling

- `streamerstip.com/academy` → Academy home
- `/academy/guide/{id}` → Guide
- `/academy/lesson/{id}?guideId=` → Lesson
- `/academy/category/{id}`, `/academy/path/{id}`, `/academy/search`, `/academy/saved`, `/academy/progress`
- Website fallback when app not installed: unchanged (universal links / store)

## Offline behavior

- Category, guide summary, and path metadata cached in `SharedPreferences`
- Progress writes queued through Firestore offline persistence
- Failed home load falls back to cached guide summaries
- XP events require connectivity (server-side award); progress saved locally first

## Automated tests added

- `test/unit/features/academy/academy_search_service_test.dart`

## Manual testing checklist

- [ ] iPhone (portrait) — Discover card tap → Academy home
- [ ] iPhone — Search, category, guide, lesson flow
- [ ] iPhone — Complete lesson → XP event (verify in gamification audit)
- [ ] iPhone — Save guide, Apply to Content Planner
- [ ] iPhone — Deep link `/academy/guide/{id}`
- [ ] iPad (tablet width) — grid layout for categories
- [ ] Dark + light mode
- [ ] VoiceOver / semantic progress labels
- [ ] Offline: cached categories/guides visible; error state on missing network

## Remaining content migration work

1. **Website/admin:** Publish production categories, guides, lessons, and paths into the same Firestore collections (or deploy `/api/academy/*` that mirrors them). Demo seed is available via `node scripts/seed_academy_content.js`.
2. **Firestore indexes:** Academy composite indexes are in `firestore.indexes.json` — deploy with `firebase deploy --only firestore:indexes`.
3. **Server hook:** Cloudflare Worker + Firebase HTTPS gamification handlers now set `academyUserProgress.xpAwarded` after academy lesson completion events.
4. **Tippy backend:** `surface: academy_lesson` (and related academy fields) are injected into Tippy prompt context from lesson/guide docs.
5. **Website parity QA:** Verify titles, thumbnails, ordering, and draft filtering match production website once content is live.
6. **Manual device QA:** Discover → Academy → complete lesson → confirm XP / `xpAwarded`.
