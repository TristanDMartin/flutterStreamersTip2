# Account deletion production smoke test

Run **after** deploying `apiAccountDelete` (targeted Functions deploy). Do not add more deletion logic until both paths pass. Do not start R8 / CSP / ignoreBuildErrors until this smoke **and** the first obfuscated AAB validation pass — see [`PRODUCTION_HARDENING_SEQUENCE.md`](./PRODUCTION_HARDENING_SEQUENCE.md).

## Protected production identity

The primary production account is **protected**.

- **USE DISPOSABLE PRODUCTION ACCOUNT ONLY.**
- **NEVER DELETE OR RECYCLE THE PRIMARY TECHNQS ACCOUNT.**
- Never reset it or use it for destructive onboarding proofs.

Mismatch verification session (generic):

- Signed-in **account A** (`existingPrimaryAccount`) opens a verification link for **account B** (`verificationTargetAccount`).
- Fixed behavior: sign out A before `applyActionCode`, then continue B’s verification flow.

## Deploy

```bash
cd /Users/tristanmartin/Projects/streamerstipReact
npm run deploy:functions
# or: firebase deploy --only functions:apiAccountDelete
```

`apiAccountDelete` was deployed to `streamerstip-6cfdb` (targeted). Re-deploy only if deletion code changes again.

## Web path

1. Sign in as a disposable **active** account (has Tippy progress + Twitch if possible). Not the primary production account.
2. Settings → Account → type `DELETE` → confirm.
2. Settings → Account → type `DELETE` → confirm.
3. Verify:
   - Firebase Auth user gone
   - `users/{uid}` and subcollections gone
   - `publicUsers/{uid}` gone
   - `twitchConnections/{uid}` gone
   - `tippyBotChannels` docs for that uid / Twitch id gone
- Owned `videos/*` gone **or** immediately unrenderable (`isDeleted`, `feedEligible: false`, `ownerActive: false`)
   - Home / Discover / For You on **web and app** show **zero** videos for that UID
   - `publicUsers/{uid}` gone or `accountStatus` deleting/deleted
4. Recreate with the **same email/provider**.
5. Get Started → **MUST** open Meet Tippy / Welcome (not mid-DNA / guided profile / Home / legacy bypass).

## Flutter path (next required gate)

Use a **disposable active** account (the one that just finished Meet Tippy → Home is fine). **Never** the primary production account.

1. Hot-restart / reinstall this build so deletion + recycle client fixes are on device.
2. Profile → Manage account → type `DELETE` → confirm.
3. Logs must show:
   - `[ACCOUNT_DELETE_REQUEST] ... hasAppCheck=...`
   - `[ACCOUNT_DELETE_RESPONSE] httpStatus=200 ok=true`
4. App signs out. Auth user gone. `users/{uid}` gone.
5. Recreate with the **same** Google/Apple/password.
6. First screen **MUST** be Meet Tippy / Welcome.

Must **not** land on: resumed DNA, guided profile, Home, or legacy bypass.

If delete returns 404/502/503, retry is automatic (3 attempts). If it still fails, stop — do not locally wipe and do not start store/R8.

## Partial-failure (staging/dev)

Force a non-fatal cleanup warning (e.g. unset Mux credentials temporarily) and confirm:

- Response still `ok: true` when Auth + user tree deleted
- `warnings[]` names the failed step (actionable, not a vague "something failed")
- Retry/delete-again is safe (idempotent)
- No zombie Auth user left when cleanup mostly succeeded

## Phase 0 recycle proof capture

**USE DISPOSABLE PRODUCTION ACCOUNT ONLY.**  
**NEVER DELETE OR RECYCLE THE PRIMARY TECHNQS ACCOUNT.**

After delete → recreate of that disposable identity, dump both identities with:

```bash
cd /Users/tristanmartin/Projects/streamerstipReact
PROOF_NAME=p0-recycle \
PROOF_SURFACE=web \
PROOF_ID_TOKEN_FILE=/tmp/st-proof.token \
PROOF_INCLUDE_FIRESTORE=1 \
PROOF_OBSERVED_ROUTE='<what the new account actually showed>' \
node scripts/activation-growth-proof-dump.mjs
```

Never paste the ID token into chat. Paste only the sanitized JSON the script prints.

Record: `activationState`, `creatorScore/current`, `gamification/state`, entitlements, expected route.

Pass only if Score, XP, streak, missions, challenges, notifications, and growth events are absent on the new uid. Trial/quota/abuse history may survive.

| Check | Pass |
|-------|------|
| Web delete | Auth + `users/{uid}/**` removed |
| Flutter delete | Same server contract |
| Recreate | Welcome / Meet Tippy only |
| Mid-funnel reattach | Blocked (`ignoreLocalResume` / `startedFromWelcome`) |
| Not allowed | Resumed DNA, old profile setup, Home, legacy bypass |
