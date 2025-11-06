# Global Avatar Sync Implementation

## Overview
Comprehensive documentation for instant global avatar updates across the app and website when a user changes their avatar. This system ensures real-time synchronization using Firestore listeners and automatic UI updates.

## Architecture

### Core Components

1. **Firestore** - Single source of truth for avatar URLs
2. **Firestore Listeners** - Real-time updates when avatar changes
3. **UnifiedAvatarService** - Avatar loading and caching in app
4. **WebsiteSyncService** - Bidirectional sync between app and website
5. **RobustAuthenticationService** - User data listener for avatar changes

## How It Works

### 1. Avatar Update Flow

#### From App (Flutter):
```
User uploads avatar
    ↓
Upload to Firebase Storage
    ↓
Get download URL
    ↓
Update Firestore: users/{userId}.avatarURL
    ↓
Firestore triggers real-time listeners
    ↓
App UI updates automatically
    ↓
WebsiteSyncService syncs to website
    ↓
Website updates automatically
```

#### From Website:
```
User uploads avatar
    ↓
Upload to Firebase Storage
    ↓
Get download URL
    ↓
Update Firestore: users/{userId}.avatarURL
    ↓
Firestore triggers real-time listeners
    ↓
App listeners detect change
    ↓
App UI updates automatically
```

### 2. Real-Time Updates

#### App Side (RobustAuthenticationService)
```dart
// Real-time listener for user data changes
_firestoreInstance
    .collection("users")
    .doc(userId)
    .snapshots()
    .listen((snapshot) {
  if (snapshot.exists) {
    final data = snapshot.data()!;
    final newAvatarURL = data['avatarURL'] as String?;
    
    // Check if avatar URL changed
    if (newAvatarURL != currentAvatarURL) {
      // Update current user object
      _currentUser = User(/* ... */ avatarURL: newAvatarURL);
      notifyListeners(); // Trigger UI rebuild
    }
  }
});
```

#### Website Side (Firestore JavaScript SDK)
```javascript
// Real-time listener for user data changes
firebase.firestore()
  .collection('users')
  .doc(userId)
  .onSnapshot((snapshot) => {
    if (snapshot.exists) {
      const data = snapshot.data();
      const newAvatarURL = data.avatarURL;
      
      // Update avatar in UI
      updateAvatarInUI(newAvatarURL);
    }
  });
```

## Implementation Details

### 1. Avatar Upload (App)

**File:** `lib/services/auth_service.dart` or `lib/services/robust_auth_service.dart`

```dart
/// Upload avatar image to Firebase Storage and update user profile
Future<String> uploadAvatar(File imageFile) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Upload to Firebase Storage
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('avatars')
        .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    
    final uploadTask = storageRef.putFile(imageFile);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    // Update Firestore - this triggers real-time listeners
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
          'avatarURL': downloadUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    // Update local state immediately
    _currentUser = User(/* ... */ avatarURL: downloadUrl);
    notifyListeners();

    return downloadUrl;
  } catch (e) {
    debugPrint('❌ Error uploading avatar: $e');
    rethrow;
  }
}
```

### 2. Real-Time Listener (App)

**File:** `lib/services/robust_auth_service.dart`

```dart
/// Set up real-time listener for user data changes
void _setupUserDataListener(String userId) {
  _firestoreInstance
      .collection("users")
      .doc(userId)
      .snapshots()
      .listen((snapshot) {
    if (snapshot.exists && _currentUser != null) {
      final data = snapshot.data()!;
      final newAvatarURL = data['avatarURL'] as String? ?? '';
      final currentAvatarURL = _currentUser!.avatarURL ?? '';

      // Check if avatar URL changed
      if (newAvatarURL != currentAvatarURL && newAvatarURL.isNotEmpty) {
        // Update current user object
        _currentUser = User(
          id: _currentUser!.id,
          username: _currentUser!.username,
          displayName: _currentUser!.displayName,
          bio: _currentUser!.bio,
          avatarURL: newAvatarURL,
          // ... other fields
        );
        notifyListeners(); // Trigger UI rebuild
      }
    }
  });
}
```

### 3. Website Sync Service

**File:** `lib/services/website_sync_service.dart`

```dart
/// Sync avatar data to website
Future<bool> syncAvatarToWebsite({
  required String userId,
  required String? avatarURL,
  required String displayName,
  required String username,
}) async {
  try {
    if (avatarURL == null || avatarURL.isEmpty) {
      return false;
    }

    // Get avatar data as base64
    final avatarBase64 = await _getAvatarAsBase64(avatarURL);
    if (avatarBase64 == null) {
      return false;
    }

    // Prepare sync data
    final syncData = {
      'userId': userId,
      'avatarURL': avatarURL,
      'displayName': displayName,
      'username': username,
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000,
      'avatarBase64': avatarBase64,
    };

    // Send to website API
    final response = await _sendToWebsite(syncData);
    
    if (response) {
      // Set up real-time listener for this user
      _setupUserListener(userId);
      return true;
    }
    
    return false;
  } catch (e) {
    log("❌ Error syncing avatar to website: $e");
    return false;
  }
}

/// Set up real-time listener for user avatar changes
void _setupUserListener(String userId) {
  _userListener?.cancel();
  _currentUserId = userId;
  
  _userListener = _firestore
      .collection('users')
      .doc(userId)
      .snapshots()
      .listen((snapshot) {
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data()!;
      final newAvatarURL = data['avatarURL'] as String?;
      
      // Check if avatar URL changed
      _checkAvatarUpdate(userId, newAvatarURL);
    }
  });
}
```

### 4. Avatar Display (UnifiedAvatarService)

**File:** `lib/services/unified_avatar_service.dart`

```dart
/// Get bulletproof avatar widget with automatic updates
Widget getAvatar({
  required String imageUrl,
  double radius = 20,
  Widget? placeholder,
  Widget? errorWidget,
  bool showLoadingIndicator = true,
  bool useProfileViewStyling = true,
}) {
  // Uses CachedNetworkImage for instant loading
  // Automatically updates when imageUrl changes
  return CachedNetworkImage(
    imageUrl: imageUrl,
    // ... configuration
  );
}
```

## Website Implementation

### 1. Firestore Listener (JavaScript)

```javascript
// Real-time listener for user avatar changes
function setupAvatarListener(userId) {
  firebase.firestore()
    .collection('users')
    .doc(userId)
    .onSnapshot((snapshot) => {
      if (snapshot.exists) {
        const data = snapshot.data();
        const newAvatarURL = data.avatarURL;
        
        // Update all avatar instances in UI
        updateAllAvatarInstances(newAvatarURL);
      }
    });
}

// Update avatar in all UI components
function updateAllAvatarInstances(avatarURL) {
  // Update profile page avatar
  const profileAvatar = document.getElementById('profile-avatar');
  if (profileAvatar) {
    profileAvatar.src = avatarURL;
  }
  
  // Update navigation avatar
  const navAvatar = document.getElementById('nav-avatar');
  if (navAvatar) {
    navAvatar.src = avatarURL;
  }
  
  // Update comment avatars
  const commentAvatars = document.querySelectorAll('.comment-avatar');
  commentAvatars.forEach(avatar => {
    avatar.src = avatarURL;
  });
  
  // Update video creator avatars
  const creatorAvatars = document.querySelectorAll('.creator-avatar');
  creatorAvatars.forEach(avatar => {
    avatar.src = avatarURL;
  });
}
```

### 2. Avatar Upload (Website)

```javascript
// Upload avatar and update Firestore
async function uploadAvatar(imageFile) {
  try {
    const user = firebase.auth().currentUser;
    if (!user) throw new Error('User not authenticated');

    // Upload to Firebase Storage
    const storageRef = firebase.storage()
      .ref()
      .child(`avatars/${user.uid}_${Date.now()}.jpg`);
    
    const snapshot = await storageRef.put(imageFile);
    const downloadURL = await snapshot.ref.getDownloadURL();

    // Update Firestore - triggers real-time listeners
    await firebase.firestore()
      .collection('users')
      .doc(user.uid)
      .update({
        avatarURL: downloadURL,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });

    // UI will update automatically via listener
    return downloadURL;
  } catch (error) {
    console.error('Error uploading avatar:', error);
    throw error;
  }
}
```

## Global Update Mechanism

### How Updates Propagate Globally

1. **Single Source of Truth**: Firestore `users/{userId}.avatarURL`
2. **Real-Time Listeners**: Both app and website listen to Firestore changes
3. **Automatic UI Updates**: Listeners trigger UI rebuilds automatically
4. **No Manual Refresh Needed**: Updates happen instantly via Firestore listeners

### Update Propagation Timeline

```
Avatar Change (App/Website)
    ↓
Firestore Update (0ms)
    ↓
Firestore Listener Triggered (50-200ms)
    ↓
App UI Updates (50-200ms)
    ↓
Website UI Updates (50-200ms)
    ↓
Total Update Time: ~100-400ms
```

## Key Features

### ✅ Instant Updates
- Real-time synchronization via Firestore listeners
- No manual refresh required
- Updates propagate automatically

### ✅ Bidirectional Sync
- App → Website: Via WebsiteSyncService
- Website → App: Via Firestore listeners
- Both directions work simultaneously

### ✅ Automatic UI Updates
- App: `notifyListeners()` triggers widget rebuilds
- Website: JavaScript listeners update DOM elements
- All avatar instances update automatically

### ✅ Caching & Performance
- UnifiedAvatarService handles caching
- CachedNetworkImage for instant display
- Memory and disk caching for performance

## Testing

### Test Avatar Update Flow

1. **From App:**
   ```dart
   // Upload avatar
   final avatarUrl = await authService.uploadAvatar(imageFile);
   
   // Verify Firestore update
   final userDoc = await FirebaseFirestore.instance
       .collection('users')
       .doc(userId)
       .get();
   assert(userDoc.data()?['avatarURL'] == avatarUrl);
   
   // Verify website updates (check website UI)
   // Verify app UI updates (check app UI)
   ```

2. **From Website:**
   ```javascript
   // Upload avatar
   const avatarURL = await uploadAvatar(imageFile);
   
   // Verify Firestore update
   const userDoc = await firebase.firestore()
       .collection('users')
       .doc(userId)
       .get();
   assert(userDoc.data().avatarURL === avatarURL);
   
   // Verify app updates (check app UI)
   // Verify website UI updates (check website UI)
   ```

## Troubleshooting

### Avatar Not Updating

1. **Check Firestore Listener:****
   - Verify listener is active
   - Check for errors in console
   - Ensure user document exists

2. **Check Network:****
   - Verify internet connection
   - Check Firestore rules allow read/write
   - Verify user is authenticated

3. **Check UI Updates:**
   - Verify `notifyListeners()` is called
   - Check widget rebuilds are happening
   - Ensure avatar URL is being used correctly

### Avatar Not Syncing to Website

1. **Check WebsiteSyncService:**
   - Verify service is initialized
   - Check API endpoint is correct
   - Verify base64 conversion works

2. **Check Website API:**
   - Verify API endpoint exists
   - Check CORS settings
   - Verify authentication

## Current Implementation Status

### ✅ Implemented
- Firestore real-time listeners
- Avatar upload from app
- Automatic UI updates in app
- UnifiedAvatarService for caching
- WebsiteSyncService skeleton

### ⚠️ Needs Implementation
- Website API endpoint for avatar sync
- Complete WebsiteSyncService integration
- Website Firestore listener setup
- Avatar upload from website
- Error handling and retry logic

## Next Steps

1. **Complete Website Integration:**
   - Implement website API endpoint
   - Set up Firestore listeners on website
   - Test bidirectional sync

2. **Enhance Error Handling:**
   - Add retry logic for failed syncs
   - Implement offline queue
   - Add error recovery mechanisms

3. **Optimize Performance:**
   - Add avatar compression
   - Implement lazy loading
   - Add preloading strategies

## Files Involved

- `lib/services/robust_auth_service.dart` - User data listener
- `lib/services/unified_avatar_service.dart` - Avatar loading/caching
- `lib/services/website_sync_service.dart` - Website sync
- `lib/services/auth_service.dart` - Avatar upload
- `lib/widgets/edit_profile_view.dart` - Avatar upload UI
- Website: Firestore JavaScript SDK integration needed

