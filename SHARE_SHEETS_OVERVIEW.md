# Share Sheets Overview - All Implementations and Connections

## Summary
There are **3 main share sheet implementations** in the codebase, each serving different purposes and connected to different parts of the app.

---

## 1. **ShareSheetView** (Original TikTok-Style)
**File**: `lib/widgets/share_sheet_view.dart`

### **Purpose**
- Main video sharing interface with TikTok-style design
- Purple gradient background with video blur effect
- Primary share sheet for video content

### **Design**
- **Background**: Purple gradient (`#6633CC` → `#1A1A4D`)
- **Height**: 70% of screen height
- **Animation**: 200ms slide-up (TikTok-style)
- **Features**: Video continues playing with blur effect

### **Connected To**
- **Video Player**: `lib/widgets/video_player_view_optimized.dart` (line 992)
- **Service**: `ShareServiceOptimized` (original service)
- **Usage**: 
  ```dart
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ShareSheetView(
      video: widget.video,
      payload: ShareServiceOptimized().getCachedPayload(widget.video.id),
      onDismiss: () => Navigator.pop(context),
      onAction: (action) => ShareServiceOptimized().handleAction(...),
    ),
  );
  ```

### **Features**
- ✅ Connections row with search
- ✅ Dynamic platform ranking
- ✅ Contextual actions (Report, Block, Message)
- ✅ Analytics tracking
- ✅ Prefetched SharePayload

---

## 2. **EnhancedShareSheet** (New & Improved)
**File**: `lib/widgets/enhanced_share_sheet.dart`

### **Purpose**
- Enhanced version with better layout and overflow fixes
- White background with clean design
- Improved spacing and video previews

### **Design**
- **Background**: White with subtle dividers
- **Height**: 85% of screen height (constrained)
- **Animation**: 300ms slide-up with fade
- **Features**: Video thumbnail preview, better spacing

### **Connected To**
- **Service**: `EnhancedShareService` (new enhanced service)
- **Video Preview**: `VideoPreviewService` for thumbnails
- **Usage**: 
  ```dart
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => EnhancedShareSheet(
      video: video,
      onClose: () => Navigator.pop(context),
      onRepost: (videoId, creatorId) => handleRepost(...),
      // ... other callbacks
    ),
  );
  ```

### **Features**
- ✅ Video thumbnail preview
- ✅ Platform-specific sharing
- ✅ Enhanced deep linking
- ✅ Better overflow handling
- ✅ Rich metadata formatting
- ✅ Scrollable content

---

## 3. **StreamerShareSheet** (Profile Sharing)
**File**: `lib/widgets/streamer_share_sheet.dart`

### **Purpose**
- Share streamer profiles and user content
- Different from video sharing
- Focused on user/streamer sharing

### **Design**
- **Background**: Custom design for profile sharing
- **Features**: Streamer-specific sharing options
- **Analytics**: Integrated with AnalyticsService

### **Connected To**
- **Streamer Card**: `lib/widgets/streamer_card_view.dart` (line 3409)
- **Service**: Custom analytics and sharing logic
- **Usage**:
  ```dart
  showModalBottomSheet(
    context: context,
    builder: (context) => StreamerShareSheet(
      streamerId: streamerId,
      streamerName: streamerName,
      // ... other parameters
    ),
  );
  ```

### **Features**
- ✅ Streamer profile sharing
- ✅ Custom sharing options
- ✅ Analytics integration
- ✅ Error handling

---

## **Service Layer Architecture**

### **ShareServiceOptimized** (Original)
**File**: `lib/services/share_service_optimized.dart`
- Used by: `ShareSheetView`
- Features: Basic sharing, platform ranking, analytics

### **EnhancedShareService** (New)
**File**: `lib/services/enhanced_share_service.dart`
- Used by: `EnhancedShareSheet`
- Features: Video previews, rich metadata, enhanced analytics

### **VideoPreviewService** (Supporting)
**File**: `lib/services/video_preview_service.dart`
- Used by: `EnhancedShareSheet`
- Features: Thumbnail generation, caching, multiple sizes

---

## **Current Usage Map**

```
┌─────────────────────────────────────────────────────────────┐
│                    SHARE SHEETS USAGE                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Video Player View                                          │
│  └── ShareSheetView (TikTok-style, Purple)                 │
│      └── ShareServiceOptimized                             │
│                                                             │
│  Enhanced Share Sheet (New)                                │
│  └── EnhancedShareSheet (White, Clean)                     │
│      ├── EnhancedShareService                              │
│      └── VideoPreviewService                               │
│                                                             │
│  Streamer Card View                                         │
│  └── StreamerShareSheet (Profile sharing)                  │
│      └── Custom Analytics Service                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## **Key Differences**

| Feature | ShareSheetView | EnhancedShareSheet | StreamerShareSheet |
|---------|----------------|-------------------|-------------------|
| **Background** | Purple gradient | White with dividers | Custom design |
| **Height** | 70% screen | 85% screen (constrained) | Variable |
| **Video Preview** | ❌ | ✅ Thumbnails | ❌ |
| **Overflow Fix** | ❌ | ✅ Fixed | ❌ |
| **Service** | ShareServiceOptimized | EnhancedShareService | Custom |
| **Usage** | Video sharing | Video sharing (new) | Profile sharing |
| **Status** | Active | Active (improved) | Active |

---

## **Recommendations**

### **Current State**
- **ShareSheetView**: Still in use for video sharing
- **EnhancedShareSheet**: New improved version (not yet integrated)
- **StreamerShareSheet**: Active for profile sharing

### **Migration Path**
1. **Phase 1**: Replace `ShareSheetView` with `EnhancedShareSheet` in video player
2. **Phase 2**: Update all video sharing to use enhanced version
3. **Phase 3**: Deprecate old `ShareSheetView` and `ShareServiceOptimized`

### **Integration Points**
- **Video Player**: `lib/widgets/video_player_view_optimized.dart` (line 992)
- **Home View**: May need updates to use enhanced version
- **Other Views**: Check for any other share sheet usage

---

## **Files to Update for Migration**

1. **Video Player View** (`lib/widgets/video_player_view_optimized.dart`)
   - Replace `ShareSheetView` with `EnhancedShareSheet`
   - Update service calls to use `EnhancedShareService`

2. **Home View** (`lib/pages/home_view.dart`)
   - Check for any share sheet usage
   - Update to use enhanced version

3. **Other Components**
   - Search for any other `ShareSheetView` usage
   - Update to use `EnhancedShareSheet`

The enhanced share sheet provides better UX, overflow handling, and video previews, making it the preferred choice for all video sharing functionality.
