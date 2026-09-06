# Production hardening sequence (locked)

Do **not** reorder. Do **not** enable R8, tighten CSP, or remove
`ignoreBuildErrors` until steps 1–4 pass.

| Step | Item | Status gate |
|------|------|-------------|
| 1 | Deletion production smoke (web + Flutter) | Recreate → **Meet Tippy / Welcome** only |
| 2 | First obfuscated store AAB via `build_store_release.sh` | Summary: obfuscation ENABLED, R8 DISABLED |
| 3 | Validate behavior on that obfuscated build | See pass criteria below |
| 4 | Symbol retention / Crashlytics workflow | Non-empty `symbols/<version>/` + optional upload |
| 5 | R8 compatibility enablement **only** | Align Media3 → keep rules → minify test release → smoke |

## 1. Deletion smoke

Use disposable production accounts. Checklist:
[`ACCOUNT_DELETION_SMOKE_TEST.md`](./ACCOUNT_DELETION_SMOKE_TEST.md)

**USE DISPOSABLE PRODUCTION ACCOUNT ONLY.**  
**NEVER DELETE OR RECYCLE THE PRIMARY TECHNQS ACCOUNT.**

Recreate with the **same** email/provider must land on:

- Meet Tippy / Welcome

Must **not** land on:

- Resumed Creator DNA mid-step
- Old profile / guided setup mid-flow
- Home / app shell
- Legacy onboarding bypass

Also confirm server cleanup (Auth, `users/{uid}/**`, public refs, Twitch/tippyBotChannels, videos/storage) and one staging partial-failure with actionable `warnings[]`.

## 2–4. First obfuscated Android AAB — pass criteria

```bash
set -a && source .env.release && set +a
bash scripts/build_store_release.sh android
```

| Check | Pass |
|-------|------|
| AAB produced **only** via `build_store_release.sh` | yes |
| `symbols/<version>/RELEASE_SUMMARY.txt` exists | yes |
| Dart obfuscation | ENABLED |
| R8 | DISABLED |
| `symbols/<version>/` non-empty (beyond summary files) | yes |
| Install on device | success |
| Sign-in | works |
| Home feed plays | works |
| Navigation | works |
| Video upload | works |
| Tippy | works |
| Profile / StreamerCard | works |
| Account deletion | still works (canonical HTTP delete) |
| Crashlytics | symbols retained; test crash symbolicates after upload |

**Video lifecycle (must still pass on this release artifact):**

Home video playing → Profile → Back → **same video resumes automatically**

Obfuscation should not affect this; confirm release behaves like the normal test build.

## 5. R8 (later only)

See [`R8_COMPATIBILITY_AUDIT.md`](./R8_COMPATIBILITY_AUDIT.md).

- Keep `isMinifyEnabled = false` until steps 1–4 pass
- Draft keep rules may exist; do **not** wire them yet
- Next R8 pass must: align Media3 versions → finalize keeps → enable minify on a **test** release → full video/auth/billing/Firebase/secure-storage smoke

Isolate each production change so a regression points to one hardening step.
