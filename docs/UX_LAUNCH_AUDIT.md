# First-launch UX

**2026-11-14 (America/New_York).** Production launch remains **NO-GO**. Device testing remains **NO-GO**. Staging Firebase is still unverified. No store build was created.

## What this change does

A first open can show Tippy, then the official StreamersTip logo, then the existing startup shell. Skip ends it. A returning session, a seen flag, or a pending deep link skips it. Reduced motion shows the logo still, without the wave timing. Firebase auth keeps running underneath, and the existing Tippy onboarding, age checks, and account creation are unchanged.

The requested animation files `hf_20261029_050150_3df3a8c8-ed22-475c-8736-e8d250c1282b` and `hf_20261029_023135_10071274-5dc2-4217-85d1-7417009da88a` were not in this workspace. The opening uses the supplied Tippy GIF `assets/brand/official/tippy-opening-wave.gif` and the supplied gradient logo. Those files were committed before the screen change.

## Protected and left unchanged

Profile, Streamer Card front and back, profile editing, and the home feed playback widgets were not edited.

## Not done in this change

Discover, search, inbox, planner, academy, gamification, and upload screens were not redesigned. Doing that in the same change would risk the feed. No device performance was measured, so this is not an Instagram-speed claim.
