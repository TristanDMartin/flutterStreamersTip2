# StreamersTip Onboarding Experience
## Complete Cross-Platform Guide (Mobile & Website)

**Last Updated:** October 15, 2026  
**Version:** 3.1 (Product Education Layer)  
**Canonical Contract:** `docs/CANONICAL_CONTRACTS.md` Section 4  
**Status:** Canonical for both Website (React) and Mobile (Flutter)

---

## 🎯 Core Principles

### **Technical Authority**
> **Only the server decides lifecycle. Web and Flutter are renderers of the same state machine.**

Both platforms implement the **same** backend/domain contracts. There is **one** activation machine, not separate web and mobile flows.

### **Product Education Requirement**
> **Every new creator must understand what StreamersTip is, what Tippy does, what value they get, and what action to take first before they become ACTIVATED.**

Onboarding is not complete when forms are filled. It's complete when the creator understands:
1. **What is StreamersTip?**
2. **What can Tippy do for me?**
3. **Where do I go to manage my creator workflow?**
4. **What should I do first?**

If any of these answers are unclear, onboarding is not finished.

---

## Table of Contents

1. [Overview](#overview)
2. [Phase 1: Pre-Authentication](#phase-1-pre-authentication-guest)
3. [Phase 2: Account Creation](#phase-2-account-creation)
4. [Phase 3: Tippy Conversation Machine](#phase-3-tippy-conversation-machine)
5. [Phase 4: Creator Identity](#phase-4-creator-identity)
6. [Phase 5: Activation & First Mission](#phase-5-activation--first-mission)
7. [Data Storage Contract](#data-storage-contract)
8. [Close & Resume Behavior](#close--resume-behavior)
9. [Enforcement & Edge Cases](#enforcement--edge-cases)
10. [Navigation Authority](#navigation-authority)
11. [Critical Parity Requirements](#critical-parity-requirements)
12. [Testing Checklist](#testing-checklist)

---

## Overview

### Activation Lifecycle States
```
NEW → GUEST_PERSONALIZATION → ACCOUNT_REQUIRED 
  → EMAIL_VERIFICATION_REQUIRED → CREATOR_IDENTITY 
  → FIRST_GROWTH_PLAN → FIRST_MISSION → ACTIVATED
```

### What ACTIVATED Really Means

**ACTIVATED is NOT:**
- ❌ All required fields filled out
- ❌ Profile 100% complete
- ❌ User clicked through all screens

**ACTIVATED IS:**
- ✅ Identity setup complete (avatar, username, bio, platforms)
- ✅ Tippy understands core creator DNA (7 questions answered)
- ✅ First growth focus exists (personalized plan)
- ✅ Creator has been given a clear next action
- ✅ Creator understands what StreamersTip is and does
- ✅ Creator knows where to go (Mission Control)
- ✅ Creator knows what to do first (meaningful activation action)

### Two Entry Paths

| Path | Platform | Description |
|------|----------|-------------|
| **Path A: Get Started** | Web + Mobile | Direct entry to Tippy onboarding |
| **Path B: Creator Checkup** | Web Only | Optional profile investigation before signup |

**Both paths converge** at the same canonical Tippy onboarding machine after authentication.

---

## Phase 1: Pre-Authentication (Guest)

### Path A: Get Started (Direct Onboarding)

**Available on:** Website + Flutter Mobile

1. User clicks **"Get Started"** button
2. Opens canonical **Tippy onboarding** immediately
3. No prior profile investigation
4. Fresh start with no assumptions about creator

**Flow:**
```
Landing Page → Get Started → Tippy Welcome → 7 DNA Questions → Sign Up
```

---

### Path B: Creator Checkup (Optional Pre-Investigation)

**Available on:** Website Only (Flutter skips this)

#### Purpose
Public profile investigation to understand the creator **before** they tell Tippy anything.

#### Conversation Order

1. **Welcome**
   - Copy: "You already have a story online. Let me see what it says."
   - Supporting message: Drop profiles; learn before they tell you anything
   - No account required yet
   - CTA: **"LET TIPPY TAKE A LOOK"**

2. **Profile Collection**
   - Prompt: "Alright. Where should I look?"
   - Platforms: YouTube / Twitch / TikTok / Instagram / Kick
   - Input: URL or handle
   - Can add multiple, edit, or remove
   - Deduplication handled automatically
   - Privacy note: "Public profiles only"
   - CTA: **"ANALYZE MY CREATOR PRESENCE"**
   - Copy: "You only need one."

3. **Validation & Analysis**
   - Per-platform status shown explicitly
   - States: `not_provided` → `pending` → `analyzed` | `limited` | `unavailable` | `failed`
   - Parallel fetching via official APIs only
   - **Never fake analysis** - honest progress only
   - Real status messages:
     - Finding profiles...
     - Understanding content...
     - Looking for patterns...
     - Connecting the dots...

4. **Learn Phase**
   - Structured `creatorPresenceAnalysis` generated
   - Inferred fields (not confirmed DNA yet)
   - Observed vs inferred stays distinct

5. **Reveal Phase**
   - Copy: "Okay… I learned a few things"
   - Conversational reveal only as strong as evidence
   - Never claim more than data supports

6. **Confirmation**
   - "Here's what I learned. Does this sound like you?"
   - CTA: **"YES, THAT'S ME"** / **"LET ME CORRECT SOMETHING"**
   - Corrections are lightweight:
     - Content type
     - Niche/focus
     - Key themes
     - Platform ownership
     - Format preferences
   - Corrections stored in `creatorCorrections`
   - Confirmed = inference + corrections

7. **Results**
   - Opening read: "Okay. I think I understand what you're building."
   - **Creator Score Preview** (labeled as preview, not live score)
   - One biggest opportunity
   - ~3 meaningful notices with evidence
   - Creator system analysis (only if ≥2 platforms `analyzed`)
   - "What I would do first" recommendation
   - **Learn More** = progressive disclosure (deep audit with observed vs inferred)

8. **Conversion Decision**
   - Copy: "I've got a good starting picture… You won't have to start over."
   - CTA: **"CONTINUE WITH TIPPY"** (or **"BUILD MY GROWTH PLAN"** as alias)
   - Alternative: **"MAYBE LATER"** / **X** = not now
   - Preserve guest checkup session
   - No account created yet
   - No lifecycle write

9. **Zero Analyses Edge Case**
   - Honest message: "Couldn't get enough public information"
   - Options: Edit profiles or continue to Get Started
   - **Never fake a score**

10. **Partial Analyses**
    - Transparent about which platforms worked
    - Show what data was available
    - Clear about limitations

#### Analysis Quality Rules

| Analysis Status | Meaning | Requirements |
|----------------|---------|--------------|
| `analyzed` | Full official API data retrieved | YouTube Data API, Twitch Helix |
| `limited` | Partial data or fallback methods | API returned minimal data |
| `unavailable` | No official API available | Instagram, TikTok, Kick (no scraping) |
| `failed` | API call failed | Network error, rate limit, invalid handle |

**Never:**
- Fake analysis results
- Invent metrics (views, followers, engagement)
- Scrape platforms without official APIs
- Claim analysis when status is `limited` or `unavailable`

#### Checkup Intelligence

**Observed Signals** (when `analyzed` only):
- `gameName` (Twitch category)
- `tags[]` (video tags)
- `followerCount`
- `viewCount`
- `isLive`
- `currentTitle`
- `videoTypes[]`
- `topicCategories[]`

**Missing fields stay omitted** - never invent them.

**Inferred Intelligence:**
- Content type (gaming, IRL, music, etc.)
- Niche focus
- Publishing consistency
- Platform strategy
- Growth opportunities

**Confidence Levels:**
- `high` - Strong evidence from multiple sources
- `medium` - Some evidence, reasonable inference
- `low` - Limited data, uncertain inference

**Language must match confidence:**
- High: "You're clearly focused on..."
- Medium: "It looks like..."
- Low: "I don't have enough evidence yet..."

#### Creator Score Preview

**Only shown when ≥1 platform is `analyzed`**

Components:
- Overall score (0-100)
- Category scores:
  - Consistency
  - Discoverability
  - Platform Presence
  - Content Readiness
  - Growth Opportunity
- `why` explanation for each score
- Source: `checkup_answers_and_public_signals`
- **Never** uses:
  - Mux processing data
  - Private analytics
  - Post metrics
  - Invented cadence

**UI Label:** "Creator Score Preview" (not "Creator Score")

#### Findings Format

**Exactly 3 findings** when enough evidence exists:

```
Observation → Implication → Opportunity
```

Example:
- **Observation:** "You're streaming 24/7 on Twitch"
- **Implication:** "But your VOD views are low"
- **Opportunity:** "Your distribution strategy needs work before increasing volume"

#### Handoff to Canonical Onboarding

When user clicks **"CONTINUE WITH TIPPY"**:

1. **Context Transfer**
   - Confirmed DNA prefills onboarding answers
   - Unconfirmed inferred stays as **suggestions**
   - Checkup profiles prefill identity `platform_handles` screen
   - `startedFromCheckup: true` flag set

2. **Compact Confirmation**
   - Copy: "Perfect. I brought over what I learned."
   - "I already have a picture of what you're creating."
   - "Now I want to understand where you want to take it."
   - Options: **"LOOKS RIGHT"** / **"EDIT"**

3. **Skip Intro**
   - No second "Hey I'm Tippy" intro
   - `hasSeenTippyIntro: true` set

4. **Resume Questions**
   - Start at first **unknown** DNA question
   - Skip confirmed platforms question if submitted/confirmed
   - **Show** (don't skip) identity socials with prefilled handles
   - Still ask: goals, experience, schedule, unknown formats

5. **Preserve Copy Context**
   - "I can see what you're making. What I can't see is where you want to go."
   - Acknowledge checkup context throughout

#### Guest Session Persistence

**Storage:**
- `sessionStorage` key: `tippy_creator_checkup_v1`
- `localStorage` fallback
- Bound to anonymous `guestKey`: `tippy_checkup_guest_key_v1`
- Tab-scoped
- TTL: 24 hours from creation

**Session Contains:**
- Entered profile URLs/handles
- Analysis results per platform
- Inferred DNA
- Creator corrections
- Confirmed DNA
- Score preview
- Opportunities
- Recommendations

**Session Cleared On:**
- Logout
- Auth UID change
- 24h expiration
- Guest key mismatch
- Account deletion

**Guest Attach Rules:**
- Server-authorized transfer only
- Current guest session → new UID only
- Not email match, cookie match, or old UID
- Deleted/banned/deactivated UID never inherits
- Conversion is idempotent

---

## Phase 2: Account Creation

### Birthday Gate vs Email Verification Order

**⚠️ Canonical Order (V3.1 Resolution):**

```
Email/Password Signup:
1. Collect email + password + DOB in signup form
2. Create Firebase Auth account
3. Send verification email
4. User verifies email ← BLOCKS HERE
5. After verified, check DOB
6. If DOB valid (≥13), proceed to Tippy questions
7. If DOB invalid (<13), lock and sign out

Google/Apple Signup:
1. OAuth flow creates Auth account
2. Check for DOB immediately
3. If missing, show birthday gate ← BLOCKS HERE
4. If DOB valid (≥13), proceed to Tippy questions
5. If DOB invalid (<13), lock and sign out

Existing Account (Missing DOB):
1. User signs in successfully
2. Server returns birthdayRequired: true
3. Show birthday gate ← BLOCKS HERE
4. After DOB submitted, return to previous lifecycle stage
5. COMPLETE accounts return to app after DOB
```

**Golden Test Required:**
`contracts/birthday-email-verification-order.golden.json` must specify exact ordering for each auth method to prevent web/Flutter parity bugs.

---

### Birthday Gate (Age Verification)

**When it runs depends on auth method** (see canonical order above).

#### When Shown
- Every authenticated account needs valid DOB before proceeding
- Applies to: Email signup, Google, Apple, new or existing accounts
- Unverified password accounts verify email first, then DOB

#### Collection Points

**Email Signup:**
- Website form collects DOB during signup
- Flutter form collects DOB during signup
- Sent to `/api/account/pending`
- Under 13 blocked **before** Auth account exists

**Existing Accounts (Missing DOB):**
- `GET /api/account/status` returns:
  ```json
  {
    "activationState": "BIRTHDAY_REQUIRED",
    "tippyStageHint": "birthday",
    "allowApp": false,
    "birthdayRequired": true,
    "birthdayLocked": false,
    "ageEligibility": {
      "hasDateOfBirth": false,
      "meetsMinimumAge": false,
      "isAdult": false
    }
  }
  ```

#### Routes

| Platform | Route |
|----------|-------|
| **Website** | `/onboarding/birthday` |
| **Flutter** | `BirthdayStepView` in `OnboardingGate` |

#### API

**Write:** `POST /api/account/date-of-birth`
```json
{
  "dateOfBirth": "YYYY-MM-DD"
}
```

**Write-once only** - cannot be changed after submission.

**Stored Fields:**
- `users/{uid}.dateOfBirth` (if user doc exists)
- `pendingAccounts/{uid}.dateOfBirth` (copied at provisioning)
- `dateOfBirthSetAt` (timestamp)
- `dateOfBirthSource`: `signup_form` | `birthday_step`
- `ageGate.status`: `passed` | `under_minimum_age`

#### Under 13 Flow

1. User enters DOB under 13 years
2. Server sets `ageGate.status = under_minimum_age`
3. Step is **locked** (no retry allowed)
4. Client signs out immediately
5. "Not eligible" notice remains on screen
6. Auth account not created (if during signup)

#### Privacy
- DOB **never** mirrored to `publicUsers` collection
- DOB **never** exposed in any public API
- Age-restricted features read `ageEligibility`, never the raw date
- Used only for:
  - Age verification
  - Age-restricted content access (e.g., VI Hub)
  - COPPA compliance

#### Golden Contract
`contracts/birthday-gate.golden.json`

---

### Authentication Methods

**Identical implementation required on both platforms.**

| Provider | Firebase Auth | Notes |
|----------|---------------|-------|
| **Email + Password** | `password` | Requires email verification |
| **Google Sign-In** | `google.com` | Instant authentication |
| **Sign in with Apple** | `apple.com` | Apple privacy features supported |

#### Same Firebase Project
- Both Web and Flutter use the same Firebase project
- Same Auth UID across all providers
- Same `users/{uid}` Firestore document
- No separate "mobile user" or "web user" collections

#### Apple Sign-In Specifics

**Hide My Email:**
- `*@privaterelay.appleid.com` is a valid contact address
- Do **not** assume it matches Google/password email
- Do **not** use as public username
- Private relay emails usually will **not** match other providers

**First Authorization:**
- Apple provides `displayName` (given + family name) and email
- Persist these **only if** fields are still empty
- Apple omits them on later sign-ins (stored from first auth)

**Account Linking:**
- If error: `account-exists-with-different-credential`
- Sign in with original provider first
- Then call `linkWithCredential`
- Handle gracefully - don't lose user data

**Provider-Specific Routing:**
- Existing user → Resume from `GET /api/account/status`
- New user → Same bootstrap as Google (pending → status → onboarding)
- Deleted user → Canonical deletion (don't create new profile on tombstoned UID)
- Deactivated user → Reactivation policy, not new account

---

### Email Verification (Email/Password Only)

**Only required for email/password authentication.**

#### When Required
```json
{
  "activationState": "EMAIL_VERIFICATION_REQUIRED",
  "tippyStageHint": "verify_email",
  "allowApp": false
}
```

#### Flow
1. User creates account with email + password
2. Verification email sent automatically
3. User must click link in email
4. App/website polls for verification status
5. Once verified, proceed to next stage

#### User Actions
- **Resend verification email** (with rate limiting)
- **Change email address** (restarts verification)
- **Sign out** and return later

#### Routes

| Platform | Route |
|----------|-------|
| **Website** | `/onboarding/verify-email` |
| **Flutter** | Email verification screen in onboarding flow |

#### Enforcement
- **Block all app access** until verified
- Can only access:
  - Verification screen
  - Resend button
  - Sign out button
- Cannot:
  - View content
  - Create posts
  - Access dashboard
  - Use Tippy features

---

## Phase 3: Tippy Conversation Machine

### Tippy Stages (Presentation Layer)

**V3.1 Updated Stage Flow:**

```
welcome → questions → dna_reveal → value_map → signup → verify_email 
  → account_secured → avatar → username → bio 
  → platform_handles → profile_review → twitch_connect 
  → notifications → first_growth_plan → creator_space_ready 
  → first_mission → complete
```

**New Stages in V3.1:**
- `value_map` - Product education (after DNA reveal)
- `first_growth_plan` - Explicit plan creation stage
- Enhanced `creator_space_ready` - Activation summary

**Changed from V3.0:**
- Added product value education before auth
- Made first growth plan creation explicit (not hidden in background)
- Transformed creator_space_ready from generic celebration to meaningful activation summary

### Stage Categories

| Category | Stages | Purpose |
|----------|--------|---------|
| **Pre-Verify** | `welcome`, `questions`, `dna_reveal`, `signup`, `verify_email` | Guest conversation + auth |
| **Guided Identity** | `account_secured`, `avatar`, `username`, `bio`, `platform_handles`, `profile_review` | Creator profile setup |
| **Post-Identity** | `twitch_connect`, `notifications`, `creator_space_ready`, `first_mission` | Onboarding completion |

---

### The 7 DNA Questions

**Both platforms must use identical question text, options, and order.**

#### Q1: Platforms
**Question:** "Where are you creating right now?"

**Options:**
- YouTube
- Twitch
- TikTok
- Instagram
- Kick
- Other

**Type:** Multi-select  
**Can Skip:** No  
**Stored:** `users/{uid}.selectedPlatforms[]`

---

#### Q2: Content Type
**Question:** "What type of content do you make?"

**Options:**
- Gaming
- IRL / Lifestyle
- Music / Performance
- Education / Tutorial
- Art / Creative
- Tech / Programming
- Fitness / Sports
- Cooking / Food
- Beauty / Fashion
- Commentary / Discussion
- Other

**Type:** Single select  
**Can Skip:** No  
**Stored:** `users/{uid}.contentType` or in `onboarding.answers.contentType`

---

#### Q3: Niche / Focus
**Question:** "What's your niche or specific focus?"

**Type:** Text input  
**Examples:**
- Specific game (e.g., "Valorant", "Minecraft")
- Specific topic (e.g., "Graphic Design", "Fitness for Beginners")
- Genre (e.g., "Horror Games", "Vegan Cooking")

**Can Skip:** Yes ("I cover multiple things")  
**Stored:** `users/{uid}.niche` or in `onboarding.answers.niche`

---

#### Q4: Goals
**Question:** "What are you trying to achieve?"

**Options:**
- Grow my audience
- Make money / monetize
- Be more consistent
- Improve content quality
- Get discovered
- Build a community
- Learn and improve
- Just have fun

**Type:** Multi-select (max 3)  
**Can Skip:** No  
**Stored:** `users/{uid}.creatorGoals[]` and in Tippy Brain `goals`

---

#### Q5: Experience Level
**Question:** "How long have you been creating content?"

**Options:**
- Just starting (less than 1 month)
- Getting started (1-6 months)
- Building (6 months - 1 year)
- Growing (1-3 years)
- Established (3+ years)

**Type:** Single select  
**Can Skip:** No  
**Stored:** `onboarding.answers.experience`

---

#### Q6: Publishing Cadence
**Question:** "How often do you publish or go live?"

**Options:**
- Multiple times per day
- Daily
- A few times per week
- Weekly
- A few times per month
- Rarely / when I can
- I haven't started yet

**Type:** Single select  
**Can Skip:** No  
**Stored:** `onboarding.answers.cadence`

---

#### Q7: Schedule
**Question:** "When do you usually create?"

**Options:**
- Early morning (6am-9am)
- Morning (9am-12pm)
- Afternoon (12pm-5pm)
- Evening (5pm-9pm)
- Late night (9pm-12am)
- Overnight (12am-6am)
- Weekends
- No consistent schedule

**Type:** Multi-select  
**Can Skip:** No  
**Stored:** `onboarding.answers.schedule[]`

---

### DNA Reveal Phase

After all 7 questions answered:

1. **Processing Animation**
   - "Let me think about this..."
   - Brief pause (realistic, not fake delay)

2. **Personalized Reveal**
   - "Okay, I think I understand what you're building."
   - Summarizes their creator DNA
   - Identifies primary platform strategy
   - Highlights main goal/focus
   - Example: "You're a Twitch-first gaming creator focused on Valorant, trying to grow your audience while staying consistent."

3. **Growth Opportunity**
   - One primary opportunity identified
   - Specific, actionable
   - Based on their answers
   - Example: "Your biggest opportunity is consistency - streaming on a predictable schedule will help you build a loyal audience."

4. **Transition to Auth**
   - "Ready to build your growth plan?"
   - CTA: **"CREATE MY ACCOUNT"** or **"CONTINUE"**

---

### Stage: `value_map` (NEW in V3.1)

**Purpose:** Translate creator DNA into personalized product value

**Timing:** After DNA reveal, before account creation

#### Why This Stage Exists

New creators must understand **what StreamersTip does** and **why it's valuable for them specifically** before committing to sign up.

Generic feature carousels fail. Personalized value based on their answers succeeds.

#### Dynamic Value Translation

**Based on their 7 DNA answers, show:**

**Example 1: Twitch Gaming Creator Focused on Growth**
```
┌─────────────────────────────────────────┐
│  How StreamersTip helps you            │
│                                         │
│  Based on what you told me:             │
│                                         │
│  🎮 You stream on Twitch               │
│  🎯 Your goal is to grow your audience │
│  📅 You publish a few times per week   │
│                                         │
│  Here's what Tippy can do:              │
│                                         │
│  → Turn your streams into clips        │
│  → Build a posting plan that fits      │
│     your schedule                       │
│  → Track what content performs         │
│  → Guide your next move based on       │
│     what works                          │
│                                         │
│  [Create My Account]                    │
└─────────────────────────────────────────┘
```

**Example 2: YouTube Tutorial Creator Focused on Monetization**
```
┌─────────────────────────────────────────┐
│  How StreamersTip helps you            │
│                                         │
│  Based on what you told me:             │
│                                         │
│  📺 You create on YouTube              │
│  💰 Your goal is to monetize           │
│  🎓 You make educational content       │
│                                         │
│  Here's what Tippy can do:              │
│                                         │
│  → Plan content that attracts          │
│     sponsors                            │
│  → Track which topics get the most     │
│     engagement                          │
│  → Build a consistent upload schedule  │
│  → Help you identify monetization      │
│     opportunities                       │
│                                         │
│  [Create My Account]                    │
└─────────────────────────────────────────┘
```

**Example 3: Multi-Platform IRL Creator Just Starting**
```
┌─────────────────────────────────────────┐
│  How StreamersTip helps you            │
│                                         │
│  Based on what you told me:             │
│                                         │
│  📱 You're on TikTok and Instagram     │
│  🌟 You're just getting started        │
│  🎥 You make IRL lifestyle content     │
│                                         │
│  Here's what Tippy can do:              │
│                                         │
│  → Help you post consistently          │
│  → Generate content ideas when         │
│     you're stuck                        │
│  → Show you what's working (and        │
│     what's not)                         │
│  → Guide you step by step as you       │
│     learn                               │
│                                         │
│  [Create My Account]                    │
└─────────────────────────────────────────┘
```

#### Translation Rules

**Map DNA → Product Value:**

| DNA Signals | Product Value Message |
|-------------|----------------------|
| **Twitch/YouTube Live** | Turn streams into clips, plan live schedule |
| **Multi-platform** | Manage all platforms in one place, cross-post |
| **Goal: Grow** | Track what performs, get discovered |
| **Goal: Monetize** | Identify monetization opportunities, attract sponsors |
| **Goal: Consistency** | Build a posting plan, stay on track |
| **Just starting** | Step-by-step guidance, learn as you go |
| **Established (3+ years)** | Optimize what's working, scale your system |
| **No consistent schedule** | Create a realistic plan, track progress |
| **Niche specified** | Personalize to their specific niche |

#### Personalization Engine

**Server generates `valueMapContent` based on:**
```javascript
{
  platforms: ["twitch"],
  goals: ["grow_audience"],
  experience: "building",
  cadence: "few_times_week"
}

↓

{
  intro: "Based on what you told me:",
  signals: [
    "You stream on Twitch",
    "Your goal is to grow your audience",
    "You publish a few times per week"
  ],
  capabilities: [
    "Turn your streams into clips",
    "Build a posting plan that fits your schedule",
    "Track what content performs",
    "Guide your next move based on what works"
  ],
  cta: "Create My Account"
}
```

#### Storage

**Persisted to session:**
```json
{
  "onboarding": {
    "valueMapViewed": true,
    "valueMapContent": {
      "signals": ["..."],
      "capabilities": ["..."]
    }
  }
}
```

#### Copy Guidelines

**DO:**
- ✅ Use their specific platforms
- ✅ Echo their stated goals
- ✅ Be concrete (not vague "grow your creator business")
- ✅ Show 3-5 specific capabilities
- ✅ Make it feel personalized to them

**DON'T:**
- ❌ Generic "StreamersTip is a creator platform"
- ❌ Feature list ("Analytics, Planner, Editor")
- ❌ Jargon ("Leverage AI-powered insights")
- ❌ Over-promise ("Go viral in 30 days")

#### Analytics Event

`value_map_viewed` with payload:
```json
{
  "platforms": ["twitch"],
  "goals": ["grow_audience"],
  "experience": "building",
  "personalizedSignals": 3,
  "personalizedCapabilities": 4
}
```

---

### Checkup Context Integration

**If user came from Path B (Creator Checkup):**

#### Skipped Questions
- **Platforms question** skipped if Checkup had submitted/confirmed platforms
- All other questions still asked (goals, experience, schedule)

#### Prefilled Answers
- **Confirmed DNA** from Checkup prefills answers
- User sees filled form, can edit
- Example: "I saw you're on Twitch and YouTube" (pre-selected)

#### Suggested Answers
- **Unconfirmed inferred** DNA shows as suggestions
- Clearly marked as suggestions
- User can accept or change

#### Compact Confirmation
- Copy: "Perfect. I brought over what I learned."
- "I already have a picture of what you're creating."
- "Now I want to understand where you want to take it."
- Show prefilled answers
- CTA: **"LOOKS RIGHT"** / **"EDIT"**

#### Profile Socials
- `platform_handles` step still shown (not skipped)
- Prefilled with Checkup-provided handles
- User can:
  - Keep all
  - Edit any
  - Add more
  - Skip for now
- Copy: "Want people to find you elsewhere?"

---

### Conversation Continuity

**Session Storage:** `tippy_onboarding_v3`

**Persisted State:**
- `sessionId` - Unique session identifier
- `conversationAct` - Current conversation phase
- `conversationTurn` - Turn number in conversation
- `completedSteps` - Array of completed stage IDs
- `conversationTimeline[]` - Full conversation history
  - `stepId`
  - `turn`
  - `message`
  - `secondaryDelivered` (speech/animation state)
- `answers` - All DNA question answers
- `generatedPreview` - Growth plan preview
- `creatorScorePreview` - Score calculation
- `growthOpportunity` - Identified opportunity
- `growthFocus` - Recommended focus
- `initialGrowthPlan` - First plan draft
- `lastTippyMessage` - Last displayed message
- `secondarySpeechDelivered` - Speech/animation tracking
- `accountCreated` - Auth completed timestamp
- `claimedUid` - Firebase Auth UID
- `emailVerified` - Verification status
- `profileSetupProgress` - Identity completion tracking

**Checkup-Specific Fields:**
- `checkupIntention` - User's stated intention from Checkup
- `checkupProfiles` - Analyzed platform profiles
- `checkupSuggestedAnswers` - Inferred DNA from Checkup
- `checkupConfirmedAnswers` - User-confirmed DNA
- `checkupHandoffConfirmResolved` - Compact confirm completed
- `checkupPresenceSummary` - Checkup analysis summary

**Continuity Rules:**
1. Already `INTRODUCED` (or later) never shows intro again
2. Checkup handoff never shows "Hey I'm Tippy"
3. Back button restores exact committed turn
4. Forward after Back doesn't replay delivered speech
5. Survives refresh, close, verify, Google auth, Apple auth
6. Guest→auth transfer preserves all state

**Authority:**
- **Website SoT:** `lib/onboarding/tippyConversationContinuity.ts`
- **Flutter Mirror:** `lib/features/onboarding_tippy/tippy_conversation_continuity.dart`

---

## Phase 4: Creator Identity

### Stage: `account_secured`

**Transition screen after email verification or social auth.**

- Brief message: "Your account is secured"
- Automatic progression to `avatar` stage
- No user action required
- Duration: 2-3 seconds

---

## Phase 4: Creator Identity (Building Your Workspace)

**Philosophy Change (V3.1):**

Instead of: "Fill out your profile"  
Frame as: **"Build your creator workspace"**

Each field should explain **why StreamersTip needs it** and **what value it unlocks**.

---

### Stage: `avatar`

**Purpose:** Upload profile photo

**V3.1 Enhanced Copy:**

**Before (Generic):**
- "Upload your profile photo"

**After (Value-Driven):**
- **"Set your creator avatar"**
- Explanation: "This is how you'll appear to your audience on StreamersTip. A recognizable photo helps people discover and remember you."
- Value unlock: "Profile photos get 3x more engagement"

#### Options
1. **Upload Photo**
   - From device gallery
   - Aspect ratio: Square (1:1)
   - Min size: 200x200px
   - Max size: 5MB
   - Formats: JPG, PNG, WebP

2. **Take Photo**
   - Flutter: Opens camera
   - Web: File picker (no camera access)

3. **Skip**
   - Button: "Do this later"
   - Sets `photoStatus: 'skipped'`
   - Can upload later in settings

#### Storage
- Uploaded to Firebase Storage: `avatars/{uid}/avatar.jpg`
- URL stored in:
  - `users/{uid}.avatarURL`
  - `users/{uid}.photoURL`
  - `publicUsers/{uid}.avatar`
- `users/{uid}.onboarding.photoStatus`: `uploaded` | `skipped` | `not_started`

#### Validation
- File type check
- File size check (≤5MB)
- Image dimensions check (≥200x200)
- Automatic cropping to square if needed

---

### Stage: `username`

**Purpose:** Claim unique username

**V3.1 Enhanced Copy:**

**Before (Generic):**
- "Choose your username"

**After (Value-Driven):**
- **"Claim your creator handle"**
- Explanation: "Your username is your identity across StreamersTip. Choose something memorable that matches your brand."
- Value unlock: "This becomes your profile URL: streamerstip.com/@yourname"

#### Rules
- **Length:** 3-20 characters
- **Allowed:** Alphanumeric + underscore
- **Pattern:** `/^[a-zA-Z0-9_]{3,20}$/`
- **Case:** Case-insensitive for uniqueness
- **Reserved:** System usernames blocked (admin, support, etc.)

#### Real-Time Validation

**As user types:**
1. Local validation (length, pattern)
2. Debounced availability check (500ms)
3. API call: `GET /api/account/username-available?username={value}`
4. Show availability status:
   - ✅ Available
   - ❌ Already taken
   - ⏳ Checking...
   - ⚠️ Invalid format

#### Storage
- `users/{uid}.username` - Display version (preserves case)
- `users/{uid}.usernameNormalized` - Lowercase for queries
- `usernames/{normalized}` - Reservation document
  ```json
  {
    "uid": "user123",
    "claimedAt": "2026-10-14T23:00:00Z",
    "username": "CoolGamer" // Display version
  }
  ```
- `publicUsers/{uid}.username` - Public mirror

#### Uniqueness Enforcement
- Firestore Security Rules enforce uniqueness
- Backend validates on write
- Username change has 14-day quarantine (old username held)
- Account deletion releases immediately

#### Suggestions
If desired username taken, suggest:
- `{username}_{random2digits}`
- `{username}_official`
- `{username}_tv`

---

### Stage: `bio`

**Purpose:** Short creator bio/description

**V3.1 Enhanced Copy:**

**Before (Generic):**
- "Write your bio"

**After (Value-Driven):**
- **"Tell people what you create"**
- Explanation: "Help your audience and potential collaborators understand what you're about at a glance."
- Value unlock: "Creators with bios get 2x more followers"

#### Requirements
- **Max length:** 160 characters
- **Optional:** Can skip
- **Format:** Plain text (no markdown)
- **Validation:** No URLs, no excessive special characters

#### Prompt
- "Tell people what your content is about"
- "What should people know about you?"

#### Example Placeholders
- "Gaming content creator focused on competitive FPS"
- "Daily Minecraft builder & storyteller"
- "Just a gamer trying to make it!"

#### Storage
- `users/{uid}.bio`
- `publicUsers/{uid}.bio`

#### Skip Option
- Button: "Skip for now"
- Bio remains empty string
- Can fill later in profile settings

---

### Stage: `platform_handles`

**Purpose:** Connect external social profiles

**V3.1 Enhanced Copy:**

**Before (Generic):**
- "Add your social links"

**After (Value-Driven):**
- **"Connect your platforms"**
- Explanation: "Your platforms help Tippy understand where you create and personalize recommendations. This also helps your audience find you everywhere."
- Value unlock: "Tippy uses this to give you platform-specific advice"

#### Platforms Supported
- YouTube
- Twitch
- TikTok
- Instagram
- Twitter/X
- Discord
- Kick
- Facebook Gaming

#### Input Format

**Flexible input - accepts:**
- Full URL: `https://twitch.tv/coolgamer`
- Username with @: `@coolgamer`
- Plain handle: `coolgamer`

**Auto-parsing:**
- Extract handle from URL
- Remove @ prefix if present
- Validate format per platform
- Show preview of full URL

#### UI Flow

1. **Platform Selection**
   - List of platform icons
   - Click to add

2. **Handle Input**
   - Text field for username/URL
   - Live preview of profile link
   - "Add Another" button
   - Added handles show as chips (removable)

3. **Review**
   - List of all added platforms
   - Edit or remove any
   - Reorder (optional)

#### Checkup Integration

**If from Path B:**
- Prefilled with Checkup-analyzed profiles
- Each appears as editable chip
- User can keep, edit, or remove
- Can add additional platforms not in Checkup

**Copy:** "Want people to find you elsewhere?"

#### Storage
```json
{
  "users/{uid}": {
    "connectedPlatforms": [
      {
        "platform": "twitch",
        "handle": "coolgamer",
        "url": "https://twitch.tv/coolgamer",
        "addedAt": "2026-10-14T23:00:00Z"
      },
      {
        "platform": "youtube",
        "handle": "@CoolGamerYT",
        "url": "https://youtube.com/@CoolGamerYT",
        "addedAt": "2026-10-14T23:00:00Z"
      }
    ]
  }
}
```

Also mirrored to `publicUsers/{uid}.socialLinks[]`

#### Skip Option
- "Skip for now" button
- Can add later in profile settings
- Highly recommended but not required

---

### Stage: `profile_review`

**Purpose:** Final review before activation

#### Display

**Profile Preview Card:**
```
┌─────────────────────────────┐
│    [Avatar Image]           │
│                             │
│    @username                │
│    Display Name             │
│                             │
│    "Bio text here..."       │
│                             │
│    📺 Twitch: @handle       │
│    🎮 YouTube: @handle      │
│                             │
│    [Edit Profile]           │
│    [Looks Good!]            │
└─────────────────────────────┘
```

#### Actions

**Edit Profile:**
- Goes back to `username` stage
- Preserves all entered data
- Can navigate to any identity stage
- Back button returns to review

**Looks Good:**
- Proceeds to next stage
- Finalizes profile setup
- `essentialProfileComplete: true`
- Sets `profileSetupProgress.completed: true`

#### Validation
- Avatar: uploaded or skipped
- Username: claimed and valid
- Bio: entered or skipped
- Socials: added or skipped

All required fields must be completed before "Looks Good" enables.

---

## Phase 5: Activation & First Mission

### Stage: `twitch_connect`

**Purpose:** Optional Twitch OAuth connection

#### When Shown
- Only if user selected Twitch in platforms question
- Or added Twitch in `platform_handles`
- Skip if Twitch not relevant

#### OAuth Flow

1. **Prompt**
   - "Connect your Twitch account?"
   - Benefits listed:
     - Sync stream schedule
     - Import viewer stats
     - Track growth metrics
   - CTAs: **"Connect Twitch"** | **"Maybe Later"**

2. **OAuth Redirect**
   - Opens Twitch authorization
   - Requested scopes:
     - `user:read:email`
     - `user:read:broadcast` (optional)
     - `channel:read:subscriptions` (optional)
   - Handles callback with authorization code

3. **Token Exchange**
   - Backend exchanges code for access/refresh tokens
   - Stores securely in `users/{uid}/private/twitch`
   - Never exposes tokens to client

4. **Success**
   - "Twitch connected!"
   - Profile imports:
     - Twitch avatar (if user skipped avatar upload)
     - Display name (if empty)
     - Bio (if empty)
   - Schedule sync enabled

#### Storage
```json
{
  "users/{uid}": {
    "twitchConnected": true,
    "twitchUserId": "12345678",
    "twitchUsername": "coolgamer"
  },
  "users/{uid}/private/twitch": {
    "accessToken": "encrypted",
    "refreshToken": "encrypted",
    "expiresAt": "2026-10-15T23:00:00Z",
    "scopes": ["user:read:email"]
  }
}
```

#### Skip Option
- **"Maybe Later"** button
- Can connect later in settings
- No penalty for skipping
- Optional feature

---

### Stage: `notifications`

**Purpose:** Request push notification permission

#### Permission Request

**Copy:**
- "Stay updated with your creator journey"
- Benefits:
  - New follower alerts
  - Content performance updates
  - Tippy recommendations
  - Mission completions
  - Community interactions

**Actions:**
- **"Enable Notifications"** → Request OS permission
- **"Not Now"** → Skip (can enable later in settings)

#### Platform-Specific

**Flutter (Mobile):**
- Uses `firebase_messaging` package
- Requests iOS/Android permission
- Stores FCM token in `users/{uid}/private/fcmTokens[]`
- Subscribes to topics:
  - `user_{uid}`
  - `creator_updates`
  - `tippy_notifications`

**Web:**
- Requests browser notification permission
- Uses Firebase Cloud Messaging Web
- Stores web push token

#### Storage
```json
{
  "users/{uid}": {
    "notificationsEnabled": true,
    "notificationPreferences": {
      "newFollower": true,
      "videoPerformance": true,
      "tippyRecommendations": true,
      "missions": true,
      "community": true
    }
  }
}
```

---

### Stage: `first_growth_plan` (NEW in V3.1)

**Purpose:** Create the creator's first personalized growth plan

**Timing:** After Twitch/notifications, before creator_space_ready

#### Why This Stage Exists

ACTIVATED should mean the creator has a **clear next focus**, not just completed forms. The first growth plan gives them direction.

#### Flow

1. **Intro**
   - "Based on what you told me, here's your first growth focus"
   - Shows their primary goal
   - Shows their current situation

2. **Plan Generation**
   - Tippy creates a personalized plan
   - Based on: platforms, goals, experience, cadence, schedule
   - 1-2 week starter plan (not overwhelming)

3. **Plan Preview**
   ```
   ┌──────────────────────────────────────┐
   │  Your First Growth Plan              │
   │                                      │
   │  Focus: Consistent Streaming         │
   │                                      │
   │  Week 1:                             │
   │  □ Stream Monday 7pm                 │
   │  □ Stream Wednesday 7pm              │
   │  □ Create 2 clips from best moments  │
   │  □ Post clips to YouTube             │
   │                                      │
   │  Why this plan:                      │
   │  You told me you want to grow your   │
   │  audience and you stream a few times │
   │  per week. Consistency + discoverability│
   │  is your best lever right now.       │
   │                                      │
   │  [Start This Plan]                   │
   │  [Customize It]                      │
   └──────────────────────────────────────┘
   ```

4. **Confirmation**
   - User accepts or customizes
   - Plan stored to `users/{uid}/contentPlans/{planId}`
   - `firstGrowthPlanId` saved to onboarding doc

#### Storage

```json
{
  "onboarding": {
    "firstGrowthPlanCreated": true,
    "firstGrowthPlanId": "plan_001",
    "growthFocus": "Consistency + discoverability"
  },
  "users/{uid}/contentPlans/plan_001": {
    "id": "plan_001",
    "title": "Consistent Streaming Plan",
    "focus": "Consistency + discoverability",
    "startDate": "2026-10-15",
    "endDate": "2026-10-29",
    "items": [
      {
        "id": "item_001",
        "type": "stream",
        "title": "Stream Monday 7pm",
        "scheduledFor": "2026-10-15T19:00:00Z",
        "status": "planned"
      }
    ],
    "createdAt": "2026-10-15T00:00:00Z",
    "source": "onboarding_tippy"
  }
}
```

#### Plan Types by Creator DNA

| DNA | First Plan Focus |
|-----|------------------|
| **Twitch/YouTube Live + Goal: Grow** | Consistent streaming + clip repurposing |
| **YouTube Video + Goal: Monetize** | High-value topic calendar |
| **Multi-platform + Goal: Consistency** | Cross-posting workflow |
| **Just starting + any goal** | Simple weekly posting schedule |
| **Established + Goal: Grow** | Content optimization + discoverability |

#### Analytics Event

`first_growth_plan_created` with payload:
```json
{
  "planId": "plan_001",
  "focus": "Consistency + discoverability",
  "itemCount": 4,
  "weeksCovered": 2,
  "primaryPlatform": "twitch",
  "primaryGoal": "grow_audience"
}
```

---

### Stage: `creator_space_ready` (V3.1 ENHANCED)

**Purpose:** Activation summary - not generic celebration

**V3.1 Complete Redesign:**

**Before (Generic):**
```
🎉 Your Creator Space is Ready!

You're all set to start building your creator journey.

[Start Creating]
```

**After (Meaningful Activation Summary):**
```
┌─────────────────────────────────────────┐
│  Your creator system is ready.          │
│                                         │
│  ✅ Tippy knows your goals              │
│     (Grow audience, be consistent)      │
│                                         │
│  ✅ Your creator profile is set         │
│     (@coolgamer)                        │
│                                         │
│  ✅ Your platforms are mapped           │
│     (Twitch, YouTube)                   │
│                                         │
│  ✅ Your first growth focus is ready    │
│     (Consistency + discoverability)     │
│                                         │
│  ✅ Your first mission is waiting       │
│     (Create your first clip)            │
│                                         │
│  [Go to Mission Control]                │
└─────────────────────────────────────────┘
```

**Key Differences:**

1. **Not generic celebration** - Specific to what they set up
2. **Shows what was accomplished** - Echo their inputs
3. **Shows what's ready** - First plan, first mission
4. **Clear next action** - "Go to Mission Control" (not vague "Start Creating")
5. **Ties onboarding to product** - Mission Control is their hub

#### Copy Rules

**DO:**
- ✅ Echo their username
- ✅ Echo their goals
- ✅ Echo their platforms  
- ✅ Show their growth focus
- ✅ Name their first mission
- ✅ Use "your creator system" language

**DON'T:**
- ❌ Generic "You're all set!"
- ❌ Feature list of what's available
- ❌ Confetti animations without substance
- ❌ Unclear next step

#### Optional Product Map (V3.1 NEW)

**Before going to Mission Control, show 3-card product orientation:**

```
┌────────────────────────────────────────────────┐
│  What you can do in StreamersTip               │
│                                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │   Plan   │  │  Create  │  │   Grow   │    │
│  │          │  │          │  │          │    │
│  │ Turn     │  │ Record,  │  │ Use      │    │
│  │ ideas    │  │ edit,    │  │ Tippy,   │    │
│  │ into a   │  │ publish, │  │ analytics│    │
│  │ creator  │  │ and      │  │ missions │    │
│  │ plan.    │  │ repurpose│  │ and      │    │
│  │          │  │ content. │  │ Creator  │    │
│  │          │  │          │  │ Academy  │    │
│  │          │  │          │  │ to       │    │
│  │          │  │          │  │ improve. │    │
│  └──────────┘  └──────────┘  └──────────┘    │
│                                                │
│  [Got it, let's go]                           │
└────────────────────────────────────────────────┘
```

**Not 5 slides. Not a tutorial. Just 3 cards in one screen.**

Answers: "What did I just sign up for?"

#### Analytics Event

`creator_space_ready_viewed` with payload:
```json
{
  "username": "coolgamer",
  "platforms": ["twitch", "youtube"],
  "goals": ["grow_audience", "monetize"],
  "firstPlanReady": true,
  "firstMissionReady": true
}
```

#### Optional Quick Tour
- 3-5 slide carousel (swipeable)
- Key features highlighted:
  1. Content Planner
  2. Ask Tippy (AI assistant)
  3. Mission Control / Dashboard
  4. Analytics
  5. Profile & Settings

**Actions:**
- **"Start Creating"** → Proceed to app
- **"Skip Tour"** → Skip slides, go to app

---

### Stage: `first_mission` (V3.1 ENHANCED)

**Purpose:** Assign **meaningful** first activation action

**Philosophy Change:**

Make the first mission a **real activation action** that creates value, not just gamification.

#### V3.1 Mission Priority

**High-Value Activation Actions (Prioritize These):**

1. **"Ask Tippy for your first content idea"**
   - Engages core product (Tippy AI)
   - Immediately useful
   - Teaches how to use Ask Tippy
   - XP: 100

2. **"Create your first plan in Content Planner"**
   - Only if first_growth_plan was skipped/customized
   - Engages planning workflow
   - Drives retention
   - XP: 150

3. **"Upload your first video"**
   - Core content creation action
   - Populates their profile
   - Tests upload flow
   - XP: 200

4. **"Connect your primary creator platform"**
   - Only if Twitch/YouTube not connected in onboarding
   - Unlocks authorized analytics
   - Enables deeper Tippy insights
   - XP: 100

5. **"Create your first clip from a stream"**
   - For live streamers specifically
   - Teaches content repurposing
   - Immediate output
   - XP: 150

**Low-Value Actions (Deprioritize):**

- ❌ "Complete your profile" - Already done in onboarding
- ❌ "Introduce yourself" - Low activation value
- ❌ "Explore StreamersTip" - Not actionable

#### Mission Assignment Logic

**Server automatically assigns based on:**
- Creator DNA (platforms, content type, goals)
- What they've already done
- Highest-value next action

#### Mission Display

```
┌─────────────────────────────┐
│  🎯 Your First Mission      │
│                             │
│  Upload Your First Video    │
│                             │
│  Get started by sharing     │
│  your first piece of        │
│  content on StreamersTip.   │
│                             │
│  Reward: 100 XP             │
│                             │
│  [View Mission]             │
│  [Do This Later]            │
└─────────────────────────────┘
```

#### Storage
```json
{
  "users/{uid}/missions/mission_001": {
    "id": "mission_001",
    "type": "first_video_upload",
    "status": "active",
    "assignedAt": "2026-10-14T23:00:00Z",
    "xpReward": 100,
    "title": "Upload Your First Video",
    "description": "Share your first content...",
    "requirements": {
      "uploadCount": 1
    }
  }
}
```

#### Actions
- **"View Mission"** → Opens Mission Control with mission details
- **"Do This Later"** → Skip to app (mission remains active)

---

### Stage: `complete` / ACTIVATED

**Lifecycle Status:** `ACTIVATED`

#### Completion Criteria
```json
{
  "activationState": "ACTIVATED",
  "users/{uid}.onboarding": {
    "lifecycle": "COMPLETE",
    "tippyFunnelCompleted": true,
    "essentialProfileComplete": true,
    "creatorCardCompleted": true,
    "completed": true,
    "completedAt": "2026-10-14T23:00:00Z"
  }
}
```

#### What Gets Unlocked
- ✅ Full app access (Home, For You, Messages)
- ✅ Content creation (Post, Upload Video)
- ✅ Content Planner
- ✅ Ask Tippy (full AI assistant)
- ✅ Creator Dashboard & Analytics
- ✅ Mission Control & XP system
- ✅ Profile editing
- ✅ Settings & preferences
- ✅ Community features (comments, likes, follows)

#### Navigation
- **First-time:** Lands on Home feed or Creator Dashboard
- **Returning:** Resumes last location (preserved in session)

#### Celebration (Optional)
- Brief confetti animation
- "Welcome to StreamersTip!" message
- Auto-dismisses after 3 seconds

---

## Data Storage Contract

### Canonical User Document

**Path:** `users/{uid}`

```json
{
  // Identity
  "uid": "abc123",
  "email": "user@example.com",
  "displayName": "Cool Gamer",
  "username": "coolgamer",
  "usernameNormalized": "coolgamer",
  "bio": "Gaming content creator focused on FPS",
  "avatarURL": "https://storage.googleapis.com/...",
  "photoURL": "https://storage.googleapis.com/...",
  
  // Privacy
  "dateOfBirth": "1995-06-15", // Private, never public
  "ageGate": {
    "status": "passed",
    "checkedAt": "2026-10-14T22:00:00Z"
  },
  
  // Account Status
  "accountStatus": "active", // active | deactivated | banned | deleting | deleted
  "createdAt": "2026-10-14T22:00:00Z",
  "lastLoginAt": "2026-10-14T23:00:00Z",
  
  // Onboarding (V3.1 Enhanced)
  "onboarding": {
    "version": 3.1,
    "lifecycle": "COMPLETE", // NEW | TIPPY | VERIFY | CLASSIC | COMPLETE
    "tippyStage": "complete",
    "completed": true,
    "completedAt": "2026-10-15T00:00:00Z",
    "tippyFunnelCompleted": true,
    "essentialProfileComplete": true,
    "creatorCardCompleted": true,
    "valueEducationCompleted": true, // NEW V3.1
    "firstGrowthPlanCreated": true, // NEW V3.1
    "firstGrowthPlanId": "plan_001", // NEW V3.1
    "firstActivationAction": "ask_tippy", // NEW V3.1
    "slim7Completed": false,
    "hasSeenIntro": true,
    "startedFromCheckup": true,
    "photoStatus": "uploaded", // uploaded | skipped | not_started
    "valueMapViewed": true, // NEW V3.1
    "productMapViewed": true, // NEW V3.1
    "profileSetupProgress": {
      "avatar": "completed",
      "username": "completed",
      "bio": "completed",
      "socials": "completed",
      "completed": true
    },
    "answeredQuestions": {
      "platforms": ["twitch", "youtube"],
      "contentType": "gaming",
      "niche": "Valorant",
      "goals": ["grow_audience", "monetize"],
      "experience": "building",
      "cadence": "few_times_week",
      "schedule": ["evening", "late_night"]
    }
  },
  
  // Creator Profile
  "selectedPlatforms": ["twitch", "youtube"],
  "contentType": "gaming",
  "niche": "Valorant",
  "creatorGoals": ["grow_audience", "monetize"],
  "connectedPlatforms": [
    {
      "platform": "twitch",
      "handle": "coolgamer",
      "url": "https://twitch.tv/coolgamer",
      "addedAt": "2026-10-14T23:00:00Z"
    },
    {
      "platform": "youtube",
      "handle": "@CoolGamerYT",
      "url": "https://youtube.com/@CoolGamerYT",
      "addedAt": "2026-10-14T23:00:00Z"
    }
  ],
  
  // Integrations
  "twitchConnected": true,
  "twitchUserId": "12345678",
  "twitchUsername": "coolgamer",
  
  // Preferences
  "appearance": "system", // light | dark | system
  "notificationsEnabled": true,
  
  // Gamification
  "xp": 100,
  "level": 1,
  "missions": {
    "active": ["mission_001"],
    "completed": []
  }
}
```

---

### Public User Document

**Path:** `publicUsers/{uid}`

Public mirror - **never contains private data**

```json
{
  "uid": "abc123",
  "username": "coolgamer",
  "displayName": "Cool Gamer",
  "bio": "Gaming content creator focused on FPS",
  "avatar": "https://storage.googleapis.com/...",
  "contentType": "gaming",
  "platforms": ["twitch", "youtube"],
  "socialLinks": [
    {
      "platform": "twitch",
      "url": "https://twitch.tv/coolgamer"
    }
  ],
  "followerCount": 0,
  "followingCount": 0,
  "videoCount": 0,
  "createdAt": "2026-10-14T22:00:00Z",
  "accountStatus": "active"
}
```

**Never includes:**
- `dateOfBirth`
- `email`
- Auth tokens
- Private analytics
- IP addresses
- Device info

---

### Tippy Brain Document

**Path:** `users/{uid}/creatorMemory/main`

Canonical Tippy intelligence store.

```json
{
  // Creator DNA
  "creatorDNA": {
    "platforms": ["twitch", "youtube"],
    "contentType": "gaming",
    "niche": "Valorant",
    "goals": ["grow_audience", "monetize"],
    "experience": "building",
    "cadence": "few_times_week",
    "schedule": ["evening", "late_night"]
  },
  
  // Confirmed Facts
  "confirmedFacts": [
    {
      "statement": "Primary platform is Twitch",
      "type": "confirmed",
      "source": "creator_stated",
      "confidence": "high",
      "createdAt": "2026-10-14T23:00:00Z"
    }
  ],
  
  // Observations (from Checkup or connected data)
  "observations": [
    {
      "statement": "Streams 3-4 times per week",
      "type": "observation",
      "source": "twitch_api",
      "evidenceIds": ["obs_001"],
      "confidence": "high",
      "createdAt": "2026-10-14T23:00:00Z"
    }
  ],
  
  // Inferences
  "inferences": [
    {
      "statement": "Consistency is the primary lever for growth",
      "type": "inference",
      "source": "checkup_analysis",
      "evidenceIds": ["obs_001", "obs_002"],
      "confidence": "medium",
      "createdAt": "2026-10-14T23:00:00Z"
    }
  ],
  
  // Platform Intelligence
  "platformIntelligence": {
    "twitch": {
      "profileUrl": "https://twitch.tv/coolgamer",
      "analyzedAt": "2026-10-14T22:30:00Z",
      "status": "analyzed",
      "observations": {
        "followerCount": 1250,
        "avgViewers": 45,
        "streamSchedule": ["monday_evening", "wednesday_evening"]
      }
    }
  },
  
  // Current Strategy
  "currentStrategy": {
    "goal": "Grow audience to 5k followers",
    "recommendedFocus": "Consistency + discoverability",
    "weeklyFocus": null // Reserved for Phase 3
  },
  
  // Growth Plan Reference
  "growthPlan": {
    "planId": "plan_001",
    "createdAt": "2026-10-14T23:00:00Z"
  },
  
  // Metadata
  "updatedAt": "2026-10-14T23:00:00Z",
  "brainVersion": 1
}
```

---

### Onboarding Session (Guest)

**Storage:** `sessionStorage.tippy_onboarding_v3` or `localStorage` fallback

```json
{
  "sessionId": "session_abc123",
  "version": 3,
  "createdAt": "2026-10-14T22:00:00Z",
  "expiresAt": "2026-10-15T22:00:00Z",
  
  // Progress
  "conversationAct": "questions",
  "conversationTurn": 5,
  "completedSteps": ["welcome", "platforms", "contentType"],
  
  // Answers
  "answers": {
    "platforms": ["twitch", "youtube"],
    "contentType": "gaming",
    "niche": "Valorant"
  },
  
  // Auth State
  "accountCreated": true,
  "claimedUid": "abc123",
  "emailVerified": false,
  
  // Checkup Context (if from Path B)
  "startedFromCheckup": true,
  "checkupProfiles": [
    {
      "platform": "twitch",
      "profileUrl": "https://twitch.tv/coolgamer",
      "status": "analyzed"
    }
  ],
  "checkupConfirmedAnswers": {
    "platforms": ["twitch"]
  },
  "checkupSuggestedAnswers": {
    "contentType": "gaming",
    "cadence": "few_times_week"
  }
}
```

---

## Close & Resume Behavior

### X Button = "Not Now" (Never "Start Over")

#### What X Does
- ✅ Saves all progress
- ✅ Preserves answered questions
- ✅ Keeps session alive (24h for guest, indefinite for auth)
- ✅ Allows resume later

#### What X Does NOT Do
- ❌ Delete answers
- ❌ Reset lifecycle
- ❌ Mark onboarding complete
- ❌ Start over from beginning
- ❌ Create a new session

---

### Resume Logic

#### Guest Session (Pre-Auth)

**Storage:** `sessionStorage` or `localStorage`  
**TTL:** 24 hours

**Resume Behavior:**
1. Check for `tippy_onboarding_v3` session
2. If found and not expired:
   - Restore `conversationTurn`
   - Restore `answers`
   - Resume at next unanswered question
   - Show welcome-back copy: "Welcome back. Ready to keep going?"

3. If expired or missing:
   - Start fresh
   - Show first-meet copy

#### Authenticated User

**Storage:** `users/{uid}.onboarding`  
**TTL:** None (permanent until completed)

**Resume Behavior:**
1. Fetch `GET /api/account/status`
2. Read `tippyStageHint` from response
3. Route to that exact stage
4. Prefill any saved data:
   - Answered questions
   - Uploaded avatar
   - Claimed username
   - Connected platforms

**Welcome-Back Copy:**
- If progress exists: "Welcome back. Ready to keep going?"
- If mid-stage: "Let's pick up where you left off."
- If checkup transferred: "Welcome back. I still have your YouTube and Twitch profiles."

---

### Checkup Resume

**Storage:** `sessionStorage.tippy_creator_checkup_v1`  
**TTL:** 24 hours

**Resume Behavior:**

**If profiles entered but not analyzed:**
- Return to profile input step
- Show entered profiles (editable)
- Copy: "Welcome back. I still have your [platform] profiles. Ready to keep going?"
- CTA: **"ANALYZE MY CREATOR PRESENCE"**

**If analyzed but not confirmed:**
- Return to confirmation step
- Show analysis results
- Copy: "Welcome back. I finished looking while you were away."
- CTA: **"YES, THAT'S ME"** / **"LET ME CORRECT SOMETHING"**

**If confirmed (reached results):**
- Return to results page
- Show score preview + findings
- Copy: "Welcome back. Here's what I learned."
- CTA: **"CONTINUE WITH TIPPY"**

**Never:**
- Re-ask for profiles already provided
- Re-run analysis already completed
- Show first-meet copy when progress exists

---

## Enforcement & Edge Cases

### Banned Account

**Status:** `accountStatus = "banned"`

**Also applies to legacy:** `suspended`, `disabled`

#### Screen Display

**Full-screen enforcement (blocks all app access)**

```
┌─────────────────────────────┐
│                             │
│    ⚠️ Account suspended     │
│                             │
│  Your StreamersTip account  │
│  has been suspended because │
│  it did not meet our        │
│  Community Guidelines or    │
│  Terms of Service.          │
│                             │
│  [Get Help / Appeal]        │
│  [Sign Out]                 │
│                             │
└─────────────────────────────┘
```

#### Copy (Exact Text Required)
**Title:** "Account suspended"

**Body:** "Your StreamersTip account has been suspended because it did not meet our Community Guidelines or Terms of Service."

#### Available Actions
- **Get Help / Appeal:**
  - Web: Opens `/feedback-help` or links to `contact@streamerstip.com`
  - Flutter: Opens email client or in-app support
- **Sign Out:**
  - Logs user out
  - Returns to logged-out landing page

#### What's Blocked
- ❌ Home / For You feed
- ❌ Messages
- ❌ Post / Upload
- ❌ Profile editing
- ❌ Dashboard / Analytics
- ❌ Tippy features
- ❌ Settings (except to sign out)
- ❌ Any authenticated actions

#### Public Profile
- Profile hidden from public view
- Videos hidden from feeds
- Search results removed
- Direct links return 404 or "Account unavailable"

#### Detection
- Check `accountStatus` on:
  - App launch
  - After authentication
  - Periodically while active (every 5 minutes)
- Token revocation not sufficient alone
- Must actively check Firestore `users/{uid}.accountStatus`

---

### Deactivated Account

**Status:** `accountStatus = "deactivated"`

#### Screen Display

```
┌─────────────────────────────┐
│                             │
│  Account deactivated        │
│                             │
│  Your account is currently  │
│  deactivated. You can       │
│  reactivate it at any time. │
│                             │
│  [Reactivate]               │
│  [Settings]                 │
│  [Sign Out]                 │
│                             │
└─────────────────────────────┘
```

#### Available Actions

**Reactivate:**
- API call: `POST /api/account/reactivate`
- Sets `accountStatus = "active"`
- Restores `ownerActive: true` on owned videos
- Restores `feedEligible: true` on non-deleted videos
- Same UID, same username, same data
- **No onboarding restart**
- Immediate full app access

**Settings:**
- View account settings
- Change email, password
- View connected platforms
- Cannot create content while deactivated

**Sign Out:**
- Logs out
- Can sign in again later to reactivate

#### What's Hidden While Deactivated
- Profile from public view
- Videos from feeds
- Search results
- Public profile links return "Account not available"
- Threads/comments hidden

#### What's Preserved
- All content (videos, posts, comments)
- Followers / following lists
- Analytics history
- Username reservation
- Tippy Brain data
- Settings

#### Differences from Banned
- User initiated (not enforcement)
- Reversible at any time
- No appeal process needed
- Preserves username

---

### Deleted Account

**Status:** `accountStatus = "deleting"` → `"deleted"`

#### Deletion Flow

**Phase 1: Immediate (deleting)**
- `accountStatus = "deleting"`
- Profile hidden immediately
- Videos hidden from feeds
- Search results removed
- Public links stop resolving
- Username reservation released
- Block normal app entry

**Phase 2: Background Cleanup**
- Mux assets deleted
- Storage files deleted
- Video documents marked `isDeleted: true`
- Firestore subcollections cleaned
- Indexes updated
- Firebase Auth deleted last

**Phase 3: Complete (deleted)**
- `accountStatus = "deleted"`
- User doc tombstoned
- All content removed
- Username available for others

#### What User Sees

**During deletion:**
- Simple unavailable screen
- "Account is being deleted"
- Auto sign-out

**After deletion:**
- Cannot sign in (Auth deleted)
- Username is available
- No restoration possible

#### Later Signup
- Same email can create **new** account
- Different UID
- Full onboarding required
- No data carried over
- Can claim same username if still available

#### Firebase Console Delete
- Admin deletes Auth user in console
- Triggers same cascade via `onAuthUserDeleted`
- Runs `reconcileDeletedAuthUser` function
- Tombstones user doc
- Hides owned content
- Cleans indexes
- **Same deletion flow** as in-app delete

#### Never
- Restore deleted account
- Inherit old data to new UID
- Show dead profile cards
- Leak "Unknown User" in feeds
- Delete Mux before Firestore hide stamp

---

### Recycled Identity

**Scenario:** Old Auth UID with tombstoned user doc

**Status:** `users/{uid}.identityRecycled = true`

#### What Happened
- Previous account deleted
- Firebase Auth UID somehow recycled (rare)
- Old user doc still exists in deleted/tombstoned state

#### Enforcement
- Can only complete via **Tippy onboarding** on this UID
- Cannot use classic onboarding
- Cannot inherit old onboarding progress
- Must go through full funnel

#### Detection
```javascript
if (userData.identityRecycled === true) {
  // Force Tippy onboarding
  // Block classic onboarding
  // Require tippyFunnelCompleted
}
```

---

### Signup Restrictions

**Decision authority:** Backend APIs  
**Client role:** Display backend-provided messages

#### Restriction Types

| Reason | Typical Cause | User Message |
|--------|---------------|--------------|
| `disposable_email` | Temporary email service | "Temporary email addresses are not allowed. Please use a permanent email." |
| `network_temporarily_restricted` | IP/network block | "Account creation is temporarily restricted from this network. Please try again later." |
| `device_temporarily_restricted` | Device fingerprint block | "Account creation is temporarily restricted from this device. Please try again later." |
| `signup_rate_limited` | Too many accounts created | "Too many accounts were created recently. Please try again later." |
| `risk_review` | Risk signals detected | "Account creation is temporarily restricted. Please try again later." |

#### API Response Format
```json
{
  "allowed": false,
  "reason": "disposable_email",
  "code": "DISPOSABLE_EMAIL",
  "message": "Temporary email addresses are not allowed.",
  "retryAfter": null // or timestamp for time-based restrictions
}
```

#### Client Behavior
- Display exact message from server
- Show "Try Again" button if `retryAfter` provided
- Suggest alternative email if `disposable_email`
- **Never** show internal risk details
- **Never** implement client-only denylist

#### Restriction TTL
- Network/device: Hours to days (server-controlled)
- Rate limit: Exponential backoff
- Disposable email: Permanent (until permanent email used)

---

### Missing Birthday (Existing Account)

**Scenario:** Account exists but no DOB on record

**Status:** `birthdayRequired: true` from `/api/account/status`

#### When This Happens
- Legacy account created before birthday gate
- Google/Apple auth before birthday requirement
- Manual account creation by admin

#### Enforcement
```json
{
  "activationState": "BIRTHDAY_REQUIRED",
  "tippyStageHint": "birthday",
  "allowApp": false,
  "birthdayRequired": true,
  "birthdayLocked": false
}
```

#### Flow
1. User signs in
2. Status API returns `BIRTHDAY_REQUIRED`
3. Client routes to birthday step
4. User enters DOB
5. If ≥13: Proceed to normal app
6. If <13: Lock and sign out

#### For COMPLETE Accounts
- Birthday gate runs **before** returning to app
- After birthday saved, returns to app
- Does not restart onboarding
- `lifecycle` stays `COMPLETE`

---

## Navigation Authority

### Server is Authority

**All routing decisions come from the server.**

#### Primary API

**Endpoint:** `GET /api/account/status`

**Response:**
```json
{
  "activationState": "CREATOR_IDENTITY",
  "tippyStageHint": "username",
  "allowApp": false,
  "birthdayRequired": false,
  "birthdayLocked": false,
  "photoStatus": "not_started",
  "ageEligibility": {
    "hasDateOfBirth": true,
    "meetsMinimumAge": true,
    "isAdult": true
  }
}
```

#### Activation States

| State | Meaning | Client Action |
|-------|---------|---------------|
| `ACTIVATED` | Fully onboarded | Allow full app access |
| `TIPPY` | In Tippy onboarding | Route to Tippy stage (use `tippyStageHint`) |
| `CREATOR_IDENTITY` | Setting up profile | Route to identity stage (use `tippyStageHint`) |
| `FIRST_MISSION` | Completing first mission | Route to mission screen |
| `EMAIL_VERIFICATION_REQUIRED` | Must verify email | Route to email verification |
| `BIRTHDAY_REQUIRED` | Must provide DOB | Route to birthday gate |
| `ACCOUNT_REQUIRED` | Must create account | Route to signup |
| `GUEST_PERSONALIZATION` | Guest Checkup | Route to Checkup flow |
| `NEW` | No progress | Route to landing/welcome |

#### Stage Hints

**Tippy Stages:** `tippyStageHint` specifies exact screen
- `welcome` - Meet Tippy intro
- `questions` - DNA questions
- `signup` - Create account
- `verify_email` - Email verification
- `avatar` - Upload photo
- `username` - Claim username
- `bio` - Write bio
- `platform_handles` - Add social links
- `profile_review` - Review profile
- `twitch_connect` - Connect Twitch
- `first_mission` - First mission assignment

#### Client Responsibilities

**DO:**
- ✅ Fetch `/api/account/status` on every auth
- ✅ Route based on `activationState` + `tippyStageHint`
- ✅ Respect `allowApp` flag
- ✅ Check status on app resume/refresh
- ✅ Poll status during email verification
- ✅ Handle status changes while active

**DON'T:**
- ❌ Invent own lifecycle logic
- ❌ Override server routing
- ❌ Allow app access when `allowApp: false`
- ❌ Cache status indefinitely
- ❌ Assume onboarding complete without server confirmation

#### Local vs Server Conflict

**If local session says one thing, server says another:**
- **Server wins always**
- Clear local session
- Re-sync with server state
- Route to server-specified stage

**Example:**
- Local: "Questions completed, on identity step"
- Server: `tippyStageHint: "questions"`
- Action: Return to questions step, server is correct

---

### Resolution Logic

**Authority:** Server  
**Implementation:**
- Web: `lib/onboarding/resolveOnboardingDestination.ts`
- Flutter: `lib/components/onboarding/resolve_onboarding_destination.dart`
- Golden: `contracts/onboarding-lifecycle.golden.json`

#### Resolution Order

1. **Birthday gate** (if `birthdayRequired`)
2. **Email verification** (if email/password + not verified)
3. **Tippy funnel** (if `tippyStage` present)
4. **Classic funnel** (legacy fallback)
5. **ACTIVATED** (if all complete)

#### Special Cases

**Recycled identity:**
- Force Tippy onboarding
- Require `tippyFunnelCompleted: true`
- Block classic completion

**Incomplete v1:**
- Legacy version 1 onboarding
- Migrate to v3 Tippy
- Don't leave stuck in v1

**Tippy already done:**
- `tippyFunnelCompleted: true`
- `essentialProfileComplete: true`
- Route to `ACTIVATED`

---

## Critical Parity Requirements

### ✅ Must Be Identical

| Feature | Both Platforms Must |
|---------|---------------------|
| **Birthday Gate** | Same validation, same under-13 block, same API |
| **7 DNA Questions** | Exact same wording, options, order |
| **Question Skip Logic** | Same rules for which can be skipped |
| **Auth Providers** | Google, Apple, Email on same Firebase project |
| **Username Rules** | 3-20 chars, same pattern, same validation |
| **Profile Fields** | Avatar, username, bio, socials structure |
| **Lifecycle States** | Server-driven, same state machine |
| **Tippy Stages** | Same stage names, same progression |
| **Skip Behavior** | X = "not now", never "start over" |
| **Resume Logic** | Reopen at exact saved stage |
| **Tippy Personality** | Same conversational tone, same copy |
| **Data Storage** | Same Firestore structure, same field names |
| **Account Enforcement** | Same banned/deactivated screens |
| **Navigation Authority** | Server decides, clients render |

---

### ✅ Platform-Specific Differences Allowed

| Feature | Difference Allowed |
|---------|-------------------|
| **UI Design** | Material Design (Flutter) vs Custom Web UI |
| **Native Features** | Camera, file picker, share sheet, notifications |
| **Performance** | Native optimizations, lazy loading strategies |
| **Animations** | Platform-specific transitions, gestures |
| **Creator Checkup** | Website has it, Flutter skips to Path A |

---

### ❌ Never Different

**Logic:**
- Lifecycle progression
- Validation rules
- Question text
- Error messages
- Account enforcement rules

**Data:**
- Field names (`users/{uid}` structure)
- Data types
- Firestore paths
- API endpoints
- API request/response formats

**Behavior:**
- When to show birthday gate
- Email verification requirement
- Username availability logic
- Profile completion criteria
- ACTIVATED state requirements

---

## Analytics & Instrumentation (V3.1 Enhanced)

### Funnel Events

**Complete event list for V3.1:**

```javascript
// Pre-Auth
onboarding_started
dna_question_completed (per question)
dna_reveal_viewed
value_map_viewed // NEW V3.1

// Auth & Verification
account_created
email_verification_started
email_verified

// Identity
identity_started
avatar_uploaded
avatar_skipped
username_claimed
bio_entered
bio_skipped
platforms_added
platforms_skipped
profile_completed

// Growth Plan & Activation
first_growth_plan_created // NEW V3.1
first_growth_plan_customized // NEW V3.1
product_map_viewed // NEW V3.1
creator_space_ready_viewed // NEW V3.1
first_mission_assigned // NEW V3.1
activated // Main success metric

// Post-Activation (Validates Onboarding Quality)
first_tippy_prompt // NEW V3.1
first_plan_opened // NEW V3.1
first_video_uploaded // NEW V3.1
first_platform_connected // NEW V3.1
first_mission_completed // NEW V3.1
```

### Key Metrics to Track

**Funnel Conversion:**
- Started → DNA Questions Complete: __%
- DNA Questions → Value Map Viewed: __%
- Value Map → Account Created: __%
- Account Created → Profile Complete: __%
- Profile Complete → First Plan Created: __%
- First Plan → Activated: __%

**Activation Quality (Post-ACTIVATED):**
- % who complete first mission within 24h
- % who open Ask Tippy within 48h
- % who open their first plan within 48h
- % who upload first video within 7 days
- % who return Day 7, Day 14, Day 30

**Product Understanding Test:**
- Survey after activation: "What is StreamersTip?" (open response)
- Survey: "What can Tippy do for you?" (open response)
- Measure: "Where did you go first after activation?"
- Measure: "Did you complete your first mission?"

### Acceptance Test (V3.1)

**Every new creator who completes onboarding should be able to answer:**

1. **What is StreamersTip?**
   - ✅ Correct: "A platform to help me plan, create, and grow my content"
   - ❌ Wrong: "I don't know" or "A social media app"

2. **What can Tippy do for me?**
   - ✅ Correct: "Give me content ideas, plan my schedule, track what works"
   - ❌ Wrong: "I don't know" or "It's a chatbot"

3. **Where do I manage my creator workflow?**
   - ✅ Correct: "Mission Control" or "Content Planner"
   - ❌ Wrong: "I don't know" or "The home feed"

4. **What should I do first?**
   - ✅ Correct: Names their first mission or "Check my growth plan"
   - ❌ Wrong: "I don't know" or "Post something"

**If >20% of new creators fail any question, onboarding is not finished.**

---

## Testing Checklist

### Pre-Auth (Guest)

#### Path A: Direct Onboarding
- [ ] "Get Started" opens Tippy welcome
- [ ] Welcome screen shows correctly
- [ ] 7 DNA questions appear in order
- [ ] Can navigate back through questions
- [ ] Answers are saved between questions
- [ ] X button preserves progress
- [ ] Refresh/close preserves session
- [ ] Session expires after 24 hours
- [ ] Resume returns to last question
- [ ] Resume shows welcome-back copy

#### Path B: Creator Checkup (Web Only)
- [ ] Checkup landing shows correctly
- [ ] Can add YouTube URL
- [ ] Can add Twitch handle
- [ ] Can add multiple platforms
- [ ] Can edit added profiles
- [ ] Can remove profiles
- [ ] "Analyze" button triggers analysis
- [ ] Shows real-time analysis status per platform
- [ ] Never fakes "analyzed" status
- [ ] Honest "limited" / "unavailable" shown
- [ ] Score preview only shown if ≥1 analyzed
- [ ] Zero analyses shows honest message
- [ ] Findings are evidence-based
- [ ] Can correct inferred DNA
- [ ] "Continue with Tippy" transfers context
- [ ] "Maybe Later" preserves session
- [ ] X closes without deleting progress
- [ ] Resume returns to saved step
- [ ] 24h expiration works

---

### Birthday Gate

- [ ] Shown for new email signups (both platforms)
- [ ] Shown for existing accounts missing DOB
- [ ] Blocks under 13 before Auth created
- [ ] Under 13 shows locked screen
- [ ] Under 13 auto-signs out
- [ ] Age 13+ proceeds to next step
- [ ] Write-once (cannot change after submit)
- [ ] DOB stored privately
- [ ] DOB never in publicUsers
- [ ] COMPLETE accounts return to app after DOB

---

### Authentication

- [ ] Email/password signup works
- [ ] Google Sign-In works (both platforms)
- [ ] Apple Sign-In works (both platforms)
- [ ] Same Firebase project used
- [ ] Same UID created across platforms
- [ ] Email verification required for email/password
- [ ] Google/Apple skip email verification
- [ ] Verification email sent
- [ ] Can resend verification email
- [ ] Verified status detected
- [ ] Hide My Email supported (Apple)
- [ ] Account linking works for existing accounts
- [ ] Error messages are helpful

---

### Tippy Conversation

- [ ] Welcome screen shows "Hey I'm Tippy"
- [ ] Can skip intro if already seen
- [ ] Platforms question appears first
- [ ] Multi-select works
- [ ] Can select "Other"
- [ ] Content type question second
- [ ] All 7 questions appear in order
- [ ] Cannot skip required questions
- [ ] Can skip optional fields (bio, niche)
- [ ] Back button works
- [ ] Forward preserves answers
- [ ] DNA reveal shows personalized summary
- [ ] Growth opportunity displayed
- [ ] Checkup context transferred correctly
- [ ] Confirmed DNA prefills answers
- [ ] Suggested DNA shows as suggestions
- [ ] Compact confirmation works
- [ ] No second "Hey I'm Tippy" after Checkup

### Value Map (V3.1 NEW)

- [ ] Value map shown after DNA reveal
- [ ] Shows user's specific platforms
- [ ] Shows user's specific goals
- [ ] Shows 3-5 personalized capabilities
- [ ] Not generic feature list
- [ ] Twitch gaming creator sees stream-to-clip value
- [ ] YouTube tutorial creator sees monetization value
- [ ] Multi-platform creator sees management value
- [ ] Beginner sees step-by-step guidance value
- [ ] CTA is clear ("Create My Account")
- [ ] Can proceed to signup
- [ ] `value_map_viewed` event fires

---

### Creator Identity

#### Avatar
- [ ] Can upload photo
- [ ] File size validated (≤5MB)
- [ ] Image format validated (JPG/PNG/WebP)
- [ ] Cropping works for non-square
- [ ] Camera access works (Flutter)
- [ ] File picker works (Web)
- [ ] Can skip avatar
- [ ] Skipped state saved
- [ ] Avatar URL stored correctly
- [ ] photoURL matches avatarURL

#### Username
- [ ] Length validated (3-20)
- [ ] Pattern validated (alphanumeric + _)
- [ ] Real-time availability check
- [ ] Debounced API calls (not on every keystroke)
- [ ] Shows "checking..." state
- [ ] Shows "available" checkmark
- [ ] Shows "taken" error
- [ ] Suggests alternatives if taken
- [ ] Case-insensitive uniqueness
- [ ] Reserved usernames blocked
- [ ] Username stored correctly
- [ ] usernameNormalized created
- [ ] usernames/{normalized} document created

#### Bio
- [ ] Max 160 characters enforced
- [ ] Character counter shown
- [ ] Can skip bio
- [ ] Bio stored correctly
- [ ] Bio mirrored to publicUsers

#### Platform Handles
- [ ] Can add YouTube handle
- [ ] Can add Twitch handle
- [ ] Can add TikTok handle
- [ ] Accepts full URLs
- [ ] Accepts @username format
- [ ] Accepts plain handles
- [ ] URL parsed correctly
- [ ] Shows preview of profile link
- [ ] Can edit added platforms
- [ ] Can remove platforms
- [ ] Can skip all socials
- [ ] Checkup profiles prefilled
- [ ] Can add additional platforms
- [ ] Stored in connectedPlatforms array
- [ ] Mirrored to publicUsers.socialLinks

#### Profile Review
- [ ] Shows avatar (or placeholder)
- [ ] Shows username
- [ ] Shows bio (or "No bio yet")
- [ ] Shows connected platforms
- [ ] "Edit" goes back to correct step
- [ ] "Looks Good" proceeds to next stage
- [ ] All changes persisted

---

### Activation (V3.1 Enhanced)

#### Twitch Connect
- [ ] Only shown if Twitch mentioned
- [ ] OAuth flow works
- [ ] Permissions requested correctly
- [ ] Callback handled
- [ ] Tokens stored securely
- [ ] Can skip connection
- [ ] Imports profile data if avatar skipped
- [ ] twitchConnected flag set

#### Notifications
- [ ] Permission request shown
- [ ] Works on iOS (Flutter)
- [ ] Works on Android (Flutter)
- [ ] Works on Web (browser permission)
- [ ] Can skip notifications
- [ ] FCM token stored (mobile)
- [ ] Web push token stored (web)
- [ ] Notification preferences saved

#### First Growth Plan (V3.1 NEW)
- [ ] Plan generation triggered
- [ ] Shows user's growth focus
- [ ] Shows user's goals
- [ ] Plan is personalized (not generic)
- [ ] 1-2 week starter plan
- [ ] Twitch streamer gets consistency + clip plan
- [ ] YouTube creator gets topic calendar
- [ ] Multi-platform creator gets cross-post workflow
- [ ] Can accept plan
- [ ] Can customize plan
- [ ] Plan stored to `contentPlans/{planId}`
- [ ] `firstGrowthPlanId` saved
- [ ] `first_growth_plan_created` event fires

#### Product Map (V3.1 NEW)
- [ ] 3-card product orientation shown
- [ ] "Plan" card explains Content Planner
- [ ] "Create" card explains creation workflow
- [ ] "Grow" card explains Tippy/analytics/missions
- [ ] Single screen (not 5-slide tutorial)
- [ ] Can proceed to creator space
- [ ] `product_map_viewed` event fires

#### Creator Space Ready (V3.1 ENHANCED)
- [ ] NOT generic "You're all set!" screen
- [ ] Shows "Your creator system is ready"
- [ ] Lists what was accomplished:
  - [ ] "Tippy knows your goals" (with actual goals)
  - [ ] "Your creator profile is set" (with username)
  - [ ] "Your platforms are mapped" (with actual platforms)
  - [ ] "Your first growth focus is ready" (with actual focus)
  - [ ] "Your first mission is waiting" (with mission name)
- [ ] CTA is "Go to Mission Control" (not "Start Creating")
- [ ] Ties onboarding to product
- [ ] `creator_space_ready_viewed` event fires

#### First Mission (V3.1 ENHANCED)
- [ ] Mission is meaningful (not just gamification)
- [ ] Prioritizes high-value actions:
  - [ ] "Ask Tippy for your first content idea"
  - [ ] "Create your first plan"
  - [ ] "Upload your first video"
  - [ ] "Connect your primary platform"
  - [ ] "Create your first clip"
- [ ] NOT low-value actions like "Complete profile"
- [ ] Mission relevant to creator type
- [ ] Mission stored correctly
- [ ] `firstActivationAction` saved
- [ ] Can view mission details
- [ ] Mission shows in Mission Control
- [ ] `first_mission_assigned` event fires

---

### ACTIVATED State (V3.1 Definition)

- [ ] `lifecycle = COMPLETE` set
- [ ] `tippyFunnelCompleted = true` set
- [ ] `essentialProfileComplete = true` set
- [ ] `valueEducationCompleted = true` set (V3.1 NEW)
- [ ] `firstGrowthPlanCreated = true` set (V3.1 NEW)
- [ ] `firstGrowthPlanId` populated (V3.1 NEW)
- [ ] `firstActivationAction` recorded (V3.1 NEW)
- [ ] `activationState = ACTIVATED` returned
- [ ] Full app access granted
- [ ] Can post content
- [ ] Can upload videos
- [ ] Can access Content Planner (first plan ready)
- [ ] Can use Ask Tippy
- [ ] Can view Dashboard
- [ ] Can access Mission Control (first mission active)
- [ ] Can edit profile
- [ ] Can access Settings

### Product Understanding Validation (V3.1 CRITICAL)

**Test with actual users:**

- [ ] User can answer: "What is StreamersTip?"
- [ ] User can answer: "What can Tippy do for me?"
- [ ] User can answer: "Where do I manage my workflow?"
- [ ] User can answer: "What should I do first?"
- [ ] <80% can answer all 4 = onboarding needs improvement

**Post-Activation Behavior:**

- [ ] User opens Mission Control within 5 minutes
- [ ] User views their first growth plan
- [ ] User interacts with first mission
- [ ] User opens Ask Tippy within 24h
- [ ] User completes first mission within 24-48h

---

### Close & Resume

- [ ] X button closes without deleting
- [ ] Progress preserved after X
- [ ] Can reopen and resume
- [ ] Resume returns to exact step
- [ ] Welcome-back copy shown on resume
- [ ] Never shows first-meet copy on resume
- [ ] Guest session lasts 24 hours
- [ ] Auth session persists indefinitely
- [ ] Refresh preserves state
- [ ] Close/reopen browser preserves state

---

### Account Enforcement

#### Banned Account
- [ ] Full-screen suspension message shown
- [ ] Exact copy displayed
- [ ] "Get Help" button works
- [ ] "Sign Out" button works
- [ ] No app access allowed
- [ ] Profile hidden from public
- [ ] Videos hidden from feeds

#### Deactivated Account
- [ ] Deactivation screen shown
- [ ] "Reactivate" button works
- [ ] Reactivation restores full access
- [ ] Same UID after reactivation
- [ ] No onboarding restart
- [ ] Username preserved
- [ ] Data preserved
- [ ] Can sign out while deactivated

#### Deleted Account
- [ ] Cannot sign in after deletion
- [ ] Username released
- [ ] New signup creates new account
- [ ] Full onboarding required for new account
- [ ] No data carried over
- [ ] Console delete triggers same cascade

---

### Edge Cases

- [ ] Network error during signup handled
- [ ] Network error during verification handled
- [ ] Multiple tabs/windows handled correctly
- [ ] Concurrent auth attempts handled
- [ ] Token expiration handled
- [ ] Server status changes detected
- [ ] Offline mode queues actions
- [ ] Recycled identity enforces Tippy
- [ ] V1 incomplete migrates to V3
- [ ] Missing birthday triggers gate
- [ ] Under 13 blocks properly
- [ ] Disposable email rejected
- [ ] Rate limiting enforced
- [ ] Device restrictions enforced

---

### Cross-Platform Parity

- [ ] Same questions on both platforms
- [ ] Same validation rules on both
- [ ] Same error messages on both
- [ ] Same birthday enforcement on both
- [ ] Same account enforcement on both
- [ ] Same data storage structure
- [ ] Same API endpoints used
- [ ] Same Firebase project
- [ ] Same lifecycle states
- [ ] Web Checkup → Flutter onboarding transfers correctly
- [ ] V3.1 value_map stage on both platforms
- [ ] V3.1 first_growth_plan stage on both platforms
- [ ] V3.1 product_map on both platforms
- [ ] V3.1 enhanced creator_space_ready on both platforms
- [ ] V3.1 meaningful first missions on both platforms
- [ ] V3.1 analytics events on both platforms

### V3.1 Storage Parity

- [ ] `valueEducationCompleted` field on both
- [ ] `firstGrowthPlanCreated` field on both
- [ ] `firstGrowthPlanId` field on both
- [ ] `firstActivationAction` field on both
- [ ] `valueMapViewed` field on both
- [ ] `productMapViewed` field on both
- [ ] localStorage (not sessionStorage) for durable guest storage
- [ ] Same storage hierarchy on both platforms

---

## Summary

### One Onboarding, Two Surfaces

**Core Truth:**
> StreamersTip has **one** canonical onboarding machine. Website and Flutter are two rendering surfaces of the same server-driven state.

**What's Identical:**
- ✅ Lifecycle logic
- ✅ Question content
- ✅ Validation rules
- ✅ Data structures
- ✅ Account enforcement
- ✅ Navigation authority
- ✅ **V3.1:** Product education stages
- ✅ **V3.1:** Value map personalization
- ✅ **V3.1:** First growth plan creation
- ✅ **V3.1:** Product map (3 cards)
- ✅ **V3.1:** Enhanced activation summary
- ✅ **V3.1:** Meaningful first missions

**What's Different:**
- 🎨 UI design (Material vs Web)
- 📱 Native features (camera, file picker)
- 🌐 Website has Creator Checkup (optional Path B)
- 📱 Flutter always uses Path A (direct Tippy)

**Golden Rule:**
- Server decides lifecycle
- Clients render state
- Never invent logic
- Always respect `allowApp: false`
- **V3.1:** Every creator must understand the product before ACTIVATED

---

## V3.1 Change Summary

### What Changed from V3.0

**Added Stages:**
1. `value_map` - Personalized product value after DNA reveal
2. `first_growth_plan` - Explicit plan creation stage
3. `product_map` - 3-card product orientation
4. Enhanced `creator_space_ready` - Meaningful activation summary (not generic celebration)

**Enhanced Requirements:**
- ACTIVATED now requires product understanding, not just form completion
- First missions must be meaningful activation actions
- Identity setup must explain **why** each field is needed
- Storage contract clarified (localStorage for durable, not sessionStorage)

**Fixed Inconsistencies:**
- Birthday gate vs email verification order now has canonical golden test
- sessionStorage vs localStorage durability requirements clarified

**New Analytics:**
- `value_map_viewed`
- `first_growth_plan_created`
- `product_map_viewed`
- `creator_space_ready_viewed`
- `first_tippy_prompt`
- `first_plan_opened`

**New Acceptance Test:**
- Creator must answer 4 product understanding questions
- Post-activation behavior tracked (not just funnel completion)

### Implementation Strategy

**Do NOT:**
- ❌ Rewrite onboarding from scratch
- ❌ Change server lifecycle authority
- ❌ Redesign backend state machine
- ❌ Break web/Flutter parity

**DO:**
- ✅ Audit current implementations against V3.0 contract first
- ✅ Add product education layer on top of existing machine
- ✅ Add value_map, first_growth_plan, product_map stages
- ✅ Enhance creator_space_ready content (not structure)
- ✅ Upgrade first mission assignment logic
- ✅ Add new analytics events
- ✅ Test product understanding with real users

**Version:** This is V3.1 (Product Education Pass), not V4.0 (Complete Redesign)

---

## References

**Canonical Contracts:**
- `/workspace/docs/CANONICAL_CONTRACTS.md` - Section 4 (Onboarding)
- `contracts/onboarding-lifecycle.golden.json`
- `contracts/birthday-gate.golden.json`
- `contracts/tippy-creator-checkup.v1.json`
- `contracts/tippy-context-action.v1.json`

**Implementation:**
- Web: `lib/onboarding/resolveOnboardingDestination.ts`
- Flutter: `lib/components/onboarding/resolve_onboarding_destination.dart`
- Flutter Tippy: `lib/features/onboarding_tippy/tippy_onboarding_view.dart`

**API Endpoints:**
- `GET /api/account/status` - Navigation authority
- `POST /api/account/pending` - Create pending account
- `POST /api/account/date-of-birth` - Submit birthday
- `GET /api/account/username-available` - Check username
- `POST /api/account/reactivate` - Reactivate deactivated account

---

## Outstanding Issues to Resolve

### 1. Birthday Gate vs Email Verification Order

**Status:** Conflicting requirements documented  
**Action Required:** Create golden test contract

**File needed:** `contracts/birthday-email-verification-order.golden.json`

Must specify exact ordering for:
- Email/password signup
- Google OAuth signup
- Apple OAuth signup
- Existing account missing DOB

**Test cases needed:**
- Email signup with under-13 DOB
- Email signup with valid DOB, then verify
- Google signup (no verification), then DOB gate
- Existing account signs in, missing DOB

### 2. Storage Durability Contract

**Status:** Clarified in V3.1, needs implementation audit  
**Action Required:** Verify web and Flutter use correct storage

**Requirement:**
- Guest sessions: `localStorage` (durable), not `sessionStorage`
- Authenticated: Server `users/{uid}` (source of truth)
- Performance cache: `sessionStorage` OK for same-tab resume

**Audit needed:**
- [ ] Web implementation uses localStorage for guest
- [ ] Flutter implementation persists guest sessions durably
- [ ] Both platforms clear on auth state change
- [ ] Both platforms survive browser close/reopen

### 3. First Mission Assignment Logic

**Status:** Requirements defined in V3.1, needs backend implementation  
**Action Required:** Update mission assignment service

**Current:** Likely assigns based on completion status  
**Required:** Prioritize high-value activation actions

**Server logic needed:**
```javascript
function assignFirstMission(creatorDNA, onboardingState) {
  // Prioritize:
  // 1. Ask Tippy (always high value)
  // 2. Create plan (if not created)
  // 3. Upload video (for video creators)
  // 4. Connect platform (if not connected)
  // 5. Create clip (for live streamers)
  
  // Deprioritize:
  // - Complete profile (already done)
  // - Introduce yourself (low value)
}
```

### 4. Value Map Personalization Engine

**Status:** Requirements defined in V3.1, needs implementation  
**Action Required:** Build DNA → Product Value translation service

**Server endpoint needed:** `POST /api/onboarding/generate-value-map`

**Input:** 7 DNA question answers  
**Output:** Personalized capabilities list

**Translation rules documented** in Value Map section (Phase 3)

---

**Last Updated:** October 15, 2026  
**Version:** 3.1 (Product Education Layer)  
**Maintained By:** Product & Engineering  
**Next Review:** After V3.1 implementation audit
