# Website Repository V3.1 Documentation Update Instructions

## Target Repository
- **Repository:** `streamerstipReact`
- **Branch:** `homepage-merge-staging`
- **GitHub:** TristanDMartin/streamerstipReact

## Task: Apply V3.1 Onboarding Documentation Updates

Update the canonical onboarding documentation to V3.1 (Product Education Layer) to match the Flutter repository updates completed on October 15, 2026.

---

## Files to Update

### 1. `docs/ONBOARDING_EXPERIENCE.md`

**Complete replacement required.** This file has been completely rewritten for V3.1.

Source file location (for reference): The complete V3.1 version is in flutterStreamersTip2 repository at commit `8923f2ec` on branch `flutterStreamersTip2`.

**Key sections added/updated:**
- Core Principles section now includes Product Education Requirement
- V3.1 Presentation Stages added: `value_map`, `first_growth_plan`, enhanced `creator_space_ready`, enhanced `first_mission`
- New V3.1 stage documentation: Complete `value_map` stage with personalization engine
- Enhanced identity setup sections with value explanations
- New `first_growth_plan` creation stage
- Product map (3-card orientation) before activation
- Enhanced `creator_space_ready` with meaningful activation summary
- Enhanced `first_mission` with high-value activation actions
- Updated ACTIVATED definition with product understanding requirements
- New storage fields: `valueEducationCompleted`, `firstGrowthPlanCreated`, `firstGrowthPlanId`, `firstActivationAction`
- Birthday gate vs email verification canonical order resolution
- Storage durability clarification (localStorage vs sessionStorage)
- Enhanced analytics events
- V3.1 testing checklist
- Outstanding issues to resolve section

**File size:** ~3,300+ lines

### 2. `docs/CANONICAL_CONTRACTS.md`

**Section 4 update required:** "Onboarding / account state"

Replace the entire Section 4 with the V3.1 version.

**Key changes:**
- Section title updated to include "V3.1 — Product Education Layer"
- Added Version, Detailed Spec, and Status metadata
- Core Principle section added
- Authority table (unchanged)
- V3.1 Presentation Stages section added with complete stage flow
- "What ACTIVATED Means (V3.1 Definition)" section added with 5 requirements
- V3.1 Storage Fields section added
- Golden Test Contracts section added
- Birthday Gate section updated with canonical order by auth method
- Storage Durability section added
- V3.1 Implementation Strategy section added

---

## Commit Strategy

**Commit 1:** Update ONBOARDING_EXPERIENCE.md
```
docs: update onboarding to V3.1 with product education layer

Major enhancements to make onboarding canonical for both web and Flutter:

## V3.1 Product Education Layer

### New Stages Added
- value_map: Personalized product value after DNA reveal
- first_growth_plan: Explicit plan creation stage
- product_map: 3-card product orientation (Plan/Create/Grow)
- Enhanced creator_space_ready: Meaningful activation summary

### Enhanced Requirements
- ACTIVATED now means creator understands product, not just forms complete
- Must answer 4 questions: What is StreamersTip? What does Tippy do? 
  Where do I manage workflow? What should I do first?
- First missions must be meaningful (Ask Tippy, Create plan, Upload video)
- Identity setup explains WHY each field is needed (value unlock)

### Fixed Inconsistencies
- Resolved birthday gate vs email verification order conflict
- Clarified storage durability (localStorage for guests, not sessionStorage)
- Updated lifecycle to explicitly include first_growth_plan stage

### New Analytics Events
- value_map_viewed, first_growth_plan_created, product_map_viewed
- Post-activation behavior tracking

### Implementation Strategy
- Do NOT rewrite from scratch (85-90% kept from V3.0)
- Add product education layer on existing machine
- Preserve server authority and exact web/Flutter parity

This is V3.1 (Product Education Pass), not V4.0 (Complete Redesign).
```

**Commit 2:** Update CANONICAL_CONTRACTS.md Section 4
```
docs: update canonical contracts with V3.1 onboarding requirements

Update section 4 (Onboarding / account state) to reflect V3.1 Product Education Layer:

## Major Changes
- Updated lifecycle documentation to include new V3.1 stages
- Added complete presentation stage flow (welcome → complete)
- Redefined ACTIVATED state with product understanding requirements
- Added new storage fields (valueEducationCompleted, firstGrowthPlanCreated, etc.)
- Clarified birthday gate canonical order for each auth method
- Clarified storage durability hierarchy (server > localStorage > sessionStorage)

## New V3.1 Stages
- value_map: Personalized product education after DNA reveal
- first_growth_plan: Explicit first plan creation
- Enhanced creator_space_ready: Meaningful activation summary
- Enhanced first_mission: Meaningful activation action

## Storage Contract
- Server (users/{uid}.onboarding) is source of truth for authenticated
- localStorage for durable guest sessions (not sessionStorage)
- sessionStorage only for same-tab performance cache

Both docs (ONBOARDING_EXPERIENCE.md and CANONICAL_CONTRACTS.md) now aligned on V3.1.
```

---

## V3.1 Key Concepts Summary

### What Changed from V3.0

1. **New Presentation Stages:**
   - `value_map` - Personalized "How StreamersTip helps you" education
   - `first_growth_plan` - Explicit plan creation (not hidden)
   - `product_map` - 3-card product orientation (Plan/Create/Grow)
   - Enhanced `creator_space_ready` - Shows what was accomplished, not generic celebration
   - Enhanced `first_mission` - Meaningful activation actions, not just gamification

2. **Redefined ACTIVATED:**
   - Old: All required fields filled
   - New: Identity complete + Tippy understands DNA + first growth plan exists + clear next action + creator understands product (4 questions)

3. **Identity Setup Enhancements:**
   - Each field now explains WHY (value unlock)
   - Frames as "building creator workspace" not "filling forms"

4. **Fixed Inconsistencies:**
   - Birthday gate vs email verification order now has canonical golden test
   - Storage durability clarified (localStorage required, not sessionStorage)

5. **New Persisted Fields:**
   - `valueEducationCompleted`
   - `firstGrowthPlanCreated`
   - `firstGrowthPlanId`
   - `firstActivationAction`
   - `valueMapViewed`
   - `productMapViewed`

6. **New Analytics Events:**
   - `value_map_viewed`
   - `first_growth_plan_created`
   - `first_growth_plan_customized`
   - `product_map_viewed`
   - `creator_space_ready_viewed`
   - `first_mission_assigned`
   - Post-activation: `first_tippy_prompt`, `first_plan_opened`, `first_video_uploaded`

### Implementation Philosophy

**This is V3.1 (Product Education Pass), NOT V4.0 (Complete Redesign)**

- Keep 85-90% of V3.0 structure
- Add product education layer on top
- Preserve server authority
- Maintain exact web/Flutter parity
- Do NOT rewrite from scratch

---

## Acceptance Criteria

After this update:

✅ Both files are updated to V3.1  
✅ CANONICAL_CONTRACTS.md Section 4 matches Flutter repo exactly  
✅ ONBOARDING_EXPERIENCE.md is byte-identical to Flutter repo  
✅ Both files committed and pushed to `homepage-merge-staging`  
✅ Documentation is ready for web implementation teams to audit against V3.0 and add V3.1 layer

---

## How to Execute

### Option 1: Copy from Flutter Repo
1. Checkout `homepage-merge-staging` branch
2. Copy `docs/ONBOARDING_EXPERIENCE.md` from flutterStreamersTip2 (commit `8923f2ec`)
3. Copy updated Section 4 from `docs/CANONICAL_CONTRACTS.md` from flutterStreamersTip2 (commit `8923f2ec`)
4. Commit with messages above
5. Push to `homepage-merge-staging`

### Option 2: Cloud Agent Recreation
Create a new cloud agent session for streamerstipReact on `homepage-merge-staging` and paste this entire specification as the prompt. The agent will recreate the exact V3.1 updates that were applied to the Flutter repo.

---

**Created:** October 15, 2026  
**Flutter Repo Commits:** `078fd89b`, `c3545e0c`, `8923f2ec`  
**Source Branch:** `flutterStreamersTip2`  
**Target Branch:** `homepage-merge-staging`
