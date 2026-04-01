# StreamersTip App — Full View Details

## App Entry Flow

```
main.dart → IOSMinimalStartup → MyApp → AppStartupWrapper
  ├── [Loading] → Splash
  ├── [Logged in] → MainTabView
  └── [Not logged in] → AuthModalView
```

---

## 1. Splash / Loading

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/app_startup_wrapper.dart` |
| **When** | Firebase init or auth check in progress |
| **UI** | Purple gradient `#6137EB` → `#1C135D`, logo, "StreamersTip", "Connect • Create • Share" |
| **Data** | `authService.shouldShowLoading` |

---

## 2. Auth Flow

### AuthModalView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/auth_modal_view.dart` |
| **Purpose** | Landing when not logged in |
| **UI** | Gradient, logo, Sign In / Sign Up, Google, Email, Terms & Privacy |
| **Data** | `RobustAuthService` |
| **Out** | EmailLoginView, SignupView |

### EmailLoginView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/email_login_view.dart` |
| **Props** | `dismiss?: VoidCallback` |
| **UI** | Email + password fields, Sign In, Forgot Password, Sign Up link |
| **Out** | SignupView, ForgotPasswordView, TwoFactorVerificationView |

### SignupView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/signup_view.dart` |
| **Props** | `dismiss?: VoidCallback` |
| **UI** | Email, username, password, confirm password, strength indicator |
| **Out** | EmailLoginView, EmailVerificationView |

### ForgotPasswordView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/forgot_password_view.dart` |
| **Purpose** | Password reset request |

### EmailVerificationView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/email_verification_view.dart` |
| **Purpose** | Verify email after signup |

### TwoFactorVerificationView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/two_factor_verification_view.dart` |
| **Purpose** | Enter 2FA code during login |

### TwoFactorSetupView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/two_factor_setup_view.dart` |
| **Purpose** | Enable 2FA (QR code, backup codes) |

### TwoFactorSettingsView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/two_factor_settings_view.dart` |
| **Purpose** | Manage 2FA (enable/disable, backup codes) |

---

## 3. Main Tabs (MainTabView)

| Property | Value |
|----------|-------|
| **File** | `lib/pages/main_tab_view.dart` |
| **UI** | PageController + IndexedStack, CustomBottomNav (5 tabs) |
| **Tabs** | 0: Home, 1: Network, 2: Create (+), 3: Inbox, 4: Profile |

---

## 4. Home Tab

### HomeView

| Property | Value |
|----------|-------|
| **File** | `lib/pages/home_view.dart` |
| **Purpose** | Main vertical video feed |
| **UI** | FeedSelectorWidget (For You / Following / Threads), HomeContentWidget, VideoPageViewWidget |
| **Data** | HomeProvider, FeedStateProvider, VideoService, UnifiedAlgorithmService |
| **Out** | DiscoverView, NetworkView, PlayerScreen, StreamerCardView |
| **Services** | GlobalPlaybackManager, EngagementAnalyticsService, OfflineDataService |

### DiscoverView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/discover_view.dart` |
| **Purpose** | Explore trending creators, categories, videos |
| **UI** | Trending creators ring, category cards, video feeds per category |
| **Data** | DiscoverProvider, ActivityProvider, Firestore `trendingCreators`, `videos` |
| **Out** | SearchScreen, StreamerCardView, PlayerScreen, ActivityView |
| **Services** | CachingService, OfflineStorageService, AccessibilityService |

### SearchScreen

| Property | Value |
|----------|-------|
| **File** | `lib/views/search_screen.dart` |
| **Purpose** | Unified search (users, videos, hashtags) |
| **UI** | Search bar, recent searches, "Things you may like", results list |
| **Data** | SearchApiService, Firestore `users/{uid}.recentSearches` |
| **Out** | StreamerCardView, PlayerScreen |

---

## 5. Network Tab

### NetworkView

| Property | Value |
|----------|-------|
| **File** | `lib/views/network_view.dart` |
| **Purpose** | Connections, followers, following |
| **Props** | `initialTab?: String` |
| **UI** | Tabs: Connections | Followers | Following, search, sort, paginated user list |
| **Data** | FollowsService, MigrationService |
| **Out** | StreamerCardView |
| **Services** | GlobalPlaybackManager, PerformanceMonitoringService |

---

## 6. Create Tab

### TikTokCameraView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/tiktok_camera_view.dart` |
| **Purpose** | Record 9:16 vertical video |
| **UI** | Camera preview, record button, flip/flash, grid overlay |
| **Data** | TikTokCameraService, ImagePicker |
| **Out** | VideoRecordingPreview, VideoPublishingScreen |
| **Side effects** | GlobalPlaybackManager.block(), portrait lock |

### VideoRecordingPreview

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/video_recording_preview.dart` |
| **Props** | `videoFile`, `onRetake`, `onUseVideo` |
| **UI** | Video preview, Retake / Use Video buttons |
| **Data** | VideoPlayerController.file |

### VideoPublishingScreen

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/video_publishing_screen.dart` |
| **Props** | `videoFile`, `caption`, `hashtags`, `onPublish`, `onCancel` |
| **UI** | Video preview, caption, hashtags, category picker, thumbnail, schedule, publish |
| **Data** | VideoUploadService, LocalDraftService, FirestoreScheduledPostService |
| **Out** | PostSettingsScreen, SchedulePostWidget, VideoCategorizationScreen |
| **Validation** | maxCaption 500, duration 1–300s, categories: gaming/art/music/tech/sports |

### VideoEditingScreen

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/video_editing_screen.dart` |
| **Props** | `videoFile`, `onSave`, `onCancel` |
| **UI** | 4 tabs: Trim, Filters, Caption, Hashtags |
| **Data** | VideoProcessingService, HashtagLockService |
| **Out** | VideoPublishingScreen |

### VideoCategorizationScreen

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/video_categorization_screen.dart` |
| **Purpose** | Categorize existing videos (from Settings) |

### PostSettingsScreen

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/post_settings_screen.dart` |
| **Purpose** | Privacy, schedule, visibility for post |

### DraftsSheetView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/drafts_sheet_view.dart` |
| **Purpose** | List and manage draft videos |

---

## 7. Inbox Tab

### InboxViewOptimized

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/inbox_view_optimized.dart` |
| **Purpose** | Activity + Messages |
| **UI** | 2 tabs: Chats | Shared Drafts, search, chat list with unread badges |
| **Data** | InboxServiceOptimized, OfflineInboxService, ChatService |
| **Out** | ChatView, NewMessageView, DraftFeedbackView |
| **Firestore** | `chats`, `sharedDrafts` |

### ChatView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/chat_view.dart` |
| **Props** | `chat`, `otherUserId`, `otherUserName`, `otherUserAvatarURL`, `otherUserIsOnline`, `draftToSend?` |
| **UI** | Message list, text input, Giphy picker, mute, block |
| **Data** | ChatService, ChatProvider, UnreadMessagesProvider |
| **Out** | ReportService, UserBlockingService |

### NewMessageView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/new_message_view.dart` |
| **Purpose** | Start new conversation |
| **UI** | Search, primary actions, recent chats |
| **Out** | ChoosePersonView |

### ChoosePersonView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/choose_person_view.dart` |
| **Props** | `selectedDraft?: Map` |
| **Purpose** | Select recipient for message or draft share |
| **Data** | FollowsService (connections, followers, following), ChatService |
| **Out** | ChatView, DraftFeedbackView |

### ActivityView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/activity_view.dart` |
| **Purpose** | Likes, follows, comments, tags, mentions |
| **UI** | Filters: All | Likes | Follows | Comments | Tags | Mentions, ActivityRowView list |
| **Data** | ActivityProvider, AuthService, FollowsService |
| **Out** | StreamerCardView, DiscoverView |

### DraftFeedbackView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/draft_feedback_view.dart` |
| **Purpose** | Feedback when sharing draft with someone |

---

## 8. Profile Tab

### ProfileViewOptimized

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/profile_view_optimized.dart` |
| **Props** | `user`, `isCurrentUser` |
| **UI** | Avatar, display name, username, bio, UserStatsRow, tabs: Videos | Favorites | Tagged |
| **Data** | ProfileUpdateService, PostCounterService, UnifiedAvatarService |
| **Out** | MenuView, EditProfileView, ShareProfileView, StreamerCardView, ProfileVideoFeedView |
| **Sub** | ProfileBackView (flip card) |

### ProfileVideoFeedView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/profile_video_feed_view.dart` |
| **Purpose** | Grid of user's videos (Videos / Favorites / Tagged) |

### ProfileBackView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/profile_back_view.dart` |
| **Props** | `user`, `onFlip?` |
| **UI** | Bio, platforms, calendar events, hashtags |
| **Data** | Firestore `users/{id}` real-time, CalendarCleanupService |

### EditProfileView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/edit_profile_view.dart` |
| **Props** | `user`, `onUserUpdated`, `onBack?` |
| **UI** | Avatar picker, display name, username, bio, status, links |
| **Data** | ProfileUpdateService, ContentModerationService, AuthService |
| **Out** | EditFieldView, LinksEditView, ImagePickerWidget, StatusButton, AdminMonitoringPanel |
| **Rules** | 7-day cooldown for name change |

### ShareProfileView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/share_profile_view.dart` |
| **Purpose** | Share profile link |

### LinksEditView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/links_edit_view.dart` |
| **Purpose** | Edit profile links (social, website) |

---

## 9. Video Playback & Comments

### PlayerScreen

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/player_screen.dart` |
| **Props** | `mode` (homeFeed|favorites), `initialIndex`, `videoIds`, `videos?` |
| **UI** | PageView of videos, comments sidebar, like/comment/share/bookmark |
| **Data** | VideoServiceProvider, HomeProvider, DiscoverProvider, FavoritesProvider |
| **Out** | InsightsView, CommentsView2, EnhancedShareSheet, EditPostSheet |
| **Services** | GlobalPlaybackManager, VideoActionsService, VideoDownloadService |

### VideoPlayerViewOptimized

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/video_player_view_optimized.dart` |
| **Purpose** | Single video player (Mux HLS) |
| **Used in** | HomeView, PlayerScreen, DiscoverView |

### CommentsView2

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/comments_view2.dart` |
| **Props** | `videoId`, `videoOwnerId` |
| **UI** | Comment list, sort (newest/mostLiked), reply, create |
| **Data** | Firestore `videos/{id}/comments`, CommentsService |
| **Out** | CreateThreadFromCommentScreen |

### EnhancedShareSheet

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/enhanced_share_sheet.dart` |
| **Props** | `video`, `onClose`, `onReport`, `onBlock`, `onNotInterested`, `onFavorite` |
| **UI** | Share to connections, QR code, Report, Block, Not Interested, Favorite |
| **Data** | EnhancedShareService, ConnectionsRow, VideoQrCodeDialog |

---

## 10. Streamer Card & Modals

### StreamerCardView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/streamer_card_view.dart` |
| **Props** | `userId`, `currentUserId?`, `onDismiss`, `onFollow`, `onMessage`, `onShare`, `onNavigateToTab?` |
| **UI** | Avatar, name, username, follow/message, tabs: Video | Favorites | Tagged, bio, platforms, calendar |
| **Data** | Firestore `users/{id}`, FollowsService, EnhancedBookmarkService |
| **Out** | ProfileViewOptimized, ChatView, ProfileVideoFeedView |
| **Sub** | CalendarEventSheet |

### StreamerCardViewOptimized

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/streamer_card_view_optimized.dart` |
| **Purpose** | Alternative optimized streamer card |

---

## 11. Menu & Settings

### MenuView

| Property | Value |
|----------|-------|
| **File** | `lib/views/menu_view.dart` |
| **Purpose** | Profile section + menu grid |
| **UI** | Avatar, display name, username, Settings, Bookmarks, Scheduled, Insights, Account, Log out |
| **Data** | Firestore `users/{uid}` |
| **Out** | SettingsView, BookmarkView, ManagePostsView, InsightsView, ContactSupportView, TikTokAccountSwitcherModal |

### SettingsView

| Property | Value |
|----------|-------|
| **File** | `lib/views/settings_view.dart` |
| **Purpose** | Settings & Privacy hub |
| **UI** | Search, sections: Account, Security, Privacy, Content & Activity, Support & About |
| **Out** | ManageAccountView, TwoFactorSettingsView, PrivacySettingsView, BlockedAccountsView, MentionsTagsView, NotificationsView, ContentPreferencesView, VideoCategorizationScreen, PlaceholderSettingsPage (Report, Safety, Guidelines, Legal, About) |

### ManageAccountView

| Property | Value |
|----------|-------|
| **File** | `lib/views/manage_account_view.dart` |
| **Purpose** | Phone, email, password, 2FA, account deletion, data export |
| **Data** | Firestore `users/{uid}` |
| **Out** | TwoFactorSettingsView, TikTokAccountSwitcherModal |

### PrivacySettingsView

| Property | Value |
|----------|-------|
| **File** | `lib/views/privacy_settings_view.dart` |
| **Purpose** | Who can see content, visibility |

### BlockedAccountsView

| Property | Value |
|----------|-------|
| **File** | `lib/views/blocked_accounts_view.dart` |
| **Purpose** | List blocked users, unblock |
| **Data** | UserBlockingService, Firestore `users` |

### MentionsTagsView

| Property | Value |
|----------|-------|
| **File** | `lib/views/mentions_tags_view.dart` |
| **Purpose** | Who can mention/tag you |

### NotificationsView

| Property | Value |
|----------|-------|
| **File** | `lib/views/notifications_view.dart` |
| **Purpose** | Push & in-app notification preferences |

### ContentPreferencesView

| Property | Value |
|----------|-------|
| **File** | `lib/views/content_preferences_view.dart` |
| **Purpose** | Language, restricted mode, screen time |

### ContactSupportView

| Property | Value |
|----------|-------|
| **File** | `lib/views/contact_support_view.dart` |
| **Purpose** | Contact support / report |

---

## 12. Bookmarks & Insights

### BookmarkView

| Property | Value |
|----------|-------|
| **File** | `lib/pages/bookmark_view.dart` |
| **Purpose** | Saved bookmarks (events: upcoming, live, past) |
| **UI** | 3 tabs by EventStatus |
| **Data** | EnhancedBookmarkService, BookmarkEvent |

### InsightsView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/insights_view.dart` |
| **Props** | `videoId`, `videoTitle` |
| **UI** | 3 tabs: Overview, Viewers, Engagement |
| **Data** | InsightsFirebaseService, VideoAnalyticsAggregationService |
| **Sub** | InsightsOverviewTab, InsightsViewersTab, InsightsEngagementTab |

---

## 13. Threads (Forum)

### ThreadsListView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/threads/threads_list_view.dart` |
| **Purpose** | List of forum threads |

### ThreadDetailScreen

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/threads/thread_detail_screen.dart` |
| **Props** | `postId` |
| **UI** | Post content, comments, reply |
| **Data** | ForumService, ForumPost, ForumComment |

### CreateThreadScreen

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/threads/create_thread_screen.dart` |
| **Purpose** | Create new thread |

### CreateThreadFromCommentScreen

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/threads/create_thread_from_comment_screen.dart` |
| **Purpose** | Create thread from comment |

---

## 14. Account Switcher

### TikTokAccountSwitcherModal

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/tiktok_account_switcher_modal.dart` |
| **Purpose** | Switch or add accounts (TikTok-style) |
| **Data** | TikTokAccountSwitcher |

---

## 15. Other Views

### ManagePostsView

| Property | Value |
|----------|-------|
| **File** | `lib/views/manage_posts_view.dart` |
| **Purpose** | Manage user's posts |

### ResetPasswordView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/reset_password_view.dart` |
| **Purpose** | Reset password flow |

### ForgotPasswordVerificationView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/forgot_password_verification_view.dart` |
| **Purpose** | Verify reset code |

### QRScannerView

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/qr_scanner_view.dart` |
| **Purpose** | Scan QR codes |

### StoryViewer

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/story_viewer.dart` |
| **Purpose** | View stories |

### VideoOptionsBottomSheet

| Property | Value |
|----------|-------|
| **File** | `lib/widgets/video_options_bottom_sheet.dart` |
| **Purpose** | Report, block, not interested, edit caption, privacy |

---

## 16. Data Flow Summary

| Domain | Source | Sink |
|--------|--------|------|
| **Videos** | Firestore `videos` | VideoService → HomeProvider → HomeView |
| **Auth** | Firebase Auth | RobustAuthService → AppStartupWrapper |
| **Playback** | Mux HLS | GlobalPlaybackManager → VideoPlayerViewOptimized |
| **Uploads** | Camera/Gallery | MuxUploadService → Cloudflare Worker → Mux |
| **Likes** | Firestore | StreamersTipLikeService → CreatorStatsSyncService |
| **Chats** | Firestore `chats` | InboxServiceOptimized → InboxViewOptimized |
| **Comments** | Firestore `videos/{id}/comments` | CommentsService → CommentsView2 |
