import 'package:flutter/material.dart';

import '../onboarding_service.dart';
import '../onboarding_style.dart';
import '../../../services/app_store_review_service.dart';

enum SoftRatingPhase { ask, feedback, hidden }

class OnboardingSoftRatingWidget extends StatefulWidget {
  const OnboardingSoftRatingWidget({
    super.key,
    required this.userId,
    this.service,
    this.onRequestReview,
    this.compact = false,
  });

  final String userId;
  final OnboardingService? service;
  final Future<bool> Function()? onRequestReview;
  final bool compact;

  @override
  State<OnboardingSoftRatingWidget> createState() =>
      _OnboardingSoftRatingWidgetState();
}

class _OnboardingSoftRatingWidgetState
    extends State<OnboardingSoftRatingWidget> {
  OnboardingService? _service;
  SoftRatingPhase _phase = SoftRatingPhase.ask;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  OnboardingService get _resolvedService =>
      _service ??= widget.service ?? OnboardingService();

  Future<bool> _requestReview() async {
    final Future<bool> Function()? handler = widget.onRequestReview;
    if (handler != null) {
      return handler();
    }
    return AppStoreReviewService().requestReviewOrOpenStore();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _handleRateUs() async {
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
    await _resolvedService.markHasRated(widget.userId);
    if (mounted) {
      setState(() => _phase = SoftRatingPhase.hidden);
    }
  }

  Future<void> _handleNotReally() async {
    await _resolvedService.markSoftRatingDismissed(widget.userId);
    setState(() => _phase = SoftRatingPhase.feedback);
  }

  Future<void> _sendFeedback() async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);
    await _resolvedService.saveOnboardingFeedback(
      widget.userId,
      _feedbackController.text,
    );
    if (mounted) {
      setState(() {
        _phase = SoftRatingPhase.hidden;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _skipFeedback() async {
    await _resolvedService.markSoftRatingDismissed(widget.userId);
    setState(() => _phase = SoftRatingPhase.hidden);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == SoftRatingPhase.hidden) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C47FF).withValues(alpha: 0.45),
        ),
        color: const Color(0xFF6C47FF).withValues(alpha: 0.08),
      ),
      child: _phase == SoftRatingPhase.ask
          ? _buildAskPhase(context)
          : _buildFeedbackPhase(context),
    );
  }

  Widget _buildAskPhase(BuildContext context) {
    final bool stackButtons = widget.compact ||
        MediaQuery.sizeOf(context).width < 360;
    final Widget notReallyButton = OutlinedButton(
      onPressed: _isSubmitting ? null : _handleNotReally,
      style: OutlinedButton.styleFrom(
        foregroundColor: OnboardingStyle.textPrimaryFor(context),
        side: BorderSide(color: OnboardingStyle.borderFor(context)),
        padding: widget.compact
            ? const EdgeInsets.symmetric(vertical: 10)
            : null,
      ),
      child: const Text('Not really'),
    );
    final Widget rateButton = GradientPillButton(
      label: _isSubmitting ? 'Opening...' : 'Rate us',
      onPressed: _isSubmitting ? null : _handleRateUs,
    );
    return Column(
      children: <Widget>[
        Text(
          'Loving StreamersTip so far? ⭐',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: OnboardingStyle.textPrimaryFor(context),
            fontWeight: FontWeight.w800,
            fontSize: widget.compact ? 15 : 16,
          ),
        ),
        SizedBox(height: widget.compact ? 10 : 12),
        if (stackButtons) ...<Widget>[
          SizedBox(width: double.infinity, child: rateButton),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: notReallyButton),
        ] else
          Row(
            children: <Widget>[
              Expanded(child: notReallyButton),
              const SizedBox(width: 10),
              Expanded(child: rateButton),
            ],
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
      ],
    );
  }

  Widget _buildFeedbackPhase(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _feedbackController,
          maxLines: 3,
          style: TextStyle(color: OnboardingStyle.textPrimaryFor(context)),
          decoration: InputDecoration(
            hintText: 'What\'s missing? We read every response.',
            hintStyle: TextStyle(
              color: OnboardingStyle.textSecondaryFor(context),
            ),
            filled: true,
            fillColor: OnboardingStyle.surfaceFor(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        GradientPillButton(
          label: _isSubmitting ? 'Sending...' : 'Send Feedback',
          onPressed: _isSubmitting ? null : _sendFeedback,
        ),
        TextButton(
          onPressed: _skipFeedback,
          child: Text(
            'Skip',
            style: TextStyle(
              color: OnboardingStyle.textSecondaryFor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
