import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routing/app_navigator.dart';
import '../../../routing/app_routes.dart';
import '../../../services/creator_intelligence_analytics_service.dart';
import '../../../services/creator_personalization_service.dart';
import '../onboarding_style.dart';

class CreatorPersonalizationSurfaceBanner extends ConsumerWidget {
  const CreatorPersonalizationSurfaceBanner({
    super.key,
    required this.profile,
  });

  final CreatorPersonalizationProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!profile.isActive || profile.primarySurface == null) {
      return const SizedBox.shrink();
    }
    final _BannerCopy copy = _bannerCopy(profile);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(context, ref, profile.primarySurface!),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFF9248D2).withValues(alpha: 0.28),
                  const Color(0xFF00F5A0).withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF9248D2).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: <Widget>[
                Text(copy.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        copy.title,
                        style: TextStyle(
                          color: OnboardingStyle.textPrimaryFor(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        copy.subtitle,
                        style: OnboardingStyle.bodyFor(context, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: OnboardingStyle.textSecondaryFor(context),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref,
    CreatorPersonalizationSurface surface,
  ) async {
    HapticFeedback.lightImpact();
    await ref.read(creatorIntelligenceAnalyticsProvider).trackPersonalizationCtaTapped(
          uiSurface: PersonalizationCtaSurfaces.discoverBanner,
          ctaSurface: surface.name,
          creatorGoals: profile.creatorGoals,
          platforms: profile.platforms,
        );
    if (!context.mounted) {
      return;
    }
    switch (surface) {
      case CreatorPersonalizationSurface.tippy:
        await AppNavigator.openTippyChat(context);
      case CreatorPersonalizationSurface.contentPlanner:
        await AppNavigator.openContentPlanner(context);
      case CreatorPersonalizationSurface.network:
        await Navigator.of(context).pushNamed(AppRoutes.network);
      case CreatorPersonalizationSurface.discover:
        break;
    }
  }
}

class _BannerCopy {
  const _BannerCopy({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;
}

_BannerCopy _bannerCopy(CreatorPersonalizationProfile profile) {
  switch (profile.primarySurface) {
    case CreatorPersonalizationSurface.tippy:
      return const _BannerCopy(
        emoji: '🤖',
        title: 'Ask Tippy for your next move',
        subtitle: 'You told us AI coaching matters — start with a quick plan.',
      );
    case CreatorPersonalizationSurface.contentPlanner:
      return const _BannerCopy(
        emoji: '📅',
        title: 'Build your content plan',
        subtitle: 'Turn your creator focus into a schedule you can follow.',
      );
    case CreatorPersonalizationSurface.network:
      return const _BannerCopy(
        emoji: '🤝',
        title: 'Find creators to connect with',
        subtitle: 'Your focus is community — explore the Network tab next.',
      );
    case CreatorPersonalizationSurface.discover:
      return const _BannerCopy(
        emoji: '📈',
        title: 'Explore categories picked for you',
        subtitle: 'We reordered Discover based on your onboarding picks.',
      );
    case null:
      return const _BannerCopy(
        emoji: '✨',
        title: 'Personalized for you',
        subtitle: 'Keep exploring categories that match your goals.',
      );
  }
}
