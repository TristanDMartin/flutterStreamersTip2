# Website Message Notifications - Quick Implementation Guide

## 🎯 What Changed

We've implemented a **Cloud Function** that automatically handles message notifications for both the app and website. The website just needs to listen to a simple field instead of counting individual messages.

---

## ✅ What's Already Working

- ✅ Website sends messages correctly
- ✅ Cloud Function automatically increments unread counts
- ✅ Cloud Function sends push notifications
- ✅ Everything syncs across app and website

---

## 🔧 What the Website Needs to Do

### 1. Listen to Unread Counts

**Old way** (don't do this ❌):
```javascript
// Counting all unread messages manually
const unreadCount = messages.filter(m => 
  !m.readBy.includes(currentUserId)
).length;
```

**New way** (do this ✅):
```javascript
// Listen to the chat document
db.collection('chats')
  .where('participants', 'array-contains', currentUserId)
  .onSnapshot(snapshot => {
    snapshot.docs.forEach(doc => {
      const chatData = doc.data();
      
      // Just read this one field!
      const unreadCount = chatData[`unreadCount_${currentUserId}`] || 0;
      
      // Update your UI with the unread count
      updateChatBadge(doc.id, unreadCount);
    });
  });
```

### 2. Mark Chats as Read When Opened

When a user opens a chat, reset their unread count:

```javascript
async function openChat(chatId, currentUserId) {
  // Mark as read by resetting the count to 0
  await db.collection('chats').doc(chatId).update({
    [`unreadCount_${currentUserId}`]: 0
  });
  
  // Now show the chat
  showChat(chatId);
}
```

### 3. Sending Messages (Already Works!)

Your current message sending code should already work. The Cloud Function will automatically:
- Increment the recipient's unread count
- Send push notification to their devices
- Update last message info

**No changes needed** to your message sending code! 🎉

---

## 📊 Firestore Data Structure

### Chat Document:
```javascript
chats/{chatId}
├── participants: ["user1", "user2"]
├── lastMessage: "Hey!"
├── lastTimestamp: Timestamp
├── unreadCount_user1: 0    // User 1 has read everything
└── unreadCount_user2: 3    // User 2 has 3 unread
```

**Key Point**: Each user has their own `unreadCount_{userId}` field.

---

## 🔍 Quick Example

### Get Total Unread Count for Badge:

```javascript
function getTotalUnreadCount(currentUserId) {
  return db.collection('chats')
    .where('participants', 'array-contains', currentUserId)
    .onSnapshot(snapshot => {
      let totalUnread = 0;
      
      snapshot.docs.forEach(doc => {
        const data = doc.data();
        totalUnread += data[`unreadCount_${currentUserId}`] || 0;
      });
      
      // Update main inbox badge
      updateInboxBadge(totalUnread);
    });
}
```

### Display Unread Count Per Chat:

```javascript
function renderChatList(chats, currentUserId) {
  chats.forEach(chat => {
    const unreadCount = chat[`unreadCount_${currentUserId}`] || 0;
    
    // Show badge if unread
    if (unreadCount > 0) {
      showBadge(chat.id, unreadCount);
    }
  });
}
```

---

## 🚀 How It Works

```
1. User sends message (website or app)
        ↓
2. Cloud Function automatically triggers
        ↓
3. Cloud Function:
   - Increments unreadCount_{recipientId}
   - Sends push notification
   - Updates lastMessage
        ↓
4. Website listener detects change
        ↓
5. Badge updates automatically ✨
```

---

## 🧪 Testing Steps

### Test 1: Send Message from Website
1. Send a message to another user
2. **Check Firestore**: See `unreadCount_{recipientId}` increase
3. **Check their app**: Should see badge and notification

### Test 2: Receive Message
1. Have someone send you a message (from app or website)
2. **Your website**: Should see badge increase automatically
3. **Open the chat**: Badge should disappear

### Test 3: Cross-Platform Sync
1. Send message from website
2. Open chat on app → badge clears
3. **Check website**: Should also show as read

---

## 🔧 Firestore Security Rules

Make sure your `firestore.rules` allows reading/writing the unread count:

```javascript
match /chats/{chatId} {
  allow read, write: if request.auth != null && 
    request.auth.uid in resource.data.participants;
    
  allow update: if request.auth != null && 
    request.auth.uid in resource.data.participants;
}
```

*(These rules should already be in place)*

---

## 🐛 Troubleshooting

### Problem: "Badge not updating"
**Solution**: Make sure you're using a **real-time listener** (`onSnapshot`), not a one-time read (`get`).

### Problem: "Count is wrong"
**Solution**: 
1. Check Firestore console for the actual value
2. Make sure you're using the correct field: `unreadCount_{userId}` (with the underscore)
3. Try opening and closing the chat to reset it

### Problem: "Website shows different count than app"
**Solution**: Both should sync automatically. If not:
1. Check that both are listening to the same chat document
2. Verify the field name is correct
3. Clear browser cache and reload

---

## 📝 Summary Checklist

- [ ] Update chat list to read `unreadCount_{userId}` field
- [ ] Update total badge count to sum all `unreadCount_{userId}` values
- [ ] Add `update()` call to reset count when chat is opened
- [ ] Use real-time listeners (`onSnapshot`), not one-time reads
- [ ] Test sending and receiving messages
- [ ] Verify cross-platform sync (website ↔ app)

---

## 💡 Key Benefits

| Before | After |
|--------|-------|
| Count all messages per chat | Read one field |
| Multiple Firestore queries | Single field read |
| Manual notification logic | Automatic via Cloud Function |
| Inconsistent sync | Always in sync |

---

## 🔗 Need More Info?

- **Full documentation**: `MESSAGE_NOTIFICATIONS_COMPLETE.md`
- **Firebase Console**: https://console.firebase.google.com/project/streamerstip-6cfdb
- **Cloud Function**: `onMessageCreate` (already deployed)

---

## ✅ That's It!

The heavy lifting is done by the Cloud Function. The website just needs to:
1. **Read** `unreadCount_{userId}` from chat documents
2. **Reset** it to 0 when a chat is opened
3. **Everything else is automatic!** 🎉

---

**Status**: ✅ Backend deployed and ready  
**Website Changes**: Just update to read the new field  
**Estimated Time**: 30 minutes to implement

