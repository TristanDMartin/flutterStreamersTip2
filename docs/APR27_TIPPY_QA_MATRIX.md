# Apr 27 Tippy QA Matrix

## Test Accounts

- `tippy_starter@test.local` (Starter)
- `tippy_pro@test.local` (Pro)
- `tippy_studio@test.local` (Studio)
- `tippy_entitlement_only@test.local` (Entitlement-only)
- `tippy_low_credit@test.local` (Low-credit user)
- `tippy_expired_auth@test.local` (Expired-auth user)

## Preconditions

- Staging backend deployed with `tippyApi`.
- Firebase auth enabled for staging project.
- `TIPPY_API_BASE` points to staging API host.
- `TIPPY_API_MOCK=false` for staging.

## Matrix

| Case | Account | Action | Expected Result |
|---|---|---|---|
| Chat send | Pro | Send prompt in Tippy chat | `200`, `success=true`, assistant response shown |
| Credit decrement | Pro | Run chat/create-plan/ai-caption/analyze-content | Credits decrement by `1` per successful call |
| No credits | Low-credit | Send AI request at `remaining=0` | `402 INSUFFICIENT_CREDITS`, upgrade UX path shown |
| Upgrade redirect | Starter | Trigger 402 from backend | Upgrade screen opens, no silent fallback |
| Expired auth | Expired-auth | Call any Tippy endpoint | `401 TOKEN_EXPIRED`, hard route to auth |
| Offline | Pro | Disable network and send | Retryable network error shown, input preserved |
| Timeout | Pro | Force delayed backend response > timeout | Retryable timeout error shown, input preserved |
| Backend 5xx | Pro | Inject provider/internal failure | Retry UI shown, input preserved |
| Failed AI no charge | Pro | Force provider failure after reservation | Credit value unchanged after rollback |
| Unknown errors | All | Run all cases and inspect logs | No unknown error codes in logs |

## Logging Checks

- Confirm only known codes appear:
  - `AUTH_REQUIRED`
  - `TOKEN_EXPIRED`
  - `INVALID_TOKEN`
  - `INSUFFICIENT_CREDITS`
  - `UPGRADE_REQUIRED`
  - `RATE_LIMITED`
  - `AI_PROVIDER_ERROR`
  - `INTERNAL_ERROR`
  - `SERVICE_UNAVAILABLE`

## Exit Verification

- Frontend reaches staging endpoints with real Firebase auth.
- Credits update after successful Tippy actions.
- Failed requests do not decrement credits.
- No unknown error codes appear in logs.
- Mock mode cannot run in staging/prod unless explicitly enabled in dev.
