# 🚀 Deployment Instructions - Website & Mobile Sync

## Quick Summary

This deployment adds:
1. ✅ Cross-platform creator field compatibility (mobile ↔ website)
2. ✅ Cloud Functions for automatic data synchronization
3. ✅ Atomic stats operations to prevent race conditions
4. ✅ Real-time sync between all platforms

---

## 📋 Pre-Deployment Checklist

- [ ] Run migration script to fix existing videos
- [ ] Test Cloud Functions locally
- [ ] Review Firestore security rules
- [ ] Backup production database (optional but recommended)

---

## Step 1: Fix Existing Data (Migration)

### Run the Migration Script

```bash
# From project root
cd /Users/tristanmartin/Desktop/flutterST

# Install dependencies if needed
npm install firebase-admin

# Run migration
node scripts/migrate_video_creator_fields.js
```

**Expected Output:**
```
🔄 Starting video creator field migration...
📊 Found 150 videos to process
📝 Queued update for video xyz123: creatorId, creator_id
💾 Committing batch of 148 updates...

✅ Migration complete!
📊 Statistics:
   - Updated: 148 videos
   - Skipped: 2 videos
   - Errors: 0 videos
```

**Verify Migration:**
```bash
# Check Firebase Console > Firestore > videos collection
# Each video should now have:
# - userId: "..."
# - creatorId: "..."
# - creator_id: "..."
```

---

## Step 2: Deploy Cloud Functions

### Deploy Sync Functions

```bash
# Navigate to cloud functions directory
cd cloud_functions

# Install dependencies (if not already installed)
npm install

# Test functions locally (optional)
firebase emulators:start --only functions

# Deploy to production
firebase deploy --only functions
```

**Functions Being Deployed:**
- ✅ `syncVideoStatsToProfile` - Syncs video stats to user totals
- ✅ `normalizeVideoCreatorFields` - Auto-fixes creator field inconsistencies
- ✅ `syncCreatorProfileToVideos` - Updates videos when profile changes

**Expected Output:**
```
✔ functions[syncVideoStatsToProfile]: Successful create operation.
✔ functions[normalizeVideoCreatorFields]: Successful create operation.
✔ functions[syncCreatorProfileToVideos]: Successful create operation.

✔ Deploy complete!
```

**Verify Deployment:**
```bash
# List deployed functions
firebase functions:list

# Check logs
firebase functions:log
```

---

## Step 3: Deploy Mobile App Updates

### Build and Deploy Flutter App

```bash
# Navigate to project root
cd /Users/tristanmartin/Desktop/flutterST

# Run code generation (if needed)
flutter pub run build_runner build --delete-conflicting-outputs

# Test locally first
flutter run

# Build for production
flutter build apk --release  # For Android
flutter build ios --release  # For iOS
```

**Modified Files:**
- ✅ `lib/services/video_upload_service.dart` - Adds all creator field variants
- ✅ `lib/services/unified_video_service.dart` - Adds all creator field variants
- ✅ `lib/services/optimistic_video_service.dart` - Adds all creator field variants
- ✅ `lib/services/video_service.dart` - Reads from all field variants
- ✅ `lib/widgets/discover_view.dart` - Reads from all field variants
- ✅ `lib/services/atomic_stats_service.dart` - NEW: Atomic operations

---

## Step 4: Update Website

### Install Firebase SDK (if not already installed)

```bash
# Navigate to website directory
cd website  # or wherever your website code is

# Install Firebase
npm install firebase

# Or if using yarn
yarn add firebase
```

### Add Firebase Configuration

Create or update `website/src/firebase/config.js`:

```javascript
import { initializeApp } from 'firebase/app';
import { getFirestore, enableIndexedDbPersistence } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_AUTH_DOMAIN",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_STORAGE_BUCKET",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID",
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);

// Enable offline persistence
enableIndexedDbPersistence(db).catch(console.warn);
```

### Implement Real-Time Listeners

See `WEBSITE_MOBILE_SYNC_GUIDE.md` for full implementation details.

**Key Services to Add:**
1. `videoStatsService.js` - Real-time video stats
2. `userService.js` - Real-time user profiles
3. `atomicStatsService.js` - Atomic like/comment operations

### Build and Deploy Website

```bash
# Build for production
npm run build

# Deploy to Firebase Hosting (if using Firebase)
firebase deploy --only hosting

# Or deploy to your hosting provider
```

---

## Step 5: Verify Everything Works

### Test Mobile → Website Sync

1. **Upload a video from mobile app**
   ```
   ✅ Check mobile: Video appears immediately
   ✅ Check Firestore: Video has userId, creatorId, creator_id
   ✅ Check website: Video appears with creator info
   ```

2. **Like a video from mobile**
   ```
   ✅ Check mobile: Like count increments
   ✅ Check Firestore: likes field increments
   ✅ Check website: Like count updates in real-time
   ```

3. **Update profile from mobile**
   ```
   ✅ Check mobile: Profile updates
   ✅ Check Firestore: User document updates
   ✅ Check Cloud Functions logs: Videos updating
   ✅ Check website: Videos show new profile info
   ```

### Test Website → Mobile Sync

1. **Like a video from website**
   ```
   ✅ Check website: Like count increments
   ✅ Check Firestore: likes field increments
   ✅ Check mobile: Like count updates in real-time
   ```

2. **Update profile from website**
   ```
   ✅ Check website: Profile updates
   ✅ Check mobile: Profile updates in real-time
   ```

### Test Cross-Platform Real-Time Sync

1. **Open video on BOTH mobile and website**
2. **Like from mobile**
   - Website should update within 100ms
3. **Unlike from website**
   - Mobile should update within 100ms
4. **Comment from either platform**
   - Both platforms should update immediately

---

## Step 6: Monitor Performance

### Check Cloud Functions Logs

```bash
# Real-time logs
firebase functions:log --only syncVideoStatsToProfile

# Or in Firebase Console
# Functions > Logs
```

**Expected Logs:**
```
📊 Syncing stats for video abc123 to user xyz profile
✅ Synced stats for user xyz from video abc123

🔄 User xyz profile changed, updating videos...
✅ Updated 15 videos for user xyz in 1 batch(es)
```

### Monitor Firestore Usage

Check Firebase Console:
- **Firestore > Usage**
- Monitor reads/writes increase (should be minimal)
- Check for any errors

### Performance Metrics

**Expected Performance:**
- Real-time sync latency: < 100ms
- Cloud Function execution: < 1s
- No race conditions on likes/comments
- Offline changes sync when online

---

## Step 7: Update Firestore Security Rules (Optional but Recommended)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Videos collection
    match /videos/{videoId} {
      // Anyone can read published videos
      allow read: if resource.data.status == 'published';
      
      // Only creator can write
      allow create, update: if request.auth != null && 
        (request.resource.data.userId == request.auth.uid ||
         request.resource.data.creatorId == request.auth.uid ||
         request.resource.data.creator_id == request.auth.uid);
      
      // Only creator can delete
      allow delete: if request.auth != null &&
        (resource.data.userId == request.auth.uid ||
         resource.data.creatorId == request.auth.uid ||
         resource.data.creator_id == request.auth.uid);
      
      // Likes subcollection
      match /byUser/{userId} {
        allow read: if true;
        allow write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Comments subcollection
      match /comments/{commentId} {
        allow read: if true;
        allow create: if request.auth != null;
        allow update, delete: if request.auth != null && 
          resource.data.userId == request.auth.uid;
      }
    }
    
    // User liked videos
    match /users/{userId}/likedVideos/{videoId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

---

## 🎯 Success Criteria

After deployment, verify:

### Data Integrity
- [x] All videos have userId, creatorId, and creator_id fields
- [x] All three fields have identical values
- [x] No videos show "creator_id: undefined"

### Real-Time Sync
- [x] Mobile likes → Website updates in <100ms
- [x] Website likes → Mobile updates in <100ms
- [x] Profile updates propagate to all videos
- [x] Stats sync across all platforms

### Performance
- [x] No race conditions on concurrent likes
- [x] Cloud Functions execute successfully
- [x] No increase in error rates
- [x] Acceptable Firestore usage

### User Experience
- [x] Videos display correctly on all platforms
- [x] Creator info shows everywhere
- [x] Stats are accurate and synchronized
- [x] No breaking changes or regressions

---

## 🔄 Rollback Plan

If issues occur:

### Rollback Code Changes

```bash
git revert HEAD~1  # Revert last commit
flutter build apk --release  # Rebuild app
```

### Rollback Cloud Functions

```bash
# Redeploy previous version
firebase deploy --only functions --force
```

### Database Rollback

**NOT NEEDED** - The changes are additive only. Extra fields don't break anything.

---

## 📞 Troubleshooting

### Issue: Videos still show "creator_id: undefined"

**Solution:**
1. Verify migration script ran successfully
2. Check Cloud Function logs for errors
3. Manually check affected videos in Firestore Console
4. Run migration script again if needed

### Issue: Stats not syncing in real-time

**Solution:**
1. Check that real-time listeners are set up (not one-time reads)
2. Verify Cloud Functions are deployed and running
3. Check network connectivity
4. Review Firestore security rules

### Issue: Race conditions on likes

**Solution:**
1. Ensure using `FieldValue.increment()` not read-then-write
2. Use `AtomicStatsService` for all stat operations
3. Verify batch operations are atomic

### Issue: Cloud Functions timing out

**Solution:**
1. Check function execution time in logs
2. Increase timeout if needed in `firebase.json`
3. Optimize batch sizes for large updates

---

## 📚 Related Documentation

- `VIDEO_CREATOR_FIELD_SUMMARY.md` - Overview of the fix
- `WEBSITE_MOBILE_SYNC_GUIDE.md` - Detailed implementation guide
- `MIGRATION_QUICK_START.md` - Migration script guide

---

## ✅ Deployment Complete!

Once all steps are complete:

1. **Announce to team:** Cross-platform sync is live
2. **Monitor for 24 hours:** Check logs and error rates
3. **Gather feedback:** Ask users if everything works
4. **Document lessons learned:** Update this guide if needed

**Next Steps:**
- Consider standardizing on single field name in future
- Set up monitoring/alerting for sync issues
- Plan for additional cross-platform features

---

**Deployed By:** _____________  
**Deployment Date:** _____________  
**Environment:** [ ] Development [ ] Staging [ ] Production  
**Status:** [ ] Success [ ] Issues [ ] Rollback Required

