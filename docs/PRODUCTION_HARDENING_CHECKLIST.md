# Production hardening checklist

**Rule:** No more production-hardening code until GATE 1 and GATE 2 both pass.  
If either fails → stop and fix that gate before R8.

---

## GATE 1 — Account deletion

Use disposable production accounts only.

**USE DISPOSABLE PRODUCTION ACCOUNT ONLY.**  
**NEVER DELETE OR RECYCLE THE PRIMARY TECHNQS ACCOUNT.**

### Web
- [ ] Delete from web (Settings → type `DELETE`)
- [ ] Auth user removed
- [ ] `users/{uid}/**` removed
- [ ] Public/profile refs removed
- [ ] Twitch / tippyBotChannels cleaned
- [ ] Videos / storage cleaned (spot-check)
- [ ] Recreate with **same** email/provider
- [ ] Lands on **Meet Tippy / Welcome**
- [ ] Does **not** resume Creator DNA mid-step
- [ ] Does **not** restore old profile / onboarding state
- [ ] Does **not** open Home / app shell
- [ ] Does **not** take legacy bypass

### Flutter
- [ ] Delete from Flutter (Manage account)
- [ ] Cloud delete uses HTTP `/api/account/delete` (success)
- [ ] Recreate with **same** provider
- [ ] Lands on **Meet Tippy / Welcome**
- [ ] Does **not** resume mid-funnel / old Tippy session
- [ ] Does **not** restore old profile / onboarding state
- [ ] Does **not** take legacy bypass

### Staging partial failure
- [ ] Controlled cleanup failure produces actionable `warnings[]` (named step, not vague)
- [ ] Retry / second delete is safe (idempotent)
- [ ] No zombie Auth user when cleanup mostly succeeded

**GATE 1 result:** [ ] PASS [ ] FAIL — if FAIL, fix before anything else

---

## GATE 2 — First obfuscated release

```bash
set -a && source .env.release && set +a
bash scripts/build_store_release.sh android
```

### Build / artifact
- [ ] AAB created **only** through `build_store_release.sh`
- [ ] `symbols/<version>/RELEASE_SUMMARY.txt` exists
- [ ] Dart obfuscation: **ENABLED**
- [ ] R8: **DISABLED**
- [ ] `symbols/<version>/` non-empty (symbol files retained)
- [ ] AAB installs successfully on device

### Smoke on that AAB
- [ ] Auth / sign-in
- [ ] Tippy
- [ ] Home video playback
- [ ] Upload + play video
- [ ] Profile / StreamerCard
- [ ] **Home video playing → Profile → Back → same video resumes**
- [ ] Account deletion still works
- [ ] Crash reporting / symbol workflow (retain symbols; optional upload + test crash)

**GATE 2 result:** [ ] PASS [ ] FAIL — if FAIL, fix before R8

---

## After BOTH gates PASS → R8 only

Do **not** start CSP, `ignoreBuildErrors`, or unrelated refactors.

- [ ] Align Media3 dependency / versions
- [ ] Finalize necessary keep rules (`proguard-rules.pro`)
- [ ] Enable R8/minify in a **TEST** release only
- [ ] Build test release via store script (summary should show `R8: ENABLED`)
- [ ] Full smoke: video / auth / billing / Firebase / secure-storage
- [ ] Inspect crashes / runtime regressions
- [ ] Only then consider production R8

**R8 result:** [ ] PASS (ready for prod) [ ] FAIL — iterate keeps, do not ship

---

## Explicitly blocked until gates pass

- [ ] ~~Enable R8 in production~~ — blocked
- [ ] ~~CSP hardening~~ — blocked
- [ ] ~~Remove `ignoreBuildErrors`~~ — blocked
- [ ] ~~Unrelated production refactors~~ — blocked

---

**Refs:**  
`docs/PRODUCTION_HARDENING_SEQUENCE.md` · `docs/ACCOUNT_DELETION_SMOKE_TEST.md` · `docs/R8_COMPATIBILITY_AUDIT.md`
