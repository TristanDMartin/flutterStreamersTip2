# Video Creator Field Cross-Platform Compatibility Fix

## Problem Identified

The app had **inconsistent field naming** for video creators across mobile and web platforms:

### Before Fix:
- **Mobile app upload services** were using `userId` field only
- **Website/web interface** was expecting `creator_id` or `creatorId` fields
- **Some internal services** were expecting different field names

This caused:
- Videos uploaded from mobile showing `creator_id: undefined` on website
- Videos appearing orphaned (no creator) on certain platforms
- Issues with user profile video feeds and discovery features

### Field Name Variants Found:
1. `userId` - Used by mobile upload services
2. `creatorId` - Used by some internal services (camelCase)
3. `creator_id` - Expected by website (snake_case)

## Solution Implemented

### 1. Updated Video Upload Services

All video upload services now write **all three field variants** for maximum compatibility:

**Files Updated:**
- `lib/services/video_upload_service.dart` - Main upload service
- `lib/services/unified_video_service.dart` - Unified service
- `lib/services/optimistic_video_service.dart` - Optimistic updates

**Changes Made:**
```dart
final videoData = {
  'id': videoId,
  'userId': userId,              // Original field (mobile)
  'creatorId': userId,           // CamelCase variant (internal services)
  'creator_id': userId,          // Snake case variant (website)
  // ... rest of fields
};
```

### 2. Updated Video Reading Services

All video reading services now check **all three field variants** as fallbacks:

**Files Updated:**
- `lib/services/video_service.dart` - Main video service
- `lib/widgets/discover_view.dart` - Discovery view

**Changes Made:**
```dart
// Support all field name variants for cross-platform compatibility
final userId = (data['userId'] ?? data['creatorId'] ?? data['creator_id']) as String?;
```

### 3. Created Migration Scripts

Two migration scripts were created to fix existing videos in Firestore:

#### Dart Version (Flutter/Mobile)
**File:** `scripts/migrate_video_creator_fields.dart`

Run with Flutter:
```bash
# From project root
flutter run scripts/migrate_video_creator_fields.dart
```

#### JavaScript Version (Node.js)
**File:** `scripts/migrate_video_creator_fields.js`

**Prerequisites:**
1. Firebase Admin SDK installed:
   ```bash
   npm install firebase-admin
   ```

2. Service account key file at `service-account-key.json`

**Run the migration:**
```bash
node scripts/migrate_video_creator_fields.js
```

### What the Migration Does:

1. **Scans all videos** in Firestore
2. **Checks each video** for missing creator field variants
3. **Adds missing fields** using the existing creator ID value
4. **Updates in batches** for efficiency (500 videos per batch)
5. **Reports statistics**:
   - Videos updated
   - Videos skipped (already have all fields)
   - Videos with errors

## Testing Checklist

After running the migration, verify:

### 1. Mobile App
- [ ] New video uploads include all three fields (userId, creatorId, creator_id)
- [ ] Videos display correctly in home feed
- [ ] User profile shows all their videos
- [ ] Discovery feed shows videos with creators

### 2. Website
- [ ] Videos show correct creator information
- [ ] Videos no longer show `creator_id: undefined`
- [ ] User profiles display videos correctly
- [ ] Search and discovery work properly

### 3. Database Verification
Query Firestore to verify field presence:

```javascript
// In Firebase Console or using Firebase Admin
db.collection('videos').limit(10).get().then(snapshot => {
  snapshot.forEach(doc => {
    const data = doc.data();
    console.log(`Video ${doc.id}:`, {
      hasUserId: !!data.userId,
      hasCreatorId: !!data.creatorId,
      hasCreatorIdSnake: !!data.creator_id,
      allMatch: data.userId === data.creatorId && 
                data.userId === data.creator_id
    });
  });
});
```

## Migration Steps

### Recommended Order:

1. **Test in Development First**
   ```bash
   # Point to development/staging Firestore
   node scripts/migrate_video_creator_fields.js
   ```

2. **Verify Results**
   - Check random videos in Firestore console
   - Test mobile app
   - Test website

3. **Run in Production**
   ```bash
   # Point to production Firestore
   node scripts/migrate_video_creator_fields.js
   ```

4. **Monitor**
   - Check app logs for any issues
   - Monitor error rates
   - Verify user complaints resolved

## Files Modified

### Services (Write Operations):
1. `lib/services/video_upload_service.dart`
   - Line 144-145: Added creatorId and creator_id fields
   - Line 327-328: Added creatorId and creator_id fields (drafts)

2. `lib/services/unified_video_service.dart`
   - Line 187-188: Added creatorId and creator_id fields

3. `lib/services/optimistic_video_service.dart`
   - Line 80-81: Added creatorId and creator_id fields

### Services (Read Operations):
1. `lib/services/video_service.dart`
   - Line 63: Added fallback support for all three field variants

2. `lib/widgets/discover_view.dart`
   - Line 1064: Added fallback support for all three field variants

### Migration Scripts:
1. `scripts/migrate_video_creator_fields.dart` (Flutter/Dart)
2. `scripts/migrate_video_creator_fields.js` (Node.js)

## Impact Assessment

### Positive Impacts:
✅ Website can now properly read creator information
✅ Mobile app maintains backward compatibility
✅ Existing videos remain functional
✅ Future uploads work across all platforms
✅ No breaking changes to existing code

### Performance Considerations:
- **Storage:** Minimal increase (~50 bytes per video for duplicate fields)
- **Read performance:** Unchanged (still reading single field)
- **Write performance:** Negligible (writing 2 extra fields)
- **Migration time:** ~1-2 seconds per 100 videos

### Breaking Changes:
❌ **NONE** - This is a purely additive change

## Rollback Plan

If issues occur, the fix can be easily rolled back:

1. **Code Rollback:**
   ```bash
   git revert <commit-hash>
   ```

2. **Database Rollback:**
   - NOT NEEDED - The extra fields don't break anything
   - If desired, remove fields:
   ```javascript
   // Remove redundant fields (NOT RECOMMENDED)
   db.collection('videos').get().then(snapshot => {
     snapshot.forEach(doc => {
       doc.ref.update({
         creatorId: admin.firestore.FieldValue.delete(),
         creator_id: admin.firestore.FieldValue.delete()
       });
     });
   });
   ```

## Future Recommendations

### 1. Standardize on Single Field Name
Eventually migrate to using just one field name across all platforms:
- **Recommendation:** Use `userId` (most common in mobile)
- **Alternative:** Use `creator_id` (follows Firestore naming conventions)

### 2. Update Firestore Security Rules
Ensure rules reference all field variants:
```javascript
match /videos/{videoId} {
  allow read: if true;
  allow write: if request.auth != null && 
    (request.resource.data.userId == request.auth.uid ||
     request.resource.data.creatorId == request.auth.uid ||
     request.resource.data.creator_id == request.auth.uid);
}
```

### 3. Add Database Validation
Create a Cloud Function to validate field consistency:
```javascript
exports.validateVideoCreatorFields = functions.firestore
  .document('videos/{videoId}')
  .onWrite((change, context) => {
    const data = change.after.data();
    if (data.userId !== data.creatorId || 
        data.userId !== data.creator_id) {
      console.error(`Inconsistent creator fields for video ${context.params.videoId}`);
    }
  });
```

## Support

If you encounter issues:
1. Check the migration logs
2. Verify field presence in Firestore Console
3. Test with a single video first
4. Contact development team with specific video IDs

## Summary

This fix ensures **cross-platform compatibility** for video creator identification by:
- Writing all field name variants on upload
- Reading with fallback support for all variants
- Migrating existing videos to include all variants

The solution is **backward compatible**, **non-breaking**, and ensures videos work correctly across mobile apps, websites, and all internal services.

