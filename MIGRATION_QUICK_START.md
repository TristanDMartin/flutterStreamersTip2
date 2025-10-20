# Quick Start: Video Creator Field Migration

## 🚀 Run the Migration NOW

### Option 1: Using Node.js (Recommended - Faster)

```bash
# 1. Install dependencies (if not already installed)
cd /Users/tristanmartin/Desktop/flutterST
npm install firebase-admin

# 2. Ensure you have service-account-key.json
# (Download from Firebase Console > Project Settings > Service Accounts)

# 3. Run the migration
node scripts/migrate_video_creator_fields.js
```

### Option 2: Using Firebase CLI

If you don't have a service account key:

```bash
# 1. Login to Firebase
firebase login

# 2. Use Firebase Shell
firebase functions:shell

# 3. Run this code in the shell:
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

db.collection('videos').get().then(async (snapshot) => {
  console.log(`Found ${snapshot.docs.length} videos`);
  const batch = db.batch();
  let count = 0;
  
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const userId = data.userId || data.creatorId || data.creator_id;
    if (userId && (!data.creatorId || !data.creator_id)) {
      batch.update(doc.ref, {
        userId: userId,
        creatorId: userId,
        creator_id: userId
      });
      count++;
    }
  });
  
  if (count > 0) {
    await batch.commit();
    console.log(`✅ Updated ${count} videos`);
  }
});
```

## 🔍 Verify the Fix

### Check a Specific Video (e.g., smove50's videos)

Using Firebase Console:
1. Go to Firestore Database
2. Open `videos` collection
3. Find a video that previously had `creator_id: undefined`
4. Verify it now has all three fields:
   - `userId: "some-uid"`
   - `creatorId: "some-uid"` 
   - `creator_id: "some-uid"`

### Check All Videos

Run this query in Firebase Console:

```javascript
// Click "Run Query" in Firestore Console
db.collection('videos').where('creator_id', '==', null).get()
```

Should return **0 results** after migration.

## 📱 Test the Mobile App

1. **Upload a new video**
   - Open the app
   - Upload any test video
   - Check Firestore to verify it has all three fields

2. **View existing videos**
   - Check home feed
   - Check profile view
   - All videos should display with creator info

## 🌐 Test the Website

1. **Visit the website**
2. **Check video feed**
   - Videos should show creator names
   - No more `creator_id: undefined` errors
3. **Check user profiles**
   - User's videos should display correctly

## ⚡ Quick Migration (One-Liner)

If you have Firebase CLI and want to run it quickly:

```bash
node -e "const admin = require('firebase-admin'); const app = admin.initializeApp({credential: admin.credential.cert(require('./service-account-key.json'))}); const db = admin.firestore(); db.collection('videos').get().then(async s => { const b = db.batch(); let c = 0; s.docs.forEach(d => { const v = d.data(); const u = v.userId || v.creatorId || v.creator_id; if (u && (!v.creatorId || !v.creator_id)) { b.update(d.ref, { userId: u, creatorId: u, creator_id: u }); c++; } }); await b.commit(); console.log(\`✅ Updated \${c} videos\`); process.exit(0); });"
```

## 📊 Expected Output

```
🔄 Starting video creator field migration...
📊 Found 150 videos to process
✅ Video abc123 already has all creator fields, skipping
📝 Queued update for video def456: creatorId, creator_id
📝 Queued update for video ghi789: creatorId, creator_id
💾 Committing batch of 148 updates...

✅ Migration complete!
📊 Statistics:
   - Updated: 148 videos
   - Skipped: 2 videos
   - Errors: 0 videos
   - Total processed: 150 videos
```

## ❌ Troubleshooting

### Error: "Cannot find module 'firebase-admin'"
```bash
npm install firebase-admin
```

### Error: "Service account key not found"
1. Go to Firebase Console
2. Project Settings > Service Accounts
3. Click "Generate New Private Key"
4. Save as `service-account-key.json` in project root

### Error: "Permission denied"
- Ensure your service account has Firestore write permissions
- Check Firebase security rules

## 🎯 Success Criteria

After migration, verify:
- ✅ All videos have `userId`, `creatorId`, and `creator_id` fields
- ✅ All three fields have the same value for each video
- ✅ Website displays creator names correctly
- ✅ Mobile app continues to work normally
- ✅ New video uploads include all three fields

## 📞 Need Help?

Check the full documentation: `VIDEO_CREATOR_FIELD_FIX.md`

