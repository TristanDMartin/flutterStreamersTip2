# ProfileView Video UI Layout Documentation

## Overview

When a user taps on a video thumbnail in the ProfileView, a full-screen video player opens with a TikTok-style vertical scrolling interface. This document describes the complete UI layout and component hierarchy.

---

## Navigation Flow

### 1. User Interaction
- **Location**: `lib/widgets/profile_video_feed_view.dart`
- **Trigger**: User taps on a video thumbnail in the 3-column grid
- **Method**: `_openVideoPlayer()` or `_openVideoPlayerFromMap()`

### 2. Navigation
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => PlayerScreen(
      mode: PlayerMode.homeFeed,
      initialIndex: index,
      videoIds: videoIds,
      videos: videos,
    ),
  ),
);
```

---

## UI Component Hierarchy

### Root Container: `PlayerScreen`
**Location**: `lib/widgets/player_screen.dart`

```
Scaffold (black background)
└── Stack
    ├── PageView.builder (vertical scrolling)
    │   └── VideoPlayerViewOptimized (for each video)
    └── ProfileView-specific Overlays
        ├── Back Button (top-left)
        ├── Menu Button (top-right, owner only)
        └── Insights Button + Views Counter (bottom-left, owner only)
```

---

## Layer 1: PageView (Vertical Scrolling)

### Purpose
- Enables vertical swiping between videos (TikTok-style)
- Handles pagination and video switching

### Implementation
```dart
PageView.builder(
  controller: _pageController,
  onPageChanged: _onVideoChanged,
  itemCount: _videos.length,
  itemBuilder: (context, index) {
    return VideoPlayerViewOptimized(
      video: video,
      isCurrentVideo: _currentIndex == index,
      isFirstVideo: index == 0,
      tabId: 'playerScreen',
      homeViewModel: ref.read(hp.homeProvider.notifier),
      showHUD: true, // Enable HUD overlays
    );
  },
)
```

---

## Layer 2: VideoPlayerViewOptimized

**Location**: `lib/widgets/video_player_view_optimized.dart`

### Structure
```
Container (black background, full screen)
└── Stack
    ├── DoubleTapGestureDetector
    │   └── Video Player (actual video playback)
    └── HUD Overlays (if showHUD == true)
        ├── UI Overlay (creator info, caption, hashtags)
        ├── Action Buttons (like, comment, share, bookmark)
        └── Play/Pause Indicator (temporary overlay)
```

---

## Layer 3: Video Player Core

### Video Display
- **Widget**: `VideoPlayer` from `video_player` package
- **Wrapping**: `FittedBox` with `BoxFit.cover` for full-screen display
- **Background**: Black container (shown during loading)

### Gesture Handling
- **Single Tap**: Play/Pause video
- **Double Tap**: Like animation (heart animation)
- **Vertical Swipe**: Navigate between videos (handled by PageView)

---

## Layer 4: HUD Overlays

### 4.1 UI Overlay (Bottom Left)
**Position**: `bottom: safeBottom + 20.0` (ProfileView-specific positioning)

#### Components (Top to Bottom):
1. **Creator Row**
   - Avatar (circular, 40px)
   - Username (`@username`)
   - Follow Button (dynamic state: Follow/Following/Connected/You)

2. **Video Caption**
   - Max 2 lines
   - Text overflow: ellipsis
   - White text, 16px font size

3. **Hashtags**
   - Wrapped container chips
   - Semi-transparent white background
   - White border with opacity
   - Auto-prefixes `#` if missing

**Layout Constraints**:
- `left`: 12px inset
- `right`: 80px inset (space for action buttons)
- `maxHeight`: 25% of screen height

### 4.2 Action Buttons (Right Side)
**Position**: `top: screenHeight - safeBottom - groupHeight - 120.0`

#### Buttons (Top to Bottom):
1. **Like Button** (`EnhancedLikeButton`)
   - Icon: Heart (filled if liked)
   - Count: Like count below icon
   - Animation: Heart animation on double-tap
   - Size: 56px × 56px

2. **Comment Button**
   - Icon: Chat bubble outline
   - Count: Real-time comment count (from Firestore)
   - Opens `CommentsView2` modal

3. **Share Button**
   - Icon: Share/Forward
   - Opens `EnhancedShareSheet` modal

4. **Bookmark Button**
   - Icon: Bookmark (filled if bookmarked)
   - Integrates with `UnifiedBookmarkService`
   - Real-time state updates

**Layout**:
- `right`: 12px inset
- Button size: 56px × 56px
- Gap between buttons: 16px
- Total height: ~280px (4 buttons + 3 gaps)

### 4.3 Play/Pause Indicator
- **Position**: Center of screen
- **Visibility**: Shown temporarily when video is tapped
- **Animation**: Fade in/out with scale animation
- **Icon**: Play or Pause icon

---

## Layer 5: ProfileView-Specific Overlays

**Location**: `lib/widgets/player_screen.dart` - `_buildProfileViewOverlays()`

### 5.1 Back Button (Top Left)
- **Position**: `top: safeTop + 16, left: 16`
- **Icon**: Arrow back (white, 28px)
- **Action**: Closes PlayerScreen and returns to ProfileView

### 5.2 Menu Button (Top Right, Owner Only)
- **Position**: `top: safeTop + 16, right: 16`
- **Visibility**: Only shown if `currentUser?.uid == video.creator.id`
- **Icon**: More vert (white, 28px)
- **Action**: Opens video options menu (Edit, Privacy, Download, Delete)

### 5.3 Insights Button + Views Counter (Bottom Left, Owner Only)
- **Position**: `bottom: safeBottom + 120.0, left: 12`
- **Visibility**: Only shown if video owner
- **Components**:
  - **Insights Button**: Opens `InsightsView` with video analytics
  - **Views Counter**: Displays formatted view count (e.g., "1.2K views")

---

## Video Options Menu

**Trigger**: Menu button (top-right, owner only)

### Options:
1. **Edit Post**
   - Opens `EditPostSheet` modal
   - Allows editing caption and hashtags
   - Updates Firestore and in-memory state

2. **Privacy Settings**
   - Placeholder (coming soon)

3. **Download**
   - Placeholder (coming soon)

4. **Delete**
   - Confirmation dialog
   - Placeholder (coming soon)

---

## Video Player Features

### Audio Management
- **Initial State**: Muted (volume = 0.0)
- **Unmute**: On first user interaction or when video becomes current
- **Audio Enhancement**: `AudioEnhancementService` applies TikTok-style audio processing
- **Global Playback Manager**: Manages audio focus across tabs

### Video Resume/Restart Logic
- **Service**: `VideoResumeService`
- **Behavior**:
  - Resume if user swipes away and returns within 2 seconds
  - Restart if video was finished or user was away > 2 seconds
  - Saves playback position on page leave

### Watch Time Tracking
- **Service**: `EngagementAnalyticsService`
- **Frequency**: Reports every 25% watched (or at 99%)
- **Purpose**: Viral algorithm optimization

### Real-Time Updates
- **Comment Count**: Firestore snapshot listener
- **Like Count**: Real-time updates via `StreamersTipLikeService`
- **Bookmark State**: Event stream from `UnifiedBookmarkService`

---

## Positioning Constants

### UI Overlay (ProfileView)
```dart
bottom: safeBottom + 20.0  // Minimal spacing from bottom
left: 12.0
right: 80.0  // Space for action buttons
```

### Action Buttons (ProfileView)
```dart
top: screenHeight - safeBottom - groupHeight - 120.0
right: 12.0
```

### ProfileView Overlays
```dart
Back Button: top: safeTop + 16, left: 16
Menu Button: top: safeTop + 16, right: 16
Insights: bottom: safeBottom + 120.0, left: 12
```

---

## State Management

### Providers Used:
- `robustAuthServiceProvider`: Current user authentication
- `homeProvider`: Video feed state
- `followButtonServiceProvider`: Follow button state logic
- `globalPlaybackManagerProvider`: Audio focus management

### Services Used:
- `UnifiedBookmarkService`: Bookmark state and events
- `StreamersTipLikeService`: Like functionality
- `EngagementAnalyticsService`: Watch time tracking
- `VideoResumeService`: Resume/restart logic
- `GlobalPlaybackManager`: Audio focus and playback control

---

## Performance Optimizations

1. **Lazy Loading**: Videos are loaded only when needed
2. **Controller Registry**: Prevents multiple controllers for same video
3. **Memory Management**: Controllers disposed when video is not current
4. **Cache Management**: Thumbnail caching via `CachedNetworkImage`
5. **Audio Focus**: Global manager prevents audio bleeding between tabs

---

## Gesture Interactions

### Single Tap
- **Action**: Toggle play/pause
- **Visual Feedback**: Play/pause indicator overlay

### Double Tap
- **Action**: Like animation
- **Visual Feedback**: Heart animation from tap location

### Vertical Swipe
- **Up**: Next video
- **Down**: Previous video
- **Implementation**: Handled by `PageView`

### Horizontal Swipe (Future)
- **Left**: Show StreamerCardView (profile view)
- **Right**: Same as left (TikTok-style)

---

## Modal Views

### CommentsView2
- **Trigger**: Comment button tap
- **Type**: Bottom sheet modal
- **Features**: Real-time comments, reply functionality, comment submission

### EnhancedShareSheet
- **Trigger**: Share button tap
- **Type**: Bottom sheet modal
- **Features**: Share to social platforms, copy link, download
- **App & Website Sharing**: 
  - **Web URL**: `https://streamerstip.com/video/{videoId}` - Opens in browser
  - **Deep Link**: `streamerstip://video/{videoId}` - Opens in app if installed
  - **Smart Link Handling**: When web URL is shared, clicking it will:
    - Open in app if installed (via deep link)
    - Fall back to website if app not installed
  - **Share Targets**: Copy Link, Instagram, SMS, WhatsApp, Facebook, Twitter, Telegram, Email, Repost, More

### InsightsView
- **Trigger**: Insights button tap (owner only)
- **Type**: Full-screen modal
- **Features**: Video analytics, view statistics, engagement metrics

### StreamerCardView
- **Trigger**: Profile avatar/username tap
- **Type**: Full-screen modal
- **Features**: Creator profile, follow functionality, video grid

---

## File Structure

```
lib/
├── widgets/
│   ├── player_screen.dart              # Main PlayerScreen container
│   ├── video_player_view_optimized.dart # Core video player + HUD
│   ├── profile_video_feed_view.dart    # Profile video grid + tap handler
│   ├── enhanced_like_button.dart       # Like button with animations
│   ├── comments_view2.dart             # Comments modal
│   ├── enhanced_share_sheet.dart       # Share modal
│   └── insights_view.dart              # Analytics view (owner only)
└── services/
    ├── video_resume_service.dart       # Resume/restart logic
    ├── global_playback_manager.dart    # Audio focus management
    └── unified_bookmark_service.dart   # Bookmark state management
```

---

## Key Design Decisions

1. **TikTok-Style Layout**: Vertical scrolling, full-screen video, right-side action buttons
2. **Consistent HUD**: Same HUD elements across HomeView, ProfileView, and DiscoverView
3. **Owner-Specific Features**: Insights, menu, and views counter only for video owners
4. **Real-Time Updates**: Firestore listeners for comments, likes, and bookmarks
5. **Performance First**: Lazy loading, controller registry, and memory management

---

## Share Functionality: App & Website Support

### Dual Link System

The share functionality supports both **app** and **website** sharing through a dual-link system:

#### 1. Web Share URL
- **Format**: `https://streamerstip.com/video/{videoId}?utm_source=app&utm_medium=share`
- **Purpose**: Opens video in web browser
- **Usage**: Primary link for sharing across platforms
- **Features**:
  - Universal compatibility (works on all devices)
  - Open Graph metadata for rich previews
  - UTM tracking parameters for analytics

#### 2. Deep Link (App)
- **Format**: `streamerstip://video/{videoId}`
- **Purpose**: Opens video directly in the app
- **Usage**: Automatic fallback when app is installed
- **Features**:
  - Instant app opening
  - Direct navigation to video
  - Seamless user experience

### Smart Link Handling

When a user shares a video:

1. **Share Payload Generation**:
   ```dart
   SharePayload(
     links: ShareLinks(
       webShareUrl: 'https://streamerstip.com/video/{videoId}',
       deepLink: 'streamerstip://video/{videoId}',
       downloadUrl: video.videoURL,
       embedCode: '<iframe>...</iframe>',
     ),
   )
   ```

2. **Link Selection Logic**:
   - **Copy Link**: Copies web URL to clipboard
   - **Social Platforms**: Shares web URL with preview
   - **App Detection**: Recipient's device automatically detects app installation
   - **Fallback**: If app not installed, opens web URL in browser

3. **Platform-Specific Behavior**:
   - **WhatsApp**: Shares web URL with preview card
   - **SMS**: Shares web URL with text message
   - **Email**: Shares web URL with thumbnail and metadata
   - **Facebook/Twitter**: Shares web URL with Open Graph preview
   - **Instagram**: Shares via Instagram Direct with preview
   - **Telegram**: Shares web URL with preview

### Deep Link Processing

When a shared link is clicked:

1. **App Installed**:
   - Deep link handler detects `streamerstip://` scheme
   - App opens directly to video player
   - Video loads immediately

2. **App Not Installed**:
   - Browser opens web URL
   - Video plays in web player
   - Option to download app is shown

### Share Sheet Features

The `EnhancedShareSheet` provides:

- **Connections Row**: Share directly to app connections
- **Platform Targets**: 10+ sharing options
- **Video Preview**: High-quality thumbnail in share content
- **Rich Metadata**: Caption, creator info, hashtags included
- **Analytics Tracking**: All shares tracked for engagement metrics

### Supported Share Targets

1. **Copy Link** - Copies web URL to clipboard
2. **Instagram Direct** - Shares via Instagram
3. **SMS/Messages** - Text message with link
4. **WhatsApp** - WhatsApp message with preview
5. **Repost** - Repost within app
6. **Facebook** - Facebook share with preview
7. **Twitter** - Twitter tweet with link
8. **Telegram** - Telegram message with preview
9. **Email** - Email with thumbnail and metadata
10. **More** - System share sheet (all platforms)

---

## Future Enhancements

1. **Horizontal Swipe Gestures**: Navigate to creator profile
2. **Video Filters**: Apply filters during playback
3. **Video Reactions**: Quick reaction buttons (emoji)
4. **Duet/Stitch**: Create duets and stitches from video
5. **Enhanced Analytics**: More detailed insights for creators
6. **Universal Links**: iOS/Android universal link support for seamless app/web switching

