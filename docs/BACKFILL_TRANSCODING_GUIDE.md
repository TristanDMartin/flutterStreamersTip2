# Backfill Video Transcoding Guide

**Purpose:** Transcode existing videos to 720p and 480p for low-memory device compatibility.

---

## Overview

The `backfillVideoTranscoding` Cloud Function processes existing videos that don't have multi-resolution variants yet. It:

- Finds published videos without `mp4_720_url` or `mp4_480_url` fields
- Processes them in batches (to avoid timeouts)
- Downloads, transcodes, uploads, and updates Firestore
- Skips videos that are already transcoded
- Handles errors gracefully (continues processing other videos)

---

## Deployment

1. **Deploy the function:**
   ```bash
   cd cloud_functions
   firebase deploy --only functions:backfillVideoTranscoding
   ```

2. **Wait for deployment to complete** (usually 2-5 minutes)

---

## Usage

### Test Run (Dry Run)

First, test which videos will be processed:

```bash
# Get the function URL from Firebase Console or:
# https://us-central1-<PROJECT_ID>.cloudfunctions.net/backfillVideoTranscoding

curl "https://us-central1-<PROJECT_ID>.cloudfunctions.net/backfillVideoTranscoding?dryRun=true&limit=10"
```

This returns a list of videos that would be processed without actually transcoding them.

### Process Videos (Small Batch First)

Process 5 videos to test:

```bash
curl "https://us-central1-<PROJECT_ID>.cloudfunctions.net/backfillVideoTranscoding?batchSize=5&limit=10"
```

### Process More Videos

After verifying the small batch works:

```bash
# Process 10 videos at a time, up to 100 total
curl "https://us-central1-<PROJECT_ID>.cloudfunctions.net/backfillVideoTranscoding?batchSize=10&limit=100"
```

### Process All Videos (Multiple Runs)

Since the function has a timeout limit, process videos in multiple runs:

```bash
# Run 1: Process first 10 videos
curl "https://us-central1-<PROJECT_ID>.cloudfunctions.net/backfillVideoTranscoding?batchSize=10&limit=10"

# Wait for completion, then run 2: Process next 10 videos
curl "https://us-central1-<PROJECT_ID>.cloudfunctions.net/backfillVideoTranscoding?batchSize=10&limit=10"

# Continue until all videos are processed
```

---

## Query Parameters

- **`batchSize`** (optional, default: 10): Number of videos to process in this run
- **`limit`** (optional, default: 100): Maximum number of videos to query from Firestore
- **`dryRun`** (optional, default: false): If `true`, only returns which videos would be processed (no transcoding)

---

## Response Format

### Success Response:
```json
{
  "success": true,
  "summary": {
    "totalFound": 25,
    "processed": 10,
    "succeeded": 9,
    "failed": 1
  },
  "errors": [
    {
      "videoId": "abc123",
      "error": "Video file not found in Storage"
    }
  ],
  "message": "Processed 10 videos. 9 succeeded, 1 failed."
}
```

### Dry Run Response:
```json
{
  "success": true,
  "dryRun": true,
  "videosFound": 25,
  "videos": [
    {
      "id": "video1",
      "userId": "user1",
      "videoUrl": "https://..."
    }
  ]
}
```

---

## What Happens to Each Video

1. **Mark as processing**: Sets `transcodingStatus: 'processing'` in Firestore
2. **Download original**: Downloads the original video file from Storage
3. **Transcode**: Generates 720p and 480p variants using FFmpeg
4. **Upload variants**: Uploads variants to Storage at:
   - `videos/{userId}/{videoId}_720p.mp4`
   - `videos/{userId}/{videoId}_480p.mp4`
5. **Update Firestore**: Sets:
   - `mp4_1080_url`: Original video URL
   - `mp4_720_url`: 720p variant URL
   - `mp4_480_url`: 480p variant URL
   - `videoUrl`: Updated to 720p (for backward compatibility)
   - `videoURL`: Updated to 720p (alternative field name)
   - `transcodingStatus`: `'completed'`
6. **Cleanup**: Removes temporary files

---

## Error Handling

- Videos that fail are marked with `transcodingStatus: 'failed'` and `transcodingError: <error message>`
- The function continues processing other videos even if one fails
- Errors are returned in the response so you can see which videos failed

Common errors:
- **Video file not found**: The video file doesn't exist in Storage (might have been deleted)
- **Invalid video format**: The video file is corrupted or in an unsupported format
- **Timeout**: Video is too large or processing takes too long (try smaller batchSize)

---

## Monitoring

1. **Check Firebase Console** → Cloud Functions → `backfillVideoTranscoding` → Logs
2. **Check Firestore**: Videos will have `transcodingStatus` field set to `'completed'` or `'failed'`
3. **Check Storage**: New files will appear at `videos/{userId}/{videoId}_720p.mp4` and `videos/{userId}/{videoId}_480p.mp4`

---

## Cost Considerations

- **Cloud Functions**: Charged per invocation and execution time (9-minute timeout per video)
- **Storage**: Original videos are not duplicated, only variants are stored (additional storage cost)
- **FFmpeg processing**: Uses 2GB memory, which costs more than standard functions

**Estimated cost per video:**
- Small video (50MB): ~$0.01-0.02
- Medium video (200MB): ~$0.05-0.10
- Large video (500MB): ~$0.15-0.30

**Tip:** Process videos in smaller batches during off-peak hours to spread out costs.

---

## Best Practices

1. **Start small**: Test with `batchSize=1` first
2. **Monitor logs**: Watch the Firebase Console logs during first run
3. **Check results**: Verify a few videos in Firestore to ensure URLs are set correctly
4. **Process in batches**: Don't process all videos at once (use `limit` parameter)
5. **Handle failures**: Check the `errors` array in the response and manually fix problematic videos if needed

---

## Troubleshooting

### Function times out
- Reduce `batchSize` (try 1 or 2)
- Some videos might be too large - skip them and process smaller videos first

### Video file not found
- Check if the video file exists in Storage
- The function tries multiple path formats, but some videos might have unusual paths
- You may need to manually update these videos

### All videos fail
- Check if FFmpeg is properly installed (should be automatic with `@ffmpeg-installer/ffmpeg`)
- Check Cloud Functions logs for more details
- Verify Storage permissions

### Videos are skipped
- Videos with `transcodingStatus: 'completed'` are automatically skipped
- Videos without `videoUrl` or `videoURL` fields are skipped
- Only `status='published'` videos are processed

---

## Next Steps

After backfilling:
1. Verify videos in the app play correctly
2. Monitor for any playback issues
3. Consider setting up a scheduled function to periodically check for new videos that need transcoding
4. Remove the backfill function once all videos are processed (optional)

