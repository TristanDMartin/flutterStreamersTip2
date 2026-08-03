# Threads v2 Review Gate

**Status:** Approved for Phase 1–3 ship (flags on; cutover off)  
**Date:** 2026-08-02  
**Approved:** 2026-08-02

## Deliverables

| Artifact | Path | Purpose |
|----------|------|---------|
| Legacy audit | [`THREADS_LEGACY_AUDIT.md`](THREADS_LEGACY_AUDIT.md) | Every forumPosts R/W path |
| JSON contract | [`contracts/threads.v2.json`](../../contracts/threads.v2.json) | Single SoT enums/entities/thresholds |
| Contract doc | [`THREADS_CONTRACT_V2.md`](THREADS_CONTRACT_V2.md) | Human-readable SoT |
| Migration plan | [`THREADS_MIGRATION_PLAN.md`](THREADS_MIGRATION_PLAN.md) | Dual-read, flags, cutover |

## Review checklist

- [x] Thread type IDs and payload shapes cover Question / Feedback / Win / Debate / Collaboration / Build-in-public
- [x] Category IDs and legacy aliases are acceptable
- [x] Reaction set and per-type allowlists are acceptable (no dislike in v2)
- [x] Momentum thresholds and “server-owned” rule accepted
- [x] Feed filter + module IDs accepted
- [x] Tippy starter presets accepted
- [x] Gamification + analytics event names accepted
- [x] Storage paths (`threads/...`) and dual-read strategy accepted
- [x] Cutover criteria accepted (Phase 5 still open)
- [x] Phase 1–3 shells + typed create/detail ship behind `threads_v2_ui` / `_reads` / `_writes` (cutover remains off)

## Decision log

| Decision | Choice |
|----------|--------|
| Foundation vs Shell | Foundation-first |
| First deliverable | Contract + architecture + migration (not UI) |
| Platforms | Flutter + website share one contract; Flutter is design-canonical |
| Legacy | Dual-read adapter; keep `forumPosts` until cutover |
| Thread ids | Preserve forumPost id on backfill |
| Phase 2–3 ship | Enable ui/reads/writes; keep `threads_v2_cutover` off |

## Approval

| Role | Name | Date | Sign-off |
|------|------|------|----------|
| Product | StreamersTip | 2026-08-02 | Approved Phase 1–3 |
| Engineering (Flutter) | StreamersTip | 2026-08-02 | Approved |
| Engineering (Web) | StreamersTip | 2026-08-02 | Approved |
| Backend | StreamersTip | 2026-08-02 | Deferred Phase 5 cutover |

## Ship flags

| Flag | Staging | Production |
|------|---------|------------|
| `threads_v2_ui` | on | on after smoke |
| `threads_v2_reads` | on | on after smoke |
| `threads_v2_writes` | on | on after smoke |
| `threads_v2_cutover` | off | off |

## Parity smoke (Flutter ↔ web)

1. Open Creator Threads shell — same filters/modules/Tippy starters.
2. Create typed thread on Flutter → appears on web (same id when both write/read v2).
3. Create typed thread on web → appears on Flutter.
4. Open detail → reply + helpful reaction + resolve (author).
5. Deep link `/threads/{id}` opens v2 detail when UI flag on.
6. Flags off restores legacy forum UX.
