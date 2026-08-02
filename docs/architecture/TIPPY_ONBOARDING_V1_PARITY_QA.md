# Tippy Onboarding v1 — Website + Flutter Parity Checklist

Shared contract: `contracts/tippy-onboarding.v1.json`

## Entry
- [ ] Flutter Get Started opens Tippy onboarding (not cold SignupView)
- [ ] Website Start Free navigates to `/onboarding`
- [ ] Returning Sign In still uses auth/login (not Tippy funnel)

## Pre-auth stages
- [ ] Welcome copy matches contract (`Hi there! I'm Tippy...`)
- [ ] Questions intro after Continue
- [ ] Slim 7 progress shows Step N of 7
- [ ] Answers persist in guest session (`tippy_onboarding_v1`)
- [ ] Notifications explain before OS/browser prompt; Not now continues
- [ ] Trial stores `trialIntent` only (no charge before account)
- [ ] Pre-signup Tippy copy matches contract

## Attach
- [ ] After signup/login, `POST /api/tippy/onboarding/attach` succeeds
- [ ] Creator Memory fields written (type, platforms, niche, experience, goals, schedule, formats)
- [ ] `users/{uid}.onboarding.slim7Completed` / `tippyOnboardingV1Attached` set
- [ ] Re-attach same `sessionId` is idempotent
- [ ] Guest session cleared after successful funnel completion

## Post-auth
- [ ] Email verify stays in Tippy shell (password users)
- [ ] Creator profile step collectable / skippable forward
- [ ] Find friends optional (Continue without contacts)
- [ ] Success celebration respects reduced motion
- [ ] Landing choice Recommended vs Explore both reach main app
- [ ] Legacy personalize goals/platforms skipped when slim7 attached

## Analytics event names (both platforms)
- tippy_onboarding_started
- tippy_onboarding_step_completed
- tippy_onboarding_questions_completed
- tippy_onboarding_notifications_choice
- tippy_onboarding_trial_intent
- tippy_onboarding_signup_started
- tippy_onboarding_signup_attached
- tippy_onboarding_completed
- tippy_onboarding_landing_choice

## A11y
- [ ] `prefers-reduced-motion` / reduceMotion disables bounce/wave/idle loops
