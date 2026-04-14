# Gamification — Web & HTTP API Documentation

This document describes how **StreamersTip web** (or any browser client) integrates with **trusted gamification events**, the **Cloudflare Worker** (recommended), optional **Firebase HTTPS**, and **Firestore** data the UI reads.

**Architecture principle:** Prefer the **Cloudflare Worker** for `POST /gamification/events`. Use **Firebase Cloud Functions** only if you explicitly need them. The mobile app uses the same HTTP contract.

---

## Table of contents

1. [Overview](#overview)
2. [Endpoints & base URLs](#endpoints--base-urls)
3. [Authentication](#authentication)
4. [HTTP API — `POST /gamification/events`](#http-api--post-gamificationevents)
5. [CORS (browser)](#cors-browser)
6. [Idempotency](#idempotency)
7. [Firestore — backend writes](#firestore--backend-writes)
8. [Firestore — UI reads (`users/{uid}`)](#firestore--ui-reads-usersuid)
9. [Event `type` strings](#event-type-strings)
10. [Web client example (JavaScript)](#web-client-example-javascript)
11. [Errors & status codes](#errors--status-codes)
12. [Testing with `curl`](#testing-with-curl)
13. [Operations checklist](#operations-checklist)
14. [Troubleshooting](#troubleshooting)
15. [Related files in this repo](#related-files-in-this-repo)

---

## Overview

| Piece | Role |
|-------|------|
| **Client (web app)** | User signs in with **Firebase Auth**. After a **real** product action (e.g. publish), the client sends a **trusted event** to the Worker with a **fresh ID token** and a **unique `eventId`**. |
| **Cloudflare Worker** | Verifies the token, validates JSON, enforces `uid` match, **idempotently** creates `gamification_events/{eventId}`, applies **mission progress + XP** to `users/{uid}`, writes **audit** docs. |
| **Firestore** | Source of truth for **XP**, **missions**, **gamification summary**. Web UI reads `users/{uid}` (and optionally listens in real time). |

The client **does not** compute XP or mission completion; the **server** does.

---

## Endpoints & base URLs

### Recommended: Cloudflare Worker

- **Origin (example):** `https://streamerstip-mux-api.streamerstip.workers.dev`
- **Path:** `/gamification/events`
- **Full URL:**  
  `https://streamerstip-mux-api.streamerstip.workers.dev/gamification/events`

### Optional: Firebase HTTPS (same JSON body, different path)

- **Full function URL (example pattern):**  
  `https://<REGION>-<PROJECT_ID>.cloudfunctions.net/gamificationEvents`  
- The Firebase handler is a **single function URL** — **do not** append `/gamification/events` (Flutter’s `GamificationEventService` uses the full `cloudfunctions.net` URL as-is).

---

## Authentication

Every request must include:

```http
Authorization: Bearer <Firebase_ID_token>
Content-Type: application/json
```

Obtain the ID token after sign-in:

- **Firebase Web SDK:** `const token = await firebase.auth().currentUser.getIdToken(/* forceRefresh */ false)`
- Token must be **non-expired**. Refresh if needed (`getIdToken(true)`).

The Worker verifies the token with Firebase (**Web API key** + Identity Toolkit). The JSON body must include **`uid`** exactly equal to the authenticated user’s UID (`sub` / `localId`).

---

## HTTP API — `POST /gamification/events`

### Request body (JSON object)

| Field | Required | Type | Notes |
|-------|----------|------|--------|
| `eventId` | Yes | string | Non-empty; use a **UUID v4** per event (client-generated). |
| `uid` | Yes | string | Must equal the Firebase user ID from the token. |
| `type` | Yes | string | Dot-separated event name (see [Event `type` strings](#event-type-strings)). Example: `content.published`. |
| `source` | No | string | e.g. `web`, `app`. |
| `entityType` | No | string | Optional entity category. |
| `entityId` | No | string | Optional entity id. |
| `timestamp` | No | string | ISO-8601 UTC (client may send). |
| `metadata` | No | object | Arbitrary JSON object. |

### Example body

```json
{
  "eventId": "550e8400-e29b-41d4-a716-446655440000",
  "uid": "firebaseUidHere",
  "type": "content.published",
  "source": "web",
  "entityType": "video",
  "entityId": "videoDocId",
  "timestamp": "2026-04-03T12:00:00.000Z",
  "metadata": {
    "platform": "streamerstip"
  }
}
```

### Success response

- **Status:** `200`
- **Body:** `{ "ok": true }`
- **Duplicate (same `eventId` retried):** still **`200`** and `{ "ok": true }` — idempotent success, no double XP.

### Validation failures

- Missing/invalid JSON, missing required fields, `uid` ≠ token user → **400** / **403** with `{ "error": "..." }`.

---

## CORS (browser)

The Worker sends CORS headers for allowed **origins**. As implemented in `cloudflare_workers/mux/src/index.js`, allowed origins include:

- `https://www.streamerstip.com`
- `https://streamerstip.com`
- `http://localhost:3000`
- `http://localhost:5173`

**Preflight:** `OPTIONS` is handled; allowed headers include **`Authorization`**, **`Content-Type`**.

If your web app runs on another origin (e.g. staging URL), add it to **`ALLOWED_ORIGINS`** in the Worker and redeploy.

Browser requests that include `Authorization` trigger a **CORS preflight** (`OPTIONS`); the Worker must list your origin — otherwise the browser blocks the response.

---

## Idempotency

- **Key:** `eventId` (UUID).
- **Store:** Firestore document **`gamification_events/{eventId}`** — create-only; second create fails with conflict → handler treats as **duplicate** and does **not** apply XP twice.
- **Audit:** `users/{uid}/gamification_audit/{eventId}` tracks processing.

**Client rule:** Generate **one new `eventId` per logical real-world action**. Retries of the **same** action should reuse the **same** `eventId` if you want deduplication.

---

## Firestore — backend writes

| Path | Purpose |
|------|---------|
| `gamification_events/{eventId}` | Event receipt; idempotency anchor (`uid`, `type`, `createdAt`). |
| `users/{uid}` | `gamification` map, `dailyMissions` / `missions` arrays (mission progress, XP-related fields). |
| `users/{uid}/gamification_audit/{eventId}` | Audit row (`xpGained`, `type`, `processedAt`). |

Writes are performed by the **Worker** (or optional Cloud Function), not by the web client directly for trusted XP.

---

## Firestore — UI reads (`users/{uid}`)

The web UI should **read** the user document (and optionally **listen** with `onSnapshot`) to show level, XP, missions.

**Field overview** (camelCase preferred; several snake_case aliases are accepted by shared parsers — see `lib/features/gamification/firestore_user_shape.md`):

- **`gamification`** (map): `level`, `totalXp`, `streakDays`, `creatorScore`, `rankTitle`, `nextAction`, `lastQualifiedActivityAt`, `updatedAt`, …
- **`dailyMissions`** / **`missions`** (arrays of mission objects): `missionId`, `templateId`, `type`, `status`, `title`, `description`, `target`, `progress`, `rewardXp`, `startsAt`, `expiresAt`, `completedAt`, `rewardClaimed`, …

If mission arrays are **empty**, the product may show **template placeholders** until the backend materializes rows — **real** progress requires server-written mission documents.

---

## Event `type` strings

Use the same canonical strings as the app and Worker. They are defined in code as **`GamificationEventTypes`** in:

`lib/features/gamification/gamification_event_types.dart`

Examples:

- **Content:** `content.published`, `content.video_uploaded`, `content.draft_saved`, …
- **Profile:** `profile.completed`, `profile.avatar_uploaded`, …
- **Engagement:** `engagement.comment_created`, `engagement.follow_created`, …

Mission templates on the server listen for specific `type` values; sending an unknown `type` still records the event but may not advance a mission.

---

## Web client example (JavaScript)

```javascript
async function emitGamificationEvent({
  baseUrl,       // Worker origin, e.g. https://streamerstip-mux-api.streamerstip.workers.dev
  idToken,       // await auth.currentUser.getIdToken()
  uid,           // auth.currentUser.uid
  type,
  entityType,
  entityId,
  metadata,
}) {
  const eventId = crypto.randomUUID();
  const url = `${baseUrl.replace(/\/$/, '')}/gamification/events`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      eventId,
      uid,
      type,
      source: 'web',
      entityType,
      entityId,
      timestamp: new Date().toISOString(),
      metadata: metadata ?? { platform: 'streamerstip' },
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Gamification HTTP ${res.status}: ${text}`);
  }
  return res.json(); // { ok: true }
}
```

Call **`emitGamificationEvent`** only **after** the underlying action succeeds (e.g. publish API returned OK).

---

## Errors & status codes

| Status | Typical cause |
|--------|----------------|
| 200 | Success or idempotent duplicate. |
| 400 | Invalid JSON, missing `eventId` / `uid` / `type`. |
| 401 | Missing/invalid `Authorization` or token verification failed. |
| 403 | `uid` in body does not match token user. |
| 500 | Server misconfiguration or Firestore error. |

Do not expose raw exception strings to end users in the UI; log details for developers.

---

## Testing with `curl`

```bash
export TOKEN='<paste Firebase ID token>'
export BASE='https://streamerstip-mux-api.streamerstip.workers.dev'
export UID='<same uid as token>'

curl -sS -X POST "$BASE/gamification/events" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"eventId\":\"$(uuidgen | tr '[:upper:]' '[:lower:]')\",\"uid\":\"$UID\",\"type\":\"content.published\",\"source\":\"curl\"}"
```

Repeat with the **same** `eventId` to verify idempotency (still `200`, no double XP in Firestore).

---

## Operations checklist

1. Deploy Worker (`cloudflare_workers/mux`) and set **`FIREBASE_WEB_API_KEY`**, **`FIREBASE_SERVICE_ACCOUNT_JSON`**, **`FIREBASE_PROJECT_ID`** (see `wrangler.toml` + README).
2. Confirm **CORS** includes your web origin.
3. From the browser, sign in, trigger a real action, emit event, verify **`gamification_events`** and **`users/{uid}`** in Firebase Console.
4. Optional: deploy Firebase **`gamificationEvents`** only if not using the Worker for this path.

Detailed step-by-step: **Part D** in `lib/features/gamification/firestore_user_shape.md`.

---

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Browser “CORS error” | Origin in Worker `ALLOWED_ORIGINS`; preflight `OPTIONS` succeeds. |
| 401 | Token expired; call `getIdToken(true)`. |
| 403 | `uid` in JSON must match signed-in user. |
| 200 but XP unchanged | Mission rows may be missing on `users/{uid}`; template `templateId` must match server config; event `type` must match mission template `progressEventKeys`. |
| Duplicate not deduping | Reuse exact same `eventId`; verify `gamification_events` create conflict handling. |

---

## Related files in this repo

| Area | Path |
|------|------|
| Worker handler | `cloudflare_workers/mux/src/index.js` (`handleGamificationEvent`, `applyGamificationMissions`) |
| Worker deploy / secrets | `cloudflare_workers/mux/wrangler.toml`, `cloudflare_workers/mux/README.md` |
| Optional Firebase HTTPS | `cloud_functions/src/gamification/gamification_events_http.js`, `cloud_functions/index.js` (`gamificationEvents`) |
| Flutter client | `lib/features/gamification/services/gamification_event_service.dart` |
| Base URL config | `lib/features/gamification/gamification_backend_config.dart` |
| Event type constants | `lib/features/gamification/gamification_event_types.dart` |
| Firestore read shape | `lib/features/gamification/firestore_user_shape.md` |

---

*Last aligned with repo implementation: Worker gamification route, Firestore idempotency, and shared event types.*
