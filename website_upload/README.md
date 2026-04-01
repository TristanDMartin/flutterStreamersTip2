# Website Client-Side Video Transcoding

Zero server cost. Transcode videos in the browser before upload using FFmpeg.wasm.

## Setup

```bash
npm install @ffmpeg/ffmpeg @ffmpeg/util firebase
```

## Usage (React/Next.js)

```javascript
import { initializeApp } from 'firebase/app';
import { transcodeAndUploadVideo } from './transcodeAndUpload';

const app = initializeApp(firebaseConfig);

async function handleUpload(videoFile, userId, videoId) {
  const result = await transcodeAndUploadVideo(
    videoFile,
    userId,
    videoId,
    app,
    (percent, stage) => setProgress({ percent, stage })
  );
  if (result.success) {
    // Video is ready - mp4_720_url set in Firestore
  } else {
    console.error(result.error);
  }
}
```

## Flow

1. User selects video
2. FFmpeg.wasm transcodes to 720p (H.264/AAC, 30fps) in browser
3. Upload transcoded file to `videos/{userId}/{videoId}.mp4`
4. Firestore doc updated with `mp4_720_url`, `status: 'ready'`

The Cloud Function trigger will see the upload, run a format check, and (since it's already 720p) use the file as-is without server transcoding.
