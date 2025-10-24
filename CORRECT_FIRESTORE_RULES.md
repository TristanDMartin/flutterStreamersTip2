# CORRECT Firestore Rules for Video Upload

## 🚨 **CRITICAL: Use These Exact Rules**

The previous rules had field name mismatches. These rules match your app's actual data structure.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isValidUser(userId) {
      return userId is string && userId.size() > 0 && userId.size() <= 128;
    }
    
    function isValidString(value, minLength, maxLength) {
      return value is string && value.size() >= minLength && value.size() <= maxLength;
    }
    
    function isValidTimestamp(value) {
      return value is timestamp;
    }
    
    function isValidUrl(value) {
      return value is string && value.matches('https://.*');
    }
    
    function isValidEmail(value) {
      return value is string && value.matches('.*@.*\\..*');
    }
    
    // User profiles - public read, owner write
    match /users/{userId} {
      allow read: if true; // Public profiles
      allow write: if isOwner(userId) && isValidUser(userId);
      
      // Allow follower/following count updates for follow operations
      allow update: if isAuthenticated() && 
        isValidUser(userId) &&
        (resource.data.diff(resource.data).affectedKeys().hasOnly(['followerCount', 'followingCount', 'updatedAt']) ||
         // Allow any authenticated user to update follower/following counts (for follow operations)
         (request.resource.data.keys().hasAll(['followerCount', 'followingCount']) && 
          request.resource.data.followerCount >= 0 && 
          request.resource.data.followingCount >= 0));
      
      // User subcollections (excluding bookmarks which has its own rule)
      match /{subcollection=**} {
        allow read: if true; // Public read for all subcollections
        allow write: if isOwner(userId);
      }
      
      // Bookmarks subcollection - proper authentication
      match /bookmarks/{eventId} {
        allow read, write: if isOwner(userId);
      }
      
      // Events subcollection
      match /events/{eventId} {
        allow read: if true; // Public read for events
        allow create: if isOwner(userId) && 
          isValidString(resource.data.title, 1, 200) &&
          isValidString(resource.data.description, 0, 2000) &&
          isValidTimestamp(resource.data.start_at) &&
          isValidTimestamp(resource.data.end_at) &&
          resource.data.start_at < resource.data.end_at &&
          resource.data.visibility in ['public', 'unlisted', 'private'] &&
          resource.data.type in ['stream', 'collab', 'irl', 'other'] &&
          resource.data.host_uid == userId &&
          isValidTimestamp(resource.data.created_at) &&
          isValidTimestamp(resource.data.updated_at);
        
        allow update: if isOwner(userId) && 
          isValidString(resource.data.title, 1, 200) &&
          isValidString(resource.data.description, 0, 2000) &&
          isValidTimestamp(resource.data.start_at) &&
          isValidTimestamp(resource.data.end_at) &&
          resource.data.start_at < resource.data.end_at &&
          resource.data.visibility in ['public', 'unlisted', 'private'] &&
          resource.data.type in ['stream', 'collab', 'irl', 'other'] &&
          resource.data.host_uid == userId &&
          isValidTimestamp(resource.data.updated_at);
        
        allow delete: if isOwner(userId);
      }
    }
    
    // Videos collection (for mobile app posts) - FIXED FIELD NAMES
    match /videos/{videoId} {
      allow read: if true; // Public read for all videos
      allow create: if isAuthenticated() && 
        isValidString(resource.data.caption, 0, 500) &&           // ✅ FIXED: caption instead of title
        isValidUser(resource.data.userId) &&                      // ✅ FIXED: userId instead of uid/authorId
        request.auth.uid == resource.data.userId;                 // ✅ FIXED: userId instead of uid/authorId
      
      allow update: if isAuthenticated() && 
        isValidString(resource.data.caption, 0, 500) &&           // ✅ FIXED: caption instead of title
        isValidUser(resource.data.userId) &&                      // ✅ FIXED: userId instead of uid/authorId
        request.auth.uid == resource.data.userId;                 // ✅ FIXED: userId instead of uid/authorId
      
      allow delete: if isAuthenticated() && 
        isValidUser(resource.data.userId) &&                      // ✅ FIXED: userId instead of uid/authorId
        request.auth.uid == resource.data.userId;                 // ✅ FIXED: userId instead of uid/authorId
    }
    
    // Website posts collection (for website uploads) - KEEP ORIGINAL
    match /website_posts/{postId} {
      allow read: if true; // Public read for all posts
      allow create: if isAuthenticated() && 
        isValidString(resource.data.title, 1, 200) &&
        isValidUser(resource.data.uid || resource.data.authorId) &&
        (request.auth.uid == resource.data.uid || request.auth.uid == resource.data.authorId);
      
      allow update: if isAuthenticated() && 
        isValidString(resource.data.title, 1, 200) &&
        isValidUser(resource.data.uid || resource.data.authorId) &&
        (request.auth.uid == resource.data.uid || request.auth.uid == resource.data.authorId);
      
      allow delete: if isAuthenticated() && 
        isValidUser(resource.data.uid || resource.data.authorId) &&
        (request.auth.uid == resource.data.uid || request.auth.uid == resource.data.authorId);
    }
    
    // Website videos collection (for website uploads) - KEEP ORIGINAL
    match /website_videos/{videoId} {
      allow read: if true; // Public read for all videos
      allow create: if isAuthenticated() && 
        isValidString(resource.data.title, 1, 200) &&
        isValidUser(resource.data.uid || resource.data.authorId) &&
        (request.auth.uid == resource.data.uid || request.auth.uid == resource.data.authorId);
      
      allow update: if isAuthenticated() && 
        isValidString(resource.data.title, 1, 200) &&
        isValidUser(resource.data.uid || resource.data.authorId) &&
        (request.auth.uid == resource.data.uid || request.auth.uid == resource.data.authorId);
      
      allow delete: if isAuthenticated() && 
        isValidUser(resource.data.uid || resource.data.authorId) &&
        (request.auth.uid == resource.data.uid || request.auth.uid == resource.data.authorId);
    }
    
    // Feed collections - allow authenticated users to read
    match /for_you/{feedId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    match /following/{feedId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    // Category feeds - allow authenticated users to read
    match /gaming/{feedId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    match /music/{feedId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    match /art/{feedId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    match /tech/{feedId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    match /sports/{feedId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    match /comedy/{feedId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    match /lifestyle/{feedId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    match /education/{feedId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    // Notifications collection
    match /notifications/{notificationId} {
      allow read: if isAuthenticated() && request.auth.uid == resource.data.userId;
      allow write: if isAuthenticated() && request.auth.uid == resource.data.userId;
    }
    
    // Comments collection
    match /comments/{commentId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && 
        isValidString(resource.data.content, 1, 1000) &&
        isValidUser(resource.data.userId) &&
        request.auth.uid == resource.data.userId;
      
      allow update: if isAuthenticated() && 
        isValidString(resource.data.content, 1, 1000) &&
        isValidUser(resource.data.userId) &&
        request.auth.uid == resource.data.userId;
      
      allow delete: if isAuthenticated() && 
        isValidUser(resource.data.userId) &&
        request.auth.uid == resource.data.userId;
    }
    
    // Follows collection
    match /follows/{followId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && 
        isValidUser(resource.data.followerId) &&
        isValidUser(resource.data.followingId) &&
        request.auth.uid == resource.data.followerId;
      
      allow delete: if isAuthenticated() && 
        isValidUser(resource.data.followerId) &&
        request.auth.uid == resource.data.followerId;
    }
    
    // Usernames collection
    match /usernames/{username} {
      allow read: if true; // Public read for username availability
      allow write: if isAuthenticated() && 
        isValidString(resource.data.username, 3, 30) &&
        isValidUser(resource.data.userId) &&
        request.auth.uid == resource.data.userId;
    }
    
    // Default rule - deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## 🔧 **Key Changes Made**

1. **Fixed Field Names**:
   - `title` → `caption` (your app sends `caption`)
   - `uid`/`authorId` → `userId` (your app sends `userId`)
   - `creatorId`/`creator_id` → `userId` (your app sends `userId`)

2. **Relaxed Validation**:
   - `caption` can be 0-500 characters (optional)
   - Removed strict validation for other fields

3. **Kept Website Rules**:
   - `website_posts` and `website_videos` collections unchanged
   - Uses original field names (`title`, `uid`, `authorId`)

## 📋 **Instructions**

1. **Copy the entire rules above**
2. **Go to Firebase Console**: https://console.firebase.google.com/project/streamerstip-6cfdb/firestore/rules
3. **Replace ALL existing rules** with the rules above
4. **Click "Publish"**
5. **Test video upload**

## ✅ **Expected Result**

After updating these rules, your video upload should work because:
- Rules now match your app's field names (`userId`, `caption`, etc.)
- Authentication is properly validated
- All required fields are present in your app's data
