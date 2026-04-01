# Avatar Upload: App & Website Sync

Unified avatar upload and sync between the Flutter app and website. Both platforms use the same Cloudflare Worker and R2 storage; Firestore is the single source of truth.

---

## Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────┐
│  Flutter App    │     │  Cloudflare Worker    │     │  R2 Bucket  │
│  or Website    │────▶│  POST /media/upload   │────▶│  avatars/   │
└─────────────────┘     └──────────────────────┘     └─────────────┘
         │                            │                        │
         │                            │                        │
         ▼                            ▼                        │
┌─────────────────┐                  │                        │
│  Firestore      │◀─────────────────┴────────────────────────┘
│  users/{uid}    │   Worker returns URL; client updates doc
│  avatarURL      │
└─────────────────┘
         │
         │  Real-time listener (both app & website)
         ▼
   Avatar displays everywhere
```

---

## Upload API (Shared)

### Endpoint

```
POST https://streamerstip-mux-api.streamerstip.workers.dev/media/upload
```

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer <firebase_id_token>` |
| `X-Upload-Type` | No | `avatar` (default) or `chat` |
| `Content-Type` | Auto | `multipart/form-data` |

### Request Body

- **Form field**: `file` — image file (JPEG, PNG, GIF for chat)
- **Max size**: 5 MB (avatar), 10 MB (chat)

### Response

```json
{ "url": "https://pub-xxx.r2.dev/avatars/{uid}/{timestamp}.jpg" }
```

### Errors

| Status | Meaning |
|--------|---------|
| 401 | Missing or invalid Firebase token |
| 400 | Missing file in form data |
| 413 | File too large |
| 503 | `MEDIA_PUBLIC_BASE_URL` not configured |

---

## App Implementation (Flutter)

### Flow

1. User selects image → `EditProfileView` or `AuthService.uploadAvatar`
2. `R2MediaService.uploadAvatar(file)` → POST to Worker with `X-Upload-Type: avatar`
3. Worker uploads to R2, returns public URL
4. `AuthService` updates Firestore: `users/{uid}.avatarURL = url`
5. `ProfileUpdateService` notifies listeners; UI refreshes

### Code Locations

| Component | Path |
|-----------|------|
| Upload service | `lib/services/r2_media_service.dart` |
| Auth integration | `lib/services/auth_service.dart` → `uploadAvatar()` |
| Profile edit UI | `lib/widgets/edit_profile_view.dart` |
| Worker URL | `https://streamerstip-mux-api.streamerstip.workers.dev` |

### Example (Flutter)

```dart
final url = await R2MediaService.instance.uploadAvatar(imageFile);
await FirebaseFirestore.instance.collection('users').doc(uid).update({
  'avatarURL': url,
  'updatedAt': FieldValue.serverTimestamp(),
});
```

---

## Website Implementation

### Flow

1. User selects image in profile/settings
2. Call Worker `POST /media/upload` with `FormData` and Firebase ID token
3. Worker returns `{ url }`
4. Update Firestore `users/{uid}` with `avatarURL` and `updatedAt`
5. UI reads from Firestore or local state; real-time listener updates when changed elsewhere

### Example (JavaScript/TypeScript)

```typescript
async function uploadAvatar(file: File): Promise<string> {
  const user = auth.currentUser;
  if (!user) throw new Error('Not authenticated');
  const token = await user.getIdToken(true);

  const formData = new FormData();
  formData.append('file', file);

  const res = await fetch(
    'https://streamerstip-mux-api.streamerstip.workers.dev/media/upload',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'X-Upload-Type': 'avatar',
      },
      body: formData,
    }
  );

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || `Upload failed: ${res.status}`);
  }

  const { url } = await res.json();
  await updateDoc(doc(db, 'users', user.uid), {
    avatarURL: url,
    updatedAt: serverTimestamp(),
  });
  return url;
}
```

---

## Firestore Schema

### users collection

| Field | Type | Description |
|-------|------|-------------|
| `avatarURL` | string | Public URL of avatar (R2 or legacy Firebase) |
| `updatedAt` | timestamp | Last profile update |

Both app and website must write `avatarURL` when uploading. Use the same field name for cross-platform sync.

---

## Sync Mechanism

### Source of Truth

- **Firestore** `users/{userId}.avatarURL` is the single source of truth.
- App and website both **write** to Firestore after a successful upload.
- Both **listen** to Firestore for real-time updates (e.g. when the other platform changes the avatar).

### App → Website

- App uploads via Worker → updates Firestore.
- Website uses `onSnapshot(doc(db, 'users', uid))` (or equivalent) to react to `avatarURL` changes.

### Website → App

- Website uploads via Worker → updates Firestore.
- App uses `FirebaseFirestore.instance.collection('users').doc(uid).snapshots()` (e.g. via `ProfileUpdateService` or `UnifiedAvatarService`) to react to changes.

### Legacy WebsiteSyncService

- `lib/services/website_sync_service.dart` uses an older pattern (base64 + custom API).
- Prefer the shared Worker + Firestore flow above. The Worker is the canonical upload endpoint for both platforms.

---

## R2 Storage Layout

| Path | Purpose |
|------|---------|
| `avatars/{uid}/{timestamp}.jpg` | User avatars |
| `avatars/{uid}/{timestamp}.png` | PNG avatars |
| `chat/{uid}/{timestamp}.gif` | Chat GIFs |

- `uid`: Firebase Auth UID
- `timestamp`: `Date.now()` at upload time
- Extension: `.jpg`, `.png`, or `.gif` based on `Content-Type`

---

## CORS

The Worker allows:

- `https://www.streamerstip.com`
- `https://streamerstip.com`
- `http://localhost:3000`
- `http://localhost:5173`

Add other origins in `cloudflare_workers/mux/src/index.js` → `ALLOWED_ORIGINS` if needed.

---

## Environment & Secrets

### Worker (Cloudflare)

| Secret | Purpose |
|--------|---------|
| `MEDIA_PUBLIC_BASE_URL` | R2 public URL (e.g. `https://pub-xxx.r2.dev`) — no trailing slash |
| `FIREBASE_WEB_API_KEY` | For verifying Firebase ID tokens |

### R2 Bucket

- Name: `streamerstip-media`
- Public access: Enable Public Development URL or use Custom Domain (`media.streamerstip.com`)

---

## Validation (Both Platforms)

Before upload:

- File exists and is readable
- Size ≤ 5 MB (avatar) or 10 MB (chat)
- User is authenticated
- Valid Firebase ID token

---

## Checklist for Website Parity

- [ ] Website uses `POST /media/upload` (same Worker as app)
- [ ] Website sends `Authorization: Bearer <id_token>` and `X-Upload-Type: avatar`
- [ ] Website updates Firestore `users/{uid}.avatarURL` after upload
- [ ] Website listens to Firestore for `avatarURL` changes (app → website sync)
- [ ] CORS includes website origin in Worker `ALLOWED_ORIGINS`
