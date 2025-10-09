# Share Sheet Implementation - TikTok Style

## Overview

The share sheet implementation follows TikTok's pattern where:
- ✅ Video continues playing behind the modal with slight blur
- ✅ Fast 200ms slide-up animation for instant feedback
- ✅ Prefetched data for instant modal display
- ✅ Dynamic platform ranking based on user behavior
- ✅ Comprehensive analytics tracking
- ✅ Swipe-down or tap outside to dismiss

## Architecture

### 1. SharePayload Model (`lib/models/share_payload.dart`)

Prefetched data structure that ensures instant modal display:

```dart
SharePayload
├── videoId: String
├── links: ShareLinks
│   ├── webShareUrl: String
│   ├── deepLink: String?
│   ├── downloadUrl: String?
│   └── embedCode: String?
├── permissions: SharePermissions
│   ├── canShare: bool
│   ├── canDownload: bool
│   ├── canDuet: bool
│   ├── canRemix: bool
│   └── canRepost: bool
├── metadata: ShareMetadata
│   ├── creatorUsername: String
│   ├── creatorDisplayName: String
│   ├── caption: String?
│   ├── thumbnailUrl: String?
│   ├── hashtags: List<String>
│   └── createdAt: DateTime?
└── platformUsageRanking: Map<String, int>
```

### 2. ShareServiceOptimized (`lib/services/share_service_optimized.dart`)

Enhanced service with:

#### Prefetching
- `fetchSharePayload(HomeVideo)` - Prefetch share data for instant modal
- `getCachedPayload(String)` - Get cached payload instantly
- `clearOldCache()` - Manage memory with LRU cache (10 items max)

#### Platform Sharing
- `shareToTarget(ShareTarget, SharePayload)` - Share to specific platform
- Supports: Copy Link, Instagram Direct, SMS, WhatsApp, Repost, Facebook, Twitter, Telegram, Email, More
- Dynamic ranking based on usage frequency

#### Analytics Tracking
- `trackShareSheetOpen(videoId)` - When modal opens
- `trackShareCancel(videoId)` - When user dismisses
- `trackDownloadBlocked(videoId, reason)` - When download restricted
- Auto-tracking for `share_target_tap` and `share_success`

#### Action Handling
- `handleAction(ShareAction, videoId, creatorId)` - Handle contextual actions
- Supports: Report, Block, Send Message, Not Interested, Favorite

### 3. ShareSheetView (`lib/widgets/share_sheet_view.dart`)

TikTok-style bottom sheet with three layers:

#### A. Background Layer
- Video continues playing with 3px blur
- `BackdropFilter` with 30% black overlay
- Tap outside to dismiss

#### B. Share Sheet (55% of screen)
- **Purple gradient** (Color(0xFF6633CC) → Color(0xFF1A1A4D))
- **Swipe handle** - Gray bar for gesture dismiss
- **Header** - "Send to" with close button
- **Primary Share Row** - 5 dynamically ranked targets
- **Divider** - Visual separation
- **Contextual Actions** - Report, Block, Send Message

#### C. Animation
- 200ms fast slide-up (TikTok-style)
- `CurvedAnimation` with `Curves.easeOut`
- Reverse animation on dismiss

### 4. OptimizedShareButton (`lib/widgets/optimized_share_button.dart`)

Updated button with:

#### Prefetching
- Automatically prefetches `SharePayload` in `initState()`
- Uses cached data for instant modal display
- Falls back to on-demand fetch if cache miss

#### Modal Display
- Opens `ShareSheetView` via `showModalBottomSheet`
- Transparent background
- `isScrollControlled: true` for full control
- `isDismissible: true` and `enableDrag: true`

#### Action Callbacks
- Report → Shows report dialog
- Block → Shows block confirmation
- Send Message → TODO: Navigate to DM view
- Not Interested → TODO: Hide similar content
- Favorite → TODO: Add to favorites

## UI Layers

```
┌─────────────────────────────────┐
│                                 │
│    Video (playing, blurred)     │ ← Background Layer
│                                 │
│  ┌───────────────────────────┐  │
│  │  ▂▂▂  Swipe Handle        │  │
│  │                           │  │
│  │  Send to              [×] │  │ ← Header
│  │                           │  │
│  │  ◯    ◯    ◯    ◯    ◯   │  │ ← Primary Share Row
│  │ Copy Insta SMS WhatsApp+  │  │   (Dynamically ranked)
│  │                           │  │
│  │  ─────────────────────────│  │ ← Divider
│  │                           │  │
│  │  🚩 Report                │  │
│  │  🚫 Block                 │  │ ← Contextual Actions
│  │  💬 Send Message          │  │
│  │                           │  │
│  └───────────────────────────┘  │ ← Share Sheet (55%)
│                                 │
└─────────────────────────────────┘
```

## Analytics Events

| Event | Description | Metadata |
|-------|-------------|----------|
| `share_sheet_open` | Modal opens | `videoId`, `timestamp` |
| `share_target_tap` | User selects platform | `videoId`, `method`, `timestamp` |
| `share_copylink` | Copy Link tapped | `videoId`, `timestamp` |
| `share_success` | Share completes | `videoId`, `method`, `timestamp` |
| `share_cancel` | User dismisses | `videoId`, `timestamp` |
| `share_download_blocked` | Download restricted | `videoId`, `reason`, `timestamp` |

## Dynamic Ranking

Share targets are reordered based on usage frequency:

1. **Initial Order**: Copy Link, Instagram, SMS, WhatsApp, Repost
2. **After Usage**: Most-used platforms move to front
3. **Storage**: In-memory map (`_platformUsageCount`)
4. **Reset**: Cleared on app restart (can be persisted to SharedPreferences)

## Video Playback Policy

### NavigationObserver Updated
`lib/services/navigation_observer.dart` now handles share modals:

```dart
// Don't pause for these modals:
- ModalBottomSheetRoute (generic)
- CommentsView2
- ShareSheetView

// Video continues playing:
- Same video instance
- No controller disposal
- No reload/reset
- Position maintained
```

## Permissions

All videos currently default to:
- ✅ `canShare: true`
- ✅ `canDownload: true` (can be configured per video)
- ✅ `canDuet: true`
- ✅ `canRemix: true`
- ✅ `canRepost: true`

To restrict, modify `ShareServiceOptimized.fetchSharePayload()`.

## Platform-Specific Implementations

### Copy Link
- Copies `webShareUrl` to clipboard
- Shows green SnackBar confirmation
- **Does not** close modal (allows multiple shares)

### Instagram Direct
- Attempts `instagram://library` deep link
- Falls back to system share sheet
- Uses downloadUrl from payload

### SMS
- Uses `sms:?body=` URL scheme
- Includes video link and caption

### WhatsApp
- Tries `whatsapp://send` deep link
- Falls back to `https://wa.me` web link
- Full message with hashtags

### Repost
- Triggers in-app repost flow
- TODO: Implement repost dialog

### Facebook, Twitter, Telegram
- Platform-specific deep links
- Web fallbacks for app not installed

### Email
- Opens mail client with pre-filled subject/body
- Includes video link and creator info

### More
- System share sheet
- Native platform sharing

## Integration Points

### HomeView
No changes required! The `OptimizedShareButton` already:
- Prefetches data automatically
- Handles modal display
- Manages video playback coordination

### Video Controllers
Existing `GlobalPlaybackCoordinator` handles:
- Not pausing for share/comment modals
- Maintaining playback state
- Controller lifecycle

## Performance

### Prefetching Strategy
1. **When**: OptimizedShareButton `initState()`
2. **Cache**: Max 10 payloads (LRU)
3. **Fallback**: On-demand fetch if cache miss
4. **Cleanup**: Auto-clear old entries

### Modal Speed
- **Target**: Instant (<100ms perceived)
- **Animation**: 200ms slide-up
- **Data**: Prefetched (0ms fetch)
- **Total**: ~200ms open time

## Testing Checklist

- [ ] Tap share button → Modal opens instantly
- [ ] Video continues playing with blur
- [ ] Tap outside → Modal dismisses
- [ ] Swipe down → Modal dismisses
- [ ] Copy Link → Shows confirmation, stays open
- [ ] Instagram → Opens Instagram or system share
- [ ] SMS → Opens Messages with pre-filled text
- [ ] WhatsApp → Opens WhatsApp with link
- [ ] Report → Shows report dialog
- [ ] Block → Shows block confirmation
- [ ] All platforms track analytics
- [ ] Most-used platforms move to front (after 2-3 shares)
- [ ] Video doesn't pause/reload
- [ ] Video position maintained on dismiss

## Future Enhancements

1. **Persistent Ranking**: Save platform usage to SharedPreferences
2. **Download Feature**: Add actual download to camera roll
3. **Repost Dialog**: In-app repost with custom caption
4. **DM Navigation**: Deep link to StreamersTip DM view
5. **Not Interested**: Hide similar content algorithm
6. **Favorites**: Add to favorites collection
7. **Share History**: Track what was shared where
8. **Creator Controls**: Let creators restrict sharing/downloading per video

## Code Generation

When modifying `SharePayload`:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Comparison to TikTok

| Feature | TikTok | StreamersTip | Status |
|---------|--------|--------------|--------|
| Video keeps playing | ✅ | ✅ | ✅ Match |
| Blur background | ✅ | ✅ | ✅ Match |
| Fast animation | ✅ (200ms) | ✅ (200ms) | ✅ Match |
| Swipe to dismiss | ✅ | ✅ | ✅ Match |
| Dynamic ranking | ✅ | ✅ | ✅ Match |
| Prefetched data | ✅ | ✅ | ✅ Match |
| Copy link stays open | ✅ | ✅ | ✅ Match |
| Contextual actions | ✅ | ✅ | ✅ Match |
| Purple gradient | ❌ | ✅ | 🎨 Enhanced |
| Analytics tracking | ✅ | ✅ | ✅ Match |

## Notes

- SharePayload is Freezed-generated for immutability
- All enums use `analyticsName` for consistent tracking
- Service uses singleton pattern for global state
- Video playback coordination is automatic
- No manual setup required in HomeView

