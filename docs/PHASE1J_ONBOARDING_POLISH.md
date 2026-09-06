# Phase 1J — Onboarding Polish

Phase 1J is experience polish on one already-proven onboarding contract.

It does not introduce new lifecycle logic, web-only behavior, or Flutter-only
behavior. Every change must preserve the Phase 1 production contract across
website and app.

## Rules

- No new onboarding lifecycle contract.
- No web-only behavior.
- No Flutter-only behavior.
- No stage-order changes unless the shared contract changes intentionally.
- Existing Phase 1 functional tests must pass unchanged.
- If polish requires changing the lifecycle contract, the polish is wrong.

## Canonical Surfaces

Website and Flutter must remain aligned on:

- Stage order.
- Copy.
- CTA colors and interaction semantics.
- Creator DNA reveal.
- Creator-space ready card.
- `+50 XP` setup bonus.
- First mission activation meaning.
- Resume and kill/reopen behavior.
- Delete and recreate reset behavior.

## 1J Sequence

1. 1J.1 — Instant transitions + loading-state cleanup.
2. 1J.2 — Email verification handoff.
3. 1J.3 — Branded verification email/domain.
4. 1J.4 — Twitch popup/external-auth continuity.
5. 1J.5 — Performance + minimal onboarding shell.
6. 1J.6 — Motion, haptics, and celebration.
7. 1J.7 — Final web to Flutter visual/behavior parity pass.

## 1J.1 Acceptance Standard

PHASE 1J — SLICE 1
INSTANT TRANSITIONS + LOADING CLEANUP

Web status (streamerstipReact): **1J.1 complete** — username interstitial
removed, optimistic locked-username/bio Continues + profile finalize advance,
first-mission silent retry + stable CTA, STALE attach no welcome rewind, verify
UI “Continuing…”. Flutter mirrored the same semantics.

- [x] No blank screens between onboarding stages.
- [x] No flashing previous stages during async work.
- [x] No visible "setup is still saving".
- [x] No manual retry for normal account activation.
- [x] No duplicate CTA presses required.
- [x] Buttons respond immediately on tap/click.
- [x] Current screen stays visually stable while server work finishes.
- [x] Forward transitions feel continuous.
- [x] Back transitions preserve all entered data.
- [x] Web and Flutter use the same transition semantics.
- [x] Loading copy is identical where the experience is equivalent.

## 1J.2 Acceptance Standard

PHASE 1J — SLICE 2
SEAMLESS EMAIL VERIFICATION HANDOFF

- [x] Creator can verify in another tab/browser and Tippy continues without
      feeling stuck on “setup is finishing”.
- [x] Tippy polls while on `verify_email` (Flutter: 2s; web: existing poll).
- [x] App resume while on `verify_email` rechecks silently.
- [x] Optimistic advance to `account_secured` then background activation.
- [x] Manual CTA is secondary (“Already verified? Continue”), not the only path.
- [x] Verify / legacy surfaces use “Email verified / Continuing…” — never
      “Setting up your creator profile…” or “Finishing your account…”.
- [x] Web dual-tab BroadcastChannel / storage handoff + longer ack window.
- [x] Branded verification email/domain handled in **1J.3**.

**1J.2 status:** complete for handoff UX. Proceed to **1J.3**.

## 1J.3 Acceptance Standard

PHASE 1J — SLICE 3
BRANDED VERIFICATION EMAIL

- [x] Sender name = StreamersTip
- [x] Sender uses StreamersTip-owned domain when Resend is configured
- [x] Subject / body / CTA match shared branding copy
- [x] Button URL is StreamersTip `/verify-email` (not firebaseapp.com action)
- [x] Production continue origin never localhost
- [x] Debug may use explicit localhost continue origin
- [x] Flutter + web call the same send API; 1J.2 handoff unchanged
- [x] No verification lifecycle / stage-order changes

**1J.3 status:** complete for branding path. **Not production-live** until a
real branded inbox proof (Resend + owned `/verify-email` link + 1J.2 handoff).
Proceed to **1J.4**.

## 1J.4 Acceptance Standard

PHASE 1J — SLICE 4
TWITCH OAUTH CONTINUITY

- [x] Web popup OAuth (controlled same-tab fallback if blocked)
- [x] Popup closes on success when allowed; original tab auto-detects
- [x] Flutter external browser/app switch resumes same `twitch_connect` stage
- [x] DNA + profile draft preserved across OAuth
- [x] Cancel / failure does not rewind or reset onboarding
- [x] Skip continues normally
- [x] Success updates integration / connection status only — not lifecycle ownership
- [x] No duplicate Twitch-connect after CONNECTED resume

**1J.4 status:** complete for handoff UX. Proceed to **1J.5**.

## 1J.5 Acceptance Standard

PHASE 1J — SLICE 5
PERFORMANCE + MINIMAL ONBOARDING SHELL

Rule: authenticated ≠ activated. Do not move creators forward before
server-owned lifecycle says they can.

- [x] Full app shell does not boot before ACTIVATED
- [x] Flutter onboarding does not mount MainTabView / feed services
- [x] Gamification Firestore listen waits for app-shell ready
- [x] Status-first bootstrap; `ensureMigrated` deferred off Tippy path
- [x] Status cache + in-flight dedupe; pending seeds verify-email status
- [x] Onboarding splash is chrome-only (no full-page spinner)
- [x] Web + Flutter share the same boot gate semantics
- [x] No lifecycle timing changes

**1J.5 status:** complete for shell isolation + critical-path cache. Proceed to **1J.6**.

## 1J.6 checklist — Motion, haptics, celebration

Presentation only. Never delay ACTIVATED or invent stage progress.

- [x] Forward transitions use short directional AnimatedSwitcher (~180ms)
- [x] Back transitions reverse slide; stage context preserved
- [x] Reduced motion / `MediaQuery.disableAnimations` → Duration.zero
- [x] Light haptics only on success (avatar upload, continue with photo,
      Creator Card finalize, Twitch connected, creator-space CTA, first mission)
- [x] Avatar “Looking good” flash; Creator Card haptic on optimistic advance
- [x] +50 XP celebrate scale on `creator_space_ready`
- [x] First-mission haptic only after successful attach
- [x] No await on haptics/animation before navigation

**1J.6 status:** complete in code. Next: **1J.7** parity pass, then disposable
production proof (web + Flutter) before Phase 1 freeze.

## 1J.7 checklist — Final web ↔ Flutter parity

Compare creator experience and canonical state, not implementation details.

- [x] v3 stage order + Twitch conditional branch (`stageAfterCreatorCard`)
- [x] Back from notifications skips `twitch_connect` when DNA omitted Twitch
- [x] Shared copy: notifications title/CTA, account secured next, identity,
      Twitch, creator space, first mission
- [x] Username / bio remix / avatar / verify / Twitch / notifications semantics
- [x] Creator Card optimistic finalize; +50 XP meaning; ACTIVATED terminal
- [x] Resume + delete/recreate reset aligned with web contract tests

**1J.7 status:** complete in code/tests. Run disposable production proof on web
+ Flutter (see web `docs/architecture/PHASE_1J_ONBOARDING_POLISH.md`).

## Required CTA Pattern

For account creation, verification, Creator Card finalize, and first mission,
the UI uses the same pattern:

1. Tap CTA.
2. Show immediate pressed/loading state.
3. Preserve current content.
4. Complete server operation.
5. Transition directly forward.

Do not use this pattern:

1. Tap.
2. Screen disappears.
3. Spinner appears.
4. Old screen flashes.
5. Status refetch flashes.
6. Another spinner appears.
7. Next screen appears.

## Monotonic Visible Stage Floor

The visible stage must never visually rewind during temporary network/loading
states.

Once the creator reaches stages such as `verify_email`, `account_secured`,
`username`, or `profile_review`, auth/status reconciliation must preserve that
visible floor until a real forward transition occurs.

## Web Guidance

Eliminate unnecessary rerenders or remounts during auth/status reconciliation.
Async work should preserve the current stage content until the operation either
advances forward or shows an inline recoverable error.

## Flutter Guidance

Keep one stable onboarding host. Avoid stage-widget destruction/recreation where
it causes state loss, duplicate lifecycle work, or visible backtracking.

