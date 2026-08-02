# Creator Threads Contract v2

Shared vocabulary for **website** + **Flutter**. Single source of truth: [`contracts/threads.v2.json`](../../contracts/threads.v2.json).

**Product:** Creator Threads — the place creators talk through the decisions behind the content. The video feed shows what creators made; Threads shows what they are learning, debating, needing feedback on, and building next.

**Storage (Phase 1 target):**
- SoT: `threads/{threadId}` (+ `replies`, `reactions`, `participants`, `resolution`, `tippySummary`)
- Categories: `threadCategories/{categoryId}` (canonical IDs in contract; may mirror/seed from `forumCategories` during migration)
- Legacy: `forumPosts` / `forumPosts/{id}/comments` remain via **dual-read adapter** until cutover
- Follows: canonical participant/follow on thread; migrate web `threadFollows` and unused `followedBy[]`

## Files

| Artifact | Path |
|----------|------|
| JSON schema | `contracts/threads.v2.json` |
| Legacy audit | `docs/architecture/THREADS_LEGACY_AUDIT.md` |
| Migration | `docs/architecture/THREADS_MIGRATION_PLAN.md` |
| Flutter mirror | `lib/features/threads/threads_contract.dart` |
| Website mirror | `streamerstipReact/types/threadsContract.ts` |
| Flutter repository | `lib/features/threads/threads_repository.dart` |
| Website repository | `streamerstipReact/lib/threads/threadsRepository.ts` |

## Canonical Thread

Required fields (see contract `threadEntityRequiredFields`):

`id`, `schemaVersion` (2), `authorId`, `type`, `title`, `body`, `categoryId`, `status`, `momentumState`, `visibility`, counters (`replyCount`, `participantCount`, `helpfulCount`, `saveCount`, `followCount`), `lastActivityAt`, `createdAt`, `updatedAt`.

Optional: `platformTags`, `topicTags`, typed `payload`, `sourceVideoId`, `sourceCommentId`, `sourceComment`, moderation fields, Tippy summary ref.

## Thread types

| ID | Label |
|----|-------|
| `question` | Ask a question |
| `feedback_request` | Request feedback |
| `creator_win` | Share a win |
| `debate` | Start a debate |
| `collaboration` | Find collaborators |
| `build_in_public` | Post an update |

Payload keys are defined per type in the JSON contract. Clients must not invent extra required fields outside the contract.

## Categories

Canonical IDs: `growth`, `streaming`, `content_ideas`, `video_feedback`, `gear_setup`, `gaming`, `monetization`, `collaboration`, `creator_life`.

Legacy category names/ids normalize via `legacyCategoryAliases`.

## Status and resolution

Statuses: `open` → `answered` → `resolved` (also `still_need_help`, `locked`, `deleted`).

`ThreadResolution`: `selectedReplyIds`, `resolutionNote`, `resolvedAt`, `resolvedBy`.

Legacy `published` → `open`; `deleted` stays deleted.

## Momentum (server-owned)

States: `new`, `picking_up`, `trending`, `active_now`, `resolved`.

Thresholds live in `momentumThresholds` in the JSON contract. **Clients must not invent momentum.** Conversation Pulse tones/icons/labels are in `momentumPulse` (color + icon + label for a11y).

## Reactions

Canonical: `helpful`, `relatable`, `great_idea`, `congratulations`, `agree`, `different_take`.

Hearts/likes are **legacy only** (`legacyReactionAliases.like` → `helpful` on read projection). Dislike has no v2 equivalent (`null`).

Allowed reactions vary by thread type (`reactionAllowedByThreadType`).

## Feed filters and modules

Filters: `for_you`, `following`, `trending`, `unanswered`, `live`.

Modules: `continue_conversation`, `creator_goals`, `need_your_input`, `trending_in_space`, `creator_wins`, `featured`.

Membership and ranking are **server/repository** responsibilities using interest signals + Tippy memory — not client heuristics on raw `forumPosts`.

## Tippy

- Starter presets: `tippyStarterPresets` (id, type, category, prompt, structure).
- Summary DTO: text, generatedAt, `isAiGenerated: true` label required in UI, sourceActivityAt.

## Gamification and analytics

Event strings are fixed in the contract (`gamificationEvents`, `analyticsEvents`). Create/participate paths must emit the named events after v2 cutover.

Reputation labels: `helpful_voice`, `growth_contributor`, `setup_specialist`, `feedback_regular`, `community_builder`, `collaboration_starter`.

## Repository interface

Both platforms implement the same method set (`repositoryMethods` in JSON): `listFeed`, `listModules`, `getThread`, `createThread`, `addReply`, `react`, `resolveThread`, `markViewed`, `followThread`, `followCategory`, Tippy helpers, `reportThread`, etc.

## Writes

- New clients write **canonical** enum strings only.
- Never write legacy `like`/`heart` as the primary reaction model.
- Never write `published` as status — use `open`.
- Dual-read projection may expose `legacyLikeCount` for transition UI only.

## Related product docs

- Positioning and UX brief: product Threads redesign (Creator Threads).
- Legacy system: `docs/FEED_COMMENTS_THREADS_SYSTEM.md` (points here for v2).
