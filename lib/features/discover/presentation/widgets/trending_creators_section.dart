import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/feature_flags.dart';
import '../../../../core/theme/st_theme_tokens.dart';
import '../../../../models/trending_creator.dart';
import '../../../../providers/discover_provider.dart';
import '../../../../routing/app_navigator.dart';
import 'trending_creator_card.dart';
import 'trending_creator_skeleton.dart';

class TrendingCreatorsSection extends ConsumerWidget {
  const TrendingCreatorsSection({
    super.key,
    required this.isDark,
    required this.onCreatorTap,
  });

  final bool isDark;
  final void Function(TrendingCreator creator) onCreatorTap;

  static const double _gridHPadding = 20;
  static const double _headerBottom = 12;
  static const double _cardMainExtent = 178;
  static const int _skeletonCount = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DiscoverState state = ref.watch(discoverProvider);
    final ThemeData theme = Theme.of(context);
    final Color onSurface = theme.colorScheme.onSurface;
    return KeyedSubtree(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _gridHPadding,
              0,
              _gridHPadding,
              _headerBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Trending Creators',
                            style: TextStyle(
                              color: onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Creators gaining momentum right now',
                            style: TextStyle(
                              color: onSurface.withValues(alpha: 0.68),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        AppNavigator.openSearch(context);
                      },
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            colors: <Color>[
                              StThemeColors.brandPurple,
                              StThemeColors.brandBlue,
                            ],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(_gridHPadding, 0, _gridHPadding, 4),
            child: _buildBody(context, ref, state),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, DiscoverState state) {
    if (state.trendingCreatorsLoadFailed) {
      return _TrendingError(onRetry: () {
        ref.read(discoverProvider.notifier).loadTrendingCreators();
      });
    }
    if (state.isLoadingTrendingCreators && state.trendingCreators.isEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: _cardMainExtent,
        ),
        itemCount: _skeletonCount,
        itemBuilder: (BuildContext context, int index) {
          return const TrendingCreatorSkeleton();
        },
      );
    }
    if (state.trendingCreators.isEmpty) {
      return const _TrendingEmpty();
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: _cardMainExtent,
      ),
      itemCount: state.trendingCreators.length,
      itemBuilder: (BuildContext context, int index) {
        final TrendingCreator creator = state.trendingCreators[index];
        return TrendingCreatorCard(
          key: ValueKey<String>('trending_creator_${creator.id}'),
          creator: creator,
          isDark: isDark,
          onOpenProfile: () => onCreatorTap(creator),
        );
      },
    );
  }
}

class _TrendingEmpty extends StatelessWidget {
  const _TrendingEmpty();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurface.withValues(alpha: 0.68);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.people_outline_rounded,
            size: 40,
            color: muted,
          ),
          const SizedBox(height: 12),
          Text(
            'No trending creators yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Once creators start posting and connecting, they’ll appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          if (FeatureFlags.trendingInvite) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {},
              child: const Text('Invite creators'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendingError extends StatelessWidget {
  const _TrendingError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurface.withValues(alpha: 0.68);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: muted,
          ),
          const SizedBox(height: 12),
          Text(
            'Couldn’t load trending creators',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
