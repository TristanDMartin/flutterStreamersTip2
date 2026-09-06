import 'dart:async';

import 'package:flutter/material.dart';
import '../core/feature_flags.dart';
import '../services/creator_intelligence_analytics_service.dart';
import '../services/email_verification_feature_gate.dart';
import '../models/chat.dart';
import '../models/creator_profile_snapshot.dart';
import '../models/home_video.dart';
import '../models/user.dart';
import '../services/creator_cache_service.dart';
import '../widgets/streamer_card_view.dart';
import '../widgets/player_screen.dart';
import '../utils/home_video_from_firestore.dart';
import '../utils/home_video_playback.dart';
import 'app_routes.dart';
import '../providers/unread_messages_provider.dart';
import '../features/content_planning/content_planner_view.dart';
import '../features/approvals/approval_review_view.dart';
import '../features/tippy/models/tippy_launch_context.dart';

class AppNavigator {
  static void _trackToolOpened(String toolId) {
    unawaited(
      CreatorIntelligenceAnalyticsService().trackToolOpened(toolId: toolId),
    );
  }

  static Future<T?> openPlayer<T>(
    BuildContext context, {
    required PlayerMode mode,
    required int initialIndex,
    required List<String> videoIds,
    List<HomeVideo>? videos,
    String? focusCommentId,
    bool fullscreenDialog = true,
  }) async {
    if (videoIds.isEmpty) {
      return null;
    }
    final int safeIndex = initialIndex.clamp(0, videoIds.length - 1);
    final String targetVideoId = videoIds[safeIndex];
    HomeVideo? providedPlayable;
    if (videos != null) {
      for (final HomeVideo video in videos) {
        if (video.id == targetVideoId && isHomeVideoPlayable(video)) {
          providedPlayable = video;
          break;
        }
      }
    }
    // Instant open: use the card the grid already has. Only hit Firestore when
    // no playable video was provided (deep links / cold open).
    final HomeVideo? resolvedVideo = providedPlayable ??
        await loadHomeVideoForPlayback(targetVideoId);
    if (!context.mounted) {
      return null;
    }
    if (resolvedVideo == null) {
      return openVideoUnavailable<T>(
        context,
        videoId: targetVideoId,
      );
    }
    final List<HomeVideo> resolvedVideos = videos == null || videos.isEmpty
        ? <HomeVideo>[resolvedVideo]
        : videos
            .where((HomeVideo video) => video.id.isNotEmpty)
            .map((HomeVideo video) {
              if (video.id == resolvedVideo.id) {
                return resolvedVideo;
              }
              return video;
            })
            .toList(growable: false);
    final List<String> resolvedIds = resolvedVideos
        .map((HomeVideo video) => video.id)
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);
    if (resolvedIds.isEmpty) {
      return openVideoUnavailable<T>(
        context,
        videoId: targetVideoId,
      );
    }
    final int resolvedIndex = resolvedIds.indexOf(targetVideoId);
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.player,
      arguments: PlayerRouteArgs(
        mode: mode,
        initialIndex: resolvedIndex >= 0 ? resolvedIndex : 0,
        videoIds: resolvedIds,
        videos: resolvedVideos,
        focusCommentId: focusCommentId,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  static Future<T?> openProfile<T>(
    BuildContext context, {
    required User user,
    bool isCurrentUser = false,
    bool fullscreenDialog = true,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.profile,
      arguments: ProfileRouteArgs(
        user: user,
        isCurrentUser: isCurrentUser,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  static Future<T?> openChat<T>(
    BuildContext context, {
    required Chat chat,
    required String otherUserId,
    required String otherUserName,
    String? otherUserAvatarUrl,
    bool otherUserIsOnline = false,
    Map<String, dynamic>? draftToSend,
    bool fullscreenDialog = true,
  }) async {
    final bool allowed =
        await EmailVerificationFeatureGate.ensureCanSendDirectMessage(
      context,
    );
    if (!allowed || !context.mounted) {
      return null;
    }
    final String? chatId = chat.id;
    if (chatId != null && chatId.isNotEmpty) {
      unawaited(UnreadMessagesService.markChatAsRead(chatId));
    }
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.chat,
      arguments: ChatRouteArgs(
        chat: chat,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserAvatarUrl: otherUserAvatarUrl,
        otherUserIsOnline: otherUserIsOnline,
        draftToSend: draftToSend,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  static Future<T?> openVideoUnavailable<T>(
    BuildContext context, {
    required String videoId,
    String? creatorId,
    String? creatorName,
    String? creatorUsername,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.videoUnavailable,
      arguments: VideoUnavailableRouteArgs(
        videoId: videoId,
        creatorId: creatorId,
        creatorName: creatorName,
        creatorUsername: creatorUsername,
      ),
    );
  }

  static Future<T?> openDiscover<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.discover);
  }

  static Future<T?> openAcademy<T>(BuildContext context) {
    _trackToolOpened('academy');
    return Navigator.of(context).pushNamed<T>(AppRoutes.academy);
  }

  static Future<T?> openAcademySearch<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.academySearch);
  }

  static Future<T?> openAcademySaved<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.academySaved);
  }

  static Future<T?> openAcademyProgress<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.academyProgress);
  }

  static Future<T?> openAcademyCategory<T>(
    BuildContext context, {
    required String categoryId,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.academyCategory,
      arguments: AcademyCategoryRouteArgs(categoryId: categoryId),
    );
  }

  static Future<T?> openAcademyPath<T>(
    BuildContext context, {
    required String pathId,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.academyPath,
      arguments: AcademyPathRouteArgs(pathId: pathId),
    );
  }

  static Future<T?> openAcademyGuide<T>(
    BuildContext context, {
    required String guideId,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.academyGuide,
      arguments: AcademyGuideRouteArgs(guideId: guideId),
    );
  }

  static Future<T?> openAcademyLesson<T>(
    BuildContext context, {
    required String lessonId,
    String? guideId,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.academyLesson,
      arguments: AcademyLessonRouteArgs(
        lessonId: lessonId,
        guideId: guideId,
      ),
    );
  }

  static Future<T?> openAcademyLessonReplace<T>(
    BuildContext context, {
    required String lessonId,
    String? guideId,
  }) {
    return Navigator.of(context).pushReplacementNamed<T, void>(
      AppRoutes.academyLesson,
      arguments: AcademyLessonRouteArgs(
        lessonId: lessonId,
        guideId: guideId,
      ),
    );
  }

  static Future<T?> openActivity<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.activity);
  }

  static Future<T?> openSearch<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.search);
  }

  static Future<T?> openSettings<T>(
    BuildContext context, {
    String? initialSearchQuery,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.settings,
      arguments: SettingsRouteArgs(
        initialSearchQuery: initialSearchQuery,
      ),
    );
  }

  static Future<T?> openManagePosts<T>(BuildContext context) {
    return openManagePostsWithArgs(
      context,
      initialTab: ManagePostsInitialTab.scheduled,
      launchSource: ManagePostsLaunchSource.direct,
    );
  }

  static Future<T?> openContentScheduler<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(AppRoutes.contentScheduler);
  }

  static Future<T?> openContentPlanner<T>(
    BuildContext context, {
    ContentPlannerInitialScope initialScope = ContentPlannerInitialScope.today,
  }) {
    _trackToolOpened('content-planner');
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.contentPlanner,
      arguments: ContentPlannerRouteArgs(initialScope: initialScope),
    );
  }

  static Future<T?> openTippyChat<T>(
    BuildContext context, {
    TippyLaunchContext launchContext = const TippyLaunchContext(),
  }) {
    _trackToolOpened('ask-tippy');
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.tippyChat,
      arguments: launchContext,
    );
  }

  static Future<T?> openManagePostsWithArgs<T>(
    BuildContext context, {
    required ManagePostsInitialTab initialTab,
    required ManagePostsLaunchSource launchSource,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.managePosts,
      arguments: ManagePostsRouteArgs(
        initialTab: initialTab,
        launchSource: launchSource,
      ),
    );
  }

  static Future<T?> openLinkedPlatforms<T>(
    BuildContext context, {
    List<String> initialPlatforms = const [],
    bool fullscreenDialog = false,
  }) {
    if (!FeatureFlags.linkedPlatforms) {
      return Future<T?>.value();
    }
    _trackToolOpened('linked-platforms');
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.linkedPlatforms,
      arguments: LinkedPlatformsRouteArgs(
        initialPlatforms: initialPlatforms,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  static Future<T?> openGrowthAnalytics<T>(BuildContext context) {
    _trackToolOpened('growth-analytics');
    return Navigator.of(context).pushNamed<T>(AppRoutes.growthAnalytics);
  }

  static Future<T?> openVideoInsights<T>(BuildContext context) {
    _trackToolOpened('video-insights');
    return Navigator.of(context).pushNamed<T>(AppRoutes.videoInsights);
  }

  static Future<T?> openCreatorIntelligence<T>(BuildContext context) {
    _trackToolOpened('creator-intelligence');
    return Navigator.of(context).pushNamed<T>(AppRoutes.creatorIntelligence);
  }

  static Future<T?> openWeeklyReport<T>(BuildContext context) {
    _trackToolOpened('weekly-report');
    return Navigator.of(context).pushNamed<T>(AppRoutes.weeklyReport);
  }

  static Future<T?> openStudioTeamControl<T>(BuildContext context) {
    _trackToolOpened('studio-team-control');
    return Navigator.of(context).pushNamed<T>(AppRoutes.studioTeamControl);
  }

  static Future<T?> openApprovalReview<T>(
    BuildContext context, {
    required String requestId,
    required String workspaceId,
  }) {
    _trackToolOpened('approval-review');
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.approvalReview,
      arguments: ApprovalReviewArgs(
        requestId: requestId,
        workspaceId: workspaceId,
      ),
    );
  }

  static Future<T?> openStreamerCard<T>(
    BuildContext context, {
    required String userId,
    CreatorProfileSnapshot? initialCreator,
    String? currentUserId,
    VoidCallback? onDismiss,
    Function(String userId)? onFollow,
    Function(String userId)? onMessage,
    Function(String userId)? onShare,
    Function(String tabName)? onNavigateToTab,
    bool fullscreenDialog = true,
    GlobalKey? tourAnchorKey,
  }) {
    final CreatorProfileSnapshot? seed =
        CreatorCacheService.instance.resolveForNavigation(
      userId: userId,
      initialCreator: initialCreator,
    );
    final StreamerCardView card = StreamerCardView(
      userId: userId,
      initialCreator: seed,
      currentUserId: currentUserId,
      onDismiss: onDismiss,
      onFollow: onFollow,
      onMessage: onMessage,
      onShare: onShare,
      onNavigateToTab: onNavigateToTab,
    );
    final Widget page = tourAnchorKey != null
        ? KeyedSubtree(key: tourAnchorKey, child: card)
        : card;
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        settings: const RouteSettings(name: '/streamer_card'),
        fullscreenDialog: fullscreenDialog,
        builder: (_) => page,
      ),
    );
  }

  static Future<T?> replaceWithHome<T>(BuildContext context) {
    return Navigator.of(context)
        .pushNamedAndRemoveUntil<T>(AppRoutes.home, (route) => false);
  }

  static Future<T?> replaceWithAuth<T>(BuildContext context) {
    return Navigator.of(context)
        .pushNamedAndRemoveUntil<T>(AppRoutes.auth, (route) => false);
  }
}
