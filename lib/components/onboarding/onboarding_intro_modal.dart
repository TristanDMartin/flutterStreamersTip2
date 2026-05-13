import 'package:flutter/material.dart';

import 'onboarding_style.dart';

class OnboardingIntroModal extends StatefulWidget {
  const OnboardingIntroModal({
    super.key,
    required this.onComplete,
    this.onSkip,
  });

  final ValueChanged<String> onComplete;
  final VoidCallback? onSkip;

  @override
  State<OnboardingIntroModal> createState() => _OnboardingIntroModalState();
}

class _OnboardingIntroModalState extends State<OnboardingIntroModal> {
  final PageController _controller = PageController();
  int _page = 0;
  String? _creatorGoal;

  static const Map<String, String> _goals = <String, String>{
    'grow_audience': 'Grow my audience',
    'stay_consistent': 'Stay consistent',
    'improve_content': 'Improve my content',
    'network': 'Network with creators',
    'monetize': 'Get ready to monetize',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final String selected = _creatorGoal ?? 'grow_audience';
    widget.onComplete(selected);
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final double width = size.width.clamp(0, 420).toDouble();
    final bool compact = size.height < 720 || size.width < 380;
    final double maxSheetHeight =
        size.height - padding.top - padding.bottom - 44;
    final double sheetHeight = (compact ? size.height * 0.62 : 460)
        .clamp(360.0, maxSheetHeight)
        .toDouble();
    return Material(
      key: const Key('onboarding-intro-modal'),
      color: Colors.black.withValues(alpha: 0.42),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: width,
            margin: EdgeInsets.fromLTRB(
              10,
              10,
              10,
              (padding.bottom > 0 ? 8 : 14),
            ),
            decoration: OnboardingStyle.cardDecoration(context: context),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: sheetHeight,
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (int value) => setState(() => _page = value),
                    children: <Widget>[
                      _WelcomeScreen(),
                      _GoalScreen(
                        goals: _goals,
                        selectedGoal: _creatorGoal,
                        onSelected: (String value) {
                          setState(() => _creatorGoal = value);
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 16,
                    0,
                    compact ? 12 : 16,
                    compact ? 10 : 14,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Center(child: _PageDots(page: _page))),
                      if (widget.onSkip != null)
                        TextButton(
                          onPressed: widget.onSkip,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: OnboardingStyle.textSecondaryFor(context),
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: GradientPillButton(
                              key: const Key('onboarding-start-button'),
                              label: _page == 0 ? 'Next' : 'Start watching',
                              onPressed: _next,
                              icon: _page == 0
                                  ? Icons.arrow_forward_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool compact = size.height < 720 || size.width < 380;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 24,
        compact ? 16 : 24,
        compact ? 18 : 24,
        16,
      ),
      child: Column(
        children: <Widget>[
          _PhonePreview(compact: compact),
          SizedBox(height: compact ? 14 : 22),
          Text(
            'Welcome to StreamersTip',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OnboardingStyle.textPrimaryFor(context),
              fontSize: compact ? 21 : 24,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            'Swipe through creator clips, then open tools only when you need them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OnboardingStyle.textSecondaryFor(context),
              fontSize: compact ? 14 : 16,
              height: 1.35,
            ),
          ),
          SizedBox(height: compact ? 12 : 18),
          _MiniHint(
            icon: Icons.swap_vert_rounded,
            text: 'Swipe up for more videos',
          ),
          SizedBox(height: compact ? 8 : 10),
          _MiniHint(
            icon: Icons.touch_app_rounded,
            text: 'First taps will explain each tool',
          ),
        ],
      ),
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 104 : 132,
      height: compact ? 126 : 168,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: compact ? 82 : 104,
            height: compact ? 116 : 150,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(compact ? 21 : 26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.72),
                width: compact ? 5 : 6,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 54,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: compact ? 12 : 24,
            child: Icon(
              Icons.touch_app_rounded,
              color: Colors.white.withValues(alpha: 0.94),
              size: compact ? 48 : 62,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalScreen extends StatelessWidget {
  const _GoalScreen({
    required this.goals,
    required this.selectedGoal,
    required this.onSelected,
  });

  final Map<String, String> goals;
  final String? selectedGoal;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool compact = size.height < 720 || size.width < 380;
    final bool light = OnboardingStyle.isLight(context);
    final Color textPrimary = OnboardingStyle.textPrimaryFor(context);
    final Color textSecondary = OnboardingStyle.textSecondaryFor(context);
    final Color border = OnboardingStyle.borderFor(context);
    final Color chipBackground =
        light ? const Color(0xFFF8FAFC) : Colors.white.withValues(alpha: 0.08);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 20,
        compact ? 16 : 24,
        compact ? 16 : 20,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'What are you focused on right now?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textPrimary,
              fontSize: compact ? 21 : 26,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            'Pick one focus so StreamersTip can nudge you in the right moments.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontSize: compact ? 13 : 14,
              height: 1.35,
            ),
          ),
          SizedBox(height: compact ? 14 : 20),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 8 : 10,
            alignment: WrapAlignment.center,
            children: goals.entries.map((MapEntry<String, String> entry) {
              final bool selected = selectedGoal == entry.key;
              return ChoiceChip(
                key: entry.key == 'grow_audience'
                    ? const Key('creator-goal-grow-audience')
                    : Key('creator-goal-${entry.key}'),
                selected: selected,
                showCheckmark: true,
                checkmarkColor: Colors.white,
                onSelected: (_) => onSelected(entry.key),
                backgroundColor: chipBackground,
                selectedColor: const Color(0xFF4897D2),
                side: BorderSide(
                  color:
                      selected ? Colors.white.withValues(alpha: 0.35) : border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                labelPadding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 12,
                  vertical: compact ? 6 : 8,
                ),
                label: Text(
                  entry.value,
                  style: TextStyle(
                    color: selected ? Colors.white : textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 12.5 : 14,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MiniHint extends StatelessWidget {
  const _MiniHint({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bool light = OnboardingStyle.isLight(context);
    final Color textPrimary = OnboardingStyle.textPrimaryFor(context);
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: light
                ? const Color(0xFFF8FAFC)
                : Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OnboardingStyle.borderFor(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: const Color(0xFF7DD3FC), size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(2, (int index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 6),
          width: page == index ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: page == index
                ? const Color(0xFF4897D2)
                : Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
