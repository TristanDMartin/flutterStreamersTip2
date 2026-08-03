# Canonical Cross-Platform Profile & Platform Architecture

**Date:** 2026-08-02  
**Status:** Decisions locked — P1–P4 website alignment shipped  
**Companion audit:** [`PROFILE_CANONICAL_PARITY_AUDIT.md`](PROFILE_CANONICAL_PARITY_AUDIT.md)

## Vision

One StreamersTip experience across Flutter, website, and future desktop—not three products. Flutter ProfileView is the **canonical reference**. Website becomes a richer desktop presentation of the same identity, hierarchy, and design language.

## Platform philosophy

| Platform | Role | Optimize for |
|----------|------|--------------|
| Mobile (Flutter) | Everyday companion | Networking, video, messaging, Threads, Discover, Tippy chat, quick management |
| Website / Desktop | Production workspace | Planning, calendar, bulk schedule, library, team, analytics, studio, monetization |

Both must feel unmistakably like StreamersTip. Desktop enhances productivity; it does not invent a second identity system.

## Locked decisions

1. **Do not redesign Flutter ProfileView** for this phase.
2. **Identity first** — profile is not a dashboard. Hero always leads with creator identity.
3. **Public and own profiles share the same canonical profile shell.** Owner tools appear **below** (or beside on large desktop), never replacing the hero.
4. **Canonical primary tabs (order):**
   1. Videos  
   2. Threads  
   3. Favorites  
   4. Tagged  
   5. Details  
5. **Terminology:** use **Favorites** everywhere (retire Bookmarks/Saved for this surface).
6. **Details** consolidates Flutter ProfileBackView content: Bio, Platforms, Calendar/schedule, creator info, achievements/social links. No literal flip required on desktop.
7. **Threads** remain a top-level tab (core social feature).
8. **Tagged** remains a top-level tab.
9. **Network** is not a primary profile tab; surface under Details or a secondary module so it does not compete with content tabs.
10. **Visual language:** Tippy navy `#0B1224`, glass surfaces, 18–24px radius, Flutter-aligned typography/spacing/buttons; desktop may add hover and multi-column layouts.
11. **Data:** one canonical creator model / shared backends — no divergent creator fields per platform.

## Information hierarchy (hero)

1. Avatar (+ presence / live when applicable)  
2. Display name  
3. `@username`  
4. Live / presence status  
5. Creator Score (+ level/badges as compact chrome)  
6. Quiet stats: Posts · Followers · Following  
7. Primary actions (own: Edit · Share; peer: Follow · Message · Share)  
8. Tabs (Videos → Details)  
9. Tab content  

Bio and platforms live in **Details**, not competing with the primary tab bar (short hero bio line optional on desktop only if it matches Flutter front—Flutter front has no bio).

## Own-profile tools (below identity)

Allowed desktop/owner tools (do not replace hero):

Edit Profile · Analytics · Inbox · Creator Studio · Team · Monetization · Certifications · Commands · Settings · Bulk video manage · Upload

## Implementation phases

| Phase | Scope |
|-------|--------|
| **P0** | This doc + audit decisions closed |
| **P1** | Public `/streamer/[username]`: Tippy navy hero, quiet stats, canonical tab set + Details panel |
| **P2** | Own `/profile`: same hero shell; move management tabs below identity |
| **P3** | Shared components (buttons, tabs, score badge, empty states) + Favorites naming | ✅ shipped |
| **P4** | Data helpers parity (username, post counts, platforms merge) | ✅ identity helpers shipped; post-count already shared via `resolveDisplayedPostCount` |
| **P5** | Flutter follow-up only if needed for Threads/Favorites/Tagged naming consistency on ProfileView | optional |

## Success criteria

- Same recognizable profile across mobile, web, desktop  
- Identity before management tools  
- Shared design language and navigation  
- Identical creator data  
- Desktop feels like Flutter expanded  

## Open (non-blocking)

- Exact Favorites privacy rules for public viewers (mirror Flutter `showFavoritesOnCard`)  
- Whether Network appears inside Details or as a linked module  
- Literal soft-flip animation on web (optional polish; Details panel is sufficient)
