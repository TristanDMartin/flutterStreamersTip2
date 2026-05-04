# Feed and playback lifecycle — beta review

**Date:** 2026-04-27  
**Scope:** Home / Discover / Profile feed video coordination with navigation and modals.

## Entry points

- `lib/services/navigation_observer.dart` — `AppNavigationObserver` maps routes to `GlobalPlaybackManager`: owners (`home`, `discover`, `profile`, `player`, `network`), block/pause for heavy routes, unblock for shell playback routes.
- `lib/pages/main_tab_view.dart` — tab shell; observer receives named routes from navigator.
- `lib/widgets/discover_view.dart` — discover feed; returns to home trigger resume path in `didPop` (Discover → Home).

## Behaviors reviewed

| Situation | Behavior |
|-----------|----------|
| Home / Discover / Profile / Player (named) | `unblock` + `setActiveOwner` for the matching owner. |
| Comments / share modals (`PopupRoute` / `ModalRoute` + name match) | Playback **continues** (supported modals). |
| Network | **Pause all** + non-playing owner (`network`). |
| **Upgrade** (`/upgrade` or name contains `upgrade`) | Same as network: **pause all**, non-playing owner — avoids “unknown route” fallback that left audio ambiguous. |
| Streamer card, camera/recording/upload, inbox/chat | **Block** + **pause** (distinct reasons for logs). |
| Unnamed `MaterialPageRoute` | Treated as **player** context (detail flows). |
| Unknown foreground route | **Block** + **pause** (`route_change_unknown`). |

## Modal API

- `handleModalPresentation` keeps comments/share modals from pausing; other modals pause; dismiss calls `resumeAfterTabSwitch` when an active owner exists.

## Testing notes (manual)

1. From **Home** feed, open **Comments** → confirm feed keeps playing (or muted per product); dismiss → audio/video state matches expectation.
2. Navigate to **Upgrade** from feed → playback **stops**; pop upgrade → return to feed and confirm **no stuck** blocked state (tab switch / owner).
3. **Discover** → open video → **pop** back to Home → logs show resume path; video resumes on home.
4. Open **Network** from tab or route → playback paused; return to Home → playback resumes per manager rules.

## Residual risk

- Routes without `settings.name` that are not `MaterialPageRoute` may still hit **unknown** branch; prefer named routes for new full-screen flows.
- `GlobalPlaybackManager` state must stay in sync with **dispose** of individual players; any new player widgets should register/unregister with the same patterns as existing feed cells.
