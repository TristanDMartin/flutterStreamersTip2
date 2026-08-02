# Threads v2 Review Gate

**Status:** Ready for stakeholder review  
**Date:** 2026-08-02

## Deliverables to approve before Phase 1 implementation expands

| Artifact | Path | Purpose |
|----------|------|---------|
| Legacy audit | [`THREADS_LEGACY_AUDIT.md`](THREADS_LEGACY_AUDIT.md) | Every forumPosts R/W path |
| JSON contract | [`contracts/threads.v2.json`](../../contracts/threads.v2.json) | Single SoT enums/entities/thresholds |
| Contract doc | [`THREADS_CONTRACT_V2.md`](THREADS_CONTRACT_V2.md) | Human-readable SoT |
| Migration plan | [`THREADS_MIGRATION_PLAN.md`](THREADS_MIGRATION_PLAN.md) | Dual-read, flags, cutover |

## Review checklist

- [ ] Thread type IDs and payload shapes cover Question / Feedback / Win / Debate / Collaboration / Build-in-public
- [ ] Category IDs and legacy aliases are acceptable
- [ ] Reaction set and per-type allowlists are acceptable (no dislike in v2)
- [ ] Momentum thresholds and “server-owned” rule accepted
- [ ] Feed filter + module IDs accepted
- [ ] Tippy starter presets accepted
- [ ] Gamification + analytics event names accepted
- [ ] Storage paths (`threads/...`) and dual-read strategy accepted
- [ ] Cutover criteria accepted
- [ ] No production UI ships until this gate is signed (shells only behind `threads_v2_ui` after Phase 1 repos)

## Decision log

| Decision | Choice |
|----------|--------|
| Foundation vs Shell | Foundation-first |
| First deliverable | Contract + architecture + migration (not UI) |
| Platforms | Flutter + website share one contract |
| Legacy | Dual-read adapter; keep `forumPosts` until cutover |
| Thread ids | Preserve forumPost id on backfill |

## Approval

| Role | Name | Date | Sign-off |
|------|------|------|----------|
| Product | | | |
| Engineering (Flutter) | | | |
| Engineering (Web) | | | |
| Backend | | | |

Phase 1 repositories and adapters may land as **scaffolding aligned to the contract** while this gate is open; production traffic remains on legacy until flags are enabled post-approval.
