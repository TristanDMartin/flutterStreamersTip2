# BuzZz User ID Missing - Website Fix Required

## Problem Summary
The buzZz user profile created on the website is missing the `id` field in Firestore, causing the Flutter app to crash when trying to view their profile.

## Current State
- **User exists in Firestore**: ✅ Yes
- **Username**: `buzzz` ✅ 
- **Display Name**: `BuzZz` ✅
- **User ID**: ❌ **MISSING/EMPTY**
- **App Behavior**: Black screen with loading spinner, then crashes

## Error Details
```
🔵 NetworkView: User ID being passed: (empty string)
🔵 NetworkView: User username: buzzz
🔵 NetworkView: User displayName: BuzZz
🚨 Platform Error: Invalid argument(s): A document path must be a non-empty string
```

## Root Cause
When buzZz created their profile on the website, the user document was created in Firestore but the `id` field was not properly set. The Flutter app expects every user to have a valid `id` field that matches the Firestore document ID.

## Required Fix on Website

### 1. User Document Structure
The buzZz user document in Firestore should have this structure:
```json
{
  "id": "jsmbQMLQjoUyC5cUFvkrRbi9mkp1",  // ← MISSING - needs to be set
  "username": "buzzz",
  "displayName": "BuzZz",
  "email": "buzzz@example.com",
  "avatarURL": "",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 2. Website Code Fix
When creating a user profile on the website, ensure the `id` field is set:

```javascript
// When creating user document in Firestore
const userDoc = {
  id: userId,  // ← This field is missing for buzZz
  username: userData.username,
  displayName: userData.displayName,
  email: userData.email,
  avatarURL: userData.avatarURL || "",
  createdAt: new Date(),
  updatedAt: new Date()
};

await db.collection('users').doc(userId).set(userDoc);
```

### 3. Immediate Fix for buzZz
Update the existing buzZz user document:

```javascript
// Find buzZz user by username
const buzzzQuery = await db.collection('users')
  .where('username', '==', 'buzzz')
  .get();

if (!buzzzQuery.empty) {
  const buzzzDoc = buzzzQuery.docs[0];
  const buzzzId = buzzzDoc.id; // Get the document ID
  
  // Update the document to include the id field
  await buzzzDoc.ref.update({
    id: buzzzId,
    updatedAt: new Date()
  });
}
```

## Expected Result
After the fix:
- buzZz user will have a valid `id` field
- Flutter app will load their real profile instead of sample data
- No more black screen or crashes when tapping buzZz user card

## Verification
Check that the buzZz user document in Firestore has:
- ✅ `id` field populated with the document ID
- ✅ `username` field set to "buzzz"
- ✅ `displayName` field set to "BuzZz"

## Priority
**HIGH** - This is blocking users from viewing buzZz's profile and causes app crashes.

## Files Affected
- Website user creation/registration code
- Firestore user document structure
- Any user profile update functions

## Testing
1. Create a new user on the website
2. Verify the `id` field is set in Firestore
3. Test the user appears correctly in Flutter app NetworkView
4. Test tapping the user card loads their real profile (not sample data)
