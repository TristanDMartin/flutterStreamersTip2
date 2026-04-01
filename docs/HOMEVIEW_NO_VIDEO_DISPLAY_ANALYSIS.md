# HomeView: No Videos Showing — Full Reason and Fix

## What You See
- Home feed shows **30 videos** in the list (logs: `HomeContent: Building - videos: 30`).
- The **video area is black** — no frames are rendered. Audio may or may not play.

### Common pattern: “Only one plays; scroll back = black + audio”
- **Only one video** (e.g. yours) appears / plays at first.
- When you **scroll away then scroll back** to that video: **black screen but audio plays**.
- Another video may play when you land on it; then scrolling back to *that* one again gives **black + audio**.
- So: **returning to a previously viewed video often shows no picture, only sound.** Same root cause (BAD_INDEX + surface churn + controller disposal when scrolling).

## Root Cause (Why No Frames)

Videos **are** loading and controllers **are** created (ExoPlayer Init, URL set). Rendering fails in the **Android decoder/surface pipeline** on Pixel 6 (Android 14, build 36).

### 1. **MediaCodec/Surface BAD_INDEX (Primary)**
Logs show:
```
D/Codec2Client(27806): setOutputSurface -- failed to set consumer usage (6/BAD_INDEX)
E/streamersTipApp(27806): Failed to query component interface for required system resources: 6
I/CCodecConfig(27806): query failed after returning 15 values (BAD_INDEX)
```
- The **decoder** (c2.exynos.h264.decoder) receives a Surface from Flutter’s texture.
- The first **setOutputSurface** call fails with **BAD_INDEX (6)** — the surface is rejected (invalid / wrong state / wrong consumer usage).
- A follow-up call sometimes succeeds (`setOutputSurface -- generation=... consumer usage=0x900`), but the pipeline can already be broken, so **no frames are delivered** → black screen.

### 2. **Surface Churn**
Logs show repeated:
- `connecting to surface ... reason connectToSurface`
- `disconnecting from surface ... reason connectToSurface(reconnect)`
- `connecting to surface ... reason connectToSurface(reconnect-with-listener)`
- Surface generation increments: **28473355 → 28473356 → 28473357 → 28473358 → 28473359**

So the **Surface is being disconnected and reconnected often**. That can:
- Trigger BAD_INDEX when the decoder still holds a reference to the old surface.
- Prevent stable attachment so the decoder never outputs frames.

### 3. **VideoPlayer Key Still Unstable (Code vs Doc Mismatch)**
- **SURFACE_BAD_INDEX_FIX.md** says Phase 2.1 removed `_textureRebuildTick` from the key.
- **Code** still uses: `VideoPlayer:${videoId}:${controllerId}:$_textureRebuildTick`.
- When `_textureRebuildTick` changes (e.g. first-frame watchdog Tier 2 recovery), the **VideoPlayer** widget gets a **new key** → Flutter **remounts** it → **new texture/surface** → more surface churn and BAD_INDEX risk.
- So even “recovery” can make the problem worse.

### 4. **Controller Disposal During Binding (Phase 2.3 Not Done)**
- Logs show **ExoPlayer Release** then new **Init** (e.g. Release 2c1c6f1, Init f4208f8).
- If **GlobalPlaybackManager** disposes controllers while they are still **attached** to a VideoPlayer (e.g. during preload or focus change), the surface can be torn down mid-binding → BAD_INDEX or black screen.
- Phase 2.3 (attached state + TTL in GlobalPlaybackManager) is **not** implemented yet, so disposal timing is not guarded.

### 5. **Firestore PERMISSION_DENIED (Secondary)**
- `tags` listen and `videos` write fail with PERMISSION_DENIED.
- That affects **comment count** and **writes**, not the **video URL or decoder**. So it does **not** cause the black screen, but it does add noise and can confuse debugging.

---

## Summary Table

| Factor | Effect |
|--------|--------|
| setOutputSurface BAD_INDEX | Decoder rejects surface → no frames (or audio-only) |
| Surface connect/disconnect/reconnect churn | Unstable binding → BAD_INDEX / no frames |
| Controller disposed when scrolling away | On scroll back, new controller + surface → BAD_INDEX → black + audio |
| PERMISSION_DENIED (tags/videos) | Comment/write issues only, not playback |

**“Scroll back = black + audio”:** When you return to a video you already watched, the app often creates a *new* controller (old one was disposed). The new decoder gets a new surface; first setOutputSurface fails with BAD_INDEX; follow-up may succeed for audio but video pipeline stays broken → you hear sound, no picture.

---

## How to Fix

### Fix 1: Stabilize VideoPlayer Key (Do Now)
- **Remove** `_textureRebuildTick` from the **VideoPlayer** `ValueKey`.
- Use **only** `VideoPlayer:${videoId}:${controllerId}` (and `surfaceEpoch` only when `_enableSurfaceWatchdogRecreate` is true).
- Stops unnecessary remounts and reduces surface churn. Aligns code with SURFACE_BAD_INDEX_FIX Phase 2.1.

### Fix 2: Phase 2.3 — Disposal Guards
- In **GlobalPlaybackManager**: track “attached” state (videoId → controllerId) and creation time (TTL).
- **Do not dispose** a controller that is currently attached or within TTL (e.g. 5s), unless under memory pressure.
- Call **markControllerAttached** / **markControllerDetached** from VideoPlayerViewOptimized when adopting/releasing the controller.
- Prevents disposal during surface binding and reduces BAD_INDEX from mid-binding teardown.
- **Scroll-back:** Keeping controllers alive longer (TTL + attached) means when you scroll back, the same controller/surface may still be valid → less “black + audio”.

### Fix 3: First-Frame Recovery Without Remount (Optional)
- Tier 2 recovery currently calls `_forceRemountTexture()` → `_textureRebuildTick++` → **key change** → full VideoPlayer remount.
- Either:
  - **Stop** including `_textureRebuildTick` in the key (Fix 1), and/or
  - Use **surfaceEpoch** only when the surface watchdog is enabled, so normal recovery does not change the key.
- Reduces surface churn when recovering from black screen.

### Fix 4: Firestore Rules (Separate)
- Fix **tags** read and **videos** write rules so client has permission where intended.
- Stops PERMISSION_DENIED spam; does not fix black screen.

### Fix 5: If BAD_INDEX Persists — Option B
- If after Fix 1 + 2 the Pixel 6 still shows BAD_INDEX and black screen:
  - Consider **Option B** (SURFACE_BAD_INDEX_FIX / Production Readiness Scorecard): replace the playback stack on Android with a **Media3-based** (or similar) implementation that controls **surface lifecycle** explicitly and avoids Flutter texture edge cases.

---

## Verification After Fixes
1. Run on **Pixel 6** (Android 14): open HomeView, first video should show **picture** within ~600ms.
2. **Logcat**: filter for `setOutputSurface` and `BAD_INDEX` — aim for **no** BAD_INDEX during normal scroll.
3. **Surface churn**: `connectToSurface` / `disconnect` should be **rare** (e.g. only on real controller change or app background/foreground), not on every swipe or rebuild.

---

## References
- `docs/SURFACE_BAD_INDEX_FIX.md` — Phase 2.1 key strategy, Phase 2.3 disposal guards.
- `docs/PRODUCTION_READINESS_SCORECARD.md` — Android/iOS targets, Option B.
- Terminal logs: `setOutputSurface -- failed to set consumer usage (6/BAD_INDEX)`, surface generation 28473355–28473359, ExoPlayer Init/Release.
