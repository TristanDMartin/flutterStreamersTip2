# StreamersTip — App & Features Documentation

**Last updated:** July 27, 2026  
**Primary product:** StreamersTip Flutter mobile app (`flutterST`)  
**Companion product:** StreamersTip web (`streamerstipReact`)

This document describes what the product does for creators and viewers — not implementation internals.

---

## 1. What StreamersTip Is

StreamersTip is a creator growth platform for streamers and short-form content creators. It combines:

- A **TikTok-style vertical video feed** for discovering and sharing clips
- A **creator operating system** for planning, scheduling, analytics, and coaching
- **Tippy**, an AI growth partner for captions, hooks, plans, missions, and stream advice
- **Gamification** (XP, levels, streaks, missions) to keep creators posting consistently
- **Social tools** (follows, DMs, activity, threads, profiles) so creators can network and collaborate

Tagline used in-app: **Connect · Create · Share**

### Platforms

| Surface | Role |
|---------|------|
| **iOS / Android (Flutter)** | Primary mobile app — feed, create, chat, Tippy, planner, academy, billing |
| **Web (Next.js)** | Marketing site, dashboard (Mission Control, Tippy, planner, analytics), educational guides, tools, admin |

App and website share Firebase Auth / Firestore user data, billing entitlements, Tippy, content plans, and creator progression so state stays aligned across surfaces.

---

## 2. Who It’s For

| Audience | What they use |
|----------|----------------|
| **Viewers / fans** | For You feed, follow creators, like/comment/share, DMs, bookmarks |
| **Creators** | Upload & schedule clips, Tippy, content planner, insights, Academy, missions, linked platforms |
| **Teams (Creator Studio)** | Team seats, automation, exportable reports |
| **Admins / staff** | Reports, users, uploads, audit logs, creator intelligence ops |

---

## 3. Main Navigation (Mobile)

After sign-in, the app opens **Main Tab View** with five bottom tabs:

| Tab | Name | What it does |
|-----|------|--------------|
| 0 | **Home** | Vertical video feed + Progression + Threads; Creator Command Center; Tippy entry |
| 1 | **Network** | Connections, followers, and following |
| 2 | **Create (+)** | Camera / gallery capture → edit → publish or schedule |
| 3 | **Inbox** | Chats and shared drafts |
| 4 | **Profile** | Your profile, videos, favorites, tagged; opens Menu |

---

## 4. Authentication & Account Security

### Sign-in options

- Google sign-in
- Email + password
- Sign up with email, username, and password (strength indicator)

### Account lifecycle

| Feature | What it does |
|---------|--------------|
| **Email verification** | Confirms new email accounts before full access |
| **Forgot / reset password** | Request reset, verify code, set new password |
| **Two-factor authentication (2FA)** | Optional TOTP setup with QR code and backup codes; required at login when enabled |
| **Account switcher** | TikTok-style switch between / add accounts on the device |
| **Banned account screen** | Blocks banned users with a clear status view |
| **Manage account** | Phone, email, password, 2FA, data export, account deletion |

---

## 5. Home — Feed, Progression & Threads

### Feed selector

Home uses a feed selector with three modes:

| Mode | Label in UI | What it does |
|------|-------------|--------------|
| **For You** | For You | Personalized vertical short-form feed (Mux HLS playback) |
| **Following** | Shown as **Progression** | Creator progress: level, XP, streaks, missions, achievements |
| **Threads** | Threads | Forum-style community threads (not a video feed) |

### For You feed

- Full-screen vertical swipe through videos
- Like, comment, share, bookmark / favorite
- Open creator profile (Streamer Card)
- Discover / search entry points
- Engagement and watch analytics power recommendations and creator stats

### Creator Command Center (overlay on Home)

A workspace overlay that surfaces:

- Consistency / momentum status
- Scheduled queue count and next post due
- Draft count and attention alerts
- One-tap paths to **Tippy**, **Content Planner**, or scheduling
- Tier-aware prompts (unlock Tippy when AI is not entitled)

### Progression (gamification panel)

- Level and XP toward the next level
- Streak days
- Daily / active missions
- “First things to do” onboarding checklist
- Achievements
- Weekly snapshot metrics
- Ties into Tippy missions and Academy progress

### Threads

- Browse and open forum threads
- Create threads
- Create a thread from a video comment
- Comment / reply on posts

---

## 6. Discover & Search

### Discover

Explore surface for:

- Trending creators
- Category cards (e.g. gaming, art, music, tech, sports)
- Category video feeds
- Jump into Activity or creator profiles

### Search

Unified search for:

- Users / creators
- Videos
- Hashtags  
Also stores recent searches and may show “Things you may like.”

---

## 7. Create, Publish & Drafts

### Capture

- Vertical (9:16) camera recording
- Flip camera, flash, grid overlay
- Gallery import
- Recording pauses other feed playback

### Preview & edit

- Retake or use clip
- Editing tabs: **Trim**, **Filters**, **Caption**, **Hashtags**

### Publish

On the publishing screen creators can:

- Write caption (max ~500 characters)
- Add hashtags
- Pick category
- Set thumbnail
- Choose privacy / visibility
- Publish now or **schedule**
- Get Tippy help to improve caption / hashtags (credit-gated)

Typical validation: duration about 1–300 seconds; categories include gaming, art, music, tech, sports.

### Drafts

- Local drafts list
- Resume or discard unfinished posts
- Share drafts with connections for feedback (Inbox → Shared Drafts)

### Manage posts / scheduled content

From Menu → **Scheduled**:

- View and manage scheduled / published posts
- Aligns with Content Scheduler queue

Uploads go through the app upload pipeline (Mux + backend processing) so playback is optimized HLS on Home and Profile.

---

## 8. Network

**Network** tab manages social graph:

| Sub-tab | Purpose |
|---------|---------|
| **Connections** | Mutual / connected creators |
| **Followers** | People following you |
| **Following** | People you follow |

Supports search, sort, pagination, and opening a Streamer Card for any user. Connections power share targets, DMs, and draft sharing.

---

## 9. Inbox, Chat & Activity

### Inbox

Two main areas:

1. **Chats** — conversation list with unread badges and search  
2. **Shared Drafts** — drafts shared for feedback  

Actions: open chat, start **New Message**, choose a person from connections / followers / following.

### Chat

- Real-time messaging
- Text + Giphy stickers
- Mute / block / report
- Online status indicators
- Offline-friendly inbox caching where supported

### Activity

Notifications-style feed of:

- Likes
- Follows
- Comments
- Tags
- Mentions  

Filterable (All | Likes | Follows | Comments | Tags | Mentions). Tapping rows opens the relevant profile or content.

---

## 10. Profiles & Streamer Cards

### Your Profile (tab)

- Avatar, display name, username, bio, stats
- Tabs: **Videos** | **Favorites** | **Tagged**
- Flip / back side: bio, platforms, calendar events, hashtags
- Edit profile, share profile, open Menu

### Edit profile

- Avatar upload
- Display name (cooldown rules apply, e.g. 7-day name change lock)
- Username, bio, status
- Social / website links
- Content moderation on text fields

### Streamer Card (other users)

Lightweight creator profile sheet:

- Follow / message / share
- Videos, favorites, tagged content
- Bio, linked platforms, calendar events
- Path into full profile or chat

### Share profile

Share a profile link (and related share sheet options including QR where available).

---

## 11. Video Playback, Comments & Engagement

### Player

Full-screen / page-style player used from Home, Discover, Favorites, and profile grids:

- Swipe between videos
- Like, comment, share, bookmark
- Owner actions: edit caption / privacy via options sheet
- Insights entry for the creator’s own videos
- Report, block, not interested

### Comments

- List with sort (newest / most liked)
- Replies
- Create comment
- Optional path to start a Thread from a comment

### Share sheet

- Share to connections
- QR code for the video
- Report / block / not interested / favorite

---

## 12. Tippy — AI Creator Coach

**Tippy** is StreamersTip’s AI growth partner.

> “Your creator growth partner who understands streaming, content, analytics, branding, and creator life.”

### Where to open Tippy

- Creator Command Center on Home
- Dedicated Tippy chat route (`/tippy`)
- Publish assist (“Improve caption”)
- Web: `/ask-tippy` and `/dashboard/tippy`

### What Tippy can do

| Capability | What it does |
|------------|--------------|
| **Chat coaching** | Streaming, OBS, growth, branding, consistency advice |
| **Content plans** | Turn goals / chat into plans stored in Content Planner |
| **Captions & hashtags** | Generate or rewrite short-form captions |
| **Content analysis** | Review pasted captions/scripts |
| **Hook ideas** | Short-form hook suggestions |
| **Daily mission** | Generate today’s mission |
| **Growth program** | Start a structured growth program / plan |
| **Schedule proposals** | Suggest scheduling moves |
| **Creator goals** | Capture goals that personalize Tippy |

### Credits & tiers

Tippy uses **monthly AI credits** from the user’s subscription entitlements. Depth of coaching and available actions scale by tier (Creator → Creator Pro → Creator Studio). Credit balance is shown in the Tippy UI.

---

## 13. Content Planning & Scheduling

### Content Planner

Plan posting cadence and campaign-style plans:

- List of content plans
- Consistency score and scheduled queue summary (from Creator Command snapshot)
- Open plan detail
- Create plans via Tippy or planner UI
- Limits: Starter typically **1 active plan**; Pro/Studio **unlimited** (enforced by entitlements API)

### Content Scheduler

Queue of scheduled items:

- Refreshable schedule queue
- Status of upcoming / processing posts
- Works with Manage Posts and publish-time scheduling

App and web planner stay aligned on the same backend plans / queue.

---

## 14. Analytics, Insights & Reports

### Per-video Insights

Opened from a video you own:

- **Overview** — views and core performance
- **Viewers** — audience breakdown
- **Engagement** — likes, comments, shares, etc.

### Creator Intelligence (Menu)

Four tabs:

1. **Overview** — profile analytics for an allowed time window  
2. **Content** — content performance insights  
3. **Tippy** — Tippy usage / coaching signals  
4. **Growth** — growth trends  

Analytics history window is tier-gated (about **7 / 90 / 365** days).

### Creator Insights (Menu)

Per-video performance and audience deep-dive (companion to Intelligence).

### Growth Analytics

Dedicated growth analytics view for longer-term creator metrics.

### Weekly Report

Weekly growth / performance recap. Basic recap on free tier; **full weekly growth reports** on Pro+; exportable business reports on Studio.

---

## 15. Streamer Academy

In-app learning product for creators:

- Home: guides, categories, XP/level header, quests
- Search guides
- Saved guides
- Progress tracking
- Paths → guides → lessons
- Completion percentages and gamification XP tie-in

Web mirror: `/streamer-academy` plus dozens of public streaming guides (OBS, Twitch, Kick, TikTok, audio, etc.).

---

## 16. Gamification & Missions

Creators earn progress by using the product (posting, watching, social actions, Academy, Tippy missions).

| Concept | What it does |
|---------|--------------|
| **XP & levels** | Progress bar toward next level |
| **Streaks** | Reward consistent daily activity |
| **Daily missions** | Short goals; Tippy can generate missions |
| **Achievements** | Unlockable milestones |
| **Creator Score** | Aggregate health / momentum signal used in coaching |
| **Mission Control (web)** | Dashboard for missions and progression |

Progression is largely server-authoritative; the app reads live progress bundles from Firestore / APIs.

---

## 17. Bookmarks

Save content / events and browse by status (e.g. upcoming, live, past). Opened from Menu → **Bookmarks**. Favorites on profiles and the feed also act as saved video collections.

---

## 18. Linked Platforms & Cross-Posting

**Linked Platforms** connects external streaming / social accounts (feature-flagged; OAuth reconnect supported for platforms such as YouTube).

Entitlements control:

- How many platforms can be connected
- Whether **cross-posting** is allowed
- Weekly cross-post limits
- Bulk / scheduled publishing and automation (higher tiers)

---

## 19. Studio Team Control

**Creator Studio** feature for team workflows:

- Team & automation control panel
- Seat limits (catalog: up to **5** team members)
- Approvals / automation flags
- Export weekly report JSON (Studio-gated; otherwise prompts upgrade)

Web: `/dashboard/team` and settings team pages.

---

## 20. Subscriptions & Entitlements

Plans (API ids: `starter` | `pro` | `studio`):

| Display name | API id | Positioning |
|--------------|--------|-------------|
| **Creator** | `starter` | Free / entry — upload, basic Tippy, 1 plan, 7-day analytics |
| **Creator Pro** | `pro` | Serious creators — more AI credits, unlimited plans, stronger reports |
| **Creator Studio** | `studio` | Teams — max AI credits, year analytics, seats, automation, exports |

### Typical entitlement highlights (catalog / marketing; live gates use API)

| Capability | Creator | Creator Pro | Creator Studio |
|------------|---------|-------------|----------------|
| Content uploads | Unlimited | Unlimited | Unlimited |
| Active content plans | 1 | Unlimited | Unlimited |
| Monthly AI credits | 25 | 500 | 2,500 |
| Analytics history | 7 days | 90 days | 365 days |
| Connected platforms | 1 | 5 | Unlimited |
| Cross-posting | — | Yes | Unlimited weekly |
| AI caption rewrite | — | Yes | Yes |
| Weekly growth reports | Basic recap | Full | Full + export |
| Team members | — | — | Up to 5 |
| Automation / approvals | — | — | Yes |
| Content planner | Yes | Yes | Yes |

### Upgrade & billing in app

- Menu → **Upgrade** — compare tiers and subscribe
- Mobile IAP purchase verification where enabled
- Subscription status labels: Free trial, Active, Past due, Grace period, Canceled, Expired, Free
- Feature gates redirect to Upgrade when a paid capability is blocked

---

## 21. Menu & Settings

### Menu (from Profile)

| Item | Purpose |
|------|---------|
| Creator Intelligence | Insights, trends, next steps |
| Creator Insights | Per-video performance & audience |
| Upgrade | View tiers & subscribe |
| Bookmarks | Saved content |
| Scheduled | Manage posts / schedule |
| Settings | Privacy & account hub |
| Appearance | Light, dark, or system |
| Contact Support | Help / tickets |
| Log Out | Sign out |

### Settings & Privacy hub

| Section | Screens |
|---------|---------|
| **Account** | Manage Account, account switcher |
| **Security** | 2FA settings |
| **Privacy** | Privacy settings, Blocked accounts, Mentions & tags |
| **Content & Activity** | Notifications, Content preferences, Video categorization |
| **Support & About** | Report a problem, Safety Center, Community Guidelines, Terms & Privacy, About |

Notable preference areas:

- Who can see content / mention / tag you
- Notification preferences
- Language, restricted mode, screen time style limits
- Appearance theme

---

## 22. Safety, Moderation & Support

| Feature | What it does |
|---------|--------------|
| **Report** | Report videos, users, or problems |
| **Block** | Block users; manage blocked list |
| **Not interested** | Downrank / hide similar feed content |
| **Mute (chat)** | Mute conversations |
| **Community Guidelines** | In-app policy reference |
| **Safety Center** | Safety resources |
| **Contact Support** | Support tickets / help |
| **Content moderation** | Filters abusive profile/content text where wired |

---

## 23. Admin (Staff Only)

Mobile **Admin Control Center** (permission-gated) includes:

- Overview metrics
- User list / user detail (ban, role, tier)
- Reports triage (dismiss / resolve / ban)
- Uploads monitoring
- Video detail inspection
- Creator intelligence ops views
- Audit log

Web admin expands this further (`/admin/*`): users, content, analytics, pricing, gamification, CDN, monitoring, AI chatbot, security, founder analytics, etc.

---

## 24. Companion Web Product (High Level)

The website is both a marketing + education surface and a logged-in creator dashboard.

### Core product routes

| Area | Typical path | What it does |
|------|--------------|--------------|
| Homepage | `/` | Brand, Tippy/Mission demos, CTAs |
| Ask Tippy | `/ask-tippy`, `/dashboard/tippy` | Full Tippy chat |
| Mission Control | `/dashboard/mission-control` | Missions, XP, creator OS home |
| Content Planning | `/dashboard/content-planning` | Plans synced with app |
| Content Scheduler | `/dashboard/content-scheduler` | Schedule queue |
| Growth Analytics | `/dashboard/growth-analytics` | Analytics dashboards |
| Reports | `/dashboard/reports` | Growth reports |
| Team | `/dashboard/team` | Studio team |
| Pricing | `/pricing` | Plan comparison / checkout |
| Discover / For You | `/discover`, `/for-you` | Web discovery / feed surfaces |
| Streamer profiles | `/streamer/...`, `/creator/[username]` | Public creator pages |
| Streamer Academy | `/streamer-academy` | Learning hub |
| Tools | `/tools/*` | Free tools (caption, hashtag, calendar, ROI, bios, etc.) |
| Auth | `/auth/*` | Login, 2FA, password flows |
| Settings | `/settings/*` | Account, billing, platforms, privacy, team |
| Admin | `/admin/*` | Staff ops |

### Web-heavy / web-only emphasis

- Large library of SEO streaming guides (Twitch, Kick, TikTok, OBS, audio, monetization)
- Free creator tools
- Stripe-oriented pricing/checkout (alongside mobile IAP)
- Richer admin and Mission Control layouts

Mobile remains the primary place for the TikTok-style create + feed loop; web is strongest for dashboard, Tippy sessions, planning, and education.

---

## 25. Feature Map by User Job

| Job to be done | Use |
|----------------|-----|
| Discover creators & clips | Home For You, Discover, Search |
| Grow as a creator | Tippy, Planner, Scheduler, Missions, Academy |
| Post consistently | Create flow, drafts, schedule, Command Center |
| Understand performance | Insights, Creator Intelligence, Weekly Report |
| Build community | Network, Inbox, Activity, Threads, comments |
| Monetize / unlock power tools | Upgrade → Creator Pro / Studio |
| Learn streaming craft | Academy + web guides / tools |
| Moderate the platform | Admin Control Center (staff) |

---

## 26. Data Domains (Product View)

| Domain | User-facing meaning |
|--------|---------------------|
| **Videos** | Clips in feed, profile grids, player |
| **Users / profiles** | Accounts, avatars, bios, stats |
| **Chats / messages** | Inbox conversations |
| **Activity** | Social notifications |
| **Bookmarks / favorites** | Saved content |
| **Content plans** | Tippy/planner campaigns |
| **Scheduled posts** | Future publishes |
| **Gamification** | XP, levels, missions, streaks |
| **Entitlements / billing** | What Tippy & planner features you can use |
| **Academy progress** | Lesson completion |
| **Reports / analytics** | Performance history |

Underlying stack (for operators): Firebase Auth + Firestore, Mux video, Cloudflare workers for upload/API paths, shared entitlements API with the website.

---

## 27. Related Internal Docs

| Doc | Contents |
|-----|----------|
| `docs/PHASE1_WORLD_CLASS_POLISH.md` | **Active charter** — polish existing pillars (no new systems) |
| `docs/APP_PAGE_WALKTHROUGH.md` | Screen-by-screen file map for engineers |
| `docs/ARCHITECTURE_FIREBASE_CLOUDFLARE_MUX.md` | Backend architecture |
| `docs/COMPREHENSIVE_APP_AUDIT.md` | Audit notes |
| `docs/PRODUCTION_READINESS_SCORECARD.md` | Page scores & remaining gaps |

---

## 28. Quick Glossary

| Term | Meaning |
|------|---------|
| **Tippy** | AI creator coach |
| **Creator Command Center** | Home overlay for next actions / schedule health |
| **Progression** | XP, levels, missions, streaks UI |
| **Streamer Card** | Compact other-user profile |
| **Content Plan** | Multi-day / campaign posting plan |
| **Entitlements** | Server-enforced feature limits for a subscription |
| **Threads** | Forum-style community posts |
| **Creator / Pro / Studio** | Subscription display names |

---

*This documentation is intended for product, support, and onboarding. For code-level navigation of every view file, see `APP_PAGE_WALKTHROUGH.md`.*
