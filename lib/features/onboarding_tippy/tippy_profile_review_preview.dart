import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../../utils/platform_rules.dart';
import '../../widgets/profile_back_view.dart';
import '../../widgets/profile_view/profile_view_front_shell.dart';
import 'tippy_profile_draft.dart';

/// Live Profile front → back flip using the real profile shells.
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
  bool _isFront = true;
  bool _didAutoFlip = false;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 620),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
    _contentTransitionController = AnimationController(
      duration: const Duration(milliseconds: 240),
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
      Future<void>.delayed(const Duration(milliseconds: 1600), () {
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

  Map<String, dynamic> _previewUserMap() {
    final String uid =
        firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? 'preview';
    final List<Map<String, dynamic>> platforms = widget.draft.platformIds.map(
      (String id) {
        return PlatformRules.buildEditablePlatformEntry(
          type: id,
          username: widget.draft.platformHandles[id] ?? '',
          url: widget.draft.platformUrls[id] ?? '',
          id: 'tippy_$id',
          isConnected: false,
        );
      },
    ).toList();
    return <String, dynamic>{
      'id': uid,
      'uid': uid,
      'displayName': widget.draft.displayName.trim(),
      'username': widget.draft.username.trim(),
      'bio': widget.draft.bio.trim(),
      'avatarURL': widget.draft.avatarUrl,
      'photoURL': widget.draft.avatarUrl,
      'platforms': platforms,
      'categories': widget.draft.categoryIds,
      'categoryId': widget.draft.categoryIds.isNotEmpty
          ? widget.draft.categoryIds.first
          : 'gaming',
      'postCount': 0,
      'followerCount': 0,
      'followingCount': 0,
      'onlineStatus': 'online',
    };
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

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> userData = _previewUserMap();
    final String profileUserId = userData['id'] as String? ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                      isCurrentUser: true,
                      selectedTabIndex: _selectedTabIndex,
                      onTabSelected: (int index) {
                        setState(() {
                          _selectedTabIndex = index;
                        });
                        _contentTransitionController.forward(from: 0);
                      },
                      contentFade: _contentFadeAnimation,
                      contentSlide: _contentSlideAnimation,
                      onBack: () {},
                      onFlip: _flipCard,
                      onStreamerCard: () {},
                      showStreamerCardButton: false,
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
