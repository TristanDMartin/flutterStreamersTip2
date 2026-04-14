# Avatar system: web, Firestore, and mobile

This document describes how profile avatars are stored, how the website updates everywhere immediately after upload, and what the mobile app should do to stay in sync globally.

---

## Source of truth

| Location | Role |
|----------|------|
| **`users/{uid}`** (Firestore) | Canonical profile. Avatar fields: `avatarURL`, `avatarUrl` (duplicate casing for compatibility), optional `avatarPath`, `avatarUpdatedAt`, `updatedAt`. |
| **`publicUsers/{uid}`** (Firestore) | Denormalized public profile used for feeds, discovery, and lightweight reads. Includes `avatarUrl`. |
| **Cloudflare R2** (via upload worker) | Binary image storage. The public HTTPS URL returned after upload is what gets written to Firestore. |

The mobile app and the website both rely on the **same Firestore documents**. There is no separate "mobile avatar API"—if both clients read `users` / `publicUsers` and listen for updates, avatars stay aligned everywhere.

---

## Upload flow (profile / edit profile)

1. **Auth**  
   The signed-in user must match the profile being edited (`auth.currentUser.uid === userId`). See `uploadProfileAvatar` in `services/profileEditService.js`.

2. **Upload**  
   The image is sent to **Cloudflare R2** through the media upload path (`uploadToR2` in `services/r2Service.ts`):  
   - Production: worker base URL + `/api/media/upload` with `Authorization: Bearer <Firebase ID token>` and `X-Upload-Type: avatar`.  
   - Development: same shape via the Next.js API route (`getApiUrl('/api/media/upload')`).  

   Validation: image type, max size **5MB** (enforced in `uploadProfileAvatar`).

3. **Persist URL in Firestore**  
   After upload, the client writes to **`users/{uid}`**:
   - `avatarURL` and `avatarUrl` = public URL from R2  
   - `avatarPath` cleared when using direct URL (`null`)  
   - `avatarUpdatedAt`, `updatedAt` = server timestamps  

4. **Public profile mirror**  
   `syncPublicUser(uid)` in `services/publicUserSyncService.ts` updates **`publicUsers/{uid}`** with `avatarUrl` (and display name, username, etc.) so listings and other UIs do not need to read the full `users` document for every avatar.

5. **Google sign-in avatars**  
   If the profile photo comes from Google, `services/googleAvatarService.ts` can copy it to R2 and then apply the same Firestore fields as a manual upload.

---

## How the website updates “globally” (instant + durable)

### 1. Instant UI (same tab / session)

`utils/avatarStore.ts` is a **singleton in-memory cache** plus **localStorage** persistence and cross-tab `storage` events.

- After a successful upload, `EditProfileView` calls **`updateAvatarInstantly(userId, url)`**, which calls `avatarStore.updateAvatar(...)`.
- **`UserAvatar`** (`components/UserAvatar.tsx`) **subscribes** to `avatarStore` for that `userId`. When the cache updates, every mounted avatar for that user refreshes without waiting on Firestore round-trips.
- Other entry points (e.g. header, inbox, profile page) also push known URLs into `avatarStore` when they load `publicUsers` data so the cache stays warm.

This matches the intended behavior described in code comments: *instant propagation across the site like common social apps*.

### 2. Durable sync (all tabs, other devices, mobile)

- **Firestore listeners** on `users` / `publicUsers` (and hooks/services that refetch) pick up the new `avatarURL` / `avatarUrl` / `avatar_url` as soon as the write commits.
- **`publicUsers`** keeps feed and discovery UIs consistent with a small, stable document.
- The **mobile app** should:
  - Use **real-time listeners** (or periodic refetch) on `users/{uid}` and/or `publicUsers/{uid}` for the current user and any visible authors.
  - Prefer the same field precedence as the web: `avatarURL` / `avatarUrl` / `avatar_url`, then optional `avatarPath` resolution if you still support legacy paths.

After upload, the web toast copy notes that changes sync to the mobile app—meaning **Firestore is updated**; the native app must subscribe to those documents to reflect changes.

---

## Website Avatar Contract (Quick)

Use this as the minimum implementation contract for website parity with mobile.

1. **Write targets**
   - Write avatar updates to `users/{uid}`.
   - Mirror avatar updates to `publicUsers/{uid}`.

2. **Required fields**
   - Write `avatarURL`, `avatarUrl`, `avatarUpdatedAt`, `updatedAt`.
   - If using direct URL uploads, clear legacy `avatarPath` (`null`).

3. **Upload path**
   - Upload image bytes to the R2 worker media endpoint.
   - Send `Authorization: Bearer <Firebase ID token>`.
   - Send `X-Upload-Type: avatar`.

4. **Read precedence**
   - Resolve avatar URL in this order:
     - `avatarURL`
     - `avatarUrl`
     - `avatar_url`
     - then legacy fallbacks such as `avatarPath`/older image fields if supported.

5. **Real-time sync expectation**
   - Use real-time listeners (or equivalent frequent refetch) on:
     - `users/{uid}` for current user/profile.
     - `publicUsers/{uid}` for feed/discovery/list surfaces.

---

## Key files (reference)

| Area | File(s) |
|------|---------|
| Upload + Firestore write | `services/profileEditService.js` (`uploadProfileAvatar`) |
| R2 upload | `services/r2Service.ts` (`uploadToR2`) |
| `publicUsers` sync | `services/publicUserSyncService.ts` (`syncPublicUser`) |
| Global in-app cache | `utils/avatarStore.ts`, `updateAvatarInstantly` |
| Avatar UI | `components/UserAvatar.tsx`, `components/EditProfileView.tsx` |
| Google avatar copy | `services/googleAvatarService.ts` |
| Hook variant | `hooks/useAvatar.ts` (same Firestore fields after R2 upload) |

---

## Operational notes

- **Static export / hosting**: Client-side Firestore updates require **valid Firebase Auth** and **Firestore security rules** allowing the user to write their own `users/{uid}` document (and any rules for `publicUsers` you enforce).
- **Caching**: Browsers may cache images by URL; changing the stored URL (new upload) avoids stale images. `avatarUpdatedAt` helps clients decide when to bust local caches if needed.
- **Legacy docs**: Older notes in the repo may mention Firebase Storage paths; current upload path is **R2 + worker** as implemented in `r2Service.ts` and `profileEditService.js`.

---

## Quick checklist for mobile parity

1. On avatar change: upload → receive HTTPS URL → **`updateDoc` on `users/{uid}`** with the same fields as the web (or call a shared backend if you centralize writes later).  
2. Mirror to **`publicUsers/{uid}`** if the app shows lists that read from that collection.  
3. Subscribe to **`users/{uid}`** or **`publicUsers/{uid}`** so other sessions and the website show the same avatar without a separate sync channel.  
4. Optionally mirror the **instant** pattern with an in-memory store keyed by `uid` so list screens update immediately after upload.
