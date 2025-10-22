# 🔍 Admin Monitoring System

## Overview

A **real-time admin monitoring panel** that allows you (technqs) to track all app activity in real-time. Only visible to admin users.

---

## ✅ Features

### 📊 **Overview Tab**
- **Total Users** - All registered users
- **Online Users** - Currently active users (green indicator)
- **Total Videos** - All uploaded videos
- **Recent Messages** - Latest chat messages
- **Notifications** - Recent activity notifications
- **Live Activity Feed** - Real-time log of all app events

### 👥 **Users Tab**
- List of 20 most recently active users
- Online/offline status (green dot for online)
- Username, display name, last seen time
- Tap user to view details

### 📹 **Videos Tab**
- 20 most recent videos
- Caption, upload time, views, likes
- Video status (draft, processing, published, etc.)
- Tap for full video details (ID, user, stats)

### 💬 **Messages Tab**
- 20 most recent messages across all chats
- Sender, message text, timestamp
- Real-time updates as messages are sent

### 📝 **Logs Tab**
- Real-time activity log
- All monitored events (users, videos, messages, notifications)
- Timestamped entries
- Last 100 events kept in memory

---

## 🚀 How to Access

### For You (technqs):

1. **Open Your Profile** - Navigate to your profile page (technqs account)
2. **Tap "Edit Profile"** - Open the Edit Profile screen
3. **Look for Admin Button** - You'll see an admin icon (⚙️) in the top right corner of the app bar
4. **Tap to Open** - Opens the Admin Monitoring Panel
5. **Explore Tabs** - Swipe between different monitoring tabs

**Note**: This button is **ONLY visible in Edit Profile** and **ONLY when logged in as technqs**.

---

## 🔐 Admin Access Configuration

### Current Admins:
- **UID**: `bU0RxyZ2L4ULAv1Co5L4f825yV73` (technqs)
- **Username**: `technqs`

### How It Works:
The system checks 3 ways to verify admin status:
1. **UID Match** - Checks if your user ID matches the admin list (most secure)
2. **Username Match** - Backup check using your username
3. **Role Field** - Checks if your user document has `role: 'admin'` in Firestore

### Add More Admins:

**Option 1: Add UID to Code** (Most Secure)
```dart
// In lib/services/admin_service.dart
static const List<String> _adminUserIds = [
  'bU0RxyZ2L4ULAv1Co5L4f825yV73', // technqs
  'NEW_ADMIN_UID_HERE',           // Add new admin
];
```

**Option 2: Add Username** (Less Secure)
```dart
// In lib/services/admin_service.dart
static const List<String> _adminUsernames = [
  'technqs',
  'newadminusername',  // Add new admin
];
```

**Option 3: Use Firebase Console** (Dynamic)
1. Go to Firebase Console
2. Open Firestore
3. Navigate to `users/{userId}`
4. Add field: `role` = `admin`

---

## 📱 Real-Time Monitoring

### What's Monitored in Real-Time:

- ✅ **User Activity** - Online/offline status, last seen
- ✅ **Video Uploads** - New videos, views, likes
- ✅ **Messages** - All chat messages across the app
- ✅ **Notifications** - All activity notifications
- ✅ **Stats** - Total users, videos, messages

### How Real-Time Works:
- **Firebase Listeners** - Live Firestore snapshots
- **Auto-Refresh** - No manual refresh needed
- **Instant Updates** - Events appear as they happen
- **Activity Log** - All events logged with timestamps

---

## 🛠️ Admin Actions (Future Enhancements)

The system is designed to support future admin actions:

### Planned Features:
- 🚫 **Ban/Suspend Users**
- 🗑️ **Delete Videos/Comments**
- 📊 **Export Analytics**
- 🔍 **Search Users/Videos**
- 📧 **Send Push Notifications**
- 📝 **View Full Logs**
- ⚙️ **System Settings**

---

## 🔧 Technical Details

### Files Created/Updated:
1. **`lib/widgets/admin_monitoring_panel.dart`** - Main monitoring UI
2. **`lib/services/admin_service.dart`** - Admin verification service
3. **`lib/widgets/edit_profile_view.dart`** - Updated with admin button in app bar

### Firebase Collections Monitored:
- `users` - User profiles and online status
- `videos` - Video uploads and stats
- `chats/{chatId}/messages` - All messages
- `notifications/{userId}/items` - Activity notifications

### Performance:
- **Efficient Queries** - Limited to 20 most recent items per category
- **Firebase Indexes** - Uses existing indexes for fast queries
- **Memory Limit** - Logs limited to 100 entries
- **Real-Time Streams** - Low latency, instant updates

---

## 🎯 Use Cases

### Monitor User Growth:
- Check online users in real-time
- See new user registrations
- Track user engagement

### Content Moderation:
- Review new videos as they're uploaded
- Monitor video engagement (views, likes)
- Check video status (published, blocked, etc.)

### Message Monitoring:
- See recent chat activity
- Monitor message volume
- Track user interactions

### Debug & Troubleshooting:
- View live activity logs
- Check system stats
- Identify issues in real-time

---

## 🔒 Security Notes

1. **Admin-Only Access**: Button only shows for verified admin users
2. **UID-Based Auth**: Primary verification uses Firebase UID (can't be faked)
3. **No Data Modification**: Currently read-only (safe for exploration)
4. **Firestore Rules**: Existing security rules still apply
5. **No Sensitive Data**: Doesn't show passwords, tokens, or private keys

---

## 🚦 Quick Start

1. ✅ **Login as technqs**
2. ✅ **Go to your profile**
3. ✅ **Tap "Edit Profile"**
4. ✅ **Tap admin icon (top right)**
5. ✅ **Explore real-time data**
6. ✅ **Swipe between tabs**
7. ✅ **Pull to refresh stats**

---

## 📞 Support

If the admin button doesn't appear:
1. Check you're logged in as `technqs`
2. Make sure you're in **Edit Profile** screen
3. Check your user ID in Firebase Console
4. Verify it matches: `bU0RxyZ2L4ULAv1Co5L4f825yV73`
5. Check app logs for admin check messages

---

**Admin monitoring is now live! Open Edit Profile to start tracking your app in real-time.** 🚀

