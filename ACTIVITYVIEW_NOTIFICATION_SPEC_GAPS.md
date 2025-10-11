# 🎯 ActivityView Notification Cards - Spec vs. Implementation Gap Analysis

## 📊 **Current vs. Spec Comparison**

### ✅ **Already Implemented**

| Feature | Status | Location |
|---------|--------|----------|
| Avatar tap → Profile | ✅ | `activity_row_view.dart:202-204` |
| Thumbnail tap → Post | ✅ | `activity_row_view.dart:366-368` |
| Haptic feedback | ✅ | Throughout |
| Card animations | ✅ | `activity_row_view.dart:32-47` |
| Mark as read | ✅ | `activity_view.dart:1195-1204` |
| Follow button (UI) | ✅ | Present but not fully wired |
| Grouped by time | ✅ | Today, Yesterday, Last 7 Days |

---

## ❌ **Missing / Needs Implementation**

### **1. Deep Link System** ⚠️ **CRITICAL**

**Spec Requirement:**
```
app://post/{postId} → HomeView single-post mode
app://comment/{commentId} → CommentsView focused on comment
app://user/{userId} → StreamerCardView
app://tag/{tagName} → DiscoverView > TagFeed
```

**Current:** ❌ No deep link routing
**Impact:** Cannot navigate from push notifications, share links, or external sources

---

### **2. Post Navigation** ⚠️ **HIGH PRIORITY**

**Spec Requirement:**
Tap post thumbnail → Open HomeView in single-post context with:
- Target video auto-playing
- Comments accessible
- Back button returns to ActivityView

**Current Implementation:**
```dart
// activity_view.dart:1166-1168
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Post detail view coming soon!')),
);
```

**Status:** ❌ Stubbed out, shows SnackBar
**What's Needed:**
1. Create `PostDetailRoute` or `HomeView.singlePost` mode
2. Navigate with `Navigator.push()` to maintain back stack
3. Pass `videoId` to load specific post
4. Auto-play on arrival
5. Preserve ActivityView in back stack

---

### **3. Comment Navigation** ⚠️ **HIGH PRIORITY**

**Spec Requirement:**
Tap comment notification → CommentsView with:
- Comment highlighted/focused
- Auto-scroll to comment
- Reply button accessible

**Current:** ❌ No comment-specific navigation (falls through to post tap)

**What's Needed:**
1. Extend `CommentsView` to accept `focusCommentId` parameter
2. Auto-scroll to focused comment
3. Highlight focused comment for 2-3 seconds
4. Handle deleted comment fallback

---

###**4. Follow Back CTA** ⚠️ **HIGH PRIORITY**

**Spec Requirement:**
```dart
Follow Back button:
- Optimistic UI update (instant button change)
- Call idempotent Follow(userId)
- Update NetworkView counts & lists
- Update all StreamerCardView instances
- Broadcast via UserRelationStore
```

**Current Implementation:**
```dart
// activity_row_view.dart:66-67
const isFollowing = false;  // ❌ Mock data
const isMutualFollow = false;  // ❌ Mock data
```

**Status:** ❌ UI exists but not wired to actual follow service

**What's Needed:**
1. Wire to existing `RelationshipService`
2. Implement optimistic state management
3. Broadcast follow state changes to:
   - NetworkView (followers/following counts)
   - StreamerCardView (follow button state)
   - Any cached user data
4. Handle edge cases (already following, self-follow)

---

### **5. Mention & Tag Parsing** ⚠️ **MEDIUM PRIORITY**

**Spec Requirement:**
Inline `@mention` → ProfileView  
Inline `#tag` → DiscoverView > TagFeed

**Current:** ❌ No rich text parsing in comment snippets

**What's Needed:**
1. Parse comment text for `@username` and `#tag`
2. Make them tappable with different colors
3. Navigate appropriately on tap

---

### **6. Enhanced Model** ⚠️ **MEDIUM PRIORITY**

**Spec Requirement:**
```dart
NotificationCard {
  target { kind, id, thumbnailUrl, snippet }
  ctas: [ { kind, label } ]
  deeplinks { user, post, comment, tag }
  flags { isSelf, isBlocked, isDeleted }
}
```

**Current Model:**
```dart
ActivityNotification {
  id, type, user, timestamp,
  postThumbnailUrl, commentText, status, videoId
}
```

**Missing:**
- `target` structured object
- `ctas` array
- Pre-computed `deeplinks`
- `flags` for edge cases
- `isRead` field (currently using `status == 'pending'`)

---

### **7. Overflow Menu (•••)** ⚠️ **MEDIUM PRIORITY**

**Spec Requirement:**
Sheet with:
- Mute user
- Turn off notifications like this
- Report
- Block

**Current:** ❌ No overflow menu

---

### **8. Error Fallbacks** ⚠️ **MEDIUM PRIORITY**

**Spec Requirement:**
- Deleted post → "This post is unavailable" + CTA to Profile
- Blocked user → "This profile isn't available"
- Already following → treat as success (no error)

**Current:** ❌ No graceful fallbacks

---

### **9. Batch Notifications** ⚠️ **LOW PRIORITY**

**Spec Requirement:**
"X and Y others liked your post" (collapsed notifications)

**Current:** ❌ No batching

---

### **10. Analytics** ⚠️ **LOW PRIORITY**

**Spec Events:**
- `notif_opened`
- `notif_cta_clicked`
- `deeplink_resolve`
- `follow_action`

**Current:** ❌ No notification-specific analytics

---

## 🎯 **Recommended Implementation Priority**

### **Phase 1: Core Navigation (Must Have)**

1. **Post Detail Navigation** - Open HomeView in single-post mode
   - Routes to existing HomeView with specific video
   - Essential for 80% of notification taps

2. **Follow Back Wiring** - Connect to RelationshipService
   - Most common CTA
   - Already has UI, just needs logic

3. **Deep Link Foundation** - Basic routing setup
   - `app://post/{postId}`
   - `app://user/{userId}`

### **Phase 2: Enhanced Interaction (Should Have)**

4. **Comment Navigation** - Focus on specific comments
   - Enhance existing CommentsView
   - Important for engagement

5. **Mention/Tag Parsing** - Rich text in snippets
   - Better UX for contextual navigation

6. **Error Fallbacks** - Graceful degradation
   - Professional handling of edge cases

### **Phase 3: Polish (Nice to Have)**

7. **Overflow Menu** - Mute, Report, Block
8. **Batch Notifications** - Collapse similar events
9. **Analytics** - Track engagement
10. **Enhanced Model** - Structured target & CTAs

---

## 📋 **Quick Implementation Tasks (from Spec)**

### **Immediate (Can Do Now):**

✅ Avatar/name → StreamerCardView (Already done!)  
✅ Basic card tap handling (Already done!)  
✅ Mark as read (Already done!)

### **Next Up:**

1. ❌ Wire Follow Back → RelationshipService
2. ❌ Post thumbnail → HomeView single-post mode  
3. ❌ Add basic deep link routes
4. ❌ Comment tap → CommentsView with focus
5. ❌ Add deleted/blocked fallbacks
6. ❌ Parse @mentions and #tags in snippets
7. ❌ Add overflow menu (•••)
8. ❌ Implement highlight pulse on landing
9. ❌ Add analytics events
10. ❌ NetworkView follow/unfollow sync

---

## 🔍 **Files That Need Updates**

### **To Create:**
- `lib/services/deep_link_service.dart` - Route resolver
- `lib/models/notification_target.dart` - Structured target model
- `lib/models/notification_cta.dart` - CTA action model

### **To Modify:**
- `lib/widgets/activity_view.dart` - Wire navigation handlers
- `lib/widgets/activity_row_view.dart` - Add overflow menu, parse mentions/tags
- `lib/models/activity_notification.dart` - Enhance model
- `lib/pages/home_view.dart` - Add single-post mode
- `lib/widgets/comments_view.dart` - Add focus & highlight
- `lib/views/network_view.dart` - Listen for follow state changes

---

## 🎯 **Recommended Next Steps**

Since you asked about this comprehensive spec, I can help implement any of these features. The most impactful would be:

1. **Post Detail Navigation** - So notifications actually open the videos
2. **Follow Back CTA** - So users can instantly follow back
3. **Deep Links** - Foundation for everything else

**Would you like me to:**
- **Option A**: Implement Phase 1 (Post navigation + Follow Back + Basic deep links)?
- **Option B**: Start with just Post navigation (highest impact)?
- **Option C**: Continue with the original optional enhancements (pagination, new types, animations)?
- **Option D**: Something else?

Let me know which direction you'd like to go! 🚀

