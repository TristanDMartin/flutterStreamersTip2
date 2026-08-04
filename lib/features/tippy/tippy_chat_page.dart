import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../billing/api_feature_gate.dart';
import '../billing/tier_display_names.dart';
import '../billing/subscription_provider.dart';
import '../entitlements/me_entitlements_models.dart';
import '../entitlements/me_entitlements_provider.dart';
import '../gamification/gamification_providers.dart';
import '../gamification/models/subscription_plan.dart'
    show SubscriptionPlan, subscriptionPlanToApiValue;
import '../gamification/models/user_progress_bundle.dart';
import '../../routing/app_navigator.dart';
import '../../routing/app_routes.dart';
import '../content_planning/content_plan_detail_view.dart';
import '../content_planning/content_planning_models.dart';
import '../content_planning/content_planning_provider.dart';
import '../content_planning/content_planning_repository.dart';
import 'tippy_access.dart';
import 'tippy_chat_service.dart';
import 'tippy_chat_tokens.dart';
import 'tippy_legal_service.dart';
import 'tippy_message_content.dart';
import 'widgets/tippy_consent_gate.dart';
import 'tippy_personality.dart';
import '../../components/onboarding/contextual_tip_overlay.dart';
import '../../providers/creator_personalization_provider.dart';
import '../../services/creator_intelligence_analytics_service.dart';
import '../../services/retention_tracking_service.dart';
import '../../services/creator_personalization_service.dart';
import '../analytics/models/analytics_profile.dart';
import 'creator_goals_repository.dart';
import 'models/creator_goal_model.dart';
import 'models/tippy_launch_context.dart';
import 'models/tippy_ui_payload.dart';
import 'widgets/tippy_action_card.dart';
import 'widgets/tippy_approval_sheet.dart';
import 'widgets/tippy_chat_chrome.dart';
import 'widgets/tippy_context_strip.dart';
import 'widgets/tippy_goal_sheet.dart';
import 'widgets/tippy_memory_empty_state.dart';

class TippyChatPage extends ConsumerStatefulWidget {
  const TippyChatPage({
    super.key,
    this.chatService,
    this.historyStore,
    this.legalService,
    this.launchContext = const TippyLaunchContext(),
  });

  final TippyChatService? chatService;
  final TippyConversationHistoryStore? historyStore;
  final TippyLegalService? legalService;
  final TippyLaunchContext launchContext;

  @override
  ConsumerState<TippyChatPage> createState() => _TippyChatPageState();
}

class _TippyChatPageState extends ConsumerState<TippyChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatLine> _lines = <_ChatLine>[];
  late final TippyChatService _service =
      widget.chatService ?? TippyChatService();
  late final TippyConversationHistoryStore _historyStore =
      widget.historyStore ??
          TippyConversationHistoryStore(chatService: _service);
  late final TippyLegalService _legalService =
      widget.legalService ?? TippyLegalService();
  StreamSubscription<bool>? _tippyEnabledSub;
  bool _consentLoading = true;
  bool _consentGranted = false;
  bool _consentSaving = false;
  bool _tippyEnabled = true;
  bool _busy = false;
  int? _creditsRemaining;
  String? _creditsTier;
  String? _nudge;
  String? _conversationId;
  _RetryAction? _pendingRetryAction;
  TippyUiPayload _uiPayload = TippyUiPayload.empty;
  bool _memoryReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ContextualTipCatalog.scheduleFeatureTipOnMount(
          context: context,
          tip: ContextualTipCatalog.tippyTip,
        );
      }
      unawaited(_bootstrapLegalGates());
      unawaited(_loadPersonalization());
      final String? prompt = widget.launchContext.prefilledPrompt ??
          widget.launchContext.insightPrompt;
      if (prompt != null && prompt.trim().isNotEmpty) {
        _input.text = prompt.trim();
      }
    });
  }

  Future<void> _bootstrapLegalGates() async {
    try {
      final bool granted = await _legalService.hasConsent();
      if (!mounted) {
        return;
      }
      setState(() {
        _consentGranted = granted;
        _consentLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _consentLoading = false);
      }
    }
    _tippyEnabledSub?.cancel();
    _tippyEnabledSub = _legalService.watchTippyEnabled().listen(
      (bool enabled) {
        if (!mounted) {
          return;
        }
        setState(() => _tippyEnabled = enabled);
      },
    );
  }

  Future<void> _acceptConsent() async {
    if (_consentSaving) {
      return;
    }
    setState(() => _consentSaving = true);
    try {
      await _legalService.recordConsent();
      if (!mounted) {
        return;
      }
      setState(() {
        _consentGranted = true;
        _consentSaving = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _consentSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _tippyEnabledSub?.cancel();
    _input.dispose();
    _scroll.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadPersonalization() async {
    try {
      final TippyContextSnapshot contextSnapshot = await _service.fetchContext();
      final TippyCreditsInfo credits = await _service.fetchCreditsInfo();
      String? nudge = await _service.fetchNudge();
      final AnalyticsProfile profile = await ref
          .read(creatorIntelligenceAnalyticsProvider)
          .loadProfile();
      if ((nudge == null || nudge.trim().isEmpty) &&
          profile.recommendedNextActions.isNotEmpty) {
        nudge = profile.recommendedNextActions.first;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _creditsRemaining = credits.creditsRemaining;
        _creditsTier = credits.tier;
        _nudge = nudge;
        _uiPayload = contextSnapshot.ui;
        _memoryReady =
            contextSnapshot.memoryReady || credits.memoryReady;
      });
      final String? prompt = widget.launchContext.prefilledPrompt ??
          widget.launchContext.insightPrompt;
      if (prompt != null && prompt.trim().isNotEmpty && _lines.isEmpty) {
        await _send();
      }
    } on TippyChatException {
      return;
    }
  }

  Future<void> _openGoalsSheet() async {
    final CreatorGoalModel? goal = await showTippyGoalSheet(context);
    if (goal == null || !mounted) {
      return;
    }
    final CreatorGoalsRepository repository = CreatorGoalsRepository(
      chatService: _service,
    );
    await repository.saveGoal(goal);
    await _loadPersonalization();
  }

  Future<void> _runCreatePlan() async {
    if (_busy) {
      return;
    }
    final _PlanContext planContext = _buildPlanContext();
    if (!planContext.hasUsefulContext) {
      setState(() {
        _lines.add(
          const _ChatLine(
            user: false,
            text:
                'Tell me what this content plan should be about first, then I can add it to your planner.',
            isError: true,
          ),
        );
      });
      _scrollToEnd();
      return;
    }
    final MeEntitlementsData? me =
        ref.read(meEntitlementsProvider).valueOrNull;
    final List<ContentPlan> plans =
        ref.read(contentPlansProvider).valueOrNull ?? const <ContentPlan>[];
    if (me != null && !canAffordAiAction(me, 'contentPlan')) {
      setState(() {
        _lines.add(
          const _ChatLine(
            user: false,
            text:
                'Not enough AI credits for a content plan. '
                'Upgrade or wait for your monthly reset.',
            isError: true,
          ),
        );
      });
      _scrollToEnd();
      return;
    }
    if (me != null && !canCreateContentPlan(me, plans.length)) {
      setState(() {
        _lines.add(
          const _ChatLine(
            user: false,
            text:
                'Your Creator plan includes one active content plan. '
                'Upgrade to Pro for unlimited plans.',
            isError: true,
          ),
        );
      });
      _scrollToEnd();
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      final TippyPlanResult result = await _service.createPlan(
        messages: planContext.messages,
        prompt: planContext.prompt,
      );
      if (!mounted) {
        return;
      }
      final String? planId = result.planId?.trim();
      String assistantText = result.message ??
          (planId == null || planId.isEmpty
              ? 'Created a new content plan and added it to your planner.'
              : 'Created a new content plan: $planId');
      if (planId != null &&
          planId.isNotEmpty &&
          !assistantText.contains('streamerstip://content-plan/')) {
        assistantText =
            '${assistantText.trim()}\nstreamerstip://content-plan/$planId';
      }
      setState(() {
        _creditsRemaining = result.creditsRemaining ?? _creditsRemaining;
        _pendingRetryAction = null;
        _lines.add(
          _ChatLine(
            user: false,
            text: assistantText,
          ),
        );
      });
      ref.invalidate(contentPlansProvider);
      await _persistConversation();
      await _refreshCreditsSnapshot();
      unawaited(
        ref.read(creatorIntelligenceAnalyticsProvider).trackContentPlanCreated(
              planId: planId,
            ),
      );
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        unawaited(
          RetentionTrackingService.instance.trackContentPlanCreated(
            uid: uid,
            planId: planId,
            metadata: const <String, dynamic>{'surface': 'tippy_chat'},
          ),
        );
      }
    } on TippyChatException catch (e) {
      await _handleTippyError(
        error: e,
        retryAction: const _RetryAction(_RetryActionType.createPlan),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
      _scrollToEnd();
    }
  }

  Future<void> _openContentPlanById(String planId) async {
    final String id = planId.trim();
    if (id.isEmpty) {
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final String? token = await user.getIdToken();
    if (token == null || !mounted) {
      return;
    }
    final ContentPlanningRepository repo =
        ref.read(contentPlanningRepositoryProvider);
    try {
      final ContentPlan? plan = await repo.getPlanById(
        idToken: token,
        userId: user.uid,
        planId: id,
      );
      if (!mounted) {
        return;
      }
      if (plan == null) {
        setState(() {
          _lines.add(
            const _ChatLine(
              user: false,
              text: 'That content plan was not found. Open the Content planner '
                  'and pull to refresh.',
              isError: true,
            ),
          );
        });
        _scrollToEnd();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext ctx) => ContentPlanDetailView(plan: plan),
        ),
      );
    } on ContentPlanningException catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(
          const _ChatLine(
            user: false,
            text: 'Could not load that content plan. Please try again.',
            isError: true,
          ),
        );
      });
      _scrollToEnd();
    }
  }

  Future<void> _runGenerateCaption() async {
    if (_busy) {
      return;
    }
    final String prompt = _input.text.trim().isEmpty
        ? (_lines.isNotEmpty ? _lines.last.text : 'Gaming clip idea')
        : _input.text.trim();
    setState(() {
      _busy = true;
    });
    try {
      final TippyCaptionResult result =
          await _service.createCaption(prompt: prompt);
      if (!mounted) {
        return;
      }
      final String hashtags = result.hashtags.isEmpty
          ? ''
          : '\n\nHashtags: ${result.hashtags.join(' ')}';
      final String title = result.title == null ? '' : '${result.title}\n\n';
      setState(() {
        _creditsRemaining = result.creditsRemaining ?? _creditsRemaining;
        _pendingRetryAction = null;
        _lines.add(
          _ChatLine(
            user: false,
            text: '$title${result.caption}$hashtags'.trim(),
          ),
        );
      });
      await _persistConversation();
      await _refreshCreditsSnapshot();
    } on TippyChatException catch (e) {
      await _handleTippyError(
        error: e,
        retryAction: _RetryAction(
          _RetryActionType.generateCaption,
          prompt: prompt,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
      _scrollToEnd();
    }
  }

  Future<void> _runAnalyzeContent() async {
    if (_busy) {
      return;
    }
    final String content = _input.text.trim().isNotEmpty
        ? _input.text.trim()
        : (_lines.isNotEmpty ? _lines.last.text : '');
    if (content.isEmpty) {
      setState(() {
        _lines.add(
          const _ChatLine(
            user: false,
            text: 'Paste a caption or script to review first.',
            isError: true,
          ),
        );
      });
      _scrollToEnd();
      return;
    }
    final MeEntitlementsData? me =
        ref.read(meEntitlementsProvider).valueOrNull;
    if (me != null && !canAffordAiAction(me, 'growthAnalysis')) {
      setState(() {
        _lines.add(
          const _ChatLine(
            user: false,
            text:
                'Not enough AI credits for content analysis. '
                'Upgrade or wait for your monthly reset.',
            isError: true,
          ),
        );
      });
      _scrollToEnd();
      return;
    }
    setState(() => _busy = true);
    try {
      final TippyAnalyzeContentResult result =
          await _service.analyzeContent(content: content);
      if (!mounted) {
        return;
      }
      final String actions = result.actionItems.isEmpty
          ? ''
          : '\n\nNext steps:\n${result.actionItems.map((String item) => '• $item').join('\n')}';
      setState(() {
        _lines.add(
          _ChatLine(
            user: false,
            text: '${result.summary}$actions'.trim(),
            cards: result.ui.cards,
          ),
        );
        _creditsRemaining = result.creditsRemaining ?? _creditsRemaining;
      });
      await _persistConversation();
      await _refreshCreditsSnapshot();
    } on TippyChatException catch (e) {
      await _handleTippyError(error: e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      _scrollToEnd();
    }
  }

  Future<void> _runHookIdeas() async {
    if (_busy) {
      return;
    }
    final String prompt = _input.text.trim().isEmpty
        ? 'Give me 5 hooks for my next short'
        : _input.text.trim();
    setState(() => _busy = true);
    try {
      final TippyHookIdeasResult result =
          await _service.fetchHookIdeas(prompt: prompt);
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(
          _ChatLine(
            user: false,
            text: result.hooks.isEmpty
                ? (result.message ?? 'No hooks returned.')
                : result.hooks.map((String hook) => '• $hook').join('\n'),
          ),
        );
        _creditsRemaining = result.creditsRemaining ?? _creditsRemaining;
      });
      await _persistConversation();
      await _refreshCreditsSnapshot();
    } on TippyChatException catch (e) {
      await _handleTippyError(error: e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      _scrollToEnd();
    }
  }

  Future<void> _runGenerateMission() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final TippyMissionResult result = await _service.generateDailyMission();
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(
          _ChatLine(
            user: false,
            text:
                'Today\'s mission: ${result.title}'
                '${result.description == null ? '' : '\n${result.description}'}',
          ),
        );
        _creditsRemaining = result.creditsRemaining ?? _creditsRemaining;
      });
      await _persistConversation();
      await _refreshCreditsSnapshot();
    } on TippyChatException catch (e) {
      await _handleTippyError(error: e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      _scrollToEnd();
    }
  }

  Future<void> _runGrowthProgram() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final TippyPlanResult result = await _service.startGrowthProgram();
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(
          _ChatLine(
            user: false,
            text: result.message ??
                'Your 30-day growth program is ready in the planner.',
            cards: result.ui.cards,
          ),
        );
        _creditsRemaining = result.creditsRemaining ?? _creditsRemaining;
      });
      ref.invalidate(contentPlansProvider);
      await _persistConversation();
      await _refreshCreditsSnapshot();
    } on TippyChatException catch (e) {
      await _handleTippyError(error: e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      _scrollToEnd();
    }
  }

  Future<void> _runProposeSchedule() async {
    if (_busy) {
      return;
    }
    final String prompt = _input.text.trim().isEmpty
        ? 'Propose 3 posting slots this week based on my goals'
        : _input.text.trim();
    setState(() => _busy = true);
    try {
      final TippyScheduleProposalResult result =
          await _service.proposeSchedule(prompt: prompt);
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(
          _ChatLine(
            user: false,
            text: result.message ??
                'Review the schedule proposals below and approve the ones you want.',
            cards: result.ui.cards,
          ),
        );
        _creditsRemaining = result.creditsRemaining ?? _creditsRemaining;
      });
      await _persistConversation();
      await _refreshCreditsSnapshot();
    } on TippyChatException catch (e) {
      await _handleTippyError(error: e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      _scrollToEnd();
    }
  }

  Future<void> _reviewScheduleProposal(TippyUiCardData card) async {
    final String proposalId =
        (card.ctaValue ?? card.planId ?? '').trim();
    if (proposalId.isEmpty || _busy) {
      return;
    }
    final bool? approved = await TippyApprovalSheet.show(
      context,
      title: card.title,
      subtitle: card.body.isEmpty
          ? 'Approve this posting slot?'
          : card.body,
    );
    if (approved != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.approveScheduleProposal(proposalId: proposalId);
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(
          _ChatLine(
            user: false,
            text: 'Approved "${card.title}". It is now on your schedule.',
          ),
        );
      });
      await _persistConversation();
    } on TippyChatException catch (e) {
      await _handleTippyError(error: e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      _scrollToEnd();
    }
  }

  _PlanContext _buildPlanContext() {
    final String prompt = _input.text.trim();
    final List<TippyChatMessage> messages = <TippyChatMessage>[
      ..._lines
          .where((_ChatLine line) => !line.isError && !line.isThinking)
          .map(
            (_ChatLine line) => TippyChatMessage(
              role: line.user ? 'user' : 'assistant',
              content: line.text,
            ),
          ),
      if (prompt.isNotEmpty)
        TippyChatMessage(
          role: 'user',
          content: prompt,
        ),
    ];
    return _PlanContext(prompt: prompt, messages: messages);
  }

  /// Prefer `/me`; derive remaining from monthly − used when remaining is 0 but usage exists.
  int _remainingCreditsFromMe(MeEntitlementsData me) {
    final TippyAiEntitlementPayload t = me.tippyAi;
    if (t.remainingCredits > 0) {
      return t.remainingCredits;
    }
    if (t.monthlyCredits > 0 &&
        t.usedCredits >= 0 &&
        t.usedCredits <= t.monthlyCredits) {
      final int derived = t.monthlyCredits - t.usedCredits;
      return derived < 0 ? 0 : derived;
    }
    return t.remainingCredits;
  }

  int? _displayCreditsRemaining(MeEntitlementsData me) {
    final int meRem = _remainingCreditsFromMe(me);
    final int? tip = _creditsRemaining;
    if (tip != null && tip > meRem) {
      return tip;
    }
    if (meRem > 0) {
      return meRem;
    }
    if (tip != null && tip > 0) {
      return tip;
    }
    if (meRem == 0 && tip != null && tip == 0) {
      return 0;
    }
    return tip ?? (meRem >= 0 ? meRem : null);
  }

  String? _labelForResolvedTierString(String? raw) {
    if (raw == null) {
      return null;
    }
    final String t = raw.trim().toLowerCase();
    if (t.isEmpty || t == 'unknown') {
      return null;
    }
    return tierDisplayNameForApi(t == 'unknown' ? 'starter' : t);
  }

  String _creditsPillLabel(
    UserProgressBundle bundle, {
    required MeEntitlementsData me,
  }) {
    final String? fromCredits = _labelForResolvedTierString(_creditsTier);
    final String? fromApi = _labelForResolvedTierString(me.tierApi);
    final SubscriptionPlan? subscriptionPlan = bundle.subscription?.plan;
    final String label = fromCredits ??
        fromApi ??
        (subscriptionPlan == null
            ? tierDisplayNameForApi('starter')
            : tierDisplayNameForApi(
                subscriptionPlanToApiValue(subscriptionPlan),
              ));
    final int? remaining = _displayCreditsRemaining(me);
    final int limit = me.creditsLimit > 0
        ? me.creditsLimit
        : me.entitlements.monthlyAiCredits;
    if (remaining != null && limit > 0) {
      return '$label · $remaining/$limit';
    }
    if (remaining != null) {
      return '$label · $remaining';
    }
    return label;
  }

  String _timeOfDayGreeting() {
    final int hour = DateTime.now().hour;
    final String time = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final String? rawName =
        FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (rawName == null || rawName.isEmpty) {
      return '$time.';
    }
    final String first = rawName.split(RegExp(r'\s+')).first;
    return '$time, $first.';
  }

  Future<void> _send() async {
    final String trimmed = _input.text.trim();
    if (trimmed.isEmpty || _busy) {
      return;
    }
    HapticFeedback.lightImpact();
    final String clientMessageId =
        'm_${DateTime.now().millisecondsSinceEpoch}_${trimmed.hashCode.abs()}';
    final String platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'desktop',
    };
    setState(() {
      _lines.add(_ChatLine(user: true, text: trimmed));
      _lines.add(
        const _ChatLine(
          user: false,
          text: 'Tippy is thinking...',
          isThinking: true,
        ),
      );
      _busy = true;
      _input.clear();
    });
    _scrollToEnd();
    try {
      final TippyChatResult reply = await _service.sendMessage(
        messages: <TippyChatMessage>[
          TippyChatMessage(role: 'user', content: trimmed),
        ],
        chatId: _conversationId,
        clientMessageId: clientMessageId,
        platform: platform,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (reply.chatId != null && reply.chatId!.isNotEmpty) {
          _conversationId = reply.chatId;
        }
        final int thinkingIndex = _lines.lastIndexWhere(
          (_ChatLine line) => line.isThinking,
        );
        final _ChatLine replyLine = _ChatLine(
          user: false,
          text: reply.message,
          cards: reply.ui.cards,
        );
        if (thinkingIndex >= 0) {
          _lines[thinkingIndex] = replyLine;
        } else {
          _lines.add(replyLine);
        }
        _creditsRemaining = reply.creditsRemaining;
        _pendingRetryAction = null;
        if (reply.ui != TippyUiPayload.empty) {
          _uiPayload = reply.ui;
        }
      });
      await _refreshCreditsSnapshot();
      unawaited(
        ref.read(creatorIntelligenceAnalyticsProvider).trackTippyQuestionAsked(
              conversationId: _conversationId,
            ),
      );
    } on TippyChatException catch (e) {
      await _handleTippyError(
        error: e,
        previousInput: trimmed,
        retryAction: _RetryAction(
          _RetryActionType.sendMessage,
          prompt: trimmed,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.removeWhere((_ChatLine line) => line.isThinking);
        _lines.add(
          _ChatLine(
            user: false,
            text: 'Something went wrong: $e',
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
      _scrollToEnd();
    }
  }

  Future<void> _handleTippyError({
    required TippyChatException error,
    String previousInput = '',
    _RetryAction? retryAction,
  }) async {
    if (!mounted) {
      return;
    }
    final _TippyErrorHandling handling = _resolveErrorHandling(error);
    setState(() {
      _lines.removeWhere((_ChatLine line) => line.isThinking);
      _lines.add(
        _ChatLine(
          user: false,
          text: handling.message,
          isError: true,
        ),
      );
      if (handling.shouldRestoreInput && previousInput.isNotEmpty) {
        _input.text = previousInput;
        _input.selection = TextSelection.collapsed(
          offset: _input.text.length,
        );
      }
      _pendingRetryAction = handling.showRetryButton ? retryAction : null;
    });
    if (handling.routeName == null) {
      return;
    }
    if (handling.routeName == AppRoutes.auth) {
      await AppNavigator.replaceWithAuth(context);
      return;
    }
    await Navigator.of(context).pushNamed(handling.routeName!);
  }

  _TippyErrorHandling _resolveErrorHandling(TippyChatException error) {
    if (error.status == 401 || error is TippyAuthException) {
      return const _TippyErrorHandling(
        message: 'Your session expired. Please sign in again.',
        routeName: AppRoutes.auth,
      );
    }
    if (error.status == 402 || error is TippyUpgradeRequiredException) {
      return _TippyErrorHandling(
        message: error.code == 'CONTENT_PLAN_LIMIT'
            ? error.message
            : error.message,
        routeName: AppRoutes.upgrade,
      );
    }
    if (error.code == 'CONSENT_REQUIRED') {
      if (mounted) {
        setState(() => _consentGranted = false);
      }
      return const _TippyErrorHandling(
        message: 'Accept Tippy consent to continue.',
      );
    }
    if (error.code == 'TIPPY_DISABLED') {
      if (mounted) {
        setState(() => _tippyEnabled = false);
      }
      return const _TippyErrorHandling(
        message: 'Tippy AI is temporarily unavailable.',
      );
    }
    if (error.code == 'APP_CHECK_REQUIRED' || error.code == 'APP_CHECK_INVALID') {
      return const _TippyErrorHandling(
        message:
            'App verification failed. Restart the app or update to the latest build.',
        showRetryButton: true,
        shouldRestoreInput: true,
      );
    }
    if (error.code == 'AI_PROVIDER_ERROR' ||
        error.code == 'SERVICE_UNAVAILABLE' ||
        error.code == 'RATE_LIMITED') {
      return _TippyErrorHandling(
        message: error.message,
        showRetryButton: true,
        shouldRestoreInput: true,
      );
    }
    if (error.status == 429) {
      return const _TippyErrorHandling(
        message: 'You are sending requests too quickly. Try again soon.',
        showRetryButton: true,
      );
    }
    if (error is TippyNetworkException) {
      final bool isTimeout = error.message.toLowerCase().contains('timed out');
      return _TippyErrorHandling(
        message: isTimeout
            ? 'Tippy took too long to respond. Try again.'
            : 'You are offline. Check your connection and try again.',
        shouldRestoreInput: true,
        showRetryButton: true,
      );
    }
    if (error.status >= 500 && error.code == 'INTERNAL_ERROR') {
      return const _TippyErrorHandling(
        message: 'Tippy hit a temporary issue. Your credits were not used.',
        shouldRestoreInput: true,
        showRetryButton: true,
      );
    }
    return _TippyErrorHandling(
      message: error.message,
      shouldRestoreInput: true,
      showRetryButton: error.retryable,
    );
  }

  Future<void> _refreshCreditsSnapshot() async {
    try {
      final TippyCreditsInfo info = await _service.fetchCreditsInfo();
      if (!mounted) {
        return;
      }
      setState(() {
        _creditsRemaining = info.creditsRemaining ?? _creditsRemaining;
        _creditsTier = info.tier ?? _creditsTier;
      });
    } on TippyChatException {
      return;
    }
  }

  Future<void> _retryLastAction() async {
    if (_busy || _pendingRetryAction == null) {
      return;
    }
    final _RetryAction retryAction = _pendingRetryAction!;
    switch (retryAction.type) {
      case _RetryActionType.sendMessage:
        if (retryAction.prompt.isNotEmpty) {
          _input.text = retryAction.prompt;
        }
        await _send();
        break;
      case _RetryActionType.createPlan:
        await _runCreatePlan();
        break;
      case _RetryActionType.generateCaption:
        if (retryAction.prompt.isNotEmpty) {
          _input.text = retryAction.prompt;
        }
        await _runGenerateCaption();
        break;
    }
  }

  Future<void> _persistConversation() async {
    final List<_ChatLine> persisted = _lines
        .where((_ChatLine line) => !line.isThinking && !line.isError)
        .toList(growable: false);
    if (persisted.isEmpty) {
      return;
    }
    try {
      _conversationId = await _historyStore.saveConversation(
        conversationId: _conversationId,
        messages: persisted
            .map(
              (_ChatLine line) => TippyStoredMessage(
                role: line.user ? 'user' : 'assistant',
                content: line.text,
              ),
            )
            .toList(growable: false),
      );
    } catch (_) {
      return;
    }
  }

  void _startNewConversation() {
    HapticFeedback.selectionClick();
    setState(() {
      _conversationId = null;
      _lines.clear();
      _pendingRetryAction = null;
      _input.clear();
    });
  }

  Future<void> _loadConversation(TippyConversationSummary conversation) async {
    HapticFeedback.selectionClick();
    final List<TippyStoredMessage> messages =
        conversation.messages.isNotEmpty
            ? conversation.messages
            : await _historyStore.loadMessages(conversation.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _conversationId = conversation.id;
      _lines
        ..clear()
        ..addAll(
          messages.map(
            (TippyStoredMessage message) => _ChatLine(
              user: message.role == 'user',
              text: message.content,
            ),
          ),
        );
      _pendingRetryAction = null;
      _input.clear();
    });
    _scrollToEnd();
  }

  Future<void> _openHistorySheet() async {
    HapticFeedback.selectionClick();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      showDragHandle: true,
      builder: (BuildContext context) {
        return _TippyHistorySheet(
          historyStore: _historyStore,
          onNewChat: () {
            Navigator.of(context).pop();
            _startNewConversation();
          },
          onSelect: (TippyConversationSummary conversation) {
            Navigator.of(context).pop();
            unawaited(_loadConversation(conversation));
          },
        );
      },
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserProgressBundle> bundleAsync =
        ref.watch(userProgressBundleProvider);
    return bundleAsync.when(
      data: (UserProgressBundle bundle) {
        final AsyncValue<MeEntitlementsData> meAsync =
            ref.watch(meEntitlementsProvider);
        return meAsync.when(
          data: (MeEntitlementsData me) {
            if (!resolveTippyEnabledFromSnapshot(me)) {
              return _TippyLockedScaffold(
                onUpgrade: () {
                  Navigator.of(context).pushNamed(AppRoutes.upgrade);
                },
              );
            }
            if (!_tippyEnabled) {
              return const _TippyDisabledScaffold();
            }
            if (_consentLoading) {
              return const _TippyLoadingScaffold(
                message: 'Loading Tippy...',
              );
            }
            if (!_consentGranted) {
              return TippyConsentGate(
                busy: _consentSaving,
                onAccepted: _acceptConsent,
              );
            }
            return _buildChatScaffold(
              context,
              bundle: bundle,
              me: me,
            );
          },
          loading: () {
            final SubscriptionSnapshot? cached =
                readCachedSubscriptionSnapshot(ref);
            if (cached != null) {
              if (!_tippyEnabled) {
                return const _TippyDisabledScaffold();
              }
              if (_consentLoading) {
                return const _TippyLoadingScaffold(
                  message: 'Loading Tippy...',
                );
              }
              if (!_consentGranted) {
                return TippyConsentGate(
                  busy: _consentSaving,
                  onAccepted: _acceptConsent,
                );
              }
              return _buildChatScaffold(
                context,
                bundle: bundle,
                me: cached,
              );
            }
            return const _TippyLoadingScaffold(
              message: 'Checking your plan...',
            );
          },
          error: (Object e, StackTrace st) {
            if (resolveTippyEnabled(bundle)) {
              if (!_tippyEnabled) {
                return const _TippyDisabledScaffold();
              }
              if (_consentLoading) {
                return const _TippyLoadingScaffold(
                  message: 'Loading Tippy...',
                );
              }
              if (!_consentGranted) {
                return TippyConsentGate(
                  busy: _consentSaving,
                  onAccepted: _acceptConsent,
                );
              }
              return _buildChatScaffold(
                context,
                bundle: bundle,
                me: SubscriptionSnapshot.starterFallback(),
              );
            }
            return _TippyErrorScaffold(
              title: 'Could not verify your plan.',
              details: e.toString(),
              onRetry: () {
                invalidateSubscriptionEntitlements(ref);
              },
            );
          },
        );
      },
      loading: () => const _TippyLoadingScaffold(
        message: 'Loading Tippy...',
      ),
      error: (Object e, StackTrace st) => _TippyErrorScaffold(
        title: 'Could not load your plan.',
        details: e.toString(),
        onRetry: () {
          ref.invalidate(userProgressBundleProvider);
        },
      ),
    );
  }

  Widget _buildChatScaffold(
    BuildContext context, {
    required UserProgressBundle bundle,
    required MeEntitlementsData me,
  }) {
    final int? displayCredits = _displayCreditsRemaining(me);
    final String creditsLabel = _creditsPillLabel(bundle, me: me);
    final CreatorPersonalizationProfile personalization =
        ref.watch(creatorPersonalizationProvider).valueOrNull ??
            CreatorPersonalizationProfile.empty;
    final List<String> quickPrompts =
        _uiPayload.suggestedPrompts.isNotEmpty
            ? _uiPayload.suggestedPrompts
            : CreatorPersonalizationLogic.mergeQuickPrompts(
                basePrompts: TippyPersonality.quickPromptsForSnapshot(me),
                goalPrompts:
                    CreatorPersonalizationLogic.tippyQuickPromptsForGoals(
                  personalization.creatorGoals,
                ),
              );
    final List<String> starters = <String>[
      if (_nudge != null && _nudge!.trim().isNotEmpty) _nudge!.trim(),
      ...TippyChatTokens.defaultStarters,
      ...quickPrompts,
    ];
    final List<String> uniqueStarters = <String>[];
    for (final String prompt in starters) {
      if (prompt.trim().isEmpty) {
        continue;
      }
      if (uniqueStarters.contains(prompt)) {
        continue;
      }
      uniqueStarters.add(prompt);
      if (uniqueStarters.length >= 4) {
        break;
      }
    }
    final bool hasConversation = _lines.isNotEmpty;
    return Scaffold(
      backgroundColor: TippyChatTokens.bg,
      body: TippyChatAtmosphere(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _TippyTopBar(
                creditsLabel: creditsLabel,
                busy: _busy,
                onHistory: _openHistorySheet,
                onNewChat: _startNewConversation,
                onGoals: _openGoalsSheet,
              ),
              Expanded(
                child: hasConversation
                    ? ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                        itemCount: _lines.length,
                        itemBuilder: (BuildContext context, int index) {
                          final _ChatLine line = _lines[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _ChatBubble(
                              line: line,
                              onContentPlanDeepLink:
                                  line.user || line.isThinking
                                      ? null
                                      : _openContentPlanById,
                              onPrefillPrompt: (String prompt) {
                                _input.text = prompt;
                                _send();
                              },
                              onApproveSchedule: _reviewScheduleProposal,
                            ),
                          );
                        },
                      )
                    : ListView(
                        controller: _scroll,
                        padding: EdgeInsets.zero,
                        children: <Widget>[
                          TippyEmptyState(
                            greeting: _timeOfDayGreeting(),
                            starters: uniqueStarters,
                            busy: _busy,
                            onStarter: (String prompt) {
                              _input.text = prompt;
                              _send();
                            },
                            onCaption: _runGenerateCaption,
                            onGeneratePlan: _runCreatePlan,
                            footer: !_memoryReady
                                ? TippyMemoryEmptyState(
                                    onUploadTap: () {
                                      Navigator.of(context)
                                          .pushNamed(AppRoutes.camera);
                                    },
                                  )
                                : TippyContextStrip(
                                    data: _uiPayload.contextStrip,
                                  ),
                          ),
                        ],
                      ),
              ),
              if (displayCredits != null && displayCredits <= 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TippyChatTokens.amberFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TippyChatTokens.amberBorder),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Out of AI credits for this cycle.',
                            style: TippyChatTokens.nunito(
                              size: 12,
                              weight: FontWeight.w700,
                              color: const Color(0xFFFFFBEB),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed(AppRoutes.upgrade);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFBCFE8),
                          ),
                          child: const Text('Upgrade'),
                        ),
                      ],
                    ),
                  ),
                ),
              TippyComposerShell(
                controller: _input,
                onSend: _send,
                enabled: !_busy,
                hintText: hasConversation
                    ? 'Message Tippy…'
                    : 'Ask Tippy anything…',
                chips: hasConversation
                    ? _TippyActionDock(
                        busy: _busy,
                        compact: true,
                        hasRetry: _pendingRetryAction != null,
                        onRetry: _retryLastAction,
                        onCreatePlan: _runCreatePlan,
                        onGenerateCaption: _runGenerateCaption,
                        onAnalyzeContent: _runAnalyzeContent,
                        onHookIdeas: _runHookIdeas,
                        onGenerateMission: _runGenerateMission,
                        onProposeSchedule: _runProposeSchedule,
                        onGrowthProgram: _runGrowthProgram,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TippyTopBar extends StatelessWidget {
  const _TippyTopBar({
    required this.creditsLabel,
    required this.busy,
    required this.onHistory,
    required this.onNewChat,
    required this.onGoals,
  });

  final String creditsLabel;
  final bool busy;
  final VoidCallback onHistory;
  final VoidCallback onNewChat;
  final VoidCallback onGoals;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: <Widget>[
          TippyIconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icons.arrow_back_rounded,
          ),
          const SizedBox(width: 10),
          const TippyMark(size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Tippy',
                  style: TippyChatTokens.nunito(
                    size: 14,
                    weight: FontWeight.w700,
                    color: TippyChatTokens.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  busy ? 'Thinking…' : 'Ask Tippy',
                  style: TippyChatTokens.nunito(
                    size: 10,
                    color: TippyChatTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TippyCreditsPill(label: creditsLabel),
          const SizedBox(width: 6),
          TippyIconButton(
            tooltip: 'Creator goals',
            onPressed: onGoals,
            icon: Icons.flag_rounded,
          ),
          const SizedBox(width: 6),
          TippyIconButton(
            tooltip: 'New chat',
            onPressed: onNewChat,
            icon: Icons.refresh_rounded,
          ),
          const SizedBox(width: 6),
          TippyIconButton(
            tooltip: 'Conversation history',
            onPressed: onHistory,
            icon: Icons.history_rounded,
          ),
        ],
      ),
    );
  }
}

class _TippyLoadingScaffold extends StatelessWidget {
  const _TippyLoadingScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TippyChatTokens.bg,
      body: TippyChatAtmosphere(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  children: <Widget>[
                    TippyIconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icons.arrow_back_rounded,
                    ),
                    const SizedBox(width: 10),
                    const TippyMark(size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tippy',
                        style: TippyChatTokens.nunito(
                          size: 14,
                          weight: FontWeight.w700,
                          color: TippyChatTokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(
                          color: TippyChatTokens.focus,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TippyChatTokens.nunito(
                            size: 13,
                            color: TippyChatTokens.textSecondary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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

class _TippyErrorScaffold extends StatelessWidget {
  const _TippyErrorScaffold({
    required this.title,
    required this.details,
    required this.onRetry,
  });

  final String title;
  final String details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TippyChatTokens.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF111827),
              Color(0xFF07111F),
              Color(0xFF050816),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.34),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      details,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TippyActionDock extends StatelessWidget {
  const _TippyActionDock({
    required this.busy,
    required this.compact,
    required this.hasRetry,
    required this.onRetry,
    required this.onCreatePlan,
    required this.onGenerateCaption,
    required this.onAnalyzeContent,
    required this.onHookIdeas,
    required this.onGenerateMission,
    required this.onProposeSchedule,
    required this.onGrowthProgram,
  });

  final bool busy;
  final bool compact;
  final bool hasRetry;
  final VoidCallback onRetry;
  final VoidCallback onCreatePlan;
  final VoidCallback onGenerateCaption;
  final VoidCallback onAnalyzeContent;
  final VoidCallback onHookIdeas;
  final VoidCallback onGenerateMission;
  final VoidCallback onProposeSchedule;
  final VoidCallback onGrowthProgram;

  Future<void> _openTools(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1220),
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                ListTile(
                  onTap: busy
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onCreatePlan();
                        },
                  leading: const Icon(
                    Icons.auto_awesome_motion_rounded,
                    color: Color(0xFF93C5FD),
                  ),
                  title: const Text(
                    'Create + Sync Plan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    'Build a content plan and send it to your planner.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                ),
                ListTile(
                  onTap: busy
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onAnalyzeContent();
                        },
                  leading: const Icon(
                    Icons.insights_rounded,
                    color: Color(0xFF93C5FD),
                  ),
                  title: const Text(
                    'Review my content',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ListTile(
                  onTap: busy
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onHookIdeas();
                        },
                  leading: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF93C5FD),
                  ),
                  title: const Text(
                    '5 hook ideas',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ListTile(
                  onTap: busy
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onGenerateMission();
                        },
                  leading: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFF93C5FD),
                  ),
                  title: const Text(
                    'Today\'s mission',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ListTile(
                  onTap: busy
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onProposeSchedule();
                        },
                  leading: const Icon(
                    Icons.event_available_rounded,
                    color: Color(0xFF93C5FD),
                  ),
                  title: const Text(
                    'Propose posting schedule',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    'Draft slots for the week and approve what you want.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                ),
                ListTile(
                  onTap: busy
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onGrowthProgram();
                        },
                  leading: const Icon(
                    Icons.timeline_rounded,
                    color: Color(0xFF93C5FD),
                  ),
                  title: const Text(
                    'Start 30-day growth program',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ListTile(
                  onTap: busy
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onGenerateCaption();
                        },
                  leading: const Icon(
                    Icons.text_fields_rounded,
                    color: Color(0xFF93C5FD),
                  ),
                  title: const Text(
                    'AI Caption',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    'Turn the current prompt or idea into a caption.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          if (hasRetry)
            TippyAccentChip(
              label: 'Retry last request',
              accent: false,
              enabled: !busy,
              onTap: onRetry,
            ),
          TippyAccentChip(
            label: 'Caption',
            accent: false,
            enabled: !busy,
            onTap: onGenerateCaption,
          ),
          TippyAccentChip(
            label: 'Plan',
            accent: false,
            enabled: !busy,
            onTap: onCreatePlan,
          ),
          TippyAccentChip(
            label: 'Tools',
            accent: false,
            onTap: () => _openTools(context),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class TippyStoredMessage {
  const TippyStoredMessage({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'role': role,
      'content': content,
    };
  }

  static TippyStoredMessage fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return const TippyStoredMessage(role: 'assistant', content: '');
    }
    final String role =
        raw['role'] is String ? raw['role'] as String : 'assistant';
    final String content =
        raw['content'] is String ? raw['content'] as String : '';
    return TippyStoredMessage(role: role, content: content);
  }
}

class TippyConversationSummary {
  const TippyConversationSummary({
    required this.id,
    required this.title,
    required this.messages,
    this.updatedAt,
    this.lastMessage = '',
  });

  final String id;
  final String title;
  final List<TippyStoredMessage> messages;
  final DateTime? updatedAt;
  final String lastMessage;
}

/// Canonical Tippy history: `users/{uid}/tippyChats/{chatId}/messages/{id}`.
class TippyConversationHistoryStore {
  TippyConversationHistoryStore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    TippyChatService? chatService,
  })  : _firestore = firestore,
        _auth = auth,
        _chatService = chatService;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final TippyChatService? _chatService;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? _chatsCollection() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }
    return _db.collection('users').doc(user.uid).collection('tippyChats');
  }

  CollectionReference<Map<String, dynamic>>? _messagesCollection(String chatId) {
    final CollectionReference<Map<String, dynamic>>? chats = _chatsCollection();
    if (chats == null) {
      return null;
    }
    return chats.doc(chatId).collection('messages');
  }

  /// Legacy client persist path — no longer writes embedded tippyConversations.
  /// Prefer server persistence via [TippyChatService.sendPersistedMessage].
  Future<String?> saveConversation({
    required String? conversationId,
    required List<TippyStoredMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return conversationId;
    }
    String? chatId = conversationId;
    final TippyChatService? service = _chatService;
    if (chatId == null || chatId.isEmpty) {
      if (service == null) {
        return conversationId;
      }
      chatId = await service.createChat(
        title: _titleFromMessages(messages),
        platform: _platformLabel(),
      );
    }
    final CollectionReference<Map<String, dynamic>>? messagesCol =
        _messagesCollection(chatId);
    final CollectionReference<Map<String, dynamic>>? chats = _chatsCollection();
    if (messagesCol == null || chats == null) {
      return chatId;
    }
    final QuerySnapshot<Map<String, dynamic>> existing =
        await messagesCol.orderBy('createdAt').limit(200).get();
    final int existingCount = existing.docs.length;
    if (messages.length <= existingCount) {
      return chatId;
    }
    final WriteBatch batch = _db.batch();
    for (int i = existingCount; i < messages.length; i++) {
      final TippyStoredMessage message = messages[i];
      final DocumentReference<Map<String, dynamic>> ref = messagesCol.doc();
      batch.set(ref, <String, dynamic>{
        'id': ref.id,
        'role': message.role,
        'content': message.content,
        'createdAt': FieldValue.serverTimestamp(),
        'creditCost': 0,
        'platform': _platformLabel(),
        'status': 'complete',
        'metadata': <String, dynamic>{'source': 'tippy_mobile_tool'},
      });
    }
    final TippyStoredMessage last = messages.last;
    batch.set(
      chats.doc(chatId),
      <String, dynamic>{
        'title': _titleFromMessages(messages),
        'lastMessage': last.content.length > 120
            ? last.content.substring(0, 120)
            : last.content,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deleted': false,
        'archived': false,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    return chatId;
  }

  Future<List<TippyStoredMessage>> loadMessages(String chatId) async {
    final CollectionReference<Map<String, dynamic>>? messagesCol =
        _messagesCollection(chatId);
    if (messagesCol == null) {
      return const <TippyStoredMessage>[];
    }
    final QuerySnapshot<Map<String, dynamic>> snap =
        await messagesCol.orderBy('createdAt').limit(200).get();
    return snap.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data();
          final String role = data['role'] is String ? data['role'] as String : '';
          final String content =
              data['content'] is String ? data['content'] as String : '';
          return TippyStoredMessage(role: role, content: content);
        })
        .where((TippyStoredMessage m) => m.content.trim().isNotEmpty)
        .toList(growable: false);
  }

  Stream<List<TippyConversationSummary>> watchRecent() {
    final CollectionReference<Map<String, dynamic>>? collection =
        _chatsCollection();
    if (collection == null) {
      return Stream<List<TippyConversationSummary>>.value(
        const <TippyConversationSummary>[],
      );
    }
    final User? user = _firebaseAuth.currentUser;
    final String uid = user?.uid ?? '';
    return collection.limit(150).snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<TippyConversationSummary> rows = snapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
              final Map<String, dynamic> data = doc.data();
              final String owner = (data['ownerUid'] ?? data['userId'] ?? '')
                  .toString()
                  .trim();
              if (owner.isNotEmpty && owner != uid) {
                return null;
              }
              if (data['deleted'] == true || data['archived'] == true) {
                return null;
              }
              final DateTime? updatedAt = _readTimestamp(
                    data['lastMessageAt'],
                  ) ??
                  _readTimestamp(data['updatedAt']) ??
                  _readTimestamp(data['createdAt']);
              final String rawLast = data['lastMessage'] is String
                  ? data['lastMessage'] as String
                  : '';
              final String lastMessage =
                  _stripTippyFrontendContextBlock(rawLast);
              final String rawTitle = data['title'] is String
                  ? data['title'] as String
                  : '';
              final String title = _resolveTippyChatTitle(
                title: rawTitle,
                lastMessage: lastMessage,
              );
              return TippyConversationSummary(
                id: doc.id,
                title: title,
                messages: const <TippyStoredMessage>[],
                updatedAt: updatedAt,
                lastMessage: lastMessage,
              );
            })
            .whereType<TippyConversationSummary>()
            .toList(growable: false);
        rows.sort((TippyConversationSummary a, TippyConversationSummary b) {
          final int aMs = a.updatedAt?.millisecondsSinceEpoch ?? 0;
          final int bMs = b.updatedAt?.millisecondsSinceEpoch ?? 0;
          return bMs.compareTo(aMs);
        });
        if (rows.length <= 50) {
          return rows;
        }
        return rows.sublist(0, 50);
      },
    );
  }

  Future<void> softDelete(String chatId) async {
    final TippyChatService? service = _chatService;
    if (service != null) {
      await service.deleteChat(chatId: chatId);
      return;
    }
    final CollectionReference<Map<String, dynamic>>? chats = _chatsCollection();
    if (chats == null) {
      return;
    }
    await chats.doc(chatId).set(
      <String, dynamic>{
        'deleted': true,
        'archived': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> rename(String chatId, String title) async {
    final TippyChatService? service = _chatService;
    if (service != null) {
      await service.renameChat(chatId: chatId, title: title);
      return;
    }
    final CollectionReference<Map<String, dynamic>>? chats = _chatsCollection();
    if (chats == null) {
      return;
    }
    await chats.doc(chatId).set(
      <String, dynamic>{
        'title': title.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  DateTime? _readTimestamp(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    return null;
  }

  String _platformLabel() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'desktop';
    }
  }

  String _titleFromMessages(List<TippyStoredMessage> messages) {
    final String firstUser = _stripTippyFrontendContextBlock(
      messages
          .firstWhere(
            (TippyStoredMessage message) => message.role == 'user',
            orElse: () => messages.first,
          )
          .content,
    ).replaceAll(RegExp(r'\s+'), ' ');
    if (firstUser.isEmpty ||
        firstUser.contains('[TIPPY_FRONTEND_CONTEXT]')) {
      return 'Tippy conversation';
    }
    return firstUser.length > 54
        ? '${firstUser.substring(0, 54)}...'
        : firstUser;
  }
}

String _stripTippyFrontendContextBlock(String message) {
  if (message.isEmpty) {
    return '';
  }
  String out = message.replaceAll(
    RegExp(
      r'\[TIPPY_FRONTEND_CONTEXT\][\s\S]*?\[/TIPPY_FRONTEND_CONTEXT\]\s*',
      caseSensitive: false,
    ),
    '',
  );
  out = out.replaceAll(
    RegExp(r'\[TIPPY_FRONTEND_CONTEXT\][\s\S]*', caseSensitive: false),
    '',
  );
  out = out.replaceAll(
    RegExp(r'\[/?TIPPY_FRONTEND_CONTEXT\]', caseSensitive: false),
    '',
  );
  return out.trim();
}

String _sanitizeTippyChatTitle(String title) {
  final String cleaned =
      _stripTippyFrontendContextBlock(title).replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty ||
      cleaned.toUpperCase().contains('TIPPY_FRONTEND_CONTEXT') ||
      cleaned.toLowerCase() == 'new chat') {
    return '';
  }
  return cleaned;
}

String _resolveTippyChatTitle({
  required String title,
  String lastMessage = '',
}) {
  for (final String candidate in <String>[title, lastMessage]) {
    final String cleaned = _sanitizeTippyChatTitle(candidate);
    if (cleaned.isEmpty) {
      continue;
    }
    return cleaned.length > 48
        ? '${cleaned.substring(0, 45)}...'
        : cleaned;
  }
  return 'Conversation';
}

class _TippyHistorySheet extends StatelessWidget {
  const _TippyHistorySheet({
    required this.historyStore,
    required this.onNewChat,
    required this.onSelect,
  });

  final TippyConversationHistoryStore historyStore;
  final VoidCallback onNewChat;
  final ValueChanged<TippyConversationSummary> onSelect;

  String _formatRelative(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return 'just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 420,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Tippy history',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onNewChat,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New chat'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<TippyConversationSummary>>(
                stream: historyStore.watchRecent(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<TippyConversationSummary>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final List<TippyConversationSummary> conversations =
                      snapshot.data ?? const <TippyConversationSummary>[];
                  if (conversations.isEmpty) {
                    return Center(
                      child: Text(
                        'No saved Tippy conversations yet.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final TippyConversationSummary conversation =
                          conversations[index];
                      final String preview =
                          _stripTippyFrontendContextBlock(
                        conversation.lastMessage,
                      );
                      final bool hasCleanPreview = preview.isNotEmpty &&
                          !preview
                              .toUpperCase()
                              .contains('TIPPY_FRONTEND_CONTEXT');
                      final String subtitle = hasCleanPreview
                          ? preview
                          : (conversation.updatedAt == null
                              ? 'Open conversation'
                              : 'Updated ${_formatRelative(conversation.updatedAt!)}');
                      return ListTile(
                        onTap: () => onSelect(conversation),
                        leading: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.white70,
                        ),
                        title: Text(
                          _resolveTippyChatTitle(
                            title: conversation.title,
                            lastMessage: conversation.lastMessage,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white54,
                          ),
                          onPressed: () async {
                            try {
                              await historyStore.softDelete(conversation.id);
                            } catch (_) {}
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TippyDisabledScaffold extends StatelessWidget {
  const _TippyDisabledScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TippyChatTokens.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF111827),
              Color(0xFF07111F),
              Color(0xFF050816),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.smart_toy_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tippy is temporarily unavailable',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Our team has paused Tippy AI. Please check back later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TippyLockedScaffold extends StatelessWidget {
  const _TippyLockedScaffold({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TippyChatTokens.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF111827),
              Color(0xFF07111F),
              Color(0xFF050816),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1220).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFF4897D2).withValues(alpha: 0.24),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.26),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFF9248D2),
                              Color(0xFF38BDF8),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_open_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Unlock Tippy AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tippy is included on Pro and Studio, or when your account has the Tippy entitlement.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.35,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: onUpgrade,
                        icon: const Icon(Icons.workspace_premium_rounded),
                        label: const Text('View plans'),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatLine {
  const _ChatLine({
    required this.user,
    required this.text,
    this.isError = false,
    this.isThinking = false,
    this.cards = const <TippyUiCardData>[],
  });

  final bool user;
  final String text;
  final bool isError;
  final bool isThinking;
  final List<TippyUiCardData> cards;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.line,
    this.onContentPlanDeepLink,
    this.onPrefillPrompt,
    this.onApproveSchedule,
  });

  final _ChatLine line;
  final void Function(String planId)? onContentPlanDeepLink;
  final void Function(String prompt)? onPrefillPrompt;
  final void Function(TippyUiCardData card)? onApproveSchedule;

  @override
  Widget build(BuildContext context) {
    if (line.isThinking) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const TippyMark(size: 24),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: TippyChatTokens.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const TippyThinkingDots(),
          ),
        ],
      );
    }
    if (line.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                TippyChatTokens.accent,
                TippyChatTokens.bubbleEnd,
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: TippyChatTokens.accent.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            line.text,
            style: TippyChatTokens.nunito(
              size: 13,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TippyMark(size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TippyMessageContent(
                text: line.text,
                style: TippyChatTokens.nunito(
                  size: 13,
                  color: line.isError
                      ? const Color(0xFFFECACA)
                      : TippyChatTokens.textBody,
                  height: 1.4,
                ),
                onContentPlanDeepLink: onContentPlanDeepLink,
              ),
              for (final TippyUiCardData card in line.cards)
                TippyActionCard(
                  card: card,
                  onDeepLink: (String value) {
                    final RegExp planPattern = RegExp(
                      r'streamerstip://content-plan/([A-Za-z0-9_-]+)',
                    );
                    final RegExpMatch? match = planPattern.firstMatch(value);
                    if (match != null) {
                      onContentPlanDeepLink?.call(match.group(1)!);
                      return;
                    }
                  },
                  onPrefillPrompt: onPrefillPrompt,
                  onApproveSchedule: onApproveSchedule,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TippyErrorHandling {
  const _TippyErrorHandling({
    required this.message,
    this.routeName,
    this.shouldRestoreInput = false,
    this.showRetryButton = false,
  });

  final String message;
  final String? routeName;
  final bool shouldRestoreInput;
  final bool showRetryButton;
}

enum _RetryActionType { sendMessage, createPlan, generateCaption }

class _RetryAction {
  const _RetryAction(this.type, {this.prompt = ''});

  final _RetryActionType type;
  final String prompt;
}

class _PlanContext {
  const _PlanContext({
    required this.prompt,
    required this.messages,
  });

  final String prompt;
  final List<TippyChatMessage> messages;

  bool get hasUsefulContext {
    final String combined = messages
        .where((TippyChatMessage message) => message.role == 'user')
        .map((TippyChatMessage message) => message.content.trim())
        .where((String text) => text.isNotEmpty)
        .join(' ')
        .toLowerCase();
    if (combined.length < 24) {
      return false;
    }
    const List<String> genericRequests = <String>[
      'create a content plan',
      'make a content plan',
      'turn this conversation into a content plan',
      'sync it to my content planner',
      'add it to my content planner',
    ];
    final String normalized = combined.replaceAll(RegExp(r'\s+'), ' ').trim();
    return !genericRequests.contains(normalized);
  }
}
