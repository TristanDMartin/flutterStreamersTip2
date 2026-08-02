# Threads v2 — Tippy, Personalization, Gamification (Phase 4 contract binding)

Implements plan Phase 4 against [`contracts/threads.v2.json`](../../contracts/threads.v2.json).

## Tippy

| Contract field | Behavior |
|----------------|----------|
| `tippyStarterPresets` | Composer entry actions (Flutter `TypedCreateThreadScreen`, web shell chips) |
| Tippy summary DTO | `threads/{id}/tippySummary` — UI must label **AI-generated** |
| Creator goals module | Server ranks using Creator Memory + `threadInterestSignals` |

Clients must not invent Tippy summaries. Call repository `getTippySummary` when backend lands.

## Personalized modules

Module IDs (SoT): `continue_conversation`, `creator_goals`, `need_your_input`, `trending_in_space`, `creator_wins`, `featured`.

`listModules` on both repositories returns contract-shaped DTOs. Full For You ranking requires interest signals + Tippy memory (server). Dual-read may populate modules from projected legacy threads until `threads_v2_reads` is on.

## Gamification

Emit only contract event strings:

| Key | Event |
|-----|-------|
| threadCreated | `content.thread_created` |
| threadParticipated | `community.thread_participated` |
| helpfulReactionReceived | `community.helpful_reaction_received` |
| answerMarkedHelpful | `community.answer_marked_helpful` |
| unansweredHelped | `community.unanswered_helped` |

Flutter helper: `lib/features/threads/threads_gamification.dart`.

Wire emits on `createThread` / `react` / `resolveThread` after `threads_v2_writes` is enabled (do not double-emit via legacy ForumService).

## Reputation labels

`helpful_voice`, `growth_contributor`, `setup_specialist`, `feedback_regular`, `community_builder`, `collaboration_starter` — compute from reactions/resolutions, expire/evolve over time (server job).

## Weekly impact card DTO

`creatorsHelped`, `answersMarkedHelpful`, `discussionsReached30` — see Flutter `WeeklyImpactDto`.

## Analytics

Use `analyticsEvents` from the JSON contract only — shared names on web + Flutter.
