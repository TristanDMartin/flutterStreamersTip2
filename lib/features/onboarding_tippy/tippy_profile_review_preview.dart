import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/platform_rules.dart';
import '../../utils/user_profile_firestore.dart';
import '../../widgets/profile_back_view.dart';
import '../../widgets/profile_view/profile_view_front_shell.dart';
import '../../widgets/streamer_card_sections.dart';
import 'tippy_profile_draft.dart';

const Duration _profilePreviewFlipDuration = Duration(milliseconds: 420);
const Duration _profilePreviewContentDuration = Duration(milliseconds: 150);
const Duration _profilePreviewAutoFlipDelay = Duration(milliseconds: 900);

/// Onboarding profile-card preview backed by the real ProfileView front shell
/// and ProfileBackView, but locked to initial draft data so profile/feed
/// services stay dark until ACTIVATED / allowApp.
class TippyProfileReviewPreview extends StatefulWidget {
  const TippyProfileReviewPreview({
    super.key,
    required this.draft,
  });

  final TippyProfileDraft draft;

  @override
  State<TippyProfileReviewPreview> createState() =>
      _TippyProfileReviewPreviewState();
}

class _TippyProfileReviewPreviewState extends State<TippyProfileReviewPreview>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  late final AnimationController _contentTransitionController;
  late final Animation<double> _contentFadeAnimation;
  late final Animation<Offset> _contentSlideAnimation;
  int _selectedTabIndex = 0;
  bool _isFront = true;
  bool _didAutoFlip = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: _profilePreviewFlipDuration,
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
    _contentTransitionController = AnimationController(
      duration: _profilePreviewContentDuration,
      vsync: this,
    );
    _contentFadeAnimation = CurvedAnimation(
      parent: _contentTransitionController,
      curve: Curves.easeOutCubic,
    );
    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentTransitionController,
        curve: Curves.easeOutCubic,
      ),
    );
    _contentTransitionController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didAutoFlip) {
        return;
      }
      _didAutoFlip = true;
      Future<void>.delayed(_profilePreviewAutoFlipDelay, () {
        if (mounted && _isFront) {
          _flipCard();
        }
      });
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _contentTransitionController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  void _onTabSelected(int index) {
    if (_selectedTabIndex == index) {
      return;
    }
    setState(() {
      _selectedTabIndex = index;
    });
    _contentTransitionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> userData = _userDataFromDraft(widget.draft);
    final String profileUserId = userData['id'] as String;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: StreamerCardBackStyle.background,
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (BuildContext context, Widget? child) {
            final bool isShowingFront = _flipAnimation.value < 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_flipAnimation.value * 3.14159),
              child: isShowingFront
                  ? ProfileViewFrontShell(
                      userData: userData,
                      profileUserId: profileUserId,
                      isCurrentUser: false,
                      selectedTabIndex: _selectedTabIndex,
                      onTabSelected: _onTabSelected,
                      contentFade: _contentFadeAnimation,
                      contentSlide: _contentSlideAnimation,
                      onBack: () {},
                      onFlip: _flipCard,
                      onStreamerCard: () {},
                      showStreamerCardButton: false,
                      showMenuButton: false,
                      useInitialDataOnly: true,
                    )
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: ProfileBackView(
                        user: userData,
                        onFlip: _flipCard,
                        useInitialDataOnly: true,
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}

Map<String, dynamic> _userDataFromDraft(TippyProfileDraft draft) {
  final String username = draft.username.trim();
  final String displayName =
      draft.displayName.trim().isNotEmpty ? draft.displayName.trim() : username;
  final String avatarUrl = draft.avatarUrl?.trim() ?? '';
  final List<Map<String, dynamic>> platforms = draft.platformIds
      .map((String id) => _platformDataFromDraft(draft, id))
      .toList();
  return <String, dynamic>{
    'id': 'tippy_onboarding_preview',
    'uid': 'tippy_onboarding_preview',
    'displayName': displayName.isEmpty ? 'Creator' : displayName,
    'name': displayName.isEmpty ? 'Creator' : displayName,
    'username': username,
    'handle': username,
    'bio': draft.bio.trim(),
    'avatarUrl': avatarUrl,
    'avatarURL': avatarUrl,
    UserProfileFirestore.platformsField: platforms,
    UserProfileFirestore.linkedPlatformsField: platforms,
    'profileCalendarEvents': <Map<String, dynamic>>[],
    'calendarEvents': <Map<String, dynamic>>[],
    'postsCount': 0,
    'followersCount': 0,
    'followingCount': 0,
  };
}

Map<String, dynamic> _platformDataFromDraft(
  TippyProfileDraft draft,
  String id,
) {
  final String handle =
      (draft.platformHandles[id] ?? '').trim().replaceFirst(RegExp(r'^@+'), '');
  final String explicitUrl = (draft.platformUrls[id] ?? '').trim();
  final String url = explicitUrl.isNotEmpty
      ? explicitUrl
      : PlatformRules.previewPlatformUrl(id, handle) ?? '';
  return <String, dynamic>{
    'id': 'onboarding_$id',
    'type': id,
    'platformType': id,
    'displayName': PlatformRules.displayNameForType(id),
    'username': handle,
    'url': url,
    'isConnected': handle.isNotEmpty || url.isNotEmpty,
    'isVerified': false,
    'isAdultGated': PlatformRules.isAgeRestrictedType(id),
  };
}
