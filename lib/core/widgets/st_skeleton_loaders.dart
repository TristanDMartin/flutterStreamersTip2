import 'package:flutter/material.dart';

import '../theme/support_shell_style.dart';
import 'st_shimmer.dart';

/// Inbox / chat preview row skeleton.
class InboxChatSkeletonList extends StatelessWidget {
  const InboxChatSkeletonList({
    super.key,
    this.itemCount = 8,
    this.padding,
  });

  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('inbox-skeleton'),
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: itemCount,
      itemBuilder: (BuildContext context, int index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _InboxChatRowSkeleton(),
        );
      },
    );
  }
}

class _InboxChatRowSkeleton extends StatelessWidget {
  const _InboxChatRowSkeleton();

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return StShimmer(
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: shell.skeletonFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: shell.surfaceCardBorder),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: shell.skeletonLine,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    height: 13,
                    width: 140,
                    decoration: BoxDecoration(
                      color: shell.skeletonLine,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 11,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: shell.skeletonLineDim,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 12,
              decoration: BoxDecoration(
                color: shell.skeletonLineDim,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comments sheet skeleton list.
class CommentSkeletonList extends StatelessWidget {
  const CommentSkeletonList({
    super.key,
    this.itemCount = 6,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('comments-skeleton'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: itemCount,
      itemBuilder: (BuildContext context, int index) {
        final bool isReply = index.isOdd;
        return Padding(
          padding: EdgeInsets.only(
            left: isReply ? 36 : 0,
            bottom: 14,
          ),
          child: const _CommentRowSkeleton(),
        );
      },
    );
  }
}

class _CommentRowSkeleton extends StatelessWidget {
  const _CommentRowSkeleton();

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return StShimmer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: shell.skeletonLine,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  height: 12,
                  width: 96,
                  decoration: BoxDecoration(
                    color: shell.skeletonLine,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 11,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: shell.skeletonLineDim,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 11,
                  width: 180,
                  decoration: BoxDecoration(
                    color: shell.skeletonLineDim,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// StreamerCard full-screen loading skeleton.
class StreamerCardSkeleton extends StatelessWidget {
  const StreamerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: shell.pageGradient,
        ),
      ),
      child: SafeArea(
        child: StShimmer(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: shell.skeletonFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: shell.skeletonLine,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 22,
                  width: 180,
                  decoration: BoxDecoration(
                    color: shell.skeletonLine,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 14,
                  width: 120,
                  decoration: BoxDecoration(
                    color: shell.skeletonLineDim,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(3, (int index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 18,
                            decoration: BoxDecoration(
                              color: shell.skeletonLine,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 52,
                            height: 10,
                            decoration: BoxDecoration(
                              color: shell.skeletonLineDim,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const Spacer(),
                Container(
                  height: 48,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: shell.skeletonLine,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: shell.skeletonFill,
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: shell.skeletonFill,
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile header skeleton for cold profile loads.
class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return StShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: shell.skeletonLine,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 20,
              width: 160,
              decoration: BoxDecoration(
                color: shell.skeletonLine,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: 120,
              decoration: BoxDecoration(
                color: shell.skeletonLineDim,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List<Widget>.generate(3, (int index) {
                return Column(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 16,
                      decoration: BoxDecoration(
                        color: shell.skeletonLine,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 52,
                      height: 10,
                      decoration: BoxDecoration(
                        color: shell.skeletonLineDim,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Creator progression / analytics panel skeleton.
class ProgressionPanelSkeleton extends StatelessWidget {
  const ProgressionPanelSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return StShimmer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 18,
              width: 160,
              decoration: BoxDecoration(
                color: shell.skeletonLine,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: shell.skeletonFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: shell.surfaceCardBorder),
              ),
            ),
            const SizedBox(height: 12),
            ...List<Widget>.generate(3, (int index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: shell.skeletonFill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Network user row skeleton (shared with NetworkView).
class NetworkUserRowSkeleton extends StatelessWidget {
  const NetworkUserRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return StShimmer(
      child: Container(
        height: 86,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: shell.skeletonFill,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(width: 14),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: shell.skeletonLine,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: 12,
                    width: 140,
                    decoration: BoxDecoration(
                      color: shell.skeletonLine,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 90,
                    decoration: BoxDecoration(
                      color: shell.skeletonLineDim,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: shell.skeletonLineDim,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

/// Video thumbnail tile skeleton for Discover grids.
class VideoThumbnailSkeleton extends StatelessWidget {
  const VideoThumbnailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return StShimmer(
      child: Container(
        decoration: BoxDecoration(
          color: shell.skeletonFill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            width: 76,
            height: 12,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: shell.skeletonLineDim,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}
