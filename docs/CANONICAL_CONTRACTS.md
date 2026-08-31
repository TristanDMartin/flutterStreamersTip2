# Canonical contracts (website ↔ Flutter)

**Keep this file byte-identical in both repos.**

| Surface | GitHub | Local path | Locked branch |
|---|---|---|---|
| Website | `streamerstipReact` | `/Users/tristanmartin/Projects/streamerstipReact` | `homepage-merge-staging` |
| Flutter | `flutterStreamersTip2` | `/Users/tristanmartin/Projects/flutterST` | `flutterStreamersTip2` |

Both repos implement the **same** backend/domain contracts. Do not add repo-specific meanings for the same data. Do not switch branches to achieve parity. Update each repo independently on its locked branch.

Legacy aliases may be **read** for compatibility. New **writes** must use canonical field names. If one client behaves differently, fix that implementation — do not change this contract to match the bug.

Detailed video schema: `docs/VIDEO_SYSTEM_SHARED_CONTRACT.md`  
If that file disagrees with eligibility, account, or onboarding meanings here, **this file wins**.

---

## 1. Video document shape (`videos/{videoId}`)

Canonical write fields:

| Field | Meaning |
|---|---|
| `ownerId` | Uploader Firebase Auth UID |
| `categoryId` | Category key |
| `status` | Mux/processing lifecycle |
| `canonicalPlaybackUrl` | Usable HLS/playback URL |
| `muxPlaybackId` | Mux playback id (processing/media identity) |
| `isReadyForFeed` | Server said this video may enter public feeds |
| `feedEligible` | Owner/video is not feed-tombstoned |
| `ownerActive` | Owner is not deletion-tombstoned on this row |
| `isDeleted` | Soft-deleted |
| `publishedAt` | First public exposure |
| `createdAt` | Create time |

`status` values for **new writes**: `uploading` → `processing` → `ready` (or `failed` / `deleted`).

Read-only legacy aliases (do not write these as the primary key):

- owner: `userId`, `creatorId`, `uid`, `authorId`, `user_id`, `creator_id`
- playback: `hlsUrl`, `videoUrl`, `playbackUrl`
- category: `category`
- ready synonyms: `status` `published` / `active` → treat as `ready` when reading

Never use username/displayName as the ownership key. Never use `source` / `sourcePlatform` for visibility.

---

## 2. Public feed eligibility

A video is publicly feed-eligible only when **all** are true:

```
status == ready                  (legacy read: published | active)
AND isReadyForFeed == true       (legacy read: missing allowed if playable AND owner is resolved)
AND feedEligible == true         (legacy read: missing allowed IF owner is resolved and renderable)
AND ownerActive == true          (legacy read: missing allowed IF owner is resolved and renderable)
AND isDeleted != true
AND a resolvable owner id exists (ownerId | userId | uid | creatorId | authorId)
AND owner record exists
AND owner is renderable
AND canonicalPlaybackUrl is usable
```

Fail closed:

- Missing `ownerId` / `userId` / `uid` / `creatorId` / `authorId` = not feed eligible
- Missing owner record = not feed eligible
- Missing `ownerActive` / `feedEligible` is **not** assumed true unless ownership resolved
- Explicit `ownerActive == false` or `feedEligible == false` hides immediately
- Explicit `isDeleted == true` hides
- Owner `accountStatus` in `deactivated | deleting | deleted | banned | suspended | disabled` hides
- Embedded `creator` / username / avatar fields cannot establish that the creator exists

Owner renderable:

- New writes: `accountStatus = active`
- Legacy read: missing/empty `accountStatus` on an **existing, non-deleted** owner doc is treated as `active`
- Unknown non-empty statuses hide

Production invariant: `ORPHAN_PUBLIC_VIDEO_COUNT` must equal `0`. An orphan public video is `status == ready`, `isDeleted != true`, and either has no owner identifier, the owner record cannot be resolved, or the owner is not renderable.

New video writes must set `ownerActive: true` and `feedEligible: true` when exposing to feed. Do not resurrect tombstoned rows (`ownerActive === false`).

`canonicalPlaybackUrl is usable` means a non-empty HTTP(S) URL, **or** a non-empty `muxPlaybackId` that the player can resolve. `isReadyForFeed=true` with no usable playback source is **not** eligible.

Clients must not invent eligibility. Mux/backend sets processing + feed-ready flags. Account deletion/deactivation sets ownership visibility.

---

## 3. Account visibility / deletion

Canonical `users/{uid}.accountStatus` (ONLY these product states):

```
active | deactivated | banned | deleting | deleted
```

Do **not** invent `probation`. Do **not** use `blocked` as `accountStatus`.

Legacy admin writes `suspended` and `disabled` are **not** new product states. They are non-renderable. Signed-in enforcement for `banned` and existing `suspended` (and `disabled`) both use the **Account Suspended** screen. Backend may later split permanent vs temporary explicitly.

`blocked` is a **user-to-user relationship** only. It never sets `accountStatus`. Neither account becomes globally unavailable.

Signup / risk restrictions are **pre/during create** only. They never write `accountStatus = blocked` or `probation`. Disposable email is signup-only: an already-`active` account stays `active` (including existing disposable-domain users).

Do not invent client-only account states. StreamersTip does **not** support orphaned creator videos.

### Deactivate (reversible)

`accountStatus = deactivated`

Immediately hide profile, videos, threads, search, recommendations, and public profile links. Retain data and Auth. User can reactivate.

Owned videos stamp:

```
ownerActive: false
feedEligible: false
```

Do **not** set `isDeleted` or delete Mux/Auth. Do **not** release the username reservation. Reactivate restores `accountStatus = active` and `ownerActive/feedEligible = true` on non-deleted owned videos.

### Delete (permanent)

`ACCOUNT_DELETE_BEGIN` → `accountStatus = deleting` → immediate visibility off → background cleanup → `accountStatus = deleted`

Immediately:

- profile hidden
- videos hidden
- threads hidden
- search/recommendations/feed cards removed
- public profile links stop resolving
- username reservation released so another account can claim it

Owned videos stamp:

```
ownerActive: false
feedEligible: false
isDeleted: true
```

Then background: Mux assets, storage, video docs, followers, indexes, Auth last.

**Auth-console / Admin SDK deletes are the same deletion.** There is one cascade. `onAuthUserDeleted` (Firebase Auth `onDelete`) runs `reconcileDeletedAuthUser`:

- If StreamersTip `POST /api/account/delete` already finished (`accountStatus` deleted/deleting or `isDeleted`, and no feed-eligible owned videos) → exit
- Otherwise tombstone the owner, hide all owned content, clean indexes, then media

Deleting an Auth user in the Firebase Console must not leave `users/{uid}` or ready videos publicly renderable.

Missing `accountStatus` on an existing owner doc is legacy-active **only while Auth still exists**. Auth gone + leftover user doc = not active. Reconcile/tombstone; do not treat it as a live creator.

**Visibility off first, storage cleanup second.** Never delete Mux/HLS before the Firestore hide stamp. Public surfaces must never show dead cards, broken HLS, “Unknown User,” or deleted creators while cleanup runs.

Video delete (one video, not the account) tombstones that video immediately (`status: deleted`, `isDeleted: true`, `visible: false`, `isReadyForFeed: false`, `feedEligible: false`) before Mux/R2/index cleanup.

### Username uniqueness

Exclusive claim: `usernames/{normalized}` plus `users.username` / `usernameNormalized` on the live account.

- **Deactivate** keeps the reservation so reactivate restores the same username.
- **Delete** releases the reservation immediately (`usernames/{normalized}` deleted). Username-change quarantine (14 days) does **not** apply to account deletion.
- A username is **available** if it is unclaimed, the only holder is `accountStatus` `deleted` / `deleting`, or the reservation points at a missing/deleted user.
- Auth `onDelete` uses the same cascade. If delete already finished, leftover username reservations are still released.

---

## 4. Onboarding / account state

Only the **server** decides lifecycle. Web and Flutter are renderers of the same machine.

| Owner | Role |
|---|---|
| Firebase Auth | Identity |
| `GET /api/account/status` | Navigation authority |
| `users/{uid}.onboarding` | Durable progress (`lifecycle`, `tippyStage`) |
| Tippy UI | Presentation only |
| Local/session cache | Resume UX — never overrides server |

Activation:

```
NEW → GUEST_PERSONALIZATION → ACCOUNT_REQUIRED → EMAIL_VERIFICATION_REQUIRED
  → CREATOR_IDENTITY → FIRST_GROWTH_PLAN → FIRST_MISSION → ACTIVATED
```

- `activationState` = lifecycle authority
- `tippyStageHint` = presentation/resume (`onboarding.tippyStage`)
- `ACTIVATED` iff `onboarding.lifecycle = COMPLETE`
- After COMPLETE, missing photo/Twitch/bio/interests must not reopen Tippy
- If local stage ≠ server `tippyStage`, **server wins**

Resolvers: web `lib/onboarding/resolveOnboardingDestination.ts`; Flutter `lib/components/onboarding/resolve_onboarding_destination.dart`; golden `contracts/onboarding-lifecycle.golden.json`.

---

## 5. Identity providers (Google + Apple)

Same Firebase project. Same Auth UID. Same `users/{uid}` + `publicUsers/{uid}`. No Apple-only profile collection.

| Rule | Meaning |
|---|---|
| Providers | `google.com` and `apple.com` on the same Auth user |
| UID | Firebase Auth UID is the only identity key on both web and Flutter |
| First Apple authorization | Persist `displayName` (given + family) and email **only if those fields are still empty**. Apple omits them on later sign-ins. |
| Hide My Email | `*@privaterelay.appleid.com` is a valid contact address. Do not assume it matches a Google/password email. Do not use it as a public username. |
| Linking | If `account-exists-with-different-credential`, sign in with the original provider then `linkWithCredential`. Private-relay emails usually will **not** match another provider’s email. |
| Existing user | Do not restart onboarding. Resume `GET /api/account/status`. |
| New user | Same bootstrap as Google: pending account → status → onboarding machine. |
| Deleted | Canonical deletion (`accountStatus` deleting/deleted). Do not create a new live profile on the tombstoned UID. |
| Deactivated | Reactivation policy, not a new account. |

Firebase console (both clients): enable Apple provider on the StreamersTip Firebase project. Web needs an Apple Services ID + Sign in with Apple key (Team ID, Key ID, private key) and return URL `https://<authDomain>/__/auth/handler`. iOS/Android use the app’s Apple capability / SHA + the same Firebase Apple provider. Do not create a second Apple app identity.

---

## 6. Public Tippy Creator Checkup (acquisition, pre-onboarding)

Website surface for guests. Not a second onboarding, lifecycle, username, verify, or activation system. Flutter may share the contract later; Phase 2 UI is website-only.

**Machine copy:** `contracts/tippy-creator-checkup.v1.json`  
**Web SoT:** `lib/checkup/creatorCheckupContract.ts`

Two independent paths:

- **Path A — Get Started** opens canonical Tippy onboarding. It does not route to `/checkup`.
- **Path B — Creator Checkup** is optional acquisition at `/checkup`, then **Build My Growth Plan** hands off into the same onboarding machine.

Presentation: conversational acknowledgments after each answer; same 4 DNA fields. Optional public-profile look is Checkup-only and is **not** part of canonical onboarding.

Conversation order: goal → bottleneck → platforms → **optional public profiles** → cadence → optional **one** dynamic follow-up → score preview → 3 findings → plan preview. After platforms, Tippy asks conversationally: “Want me to actually take a look? You've given me enough for an initial read. If you want, share public profiles and I'll see whether what I find matches what you're telling me.” Only selected platforms are shown, each optional. Skip or analyze, then cadence immediately (“Got them. Keep going. I'll look while we talk.”). Analysis runs in the background.

Presentation/reasoning state lives on the guest Checkup session only. It is **not** lifecycle authority and is **not** added to canonical onboarding:

`initialHypothesis`, `currentHypothesis`, `supportingSignals[]`, `contradictingSignals[]`, `openQuestions[]`, `selfReportedSignals[]`, `platformObservations[]`, `analysisStatuses`, `confidence`, `primaryOpportunity`, `recommendedFocus`, `dynamicFollowUpUsed`.

Optional `bottleneckNote` (free text, chip-first) and at most one `followUp` are Checkup presentation only. Persist on close. Do not re-ask transferred DNA.

### Inputs (guest answers)

| Field | Kind | DNA handoff |
|---|---|---|
| `platforms` | multi-select | `answers.platforms` |
| `cadence` | single-select (`daily` / `few_week` / `weekly` / `few_month` / `whenever` / `not_started`) | `answers.schedule` |
| `goal` | single-select (same ids as onboarding goals) | `answers.goals = [goal]` |
| `bottleneck` | single-select (`consistency` / `discoverability` / `platforms` / `content` / `time` / `growth` / `starting`) | `answers.bottleneck` (extra; not re-asked) |
| `profiles` (optional) | per selected platform: `platform`, `handleOrUrl` / `profileUrl` | never — Checkup public assessment only |

Per-platform analysis (Checkup only):

Guest session `analysisStatus`: `not_provided` \| `pending` \| `analyzed` \| `limited` \| `unavailable`

`apiCheckupAnalyze` / server result per submitted profile persists:

- `platform`, `profileUrl`, `status`, `observedSignals`, `strengths[]`, `weaknesses[]`, `opportunities[]`, `evidence[]`, `confidence`, `analyzedAt`, `analysisVersion`
- `status`: `analyzed` \| `limited` \| `unavailable` \| `failed`
- `source`: `youtube` \| `twitch` \| `self_reported_only`
- `confidence`: `high` \| `medium` \| `low` (only when `analyzed`)
- `observations`

`handleOrUrl` remains an alias of `profileUrl`. `publicSignals` remains an alias of `observedSignals`.

Map API → guest: `failed` → `limited`; `source` is stored on the guest profile. `analyzed` / `limited` / `unavailable` keep the same `analysisStatus`. Only `analyzed` may carry strengths / weaknesses / opportunities / evidence-based conclusions. `limited` / `failed` never become fake analysis.

Also persist selected platforms, URLs, `analysisStatus`, observations, and the current Checkup step. Reopen must not re-ask provided URLs; welcome-back may mention saved profiles.

Tippy must distinguish “I analyzed this” vs “You told me this.” Never say “I analyzed your YouTube/Twitch/TikTok” unless `analysisStatus === analyzed`. Pending / limited / unavailable / failed stay **Quick Checkup** — “Initial assessment based on: what you told Tippy.” YouTube/Twitch stronger findings only when the function really returned `analyzed`. Connecting YouTube/Twitch later = authorized data. Not duplicates. Do **not** add this URL step to onboarding.

If a platform cannot be fetched with an official API already in this repo (no scrape, no fake data), status is `limited` or `unavailable` — not fake analysis. Analysis runs in parallel and must not block the conversation. If analysis is still pending at results, show Quick Checkup and upgrade in place when at least one profile becomes `analyzed`.

### Outputs

- `checkupScore` / `scorePreview` + `scoreVersion` (`checkup_score.v1`) — overall + categories `consistency`, `discoverability`, `platformPresence`, `contentReadiness`, `growthOpportunity`, plus a `why`. Source is `checkup_answers_only` (Quick Checkup — “Initial assessment based on: what you told Tippy”) or `checkup_answers_and_public_signals` when at least one profile is `analyzed` (Profile Checkup — “Initial assessment based on: what you told Tippy + N public profiles analyzed”). Never Mux, private analytics, or post metrics. UI name: **Creator Score Preview** (Tippy’s initial assessment). Not the live Creator Score.
- Exactly **3** findings, each `observation → implication → opportunity`. Self-reported findings when no public look; evidence-based when public signals are ready.
- Profile Checkup ( ≥1 `analyzed` ): concise initial results (short conclusion, then score, biggest opportunity, 3 things Tippy noticed, first growth focus) plus progressive **Learn more about my checkup** (overall read, what you told me, what I could see, platform breakdown for submitted platforms, how platforms work together only if 2+ analyzed, why this score, if I were working with you this week, first growth plan). Quick Checkup if nothing analyzed.
- `growthPlanPreview` — title, focus, why, first steps. Preview only. Do not create canonical plan docs from checkup. Build My Growth Plan still transfers platforms, goal, cadence only. Bottleneck + public observations may be Tippy context, not new lifecycle fields.

### Persistence / guest isolation

Ephemeral guest session: `sessionStorage` key `tippy_creator_checkup_v1`, `localStorage` fallback, bound to anonymous `guestKey` (`tippy_checkup_guest_key_v1`, tab-scoped). TTL 24h (`expiresAt`). No new account type. Do not write a guest user doc or lifecycle for guests. Clear on logout, auth UID change, expiration, guest-key mismatch, and account deletion. An unbound guest session must not attach to a signed-in user who did not convert it.

### Handoff boundary

CTA **Build My Growth Plan** is where canonical onboarding takes over:

1. Map checkup answers into `tippy_onboarding_v3`.
2. Set `startedFromCheckup` + `hasSeenTippyIntro`.
3. Resume existing Tippy stages (`questions` at first unanswered DNA, or `dna_reveal` if all 7 are present).
4. Skip already-answered DNA questions (`platforms`, `schedule`, `goals`). Remaining DNA (`creator_type`, `niche`, `experience`, `content_formats`) is still asked.
5. Guest answers cannot override newer canonical / already-answered DNA. Conversion is idempotent.
6. After signup, attach that session to **that** UID. Account creation, verify, identity, Growth Plan, First Mission, and `ACTIVATED` stay on the existing machine (`completeVerifiedActivation`, `users/{uid}.onboarding`).

### Analytics

Exact event names (do not spam; once per session id, question events once per question id). Payload: `checkupSessionId`, `scoreVersion`, `source`, `surface`, `isAnonymous`. **Never** include answer content.

`checkup_viewed`, `checkup_started`, `checkup_question_answered`, `checkup_completed`, `checkup_score_viewed`, `checkup_findings_viewed`, `growth_plan_preview_viewed`, `build_growth_plan_clicked`, `checkup_signup_started`, `checkup_signup_completed`, `checkup_activated`.

Existing activation / `onboarding_completed` events add `source=checkup` when the session started from checkup.

---

## 7. CLOSE / RESUME UX (Checkup + Tippy onboarding)

**X means NOT NOW, not START OVER.**

- Visible Close (X) is always available on Creator Checkup and canonical Tippy onboarding.
- Close is immediate. It does **not** delete progress, reset answers, restart, advance lifecycle, mark complete, or invent a fake completion.
- Modal/page close is **not** lifecycle authority. Close must **not** write `activationState` or `accountStatus`.
- Get Started still opens canonical Tippy onboarding. It does not route to `/checkup`.
- Do not change onboarding question option text. Do not add Checkup questions to onboarding.
- There is one activation machine. Checkup is not a second lifecycle.

### Checkup resume

Persist to the existing guest checkup session (`tippy_creator_checkup_v1`). Guest isolation and 24h expiration stay.

- If the guest answered some questions and closed before finishing: reopen restores those answers (including entered profile URLs/handles, bottleneck note, follow-up, and hypothesis state) and resumes at the next unanswered step (conversation order: goal → bottleneck → platforms → optional URLs → cadence → optional follow-up). Do not re-ask profiles already provided.
- If they already reached results: reopen results. Do not restart questions.
- Welcome-back (not first-meet) when progress exists: `Welcome back. I saved where we left off.` If profile URLs/handles were entered: `Welcome back. I still have your YouTube, Twitch, and TikTok profiles. Ready to keep going?`
- Do not say first-meet copy (`Hey! I'm Tippy…` / let's get started) when progress exists.

### Onboarding resume

Close preserves the guest/onboarding session, completed DNA, Checkup-transferred DNA, and saved avatar/username/bio.

- Resume from canonical server state + `tippyStageHint`, never from “closed = done.”
- If checkup transferred goal/platforms/cadence (`goals` / `platforms` / `schedule`): those stay skipped after close/reopen. Bottleneck stays context and is not re-asked.
- Direct Get Started uses the same save → close → resume rules.
- Welcome-back when they have progress: `Welcome back. Ready to keep going?`

### Guest Ask Tippy widget (presentation gate)

Guests can open the same Ask Tippy widget chrome from the header on marketing and app routes (`/`, `/checkup`, `/for-you`, etc.). Chat, send, and Tippy actions stay disabled until they create an account via Get Started. Close/X only hides the panel — it does not reset Creator Checkup or Tippy onboarding. Logged-in Ask Tippy is unchanged (full `toggleTippy`).

---

## 8. Account enforcement (signed-in + signup)

One meaning on website and Flutter. Clients render the same backend decision. They do not reimplement abuse logic.

### Relationship BLOCK (not platform moderation)

Creator A blocks B:

- A manages blocked accounts (`/settings/blocked` on web; Flutter blocked-accounts list) and can unblock.
- B does **not** get a “this person blocked you” notification.
- B cannot interact with A per existing block policy (comments, messages, feeds).
- Writes go to the existing relationship stores (`users/{uid}/blockedUsers/{id}` and `user_blocks`). Never `users/{uid}.accountStatus`.
- Interaction reads treat the pair as blocked if **either** store has it. New writes dual-write both. One-sided historical rows are reconciled by union backfill.

### Signup restriction (shared backend reason codes)

Decision lives on existing Next APIs / functions: `pending`, `provision`, `beforeUserCreated`, `enforceSignupSecurity`. Flutter consumes those APIs/codes. Do not keep a client-only denylist that can drift.

Canonical `reason` values on the server response (keep legacy `code` for compatibility):

| reason | Typical legacy `code` / signals | User copy |
|---|---|---|
| `disposable_email` | `DISPOSABLE_EMAIL` | Temporary email addresses are not allowed. Use a permanent email. |
| `network_temporarily_restricted` | `SIGNUP_BLOCKED` + IP / network restriction | Account creation is temporarily restricted from this network. Please try again later. |
| `device_temporarily_restricted` | `SIGNUP_BLOCKED` + device restriction | Account creation is temporarily restricted from this device. Please try again later. |
| `signup_rate_limited` | `SIGNUP_BLOCKED` + extreme velocity | Too many accounts were created recently. Please try again later. |
| `risk_review` | `SIGNUP_CHALLENGE_REQUIRED` / other risk | Account creation is temporarily restricted. Please try again later. |

Restrictions expire per existing TTL. Disposable stays rejected until a permanent email is used. Copy is honest restriction language — not “you are banned.”

### Bootstrap routing

Firebase Auth → resolve StreamersTip account → `accountStatus` → destination:

| status | destination |
|---|---|
| `active` | normal app |
| missing/empty on existing non-deleted owner | legacy-active (existing contract) |
| `deactivated` | Account deactivated screen |
| `banned` (and legacy `suspended` / `disabled`) | Account Suspended screen |
| `deleting` | block normal entry (unavailable + sign out) |
| `deleted` | do not restore; later signup is a new account + full onboarding |

Shell may load. **Protected creator functionality stays gated until enforcement resolves.** Intercept immediately after account-status resolution. Do not flash Home / For You, then swap.

Observe/refresh `accountStatus` while signed in (`active → banned | deactivated | deleting`). Token revoke is not enough.

### Banned — Account Suspended

Full-screen on both clients. Title **Account suspended**. Body exactly:

“Your StreamersTip account has been suspended because it did not meet our Community Guidelines or Terms of Service.”

Actions: **Get Help / Appeal** (`/feedback-help` or `contact@streamerstip.com`) and **Sign Out**.

Must not enter normal app: no Home/For You authenticated actions, Messages, Post, profile edit, dashboard, Tippy creator tools, Planner. Do not leak internal ban/risk reason. Public profile/videos stay hidden (owner-renderable contract).

### Deactivated

Title **Account deactivated**. Account is deactivated. Actions: **Reactivate**, **Settings**, **Sign Out**. Reactivate = same UID, no new account, no onboarding restart. Public content hidden per deactivation policy.

### Deleted

`deleting` then `deleted`. Deleted identity must never reach a “state screen” as if the account still exists. `deleting`: simple unavailable/sign-out gate. `deleted`: do not restore. Do not confuse with deactivation. Username/visibility deletion pipeline stays as specified above.

---

## Mux vs account

- Mux readiness controls **video processing state** (`status`, `muxPlaybackId`, `canonicalPlaybackUrl`, `isReadyForFeed`).
- Account deletion controls **ownership visibility** (`accountStatus`, `ownerActive`, `feedEligible`).
- Clients do not invent their own eligibility rules.
