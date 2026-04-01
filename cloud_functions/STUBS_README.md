# Re-implemented Cloud Functions

The 19 functions below were previously deployed from another codebase. They are now **re-implemented** in this repo so `firebase deploy --only functions` succeeds and behavior matches app/API usage.

## Implementations

| Function | Behavior |
|----------|----------|
| **apiCsrfToken** | GET/POST: returns a random CSRF token and `expiresIn` (seconds). |
| **apiReports** | GET: list last 50 reports (auth required). POST: submit video or user report (auth + body: videoId or userId, reason, type). |
| **apiVideoUpload** | POST: auth required, body `{ videoId, contentType }`. Returns signed Storage URL for `videos/{uid}/{videoId}.mp4`. |
| **apiGoogleSecurityEvents** | POST: appends body to `security_events` collection with `receivedAt`. |
| **apiKickAuthStart** | Redirects to Kick OAuth. Requires config: `kick.client_id` or env `KICK_CLIENT_ID`. |
| **apiKickAuthCallback** | Exchanges code for token, redirects back with `kick_connected=1&access_token=...`. Requires `kick.client_id`, `kick.client_secret` (or env). |
| **apiKickValidate** | GET with `Authorization: Bearer <token>`. Returns `{ valid: true/false }`. |
| **apiTwitchAuthStart** | Redirects to Twitch OAuth. Requires `twitch.client_id` or `TWITCH_CLIENT_ID`. |
| **apiTwitchAuthCallback** | Exchanges code, redirects with `twitch_connected=1&access_token=...`. Requires client_id + client_secret. |
| **apiYoutubeAuthStart** | Redirects to Google OAuth. Requires `youtube.client_id` or `YOUTUBE_CLIENT_ID`. |
| **apiYoutubeAuthCallback** | Exchanges code, redirects with `youtube_connected=1&access_token=...`. Requires client_id + client_secret. |
| **healthCheck** | GET: returns `200` and `{ ok: true }`. |
| **markChatAsRead** | Callable: `{ chatId }`. Requires auth. Updates `chats/{chatId}` with `unreadCount: 0`, `unreadCount_{uid}: 0`, `lastReadTimestamp`. Participant-only. |
| **onCommentDelete** | Trigger: `videos/{videoId}/comments/{commentId}` onDelete. Decrements `videos/{videoId}.commentCount` by 1. |
| **onFollowDelete** | Trigger: `follows/{followId}` onDelete. Decrements `users/{followedId}.followerCount` and `users/{followerId}.followingCount` by 1. |
| **onVideoWrite** | Trigger: `videos/{videoId}` onWrite. Syncs view/like deltas to creator `users/{creatorId}.totalViews` / `totalLikes`. |
| **sendWelcomeEmail** | Auth user onCreate. Sends welcome email via Resend if `resend.key` or `RESEND_KEY` is set; otherwise logs. |
| **cleanupExpiredCalendarEvents** | Scheduled every 24h. Marks `scheduled_posts` with `status: pending` and `schedule.scheduledAtUtc` in the past as `status: expired`. |
| **manualCleanupCalendarEvents** | Callable. Admin only (`customClaims.admin === true`). Same cleanup as above; returns `{ ok: true, expired: count }`. |

## Configuration

Set via Firebase config or environment:

- **OAuth (optional):**  
  - Kick: `kick.client_id`, `kick.client_secret` (or `KICK_CLIENT_ID`, `KICK_CLIENT_SECRET`).  
  - Twitch: `twitch.client_id`, `twitch.client_secret` (or `TWITCH_CLIENT_ID`, `TWITCH_CLIENT_SECRET`).  
  - YouTube: `youtube.client_id`, `youtube.client_secret` (or `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET`).
- **Resend (welcome email):** `resend.key` or `RESEND_KEY`; optional `resend.from` or `RESEND_FROM` for sender address.

Example:

```bash
firebase functions:config:set resend.key="re_xxx" kick.client_id="xxx" kick.client_secret="xxx"
```

## Firestore

- **Reports:** `reports` (video), `user_reports` (user).  
- **Chats:** `chats/{chatId}` with `unreadCount`, `unreadCount_{userId}`, `lastReadTimestamp`, `participants`.  
- **Videos:** `videos/{videoId}` with `commentCount`, `views`, `likes`, `userId`/`creatorId`.  
- **Users:** `users/{userId}` with `followerCount`, `followingCount`, `totalViews`, `totalLikes`.  
- **Scheduled:** `scheduled_posts` with `status`, `schedule.scheduledAtUtc`.
