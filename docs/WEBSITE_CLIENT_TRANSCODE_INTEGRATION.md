# Website Client-Side Transcoding Integration

## For Cursor / Web Developers

Integrate the `website_upload/` module into the StreamersTip website (Next.js/React) so videos are transcoded in the browser before upload. **Zero server transcoding cost.**

---

## 1. Copy the Module

Copy the `website_upload/` folder from the Flutter app repo into the website project:

```
website_project/
├── website_upload/           # Copy this folder
│   ├── package.json
│   ├── transcodeAndUpload.js
│   └── README.md
├── src/
├── package.json
└── ...
```

Or, if the website is in the same monorepo: `website_upload/` already exists at the repo root.

---

## 2. Install Dependencies

In the **website project** root:

```bash
npm install @ffmpeg/ffmpeg @ffmpeg/util firebase
```

(Or add to `package.json` dependencies and run `npm install`.)

---

## 3. Add the Upload Function

Ensure Firebase is initialized in the website. Then use `transcodeAndUploadVideo`:

```javascript
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
// Adjust path based on where website_upload/ lives relative to this file
import { transcodeAndUploadVideo } from '../website_upload/transcodeAndUpload';

// Your Firebase config
const firebaseConfig = { /* ... */ };
const app = initializeApp(firebaseConfig);

async function handleVideoUpload(videoFile, videoId) {
  const auth = getAuth(app);
  const user = auth.currentUser;
  if (!user) throw new Error('User must be logged in');

  const result = await transcodeAndUploadVideo(
    videoFile,
    user.uid,
    videoId,
    app,
    (percent, stage) => {
      if (typeof setProgress === 'function') {
        setProgress({ percent, stage })
      }
    }
  );

  if (result.success) {
    // Video is ready - mp4_720_url set in Firestore by Cloud Function
    return result.mp4_720_url
  } else {
    throw new Error(result.error)
  }
}
```

---

## 4. Full Flow (Before Upload)

1. **Create Firestore doc** with `status: 'processing'` before uploading.
2. **Call transcodeAndUploadVideo** – it transcodes in browser, then uploads.
3. **Storage trigger** – Cloud Function validates format and sets `mp4_720_url`, `status: 'ready'`.

Example:

```javascript
import { getFirestore, doc, setDoc, serverTimestamp } from 'firebase/firestore';

async function publishVideo(videoFile, title, description) {
  const db = getFirestore(app);
  const auth = getAuth(app);
  const user = auth.currentUser;
  if (!user) throw new Error('Not authenticated');

  const videoId = crypto.randomUUID().replace(/-/g, '');

  // 1. Create Firestore doc (status: processing)
  await setDoc(doc(db, 'videos', videoId), {
    id: videoId,
    userId: user.uid,
    title,
    description,
    status: 'processing',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  // 2. Transcode + upload (shows progress)
  await transcodeAndUploadVideo(
    videoFile,
    user.uid,
    videoId,
    app,
    (percent, stage) => setProgress({ percent, stage })
  );

  // 3. Cloud Function runs on Storage upload, sets mp4_720_url + status=ready
  // 4. Optionally: update doc with published status, etc.
}
```

---

## 5. Progress UI

```javascript
const [progress, setProgress] = useState({ percent: 0, stage: '' });

// In your JSX:
{progress.percent > 0 && progress.percent < 100 && (
  <div>
    <progress value={progress.percent} max={100} />
    <span>{progress.stage}: {Math.round(progress.percent)}%</span>
  </div>
)}
```

Stages: `loading`, `transcoding`, `uploading`, `done`.

---

## 6. Requirements

- **Firebase:** Storage, Firestore, Auth
- **Path:** Upload to `videos/{userId}/{videoId}.mp4` (3 parts)
- **Video doc:** Must exist before upload with `status: 'processing'`
- **Browser:** FFmpeg.wasm requires modern browser (Chrome, Firefox, Safari)

---

## 7. File Reference

| File | Purpose |
|------|---------|
| `website_upload/transcodeAndUpload.js` | Main export: `transcodeAndUploadVideo()` |
| `website_upload/package.json` | Dependencies |

---

## 8. Troubleshooting

- **"FFmpeg not found"** – Ensure `@ffmpeg/ffmpeg` and `@ffmpeg/util` are installed.
- **Slow transcoding** – Expected for large files; show progress.
- **Upload fails** – Check Firebase Storage rules; path must be `videos/{userId}/{videoId}.mp4`.
- **Video not in feed** – Cloud Function must set `mp4_720_url` and `status: 'ready'`; check Firestore.
