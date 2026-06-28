import 'dart:ui';

import 'package:flutter/material.dart';

import '../onboarding_service.dart';
import '../onboarding_style.dart';
import '../../../services/app_store_review_service.dart';

class HardRatingOverlay extends StatefulWidget {
  const HardRatingOverlay({
    super.key,
    required this.userId,
    required this.onClose,
    this.service,
    this.onRequestReview,
  });

  final String userId;
  final VoidCallback onClose;
  final OnboardingService? service;
  final Future<bool> Function()? onRequestReview;

  static OverlayEntry show({
    required BuildContext context,
    required String userId,
    required OnboardingService service,
    Future<bool> Function()? onRequestReview,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) {
        return HardRatingOverlay(
          userId: userId,
          service: service,
          onRequestReview: onRequestReview,
          onClose: () => entry.remove(),
        );
      },
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  @override
  State<HardRatingOverlay> createState() => _HardRatingOverlayState();
}

class _HardRatingOverlayState extends State<HardRatingOverlay> {
  late final OnboardingService _service;
  late final AppStoreReviewService _reviewService;
  int _selectedStars = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OnboardingService();
    _reviewService = AppStoreReviewService();
  }

  Future<bool> _requestReview() async {
    final Future<bool> Function()? handler = widget.onRequestReview;
    if (handler != null) {
      return handler();
    }
    return _reviewService.requestReviewOrOpenStore();
  }

  Future<void> _rateOnStore() async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final bool opened = await _requestReview();
    if (!mounted) {
      return;
    }
    if (!opened) {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            'Could not open the store right now. Try again in a moment.';
      });
      return;
    }
    await _service.markHasRated(widget.userId);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: const SizedBox.expand(),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DecoratedBox(
                decoration: OnboardingStyle.cardDecoration(context: context),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('🎮', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        'Enjoying StreamersTip?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: OnboardingStyle.textPrimaryFor(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'You just completed a mission — you\'re building '
                        'something. A quick rating helps other creators find us.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: OnboardingStyle.textSecondaryFor(context),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(5, (int index) {
                          final int starNumber = index + 1;
                          final bool isLit = starNumber <= _selectedStars;
                          return IconButton(
                            onPressed: () {
                              setState(() => _selectedStars = starNumber);
                            },
                            icon: Icon(
                              isLit
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isLit
                                  ? const Color(0xFFFBBF24)
                                  : OnboardingStyle.textSecondaryFor(context),
                              size: 32,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: GradientPillButton(
                          label: _isSubmitting
                              ? 'Opening...'
                              : _reviewService.storeButtonLabel,
                          onPressed: _isSubmitting ? null : _rateOnStore,
                        ),
                      ),
                      if (_errorMessage != null) ...<Widget>[
                        const SizedBox(height: 10),
                        SelectableText.rich(
                          TextSpan(
                            text: _errorMessage,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      TextButton(
                        onPressed: _isSubmitting ? null : widget.onClose,
                        child: Text(
                          'Not now',
                          style: TextStyle(
                            color: OnboardingStyle.textSecondaryFor(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
