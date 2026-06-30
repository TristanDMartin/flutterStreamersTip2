# Video Feed Visibility Audit - 2026-06-29

## Summary

Not all videos are showing because the app no longer treats every `videos/{id}`
document as feed-playable. Home and Discover require a strict ready/playable
contract:

- `status` is `ready`, `published`, or `active`
- `isReadyForFeed == true`
- `visible != false`
- public visibility (`visibility: public`, `privacy: Everyone/Public`, or both
  missing for legacy docs)
- an owner field or legacy owner hint
- a non-placeholder, non-image, non-`original.mp4` playback source

Production Firestore currently has videos that are `ready` and even have Mux
playback URLs, but still fail the feed contract because `isReadyForFeed` is
missing/false or owner metadata is missing.

## Live Production Verification

Checked on 2026-06-29 against Firebase project `streamerstip-6cfdb`.

Worker health:

```text
GET https://streamerstip-mux-api.streamerstip.workers.dev/health
=> {"worker":"ok","firestore":"ok"}
```

Firestore `videos` collection:

```text
Total videos scanned: 49
Eligible for Home/Discover: 9
Rejected by current feed gates: 40
```

Status breakdown:

```text
ready: 37
failed: 11
removed: 1
```

Feed-ready field breakdown:

```text
isReadyForFeed true: 30
isReadyForFeed false: 13
isReadyForFeed missing: 6
```

Rejection reasons using the current app rules:

```text
isReadyForFeed:not_true: 6
missing_owner: 3
not_ready_for_playback: 10
deleted_flag: 9
status:failed: 11
status:removed: 1
```

Important examples:

```text
Ready with Mux URLs, but excluded because isReadyForFeed is missing/false:
- jsmbQMLQjoUyC5cUFvkrRbi9mkp1_1780431275913_wvxe7g
- jsmbQMLQjoUyC5cUFvkrRbi9mkp1_1781462056763_p7bb37
- jsmbQMLQjoUyC5cUFvkrRbi9mkp1_1781812807350_kscuve
- OSAfmOAii1R3IUCM6jObu8lIlzA3_1780497622644_ic54lm
- OSAfmOAii1R3IUCM6jObu8lIlzA3_1780593382963_26gam3
- OSAfmOAii1R3IUCM6jObu8lIlzA3_1780593658694_kep0rx

Ready with playback URLs, but excluded because no owner/legacy owner hint:
- video_1777564297507_30ZA7hu7
- video_1779317104769_DSmcClYA
- 1777510738834_1003

Ready/feed-visible promo docs, but excluded because no playable URL:
- QitrBWt168Rw1xFX8B3E3uJn8Ql1_promo_vid_clutch
- QitrBWt168Rw1xFX8B3E3uJn8Ql1_promo_vid_ranked
- QitrBWt168Rw1xFX8B3E3uJn8Ql1_promo_vid_controller
- QitrBWt168Rw1xFX8B3E3uJn8Ql1_promo_vid_speedrun
- QitrBWt168Rw1xFX8B3E3uJn8Ql1_promo_vid_mobile
- QitrBWt168Rw1xFX8B3E3uJn8Ql1_promo_vid_esports
- QitrBWt168Rw1xFX8B3E3uJn8Ql1_promo_vid_chat
- QitrBWt168Rw1xFX8B3E3uJn8Ql1_promo_vid_setup
```

## App Code Paths

Home feed candidate loading:

- `lib/services/video_service.dart`
  - `_loadFeedCandidateDocs()` queries canonical feed-ready docs first, then
    supplements with legacy fallback queries.
  - `_runLoadAllVideos()` rejects docs using
    `rejectFeedCandidateBeforeHydration()` before hydration.
  - Hydration then requires `resolveReadyPlaybackUrl()` and
    `VideoHealthGate.resolvePlayableSource()`.

Shared feed rules:

- `lib/utils/video_document_rules.dart`
  - `rejectFeedCandidateBeforeHydration()` rejects deleted docs, bad statuses,
    `visible:false`, `isReadyForFeed != true`, private docs, and missing owners.
  - `isDiscoverEligibleFromFirestore()` also requires a ready playback source.

Playback URL rules:

- `lib/utils/video_url_resolver.dart`
  - `resolveReadyPlaybackUrl()` only returns a URL when
    `isReadyForFeed == true` and status is ready/published/active.
  - It rejects image URLs, placeholders, local file URLs, and `original.mp4`.

Playback health:

- `lib/utils/video_health_gate.dart`
  - Rejects hidden, failed, processing, not-ready, raw/original, and
    playback-not-ready documents.

Discover:

- `lib/providers/discover_provider.dart`
  - Category fetches apply `isDiscoverEligibleFromFirestore()`, so Discover
    has the same `isReadyForFeed` and playback URL requirement.

Backend/Worker:

- `cloudflare_workers/mux/src/index.js`
  - Mux webhook sets `isReadyForFeed: true` only when the asset passes gates:
    duration is 1-300 seconds, thumbnail exists, and it is not a draft.
  - Backfill helpers can patch canonical playback/feed fields when the webhook
    missed a video.

## Root Cause

There are three different buckets:

1. **Legitimate exclusions**
   - `failed`, `removed`, deleted, private/admin-removed, draft, or unplayable
     videos should not show in public feeds.

2. **Backfill/metadata drift**
   - Some production docs are `ready` and have usable Mux playback URLs, but are
     missing `isReadyForFeed: true`.
   - Current app code intentionally excludes these docs.
   - This matches the existing release note in
     `docs/APR30_SHIP_SIGNOFF_SHEET.md`: video metadata backfill must run before
     legacy videos without `isReadyForFeed: true` can return to production
     feeds.

3. **Owner/playback data defects**
   - Some docs have no owner metadata, so profile/feed hydration cannot attach
     them to a creator.
   - Promo fixture docs are marked feed-ready but do not have playable URLs, so
     they cannot be used as actual videos.

## Why This Is Happening

The strict gate is intentional. It prevents the app from trying to autoplay:

- failed uploads
- deleted/admin removed videos
- private videos
- uploads still waiting for Mux
- legacy Firebase/raw `original.mp4` files that can crash or black-screen mobile
- documents without a creator owner
- documents whose `videoUrl` is actually a thumbnail/placeholder

The issue is not that the feed query cannot see the documents. The issue is
that many documents do not satisfy the fields the current app requires before it
will build a `HomeVideo` or Discover card.

## Repair Options

Recommended order:

1. Run a dry-run backfill over `videos` and review counts.
2. Patch only docs that are public, non-deleted, `status: ready`, have a valid
   Mux/canonical/HLS playback URL, and have owner metadata or a safe owner
   inference.
3. For the six ready/Mux docs missing `isReadyForFeed`, set:
   - `isReadyForFeed: true`
   - `visible: true`
   - `playbackReady: true`
   - `visibility: public` when appropriate
   - canonical URL aliases if any are missing
4. For the three missing-owner docs, repair `ownerId/userId/creatorId/creator_id`
   only if the correct creator UID is known.
5. Do not resurrect docs rejected as deleted, removed, failed, or admin removed.
6. Either remove promo fixture docs from feed eligibility or add real playable
   Mux/HLS URLs.

## Validation Performed

Local focused tests:

```text
flutter test \
  test/unit/utils/feed_candidate_rules_test.dart \
  test/utils/video_url_resolver_test.dart \
  test/unit/utils/video_url_resolver_owner_test.dart \
  test/unit/utils/discover_video_eligibility_test.dart

Result: all 24 tests passed.
```

Production checks:

```text
Firebase project: streamerstip-6cfdb
Firestore database: projects/streamerstip-6cfdb/databases/(default)
Worker health: ok
Firestore health via Worker: ok
```

## Backfill Applied - 2026-06-29

Added a repeatable local backfill script:

```text
scripts/video_feed_visibility_backfill.js
```

Dry-run before apply:

```text
scanned: 49
eligibleBefore: 9
plannedPatches: 13
```

Applied:

```text
node scripts/video_feed_visibility_backfill.js --apply --verbose
appliedPatches: 13
```

Post-apply verification:

```text
scanned: 49
eligibleBefore: 15
plannedPatches: 0
```

What was repaired:

- 6 videos that were `ready` with playback URLs but missing
  `isReadyForFeed: true` are now feed-eligible.
- 7 already-eligible legacy videos were normalized with owner aliases,
  `visible`, `privacy/visibility`, and `playbackUrl` aliases so future reads do
  not depend on legacy inference.
- No `failed`, `removed`, deleted, missing-owner, or no-playback videos were
  patched.

Remaining rejects after safe backfill:

```text
missing_owner: 3
not_ready_for_playback: 10
deleted_flag: 9
status:failed: 11
status:removed: 1
```

Those remaining docs should stay excluded unless manually repaired:

- `missing_owner`: assign owner fields only if the correct creator UID is known.
- `not_ready_for_playback`: add real Mux/HLS playback URLs or keep them out of
  public feed eligibility.
- deleted/failed/removed docs should remain hidden.

## Bottom Line

The feed is behaving according to the current safety contract. The targeted
metadata backfill raised production Home/Discover eligibility from 9 to 15
videos. The remaining excluded docs need manual owner/playback repair or should
remain hidden.
