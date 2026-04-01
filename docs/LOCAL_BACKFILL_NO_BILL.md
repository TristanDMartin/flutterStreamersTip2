# Process Existing Videos – Zero Cloud Cost

Ways to get videos without `mp4_720_url` into the feed **without** paying for server transcoding.

---

## Option 1: Local Script (Recommended)

Run transcoding on your machine. No cloud compute cost.

### Prerequisites

- Node.js 18+
- FFmpeg installed locally: `brew install ffmpeg` (macOS) or [ffmpeg.org](https://ffmpeg.org/download.html)
- Firebase service account key (JSON)
  - Firebase Console → Project Settings → Service Accounts → Generate new private key

### Setup

```bash
cd cloud_functions
npm install
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your-service-account-key.json"
```

### Run

```bash
cd cloud_functions
node scripts/local_backfill.js --limit 10 --dry-run
```

- `--dry-run` – List videos only, no transcode
- `--limit N` – Process at most N videos (default: 10)
- Omit `--dry-run` to transcode and upload

### Cost

- **Cloud:** $0 (compute runs on your machine)
- **Storage:** Normal upload and storage costs
- **Bandwidth:** Your download/upload for originals and 720p files

---

## Option 2: Browser-Based Admin Page

Add an admin page that uses FFmpeg.wasm to process videos one by one in the browser.

- **Cost:** $0
- **Pros:** No local setup
- **Cons:** Slower, user must keep the tab open

(Implementation details in `WEBSITE_CLIENT_TRANSCODE_INTEGRATION.md` – you’d iterate over videos and call `transcodeAndUploadVideo` for each.)

---

## Option 3: Cheap VPS ($5–20 One-Time)

- Rent a small VPS for a few hours
- Run a script similar to the local one
- **Cost:** ~$5–20 for a short batch
- **Pros:** No local setup, can run unattended

---

## Option 4: Skip Transcoding for Compatible Originals

If originals are already H.264/AAC and ≤1080p, the Cloud Function can accept them.

- **Action:** Re-upload the same file to `videos/{userId}/{videoId}.mp4`
- **Cost:** Storage trigger only (format check), ~$0
- **Notes:** Not for videos that need transcoding.

---

## Recommended: Local Script

1. Use `cloud_functions/scripts/local_backfill.js`.
2. Run with `--dry-run` first to inspect.
3. Run without `--dry-run` with `--limit 5` to test.
4. Process the rest in batches.
