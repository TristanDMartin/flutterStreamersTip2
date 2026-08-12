import 'package:flutter/material.dart';

import '../../../core/theme/support_shell_style.dart';
import '../../../core/theme/st_theme_tokens.dart';

class AcademyTokens {
  static const double pagePadding = 16;
  static const double cardRadius = 20;
  static const double sectionGap = 18;
}

class AcademyGradientHeader extends StatelessWidget {
  const AcademyGradientHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.school_rounded,
    this.level,
    this.xpLabel,
    this.streakLabel,
    this.completionPercent,
    this.weeklyGoalLabel,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int? level;
  final String? xpLabel;
  final String? streakLabel;
  final double? completionPercent;
  final String? weeklyGoalLabel;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AcademyTokens.pagePadding,
        8,
        AcademyTokens.pagePadding,
        AcademyTokens.sectionGap,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: shell.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: shell.heroBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: StThemeColors.brandPurple.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (level != null || xpLabel != null || streakLabel != null) ...<Widget>[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (level != null)
                  _StatChip(label: 'Creator Level $level'),
                if (xpLabel != null) _StatChip(label: xpLabel!),
                if (streakLabel != null) _StatChip(label: streakLabel!),
                if (weeklyGoalLabel != null)
                  _StatChip(label: weeklyGoalLabel!),
              ],
            ),
          ],
          if (completionPercent != null) ...<Widget>[
            const SizedBox(height: 14),
            Semantics(
              label:
                  'Overall completion ${(completionPercent! * 100).round()} percent',
              child: AcademyAnimatedProgressBar(
                value: completionPercent!,
                height: 10,
                foreground: Colors.white,
                background: Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class AcademyAnimatedProgressBar extends StatelessWidget {
  const AcademyAnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.foreground,
    this.background,
  });

  final double value;
  final double height;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color fg = foreground ?? StThemeColors.brandPurple;
    final Color bg = background ?? scheme.surfaceContainerHighest;
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: bg),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 1),
              child: AnimatedContainer(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      fg,
                      StThemeColors.brandBlue,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AcademySearchField extends StatelessWidget {
  const AcademySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AcademyTokens.pagePadding,
        0,
        AcademyTokens.pagePadding,
        12,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        readOnly: readOnly,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search guides, platforms, tools, and strategies',
          prefixIcon: Icon(Icons.search_rounded, color: shell.muted),
          filled: true,
          fillColor: shell.surfaceCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: shell.surfaceCardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: shell.surfaceCardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: StThemeColors.brandPurple),
          ),
        ),
      ),
    );
  }
}

class AcademyCategoryCard extends StatelessWidget {
  const AcademyCategoryCard({
    super.key,
    required this.name,
    required this.description,
    required this.guideCount,
    required this.completionPercent,
    required this.isLocked,
    required this.onTap,
    this.icon,
  });

  final String name;
  final String description;
  final int guideCount;
  final double completionPercent;
  final bool isLocked;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final String semanticsLabel =
        '$name. $guideCount guides. '
        '${(completionPercent * 100).round()} percent complete.'
        '${isLocked ? ' Locked.' : ''}';
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
        child: InkWell(
          onTap: isLocked ? null : onTap,
          borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
              border: Border.all(color: shell.surfaceCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: shell.heroGradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon ?? Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    if (isLocked)
                      Icon(Icons.lock_rounded, color: shell.muted, size: 18),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$guideCount guides',
                  style: TextStyle(
                    color: shell.mutedStrong,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                AcademyAnimatedProgressBar(value: completionPercent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AcademyPathCard extends StatelessWidget {
  const AcademyPathCard({
    super.key,
    required this.title,
    required this.description,
    required this.completedLessons,
    required this.totalLessons,
    required this.onTap,
    this.isLocked = false,
    this.unlockLevel,
  });

  final String title;
  final String description;
  final int completedLessons;
  final int totalLessons;
  final VoidCallback onTap;
  final bool isLocked;
  final int? unlockLevel;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final double progress = totalLessons <= 0
        ? 0
        : (completedLessons / totalLessons).clamp(0, 1);
    final String stepNoun = totalLessons == 1 ? 'guide' : 'guides';
    return Semantics(
      button: true,
      label:
          '$title. $completedLessons of $totalLessons $stepNoun completed. '
          '${(progress * 100).round()} percent complete.'
          '${isLocked ? ' Locked.' : ''}',
      child: Material(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
        child: InkWell(
          onTap: isLocked ? null : onTap,
          borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
              border: Border.all(color: shell.surfaceCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: shell.heroGradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: shell.onChrome,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isLocked)
                      Icon(Icons.lock_rounded, color: shell.muted, size: 18)
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: shell.muted,
                        size: 22,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Text(
                      '$completedLessons of $totalLessons $stepNoun',
                      style: TextStyle(
                        color: shell.mutedStrong,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isLocked && unlockLevel != null) ...<Widget>[
                      const Spacer(),
                      Text(
                        'Unlocks at Level $unlockLevel',
                        style: TextStyle(
                          color: shell.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                AcademyAnimatedProgressBar(value: progress),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AcademyPathStepCard extends StatelessWidget {
  const AcademyPathStepCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isWebsiteBacked,
    required this.onTap,
    this.difficulty,
    this.estimatedMinutes,
  });

  final int stepNumber;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isWebsiteBacked;
  final VoidCallback onTap;
  final String? difficulty;
  final int? estimatedMinutes;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Semantics(
      button: true,
      label:
          'Step $stepNumber. $title. '
          '${isCompleted ? 'Completed.' : subtitle}',
      child: Material(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
              border: Border.all(
                color: isCompleted
                    ? StThemeColors.brandPurple.withValues(alpha: 0.45)
                    : shell.surfaceCardBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isCompleted
                        ? LinearGradient(colors: shell.heroGradient)
                        : null,
                    color: isCompleted
                        ? null
                        : StThemeColors.brandPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      : Text(
                          '$stepNumber',
                          style: TextStyle(
                            color: StThemeColors.brandPurple,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: shell.onChrome,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: shell.muted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          AcademyMetaChip(
                            label: isCompleted
                                ? 'Completed'
                                : (isWebsiteBacked ? 'Guide' : 'Lesson'),
                          ),
                          if (difficulty != null && difficulty!.isNotEmpty)
                            AcademyMetaChip(label: difficulty!),
                          if (estimatedMinutes != null &&
                              estimatedMinutes! > 0)
                            AcademyMetaChip(label: '${estimatedMinutes}m'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: shell.muted,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AcademyGuideCard extends StatelessWidget {
  const AcademyGuideCard({
    super.key,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.onTap,
    this.imageUrl,
    this.categoryName,
    this.progressPercent,
  });

  final String title;
  final String description;
  final String difficulty;
  final int estimatedMinutes;
  final VoidCallback onTap;
  final String? imageUrl;
  final String? categoryName;
  final double? progressPercent;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Material(
      color: shell.surfaceCard,
      borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
            border: Border.all(color: shell.surfaceCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (imageUrl != null && imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AcademyTokens.cardRadius),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _GuideImageFallback(shell),
                    ),
                  ),
                )
              else
                _GuideImageFallback(shell),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (categoryName != null)
                      Text(
                        categoryName!,
                        style: TextStyle(
                          color: StThemeColors.brandPurple,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        AcademyMetaChip(label: difficulty),
                        const SizedBox(width: 6),
                        AcademyMetaChip(label: '${estimatedMinutes}m'),
                      ],
                    ),
                    if (progressPercent != null) ...<Widget>[
                      const SizedBox(height: 10),
                      AcademyAnimatedProgressBar(value: progressPercent!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideImageFallback extends StatelessWidget {
  const _GuideImageFallback(this.shell);

  final StSupportShellStyle shell;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: shell.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.menu_book_rounded, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}

class AcademyMetaChip extends StatelessWidget {
  const AcademyMetaChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: shell.chipUnselectedBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: shell.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AcademyShellActionCard extends StatelessWidget {
  const AcademyShellActionCard({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onPressed,
    this.icon = Icons.menu_book_rounded,
    this.isPrimary = true,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onPressed;
  final IconData icon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: shell.heroGradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              color: shell.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: isPrimary
                ? FilledButton.icon(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: StThemeColors.brandPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(icon, size: 18),
                    label: Text(actionLabel),
                  )
                : OutlinedButton.icon(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: shell.onChrome,
                      side: BorderSide(color: shell.surfaceCardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(icon, size: 18),
                    label: Text(actionLabel),
                  ),
          ),
        ],
      ),
    );
  }
}

class AcademyEmptyState extends StatelessWidget {
  const AcademyEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.sentiment_dissatisfied_rounded, color: shell.muted, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: shell.muted, fontSize: 13, height: 1.4),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

class AcademySkeletonList extends StatelessWidget {
  const AcademySkeletonList({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(AcademyTokens.pagePadding),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 120,
        decoration: BoxDecoration(
          color: shell.skeletonFill,
          borderRadius: BorderRadius.circular(AcademyTokens.cardRadius),
        ),
      ),
    );
  }
}
