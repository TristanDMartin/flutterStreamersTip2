# Phase B device validation — camera → publish release candidate

Status: **feature-complete in code; waiting on device certification**.  
Do not change architecture again unless device testing exposes a real defect.  
Do **not** mark Phase B production-ready, and do **not** unfreeze Phase C, until the binary gate below is PASS.

## Binary release decision

**PASS** — every happy path reaches `MUX_WEBHOOK_READY` → canonical feed-ready → live toast → automatic Home / Profile / web visibility, with no refresh and no duplicate document.

**FAIL** — any of:
- an invalid artifact reaches Mux
- Processing can hang indefinitely
- reopening creates a second job
- one surface misses the video
- the app can locally forge READY

Only on **PASS**: formally mark **Phase B — Production Ready**, then unfreeze Phase C exactly as planned: Tippy ASR → caption track → timing editor → styles → entitlements → word highlight.

## Artifact / publish contract

```
camera_original        may be temporary (camera cache path).
camera_durable_copy    is the canonical recording artifact.
Draft / editor / render stages may derive from the durable copy.
Publish may only consume an audited, readable MP4.
Only Mux / webhook may set Firestore feed-ready (isReadyForFeed).
```

Strict pre-Mux audit (not size-alone): file exists, size is non-trivial
(`>= 50KB` **and** bytes/sec floor), MP4 `ftyp` present, container opens via
`VideoPlayer`, and duration is sane (`>= 1s`, `<= 5min`). Corrupt stubs
(e.g. 8.4KB) must die before Mux.

## Happy-path log sequence (approx)

```
RECORD_START_PREPARED
RECORD_STOP_COMPLETE
ARTIFACT_AUDIT stage=camera_original ... ok=true sizeBytes=<realistic>
ARTIFACT_AUDIT stage=camera_durable_copy ok=true sizeBytes=<realistic>
DRAFT_ARTIFACT_AUDIT ok=true
PUBLISH_ARTIFACT_SELECTED ...
MUX_UPLOAD_STARTED
MUX_UPLOAD_COMPLETE
PROCESSING / MUX_PROCESSING
MUX_WEBHOOK_READY
PLAYBACK_READY=true
IS_READY_FOR_FEED=true
LIVE_TOAST_SHOWN
```

Video must appear on Home + Profile + web **without refresh** (same Firestore doc).

## Camera / lifecycle E2E matrix (tougher than one short clip)

Run on **Android** and **iOS**:

- [ ] Record 3–5 seconds (rear)
- [ ] Record ~30 seconds (rear)
- [ ] Front camera record
- [ ] Rear camera record
- [ ] Record → retake → record again
- [ ] Record after hot restart
- [ ] Full path: camera → edit (optional trim/text) → Share → Uploading % → Processing → LIVE toast → feeds

## Failure matrix

- [ ] ~8KB / incomplete artifact rejected before Mux (`ARTIFACT_AUDIT` / `DRAFT_ARTIFACT_AUDIT ok=false`)
- [ ] Mux failed → terminal user-visible failure (not endless Processing)
- [ ] Reopen app mid-Processing attaches to the same video/job
- [ ] Repeated webhook / app events never create a duplicate video

## Permanent publish rule (editor)

```
hasBakedEdits == true  → publish MUST use renderedFile
hasBakedEdits == false → original/durable source may be uploaded
```

There is **no** silent fallback of `render failed → upload original`.  
On render failure the Share screen shows a recoverable error with **Retry render**.

## Editor / render checks

### Android

- [ ] Camera → record → Trim → Text → Cover → Share
- [ ] FFmpeg render completes (UI shows “Rendering your edits…”)
- [ ] Rendered file uploads (not the untouched source)
- [ ] Published playback shows exact trim + burned text
- [ ] Cover/thumbnail matches selection

### iOS

- [ ] Same flow as Android end-to-end

### Gallery

- [ ] Import → same VideoDraft/editor
- [ ] Trim + text → render → upload
- [ ] Published result matches edits

### Draft recovery

- [ ] Create edits → kill app → reopen camera
- [ ] Resume draft → edits preserved
- [ ] Render/publish still works

### FFmpeg / device pressure

- [ ] Render time acceptable for ~15–60s clips
- [ ] Temp storage under `VideoDrafts/` / cache does not grow unboundedly
- [ ] Memory pressure during render (especially Android)
- [ ] Background app during render (job completes or fails clearly)
- [ ] Render failure → Retry (no original upload)
- [ ] Cancel / leave Share during render does not orphan a bad publish
- [ ] Note binary size delta from `ffmpeg_kit_flutter_new` on Android + iOS

## After certification

On **PASS** only: mark Phase B production-ready, then unfreeze Phase C in order
(Tippy ASR → caption track → timing editor → styles → entitlements → word highlight).
Do not mix unrelated hardening into that pass.
