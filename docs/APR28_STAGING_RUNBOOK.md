# Apr 28 - Staging Runbook

## Goal

Stabilize Tippy with real staging data, clean logs, correct credits, and reliable retry UX.

## Account Matrix

- Starter
- Pro
- Studio
- Entitlement-only
- Low-credit user
- Expired-auth user

## Test Paths

- Open Tippy
- Send chat prompt
- Create Plan
- Generate AI Caption
- Exhaust credits
- Upgrade redirect
- App relaunch
- Offline retry
- Timeout retry
- 429 rate-limit behavior
- Backend 5xx fallback

## Failure Capture Template

- Route:
- Action:
- Account type:
- Expected:
- Actual:
- Error code:
- Request ID:
- Screenshot/log:

## Execution Steps

1. Point app to staging with real Firebase auth.
2. Run each test path for each account.
3. Record every failure with template fields.
4. Validate retry UX does not erase prompt and does not duplicate send.
5. Confirm successful AI actions decrement credits by exactly one.
6. Confirm failed AI actions do not decrement credits.
7. Confirm `402` opens upgrade flow.
8. Confirm app relaunch refreshes credits from backend.

## Exit Criteria Checklist

- No `FAILED_PRECONDITION` index errors in normal flow.
- No unexpected `PERMISSION_DENIED` in intended paths.
- Tippy actions return real backend responses.
- Credits remain accurate across success/failure/relaunch.
- Retry UX keeps input and provides explicit retry action.
- Logs include request metadata without prompt/message content.
