# Storage Permissions Fix

## Problem
Videos are showing 403 (Forbidden) errors because the transcoded 720p/480p files are not publicly accessible.

## Solution Applied
Updated `uploadVariant` function to call `makePublic()` after uploading files.

## Status
✅ **Fix deployed** - New videos will have public 720p/480p files
⚠️ **Existing videos** - Their 720p/480p files are still private and need to be made public

## Making Existing Files Public

### Option 1: Firebase Console (Easiest)
1. Go to Firebase Console > Storage
2. Navigate to `videos/{userId}/` folders
3. Find files ending in `_720p.mp4` and `_480p.mp4`
4. For each file:
   - Click on the file
   - Click "Get Link" or edit permissions
   - Make sure it's set to "Public"

### Option 2: Use gsutil (Fastest for bulk)
```bash
# Make all 720p files public
gsutil -m acl ch -u AllUsers:R gs://streamerstip-6cfdb.firebasestorage.app/videos/**/*_720p.mp4

# Make all 480p files public  
gsutil -m acl ch -u AllUsers:R gs://streamerstip-6cfdb.firebasestorage.app/videos/**/*_480p.mp4
```

### Option 3: Wait for Re-transcoding
The backfill function could be re-run, but it would re-transcode all videos (takes time).

## Next Steps
- New videos uploaded will automatically have public 720p/480p files
- Existing videos need their files made public (see options above)

