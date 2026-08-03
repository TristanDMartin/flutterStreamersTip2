# Canonical Profile Experience Audit

**Date:** 2026-08-02  
**Canonical reference:** Flutter `ProfileViewOptimized` (+ flip `ProfileBackView`)  
**Website targets:** `/streamer/[username]` (public) and `/profile` (own hub)  
**Goal:** Document every material difference before alignment work. Website should feel like an expanded ProfileView—not a different product.

---

## 1. Surfaces compared

| Surface | Role | Canonical? |
|---------|------|------------|
| Flutter ProfileView front | Own / routable profile identity + tabs | **Yes — primary** |
| Flutter ProfileBackView | Bio / Platforms / Calendar (flip) | **Yes — details** |
| Flutter Streamer Card | Peer Follow/Message/Share + same visual language | Related peer surface |
| Website `/streamer/[username]` | Public creator profile | Align to ProfileView + Streamer Card actions |
| Website `/profile` | Signed-in creator OS (edit, inbox, certs…) | Keep as **desktop management hub**; hero/identity must still match ProfileView |

**Decision:** Public web profile (`/streamer/...`) is the parity target for “viewing a creator.” Own `/profile` may keep desktop-only management tabs, but its **hero identity block** must match Flutter front hierarchy.

---

## 2. Information hierarchy (desired canonical order)

Proposed shared front order (from Flutter + product brief):

1. Avatar (+ presence when applicable)
2. Display name
3. `@username`
4. Live / presence status
5. Creator Score badge (compact)
6. Quiet stats: Posts · Followers · Following
7. Action buttons (context-dependent)
8. Content tabs
9. Tab content (Videos / …)

Details (Flutter back / web secondary):

10. Bio  
11. Categories / hashtags  
12. Social platforms  
13. Calendar  
14. Threads (feed module — web has tab; Flutter currently not on ProfileView front)  
15. Activity / about (web-only today — decide)

---

## 3. Difference matrix

### 3.1 Overall product model

| Topic | Flutter ProfileView | Website | Gap |
|-------|---------------------|---------|-----|
| Flip front/back | Front = identity + video tabs; Back = Bio/Platforms/Calendar | No flip; Bio inline on hero; Platforms/Calendar as tabs | **Major** — different mental model |
| Own vs peer | ProfileView = own-first; peers use Streamer Card | `/profile` own hub vs `/streamer` public | Different split; OK if heroes align |
| Branding | Tippy navy `#0B1224`, glass pills | `#070b14` / `#0f1322` / `#151a2b` cards | Close but not identical |
| Radius language | 18–24 glass | Mostly `0.5rem` (8px) cards | **Visual drift** |

### 3.2 Header / chrome

| Topic | Flutter | Website | Gap |
|-------|---------|---------|-----|
| App bar | Flip · (Streamer Card gated) · More → Menu | Share · Mute · ⋮ Report/Block (public); Tour · Share (own) | Different chrome; web lacks flip |
| Background | Solid `#0B1224` | Dark page + inset surface cards | Web feels more “dashboard card” |
| Back navigation | None on profile tab | Browser / site header | Expected |

### 3.3 Creator identity

| Topic | Flutter | Website | Gap |
|-------|---------|---------|-----|
| Avatar size | 112 front | 128 | Minor |
| Avatar ring | Pink→purple→blue sweep | Simpler / status dot | **Visual** |
| Bio on front | **No** (back only) | Own: always; Public: if present | **Hierarchy** |
| Hashtags / categories | Back chips | Edit form niches/goals; not same front chips | Missing on public hero |
| Subscription / Academy badges | Not on ProfileView chrome | Prominent on web hero | Web-only chrome |
| Joined date | No | Own yes | Web-only |
| Presence | Own status dot | Own editable StatusIndicator; public pill | Align labels/colors |

### 3.4 Statistics

| Topic | Flutter | Website | Gap |
|-------|---------|---------|-----|
| Order | Posts · Followers · Following | Same | Aligned |
| Connections | Hidden on ProfileView | Not on hero | OK |
| Presentation | Quiet text row | Bordered mini cards | Style drift |
| Creator Score | Overlay badge → sheet | Badge + modal (similar breakdown) | Mostly aligned |

### 3.5 Action buttons

| Context | Flutter | Website | Gap |
|---------|---------|---------|-----|
| Own front | Edit Profile · Share Profile | Tour · Share · View Analytics | Terminology + extras |
| Peer | Streamer Card: Follow · Message · Share | Follow · Message · Share · Mute · Report/Block | Web richer moderation (keep desktop) |
| Message enablement | Streamer Card rules | Only when Connected | Verify same follow-graph rules |

### 3.6 Tabs (navigation order)

| Flutter ProfileView | Website public `/streamer` | Website own `/profile` |
|---------------------|----------------------------|-------------------------|
| 1. Video | 1. Videos {count} | 1. Edit Profile |
| 2. Favorites | 2. Threads | 2. Videos |
| 3. Tagged | 3. Network | 3. Threads |
| | 4. Platforms | 4. Inbox |
| | 5. Calendar | 5. Calendar |
| | | 6. Bookmarks |
| | | 7. Certifications |
| | | 8. Commands (conditional) |
| | | 9. My Network |

**Gaps:**
- Flutter has **Favorites** + **Tagged**; public web has neither (Bookmarks live only on own `/profile`).
- Web has **Threads** / **Network** / **Platforms** / **Calendar** as top tabs; Flutter puts Platforms/Calendar on **back**, Threads not on ProfileView.
- Own web `/profile` leads with **Edit Profile** — management-first, not identity-first like Flutter.

### 3.7 Content & empty states

| Topic | Flutter | Website | Gap |
|-------|---------|---------|-----|
| Video empty (own) | “No Videos Yet” / start creating | “No videos yet” + Upload CTA | Close |
| Favorites private | Explicit private empty | N/A on public | Missing feature on public |
| Tagged | Dedicated tab | Absent | **Feature gap** |
| Platforms empty | Back: “No platforms added yet.” | Platforms tab empty state | OK if relocated |
| Loading | Skeleton grids / “…” stats | Spinners + pulse skeletons | Cohesive enough |
| Errors | Labeled retry states | Not found / load errors | Align copy |

### 3.8 Gamification

| Topic | Flutter | Website | Gap |
|-------|---------|---------|-----|
| Creator Score badge + modal | Yes | Yes | Align styling to Tippy glass |
| XP / streak on profile | No | No on hero | OK |
| Certifications tab | No on ProfileView | Own `/profile` only | Desktop hub OK |
| Tour | No | Own Tour button | Desktop OK |

### 3.9 Data consistency

| Data | Flutter | Website | Risk |
|------|---------|---------|------|
| Own profile | `users/{uid}` (+ cache) | `users/{uid}` | OK |
| Public profile | `publicUsers` watch | `publicUsers` resolve | OK if same fields |
| Stats | Shared field resolution | Similar fallbacks | Audit field aliases |
| Videos | VideoService / owner feeds | `/api/profile-videos` | Count drift possible |
| Score | `creatorScore/current` | Same path | OK |
| Platforms | User profile parse | platforms subcollection → user | Verify merge parity |
| Calendar | Content planning API + user events | Calendar views | Verify same events |

### 3.10 Motion & interaction

| Topic | Flutter | Website |
|-------|---------|---------|
| Signature motion | Card flip 600ms | No flip |
| Tab change | Fade/slide 240ms | Hover color 150ms |
| Desktop hover | N/A | Thumb lift, score glow | Keep as desktop enhancement |

---

## 4. Features: canonical vs platform-specific

### Become or stay canonical (both platforms)

- Tippy navy identity surface (not generic slate cards)
- Quiet stats row: Posts · Followers · Following
- Creator Score compact badge + same breakdown modal
- Video / Favorites / Tagged (or explicit decision to drop Tagged on web)
- Bio, Platforms, Calendar as **details** (flip or details panel—not competing with video tabs)
- Edit + Share (own); Follow + Message + Share (peer)
- Same terminology: **Video** vs **Videos**, **Favorites** vs **Bookmarks** (pick one)

### Website-only (allowed desktop hub — do not put on Flutter ProfileView front)

- Inbox tab, Certifications, Commands, Bookmarks manager, bulk video manage, upload/publish, analytics link, billing banner, tour, report/mute/block menu

### Flutter-only today (decide)

- Profile flip + Streamer Card entry (admin-gated)
- Tagged tab
- Favorites privacy gate on peer card

---

## 5. Recommended alignment direction (no implementation yet)

### Phase A — Public `/streamer/[username]` → ProfileView parity

1. Restyle hero to Tippy navy / glass language; quiet stats (not heavy mini-cards).
2. Match identity order: Avatar → Name → @handle → status → Score → stats → actions.
3. Move Bio out of competing with tabs into a **Details** section or tab that mirrors ProfileBackView (Bio · Platforms · Calendar).
4. Align primary tabs with Flutter: **Video · Favorites · Tagged** (map Bookmarks→Favorites; add Tagged or document deferral).
5. Keep Threads / Network as secondary modules or under Details—do not bury Video behind Edit-style chrome.
6. Preserve desktop enhancements: wider hero, hover on thumbs, moderation ⋮.

### Phase B — Own `/profile` hero parity

1. Make hero match Flutter front (Edit Profile + Share Profile as primary CTAs).
2. Keep management tabs (Inbox, Certs, …) **below** identity—or in a “Creator tools” strip—so first viewport feels like ProfileView.
3. Prefer opening Edit as a panel/route from the Edit CTA, not as tab #1.

### Phase C — Data & terminology lock

1. Shared display helpers for username/displayName (mirror Flutter `ProfileUsernameUtils`).
2. Single posts-count resolution rules.
3. Glossary: Favorites = saved videos; Threads = Creator Threads; etc.

### Phase D — Optional flip on web

Desktop can use a Details panel or soft flip affordance; do not block parity on a literal CSS 3D flip.

---

## 6. Success checklist (from brief)

| Criterion | Status today |
|-----------|--------------|
| Instantly familiar across platforms | **No** — web is hub/card; Flutter is Tippy flip profile |
| Navigation consistent | **No** — different tab sets/order |
| Same information order | **Partial** — stats OK; bio/platforms/tabs differ |
| Shared component identity | **Partial** — score similar; chrome/radius/colors drift |
| Branding consistent | **Partial** — purple OK; navy/glass incomplete on web |
| Data identical | **Mostly** — watch for video counts / platforms merge |
| Desktop = enhanced mobile | **Not yet** — desktop is a different IA |

---

## 7. Key file references

**Flutter**
- `lib/widgets/profile_view_optimized.dart`
- `lib/widgets/profile_view/profile_view_front_shell.dart`
- `lib/widgets/profile_view/profile_view_header_section.dart`
- `lib/widgets/profile_view/profile_view_tabbed_section.dart`
- `lib/widgets/profile_back_view.dart`
- `lib/widgets/streamer_card_view.dart`

**Website**
- `app/streamer/[username]/StreamerPageClient.tsx`
- `app/profile/page.tsx`
- Related: `EditProfileView`, `ForumSection`, `FollowButton`, Creator Score components

---

## 8. Audit complete — decisions locked

See [`PROFILE_CANONICAL_ARCHITECTURE.md`](PROFILE_CANONICAL_ARCHITECTURE.md).

| Question | Decision |
|----------|----------|
| Threads / Network top-level? | **Threads** top-level. **Network** not primary — Details or secondary module. |
| Tagged on web? | **Yes** — top-level tab. |
| Bookmarks naming? | Canonical name: **Favorites**. |
| Own `/profile` hub? | Same canonical profile first; owner tools **below** identity. |
| Bio on hero? | Prefer **Details** (Flutter front has no bio). |
| Flip on web? | Details panel (no required 3D flip). |

**Implementation status (2026-08-02):** P0–P4 shipped (shared chrome, identity helpers, desktop layout). P5 Flutter naming follow-up optional.
