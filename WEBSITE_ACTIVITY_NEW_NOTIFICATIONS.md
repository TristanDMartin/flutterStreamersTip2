# Website Activity Feed - New Notification Types

## 🎯 Quick Summary

**What Changed**: Added 4 new notification types that will now appear in `/notifications/{userId}/items`.

**Backend**: ✅ Already deployed (Cloud Functions active)

**Website Needs**: Update ActivityView UI to display the new types

---

## 🆕 New Notification Types

The website's existing Firestore listener will now see these **4 new `type` values**:

| Type | When It Triggers | Example Message |
|------|------------------|----------------|
| `commentReply` | Someone replies to your comment | "John replied to your comment: 'Great point!'" |
| `newVideo` | Someone you follow posts a video | "Jane posted a new video" |
| `milestone` | Your video hits view/like milestone | "Your video reached 10K views! 🎉" |
| `liveStream` | Someone you follow goes live | "Mike is live now! 🔴" |

---

## 📊 Data Structure

### Existing Fields (Already Handled):
```javascript
{
  id: string,
  type: 'like' | 'follow' | 'comment' | 'tag' | 'mention',
  user: {
    id: string,
    username: string,
    displayName: string,
    avatarURL: string
  },
  timestamp: Timestamp,
  videoId?: string,
  postThumbnailUrl?: string,
  commentText?: string,
  status: 'pending' | 'delivered',
  isRead: boolean
}
```

### New Fields (for New Types):
```javascript
{
  // ... existing fields ...
  
  // For commentReply
  parentCommentId?: string,  // ID of the comment being replied to
  
  // For milestone
  milestoneType?: 'views' | 'likes',
  milestoneValue?: 100 | 1000 | 10000 | 100000 | 1000000,
}
```

---

## 🎨 UI Implementation

### 1. Update Notification Type Handler

**Current Code** (you probably have something like this):
```javascript
function getNotificationMessage(notification) {
  switch (notification.type) {
    case 'like':
      return 'liked your post';
    case 'follow':
      return 'started following you';
    case 'comment':
      return `commented: "${notification.commentText}"`;
    case 'tag':
      return 'tagged you in their video';
    case 'mention':
      return 'mentioned you in a comment';
    
    // ADD THESE:
    default:
      return 'sent you a notification';
  }
}
```

**Updated Code** (add these cases):
```javascript
function getNotificationMessage(notification) {
  switch (notification.type) {
    case 'like':
      return 'liked your post';
    case 'follow':
      return 'started following you';
    case 'comment':
      return `commented: "${notification.commentText}"`;
    case 'tag':
      return 'tagged you in their video';
    case 'mention':
      return 'mentioned you in a comment';
    
    // NEW: Comment Reply
    case 'commentReply':
      return notification.commentText 
        ? `replied to your comment: "${notification.commentText}"`
        : 'replied to your comment';
    
    // NEW: New Video
    case 'newVideo':
      return 'posted a new video';
    
    // NEW: Milestone
    case 'milestone':
      if (notification.milestoneType && notification.milestoneValue) {
        const formatted = formatNumber(notification.milestoneValue);
        return `Your video reached ${formatted} ${notification.milestoneType}! 🎉`;
      }
      return 'reached a milestone! 🎉';
    
    // NEW: Live Stream
    case 'liveStream':
      return notification.commentText || 'is live now! 🔴';
    
    default:
      return 'sent you a notification';
  }
}

// Helper function
function formatNumber(num) {
  if (num >= 1000000) return `${(num / 1000000).toFixed(1)}M`;
  if (num >= 1000) return `${(num / 1000).toFixed(1)}K`;
  return num.toString();
}
```

---

### 2. Update Avatar Ring Colors

**Current Code**:
```javascript
function getNotificationColor(type) {
  switch (type) {
    case 'like': return '#E91E63';    // Pink
    case 'follow': return '#2196F3';  // Blue
    case 'comment': return '#4CAF50'; // Green
    case 'tag': return '#FF9800';     // Orange
    case 'mention': return '#9C27B0'; // Purple
    default: return '#9E9E9E';        // Gray
  }
}
```

**Updated Code** (add these):
```javascript
function getNotificationColor(type) {
  switch (type) {
    case 'like': return '#E91E63';        // Pink
    case 'follow': return '#2196F3';      // Blue
    case 'comment': return '#4CAF50';     // Green
    case 'tag': return '#FF9800';         // Orange
    case 'mention': return '#9C27B0';     // Purple
    
    // NEW
    case 'commentReply': return '#00BCD4'; // Cyan
    case 'newVideo': return '#9248D2';     // StreamersTip Purple
    case 'milestone': return '#FFC107';    // Gold
    case 'liveStream': return '#F44336';   // Red
    
    default: return '#9E9E9E';            // Gray
  }
}
```

---

### 3. Update Navigation Handler

**Current Code**:
```javascript
function handleNotificationClick(notification) {
  switch (notification.type) {
    case 'like':
    case 'comment':
      if (notification.videoId) {
        navigateToVideo(notification.videoId);
      } else {
        navigateToProfile(notification.user.id);
      }
      break;
    
    case 'follow':
    case 'tag':
    case 'mention':
      navigateToProfile(notification.user.id);
      break;
  }
}
```

**Updated Code** (add these):
```javascript
function handleNotificationClick(notification) {
  switch (notification.type) {
    case 'like':
    case 'comment':
      if (notification.videoId) {
        navigateToVideo(notification.videoId);
      } else {
        navigateToProfile(notification.user.id);
      }
      break;
    
    case 'follow':
    case 'tag':
    case 'mention':
      navigateToProfile(notification.user.id);
      break;
    
    // NEW: Comment Reply, New Video, Milestone
    case 'commentReply':
    case 'newVideo':
    case 'milestone':
      if (notification.videoId) {
        navigateToVideo(notification.videoId);
      } else {
        navigateToProfile(notification.user.id);
      }
      break;
    
    // NEW: Live Stream
    case 'liveStream':
      navigateToProfile(notification.user.id);
      break;
  }
}
```

---

## 🎨 Visual Design Reference

### Avatar Ring Colors (Match Mobile App):

```css
/* Existing */
.notification-like { border-color: #E91E63; }    /* Pink */
.notification-follow { border-color: #2196F3; }  /* Blue */
.notification-comment { border-color: #4CAF50; } /* Green */
.notification-tag { border-color: #FF9800; }     /* Orange */
.notification-mention { border-color: #9C27B0; } /* Purple */

/* NEW - Add these */
.notification-commentReply { border-color: #00BCD4; } /* Cyan */
.notification-newVideo { border-color: #9248D2; }     /* StreamersTip Purple */
.notification-milestone { border-color: #FFC107; }    /* Gold */
.notification-liveStream { border-color: #F44336; }   /* Red */
```

### Icons (Optional):
```javascript
function getNotificationIcon(type) {
  switch (type) {
    case 'commentReply': return '💬'; // or <Reply /> icon
    case 'newVideo': return '🎬';     // or <VideoCamera /> icon
    case 'milestone': return '🎉';    // or <Trophy /> icon
    case 'liveStream': return '🔴';   // or <LiveStream /> icon
    // ... existing cases ...
  }
}
```

---

## 📱 Example Component Update

**React/Next.js Example**:

```jsx
// NotificationRow.jsx
function NotificationRow({ notification }) {
  const message = getNotificationMessage(notification);
  const color = getNotificationColor(notification.type);
  
  return (
    <div 
      className="notification-row"
      onClick={() => handleNotificationClick(notification)}
    >
      {/* Avatar with colored ring */}
      <div 
        className="avatar-ring"
        style={{ borderColor: color }}
      >
        <img src={notification.user.avatarURL} alt={notification.user.displayName} />
      </div>
      
      {/* Notification text */}
      <div className="notification-content">
        <p>
          <strong>{notification.user.displayName}</strong> {message}
        </p>
        <span className="timestamp">{formatTimestamp(notification.timestamp)}</span>
      </div>
      
      {/* Thumbnail or action button */}
      <div className="notification-action">
        {notification.postThumbnailUrl ? (
          <img src={notification.postThumbnailUrl} alt="Video thumbnail" />
        ) : notification.type === 'follow' ? (
          <button>Follow Back</button>
        ) : null}
      </div>
    </div>
  );
}
```

---

## ✅ What's Already Working

**No changes needed** for:
- ✅ Firestore listener (automatically receives new types)
- ✅ Backend (Cloud Functions deployed)
- ✅ Database structure (fields already exist)
- ✅ Security rules (already updated)

---

## 🔥 What Website Needs to Update

**3 Simple Changes**:

1. **Update `getNotificationMessage()`** - Add 4 new cases
2. **Update `getNotificationColor()`** - Add 4 new colors
3. **Update `handleNotificationClick()`** - Add 4 new navigation cases

**Estimated Time**: 15-30 minutes

---

## 🧪 Testing

After updating, test these scenarios:

1. **Comment Reply**: Reply to a comment → Parent commenter sees notification ✅
2. **New Video**: Upload video → Followers see notification ✅  
3. **Milestone**: Like a video to 100 → Owner sees celebration ✅
4. **Live Stream**: Update calendar event to 'live' → Followers see alert ✅

---

## 📦 Data Examples

### Example: Comment Reply Notification
```json
{
  "id": "notif_123",
  "type": "commentReply",
  "user": {
    "id": "user_456",
    "username": "john_doe",
    "displayName": "John Doe",
    "avatarURL": "https://..."
  },
  "videoId": "video_789",
  "commentText": "I agree! Great point!",
  "parentCommentId": "comment_321",
  "postThumbnailUrl": "https://...",
  "timestamp": "2025-10-21T...",
  "isRead": false,
  "status": "delivered"
}
```

### Example: Milestone Notification
```json
{
  "id": "notif_456",
  "type": "milestone",
  "user": {
    "id": "owner_id",
    "username": "you",
    "displayName": "You",
    "avatarURL": "https://..."
  },
  "videoId": "video_789",
  "milestoneType": "views",
  "milestoneValue": 10000,
  "postThumbnailUrl": "https://...",
  "timestamp": "2025-10-21T...",
  "isRead": false,
  "status": "delivered"
}
```

### Example: New Video Notification
```json
{
  "id": "notif_789",
  "type": "newVideo",
  "user": {
    "id": "creator_123",
    "username": "jane_creator",
    "displayName": "Jane Creator",
    "avatarURL": "https://..."
  },
  "videoId": "new_video_456",
  "postThumbnailUrl": "https://...",
  "timestamp": "2025-10-21T...",
  "isRead": false,
  "status": "delivered"
}
```

---

## 🎯 Summary

**Backend**: ✅ Complete (Cloud Functions deployed)

**Website**: Update 3 functions (15-30 min work)

**Result**: Full TikTok/Instagram notification parity!

---

## 📚 Related Docs

- `ACTIVITYVIEW_COMPLETE_NOTIFICATIONS.md` - Full technical details
- `WEBSITE_MESSAGE_NOTIFICATIONS_GUIDE.md` - Message notifications guide
- `WEBSITE_VIDEO_MORE_OPTIONS_GUIDE.md` - Video options guide

---

**That's it!** Just update those 3 functions and your website ActivityView will match the mobile app perfectly. 🚀

