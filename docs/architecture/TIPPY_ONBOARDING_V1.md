# Tippy Onboarding Contract v1

**Status:** Implementation in progress  
**Contract:** `contracts/tippy-onboarding.v1.json`  
**Parity:** Website (`streamerstipReact`) + Flutter (`flutterST`)

## Funnel

Get Started / Start Free → Welcome → Slim 7 → Notifications → Trial intent → Signup → Verify → Creator Profile → Find Friends → Success → Landing choice

## Shared rules

- Question IDs, option values, and field paths are identical on web and mobile.
- Guest answers live in local session (`tippy_onboarding_v1`) until auth.
- After signup/login, `POST /api/tippy/onboarding/attach` writes Creator Memory + seeds `users/{uid}.onboarding`.
- Tippy mascot is a replaceable presentation layer (`TippyMascot` → `CodeDrawnTippy` today; Rive later).
- Billing never starts before an authenticated account; trial screen only stores `trialIntent`. After signup + email verify, `trialIntent` opens Creator Pro Stripe/IAP checkout once.

## Consumers

- Flutter: `lib/features/onboarding_tippy/tippy_onboarding_contract.dart`
- Website: `lib/onboarding/tippyOnboardingContract.ts`
