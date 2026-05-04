# ADR: Firestore and Storage rules for public beta

**Status:** Accepted for beta (documented risk)  
**Date:** 2026-04-27  
**Scope:** `firestore.rules`, `storage.rules`

## Context

Public beta requires a conscious choice between tightening security rules (with app and possibly web changes) and shipping with known broad rules plus tester-facing disclosure.

## Decisions

### 1. Firestore `users/{userId}` — `allow read: if true`

**Intent:** Public profiles and username lookup during login (comment in rules).

**Risk:** Any client can read user profile documents without authentication.

**Beta decision:** **Accept** for beta. Product assumes public profile fields only; sensitive fields must not live in this document or must be stripped server-side / moved to private subcollections.

**Post-beta:** Optional tighten to `allow read: if resource.data.visibility == 'public' || request.auth.uid == userId` (or equivalent) after auditing all readers (mobile, web, share links).

### 2. `users/{userId}/following` and `followers` — any authenticated read/write

**Intent:** Social graph and follow UX without Cloud Functions on every follow.

**Risk:** Authenticated users can write arbitrary follower/following documents under another user’s path (depending on path rules: writes are under `users/{userId}/following/{id}` where `userId` is the profile owner—verify app only writes self-owned paths; cross-user spam still possible if app bugs).

**Beta decision:** **Accept** with reliance on **client path conventions** and QA on follow/unfollow flows. Document for testers: graph integrity is best-effort at rules layer.

**Post-beta:** Restrict writes to owner or mutual operations via Functions + atomic counters.

### 3. Storage `content/**` — `allow write: if request.auth != null`

**Intent:** Fast uploads for authenticated creators.

**Risk:** Any signed-in user can write under `content/` (path not scoped to UID in rules).

**Beta decision:** **Accept** for beta **only if** app always uses unpredictable paths (e.g. UUID prefixes) and does not expose listing of arbitrary others’ private blobs. Prefer tightening to `content/{userId}/{allPaths=**}` with matching app paths before wide public launch.

### 4. Storage `chats/{chatId}/{allPaths=**}` — any authenticated read/write

**Intent:** Chat attachments.

**Risk:** Any auth user can read/write any `chatId` if IDs are guessable.

**Beta decision:** **Accept** for beta with requirement that **chat IDs are unguessable** (Firestore chat doc IDs) and attachment paths are not enumerable. **Post-beta:** `request.auth.uid in resource.metadata.participants` or metadata from Firestore-backed lookup pattern.

## One-page summary for beta testers

- **Public:** Profile fields exposed under the app’s “public profile” model may be readable without login where the product shows them (e.g. discovery, share links).
- **Private:** Treat DMs, drafts, and account-only areas as private in the **product UX**; rules are not minimal-zero-trust for every path listed above—report suspected data exposure via the in-app feedback channel.

## Review trigger

Revisit this ADR before **production** launch or if abuse is observed on staging/beta (storage fill, graph spam, profile scraping).
