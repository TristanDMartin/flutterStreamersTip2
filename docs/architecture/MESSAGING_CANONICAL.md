# Messaging Canonical Architecture (Inbox + Chat)

**Status:** Flutter mobile Inbox/Chat is the design + IA source of truth.  
**Website should follow Flutter** (same pattern as Profile canonical).

| Role | Path |
|---|---|
| **Canonical (mobile)** | Flutter `InboxViewOptimized` + `ChatViewOptimized` + `ChatUiTokens` |
| **Align to mobile** | Website `InboxView` + `ChatView` |

## Surfaces

| Surface | Flutter (canonical) | Website (follows Flutter) |
|---|---|---|
| Inbox list | Main tab → `InboxViewOptimized` | `/profile?tab=messages` → `InboxView` |
| Thread | Pushed `ChatViewOptimized` | Embedded `ChatView` (nav model may differ; chrome matches) |
| New message | `NewMessageView` | New-message modal |

## Locked IA (from mobile)

1. Header: **Messages** + Select + **New Message** / **+ New**
2. Always-on search
3. Flat conversation list (no Requests/Groups until both ship)
4. Chat: back + identity chip (name + status) + overflow
5. Composer: text + send; media via attach/paste
6. System account (`STREAMERTIP_SYSTEM`): read-only, no composer

## Visual tokens

Canonical tokens: Flutter `lib/widgets/chat/chat_ui_tokens.dart`.

Website CSS (`InboxView.module.css`, `ChatView.module.css`) should track those tokens — not the reverse.

## Data fields (shared)

- `deletedFor[]`, `unreadCount_{uid}`, `unreadCountByUser.{uid}`, `mutedBy[]`
- Badge skips `supersededBy` + soft-hidden chats; CF increments both unread fields
- `pinnedUntilViewed` / system participant
- Message: `deleted` / `deletedForEveryone`, `readBy`, `gifUrl`, `messageType`

## Non-goals

- Forcing website’s embedded chat into a Flutter full-screen route (platform nav can differ)
- Shipping edit/reactions on mobile before website parity is intentional
