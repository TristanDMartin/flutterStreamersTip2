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

Website surface for guests. **Checkup is Tippy profile investigation**, not onboarding, not a second lifecycle, username, verify, activation, or `probation` system. Do not mix Checkup with `accountStatus`. Flutter has **no Checkup UI**; Path A still uses the shared onboarding machine. Machine copy lives on the website (`contracts/tippy-creator-checkup.v1.json`); keep this section identical in both repos.

**Machine copy:** `contracts/tippy-creator-checkup.v1.json`  
**Web SoT:** `lib/checkup/creatorCheckupContract.ts`

Two independent paths:

- **Path A — Get Started** opens canonical Tippy onboarding. It does not route to `/checkup`. Frozen.
- **Path B — Creator Checkup** is a public-profile investigation at `/checkup`. **CONTINUE WITH TIPPY** (BUILD MY GROWTH PLAN is an allowed alias) hands off into the same canonical onboarding machine.

Checkup does **not** collect Creator DNA interview chips (goal, bottleneck, cadence, experience, schedule). It does **not** open with “Hey I’m Tippy” or “tell Tippy about yourself.” It does **not** auto-fallback to a questionnaire when analysis fails.

Conversation order:

1. **Open** — “You already have a story online. Let me see what it says.” Supporting: drop profiles; learn before they tell you anything. No account. No questionnaire. CTA **LET TIPPY TAKE A LOOK**.
2. **Profiles** — “Alright. Where should I look?” YouTube / Twitch / TikTok / Instagram / Kick (+ existing safe extras). URL or handle. Add / remove / edit. Dedupe. **ANALYZE MY CREATOR PRESENCE**. “You only need one.” Privacy: public profiles only; private analytics later.
3. **Validate then analyze.** Per-platform status explicit. Never fake `analyzed`. One failure must not kill others. Parallelize. Cache unchanged profiles in the guest session. Real progress only (Finding profiles / Understanding content / patterns / dots) — no fake theater.
4. **Learn** structured `creatorPresenceAnalysis`. Inferred fields are **not** confirmed DNA. Observed vs inferred vs confirmed stay distinct.
5. **Reveal** conversational (“Okay… I learned a few things”) only as strong as evidence.
6. **Confirm** — “Here’s what I learned” + “Does this sound like you?” **YES, THAT’S ME** / **LET ME CORRECT SOMETHING**. Corrections are lightweight (type / niche / themes / ownership / format) in `creatorCorrections`. Confirmed = inference + correction.
7. **Result** — Opening read (“Okay. I think I understand what you're building.”) → Creator Score Preview (labeled preview, not live score) → one biggest opportunity → ~3 meaningful notices → creator system only if ≥2 `analyzed` → what I would do first. Learn More = deep audit with observed vs inferred. Score stays preview. Intelligence quality: §9.
8. **Convert** — “I’ve got a good starting picture… You won’t have to start over.” **CONTINUE WITH TIPPY** + **MAYBE LATER** / X = not now (preserve guest checkup, no account, no lifecycle).
9. **Zero analyses** — honest “couldn’t get enough public information”; edit profiles or continue to Get Started. No fake score.
10. **Partial** — transparent which platforms worked.

Presentation/reasoning state lives on the guest Checkup session only. It is **not** lifecycle authority and is **not** added to canonical onboarding:

`initialHypothesis`, `currentHypothesis`, `supportingSignals[]`, `contradictingSignals[]`, `openQuestions[]`, `selfReportedSignals[]`, `platformObservations[]`, `analysisStatuses`, `confidence`, `primaryOpportunity`, `recommendedFocus`.

### Inputs (guest answers)

| Field | Kind | DNA handoff |
|---|---|---|
| `platforms` | multi-select from submitted profiles | skip DNA platforms question when confirmed / submitted |
| `profiles` | per selected platform: `platform`, `handleOrUrl` / `profileUrl` | context (`checkupProfiles`) + prefill identity `platform_handles` (show, do not skip) |
| `creatorPresenceAnalysis` | inferred from public look | **not DNA** until confirmed |
| `creatorCorrections` | lightweight type / niche / themes / ownership / format | applied into confirmed |
| `confirmedDna` | inference + correction | prefill onboarding answers |
| `intention` | legacy optional; not asked | context only if present — never fake `answers.goals` |

Per-platform analysis (Checkup only):

Guest session `analysisStatus`: `not_provided` \| `pending` \| `analyzed` \| `limited` \| `unavailable`

`apiCheckupAnalyze` / server result per submitted profile persists:

- `platform`, `profileUrl`, `status`, `observedSignals`, `strengths[]`, `weaknesses[]`, `opportunities[]`, `evidence[]`, `confidence`, `analyzedAt`, `analysisVersion`
- `status`: `analyzed` \| `limited` \| `unavailable` \| `failed`
- `source`: `youtube` \| `twitch` \| `self_reported_only`
- `confidence`: `high` \| `medium` \| `low` (only when `analyzed`)
- `observations`

`handleOrUrl` remains an alias of `profileUrl`. `publicSignals` remains an alias of `observedSignals`.

Optional `observedSignals` when the official API returned them: `gameName`, `tags[]`, `followerCount`, `viewCount`, `isLive`, `currentTitle`, `videoTypes[]`, `topicCategories[]`. Missing optional fields stay omitted — never invent them.

Score basis: “based on public profiles Tippy could analyze.” Do **not** say “what you told Tippy” unless the guest confirmed/corrected facts or left a legacy intention. Instagram / TikTok / Kick stay `unavailable` (no scrape). YouTube uses Data API (`forHandle`, custom URL, search fallback, snippet / statistics / topics / uploads). Twitch uses Helix (user, channel, videos, stream, followers) when app credentials exist; otherwise `limited`.

Map API → guest: `failed` → `limited`; `source` is stored on the guest profile. `analyzed` / `limited` / `unavailable` keep the same `analysisStatus`. Only `analyzed` may carry strengths / weaknesses / opportunities / evidence-based conclusions. `limited` / `failed` never become fake analysis.

Also persist selected platforms, URLs, `analysisStatus`, observations, inferred / corrections / confirmed, and the current Checkup step. Reopen must not re-ask provided URLs; welcome-back may mention saved profiles (“Welcome back…” / “I finished looking…”).

Tippy must distinguish observed vs inferred vs confirmed. Never say “I analyzed your YouTube/Twitch/TikTok” unless `analysisStatus === analyzed`. Connecting YouTube/Twitch later = authorized data. Not duplicates. Do **not** add this URL step to onboarding.

If a platform cannot be fetched with an official API already in this repo (no scrape, no fake data), status is `limited` or `unavailable` — not fake analysis. Analysis runs in parallel. One failure must not kill others.

### Outputs

- `checkupScore` / `scorePreview` + `scoreVersion` (`checkup_score.v1`) — overall + categories `consistency`, `discoverability`, `platformPresence`, `contentReadiness`, `growthOpportunity`, plus a `why`. **Only when ≥1 profile is `analyzed`.** Zero analyses: no score. Source `checkup_answers_and_public_signals` when analyzed. Never Mux, private analytics, or post metrics. UI name: **Creator Score Preview** (labeled preview, not live Creator Score). Missing cadence is unknown — do not invent “You haven't started publishing consistently yet.”
- Exactly **3** findings when there is enough public evidence, each `observation → implication → opportunity`.
- Profile Checkup (≥1 `analyzed`): concise initial results (opening read, then score preview, biggest opportunity, what I noticed, creator system if 2+ analyzed, what I would do first) plus progressive **Learn more about my checkup**. How platforms work together only if 2+ analyzed.
- `growthPlanPreview` — preview only. Do not create canonical plan docs from checkup.

### Persistence / guest isolation

Ephemeral `guestCheckup` session: `sessionStorage` key `tippy_creator_checkup_v1`, `localStorage` fallback, bound to anonymous `guestKey` (`tippy_checkup_guest_key_v1`, tab-scoped). TTL 24h (`expiresAt`). Stores profiles, analysis, inferred DNA, corrections, confirmed DNA, score, opportunity, recs. No new account type. Do not write a guest user doc or lifecycle for guests. Clear on logout, auth UID change, expiration, guest-key mismatch, and account deletion.

**Guest attach** is **server-authorized current guest session → new UID only**. Not email match. Not cookie match. Not old UID match. A deleted UID never inherits old checkup/onboarding. An unbound guest session must not attach to a signed-in user who did not convert it.

### Handoff boundary

CTA **CONTINUE WITH TIPPY** (BUILD MY GROWTH PLAN OK as alias) is where canonical onboarding takes over:

1. Map **confirmed** facts into `tippy_onboarding_v3`. Unconfirmed inferred stay **suggested**, not answers. DNA `platforms` (“Where are you creating right now?”) skips when submitted/confirmed. Submitted Checkup profiles **prefill** guided identity `platform_handles` (“Want people to find you elsewhere?”) with platform + handle — **do not skip** that screen. User can add another, Continue, or Skip for now. Confirmed DNA treats those socials as confirmed; otherwise they are suggested defaults the creator can edit. Get Started without CONTINUE leaves socials empty.
2. Set `startedFromCheckup` + `hasSeenTippyIntro`. Compact confirm: “Perfect. I brought over what I learned. I already have a picture of what you're creating. Now I want to understand where you want to take it.” **LOOKS RIGHT** / **EDIT**. No second “Hey I’m Tippy.”
3. Resume existing Tippy stages (`questions` at first unanswered unknown DNA). Do not skip the whole onboarding because they did Checkup.
4. Still ask intent/goals, experience, schedule, and unknown formats. Skip duplicate confirmed DNA platforms (and confirmed type / niche / formats). Still **show** identity socials prefilling those profiles — never skip `platform_handles` because Checkup already had them.
5. Copy: “I can see what you're making. What I can't see is where you want to go.”
6. Guest answers cannot override newer canonical / already-answered DNA. Conversion is idempotent.
7. After signup, attach that **same** `tippy_onboarding_v3` `sessionId` (with checkup context) to **that** new UID (`accountCreated` + `claimedUid`). Do not reconstruct a second guest state. Account creation, verify, identity, Growth Plan, First Mission, and `ACTIVATED` stay on the existing machine (`completeVerifiedActivation`, `users/{uid}.onboarding`).
8. MAYBE LATER / X = not now. Preserve guest checkup. No account. No lifecycle write.

### Tippy conversation machine (Path A + Path B)

UI may differ. Meanings must not. Flutter has no Checkup UI; Path A still uses this machine, honesty, durable preview, guest claim, and format-aware plan. When Flutter receives transferred checkup context, it consumes confirmed + suggested the same way (compact confirm, skip intro, skip confirmed DNA platforms, **prefill** identity `platform_handles` from `checkupProfiles`).

```
INTRODUCED → DISCOVERY → ASSESSMENT → PREVIEW → ACCOUNT_GATE
  → ACCOUNT_CLAIMED → PROFILE_BUILD → PLAN_BUILD → COMPLETE
```

Persist on the existing `tippy_onboarding_v3` store (not a second session):

`sessionId`, `conversationAct`, `conversationTurn`, `completedSteps`, `conversationTimeline[]` (`stepId`, `turn`, `message`, `secondaryDelivered`), `answers`, `generatedPreview` / `creatorScorePreview` / `growthOpportunity` / `growthFocus` / `initialGrowthPlan`, `lastTippyMessage`, `secondarySpeechDelivered`, `accountCreated`, `claimedUid`, `emailVerified`, `profileSetupProgress`, `checkupIntention`, `checkupProfiles`, `checkupSuggestedAnswers`, `checkupConfirmedAnswers`, `checkupHandoffConfirmResolved`, `checkupPresenceSummary`.

- Already `INTRODUCED` (or later) never intros again. Checkup handoff never shows “Hey I’m Tippy.”
- Back restores the exact committed turn. Forward after Back does not replay delivered speech.
- Survives refresh, close, verify, Google, Apple, and guest→auth.

Web SoT: `lib/onboarding/tippyConversationContinuity.ts`. Flutter: `lib/features/onboarding_tippy/tippy_conversation_continuity.dart`.

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

- If the guest answered some questions and closed before finishing: reopen restores those answers (including entered profile URLs/handles, analysis, corrections, and hypothesis state) and resumes at the next unanswered step (conversation order: profiles → analyze → confirm → results). Do not re-ask profiles already provided.
- If they already reached results: reopen results. Do not restart questions. Welcome-back: `Welcome back. I finished looking.`
- Welcome-back (not first-meet) when progress exists: `Welcome back. I saved where we left off.` If profile URLs/handles were entered: `Welcome back. I still have your YouTube, Twitch, and TikTok profiles. Ready to keep going?`
- Do not say first-meet copy when progress exists.

### Onboarding resume

Close preserves the guest/onboarding session, completed DNA, Checkup-transferred DNA, and saved avatar/username/bio.

- Resume from canonical server state + `tippyStageHint`, never from “closed = done.”
- If checkup transferred DNA platforms: that DNA question stays skipped after close/reopen. Identity socials stay prefilling `checkupProfiles` (not skipped). Confirmed DNA stays prefilled. Unconfirmed inferred stays suggested. Goals / experience / schedule are still asked.
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

---

## 9. Tippy Creator Intelligence (Phase 2 quality bar — Phase 3 not started)

This section is the intelligence contract for Creator Checkup. It is **not** permission to start Phase 3. Phase 2 is **not frozen**. Do not implement trend monitoring, experiments, weekly reports, canonical Creator Score, missions-from-hypothesis, recurring coaching, or strategic-memory loops.

North star for Phase 2: Checkup proves Tippy can understand a creator business from public evidence — not that it “analyzed accounts.”

### Opinions, not facts-only

Every important Checkup claim moves **fact → meaning → decision**. Unacceptable as the primary result: “Your content looks good / try posting consistently / use hashtags / engage with your audience.” Acceptable: “You’re already streaming enough; I wouldn’t increase frequency first.”

### Evidence hierarchy

Every important claim belongs to exactly one kind:

| Kind | Meaning | Checkup rule |
|---|---|---|
| `creator_confirmed` | Explicitly supplied or confirmed by the creator | Highest authority for identity/intent |
| `publicly_observed` | Retrieved from a public profile Tippy actually analyzed | Never invent it |
| `inferred` | Interpretation of observed evidence | Never present as observation |
| `platform_general` | How platforms/formats work | Never as if observed about this creator |
| `private` | Authorized analytics (retention, impressions, CTR, revenue, …) | **Never in Checkup unless we actually have it** |

Never fake `analyzed`. Never invent views / retention / CTR / watch time / impressions / demographics / revenue / posting frequency / sentiment.

### Confidence language

Internal confidence is `high` | `medium` | `low`. Language must match. Low = “I don’t have enough evidence yet…” Do not fake certainty.

### Per-platform, then system

Understand each `analyzed` platform first. A cross-platform **creator system** (engine vs discovery vs shelf) is allowed only when **≥2** profiles are `analyzed` and evidence supports the roles. `limited` / `unavailable` never produce fake personalized findings.

### May disagree

Tippy may disagree with implied “stream more / post more” when evidence says distribution is the lever. Disagreement must be respectful, specific, and evidence-backed.

### One primary opportunity

One biggest opportunity + first action. Not ten equal problems. Generic “post more / use hashtags” must not be the primary opportunity when public 24/7 restream evidence exists.

### Result + Learn More

Concise result: opening read → Score Preview → biggest opportunity → ~3 notices → creator system if multi-analyzed → what I would do first → “Does this sound like you?”

Learn More (progressive disclosure): overall read; what I could actually see; what I’m inferring; per-platform breakdown; how platforms work together; what you’re underusing; **what I would not do**; if I were working with you this week (3 concrete actions); why. Observed vs inferred stay separate.

### Level 4 (scoped)

After results, the creator may ask Why / what first / which platform. Answers use **this Checkup context**. Do not build a full Ask Tippy product here.

### Phase 2 memory / onboarding

Guest Checkup context → CONTINUE WITH TIPPY → canonical auth → attach current guest session to UID. Copy: “Perfect. I brought over what I learned. I already have a picture of what you're creating. Now I want to understand where you want to take it.” / “I can see what you're making. What I can't see is where you want to go.” No second intro. Checkup answers *what they appear to be today*; onboarding answers *where they want to go*.

### Phase 3 (document only — do not build)

Architecture may later add: trend relevance, experiments, weekly report, canonical Creator Score (not this preview), missions-from-hypothesis, recurring coaching, strategic memory. Phase 2 keeps **Creator Score Preview** only.

### Phase 2 acceptance (not a freeze)

FAIL if the result could have been produced without the supplied profiles; if the recommendation applies unchanged to almost any creator; if Tippy claims data it does not have; if the analysis has no strategic opinion; if Checkup still feels like onboarding. Phase 2 stays unfrozen until those proofs pass in production.

---

## 10. Tippy Brain (one creator, one canonical server-owned Brain)

**All Tippy intelligence must converge into one canonical server-owned Tippy Brain per authenticated UID.** Website and Flutter consume and update the same context. **No** separate web brain, app brain, onboarding brain, Checkup brain, or Phase 3 brain as an independent source of truth.

Guest Checkup context exists only before authentication and is explicitly merged during authorized handoff (current guest session → new UID only). Deleted UID never inherits. Clients never become authority for Tippy memory.

**One creator. One canonical Tippy Brain. Many surfaces.**

Checkup, onboarding, dashboard, and Ask Tippy are **presentation surfaces**. They read and update this Brain. They do not keep a long-term Tippy memory of their own after claim.

This section is **not** permission to start Phase 3. Phase 2 is **not frozen**. Phase 3 may later write experiments, weekly reports, trend loops, and a live Creator Score **into this same Brain**. Do not invent a second store for those.

### Canonical path

`users/{uid}/creatorMemory/main`

This existing per-UID doc **is** the Tippy Brain. Do **not** create `users/{uid}/tippyBrain`, a top-level `tippyBrain/{uid}`, or a Flutter-only memory collection as a second source of truth.

`users/{uid}/tippyMemory/{id}` is a legacy chat-summary subcollection. It is **not** the Brain. New Tippy intelligence writes go to `creatorMemory/main`.

Global `tippyBrainKnowledge` / `tippyBrainSources` / `tippyBrainChunks` are shared platform knowledge cards (algorithms, games). They are **not** a per-creator Brain.

| Field on Brain | Meaning |
|---|---|
| `creatorDNA` | Confirmed Creator DNA the creator told or confirmed (existing MemoryItem section) |
| `confirmedFacts` | Typed insights with `type=confirmed` |
| `observations` | Retrieved public/connected facts (`type=observation`) |
| `inferences` | Interpretation + evidence + confidence (`type=inference`) — never stored as confirmed |
| `platformIntelligence` | Submitted/analyzed platforms and profile handles |
| `goals` | Existing MemoryItem goals (current state, not a parallel store) |
| `strategicMemory` | Recommended / tried / outcome / Tippy changed its mind — **schema now, Phase 3 writes later** |
| `currentStrategy` | Goal, recommended focus, weekly focus (weekly focus reserved) |
| `growthPlan` | Pointer to existing `users/{uid}/contentPlans/{planId}` |
| `missions` | Pointer to existing gamification missions |
| `creatorScore` | Pointer to existing `users/{uid}/creatorScore/current` — **not** a second score; Checkup preview is not live score |
| `experiments` | Schema now; Phase 3 writes later |
| `outcomes` | Schema now; Phase 3 writes later |
| `recommendations` | Typed insights with `type=recommendation` |
| `updatedAt` | Last Brain write |
| `brainVersion` | Brain layer version (currently `1`) |

Every meaningful insight:

```
statement, type (observation|inference|recommendation|confirmed), source, evidenceIds, confidence, createdAt, lastValidatedAt
```

Truth levels:

| Level | Meaning |
|---|---|
| Confirmed Creator DNA | Creator told or confirmed |
| Observed Intelligence | Retrieved public or connected |
| Inferred Intelligence | Interpretation + evidence + confidence |
| Strategic Memory | Recommended / tried / outcome / Tippy changed its mind (Phase 3 writes later) |
| Current State | Goal, plan, missions, score, weekly focus — existing product fields live here |
| Connected Data | Authorized analytics when we actually have them |

Inference is never confirmed. Confirmed never silently becomes inferred. Clients may **read** legacy MemoryItem fields (`identity`, `platforms.primary`, `goals.goalIds`, user-doc `selectedPlatforms`) and project them into Brain layers. New writes use the Brain layers + existing MemoryItem updaters via allowlisted APIs (`GET/POST /api/tippy/creator-memory`). Clients never write Firestore Brain docs directly.

### Guest merge

CONTINUE WITH TIPPY attach copies the **current** guest Checkup session onto the **new** UID and **merges into Brain layers**:

- Observed from public analysis (`analysisStatus === analyzed` only)
- Inferred with confidence (presence analysis — not DNA)
- Confirmed from YES / corrections

Not email match. Not cookie match. Not old UID match. A deleted / deleting / banned / deactivated UID never inherits. After claim, checkup-only `localStorage` / `sessionStorage` is resume UX, not long-term Tippy memory.

### Surfaces after auth

If Brain has confirmed platforms, Tippy must not re-ask “which platforms are you on?” Website and Flutter both skip that DNA question and may say they already know the setup (Twitch-first, etc.). Goals / experience / schedule remain asked until confirmed.

**Checkup persists in Brain and is visible on Mission Control.** After claim, Checkup is an in-account Brain record — not only a pre-signup screen. Website Mission Control (`/dashboard/mission-control`) and Flutter’s Tippy home / Command Center read the same Brain (`GET /api/tippy/creator-memory`) and project `Your Creator Read` from checkup-derived layers (`observations`, `inferences`, `confirmedFacts`, `currentStrategy`, `platformIntelligence`). Continuity copy: “I brought over what I learned from your Checkup. Here’s what I want us to focus on first.” Learn More opens Brain-backed detail, not a dead guest session. If Brain has no Checkup-derived layer, do not invent one. An activated user may be redirected from `/checkup` to Mission Control only when Brain already has that attached Checkup. Phase 2 is not frozen. Phase 3 is not started.
