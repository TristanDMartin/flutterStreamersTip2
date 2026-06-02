import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../entitlements/me_entitlements_models.dart';
import '../entitlements/me_entitlements_provider.dart';
import '../gamification/gamification_providers.dart';
import '../gamification/models/subscription_plan.dart';
import '../gamification/models/user_progress_bundle.dart';
import '../../routing/app_navigator.dart';
import '../../routing/app_routes.dart';
import '../content_planning/content_plan_detail_view.dart';
import '../content_planning/content_planning_models.dart';
import '../content_planning/content_planning_provider.dart';
import '../content_planning/content_planning_repository.dart';
import 'tippy_access.dart';
import 'tippy_chat_service.dart';
import 'tippy_message_content.dart';
import 'tippy_personality.dart';
import 'tippy_tier.dart';

class TippyChatPage extends ConsumerStatefulWidget {
  const TippyChatPage({
    super.key,
    this.chatService,
    this.historyStore,
  });

  final TippyChatService? chatService;
  final TippyConversationHistoryStore? historyStore;

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
      widget.historyStore ?? TippyConversationHistoryStore();
  bool _busy = false;
  int? _creditsRemaining;
  String? _creditsTier;
  String? _greeting;
  String? _nudge;
  String? _conversationId;
  _RetryAction? _pendingRetryAction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(meEntitlementsProvider);
      }
      _loadPersonalization();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadPersonalization() async {
    try {
      final TippyCreditsInfo credits = await _service.fetchCreditsInfo();
      final String? nudge = await _service.fetchNudge();
      if (!mounted) {
        return;
      }
      setState(() {
        _greeting = credits.greeting;
        _creditsRemaining = credits.creditsRemaining;
        _creditsTier = credits.tier;
        _nudge = nudge;
      });
    } on TippyChatException {
      return;
    }
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
    return switch (t) {
      'studio' => 'Studio',
      'pro' => 'Pro',
      'starter' => 'Starter',
      _ => 'Creator',
    };
  }

  String _planSubtitle(
    UserProgressBundle bundle, {
    required MeEntitlementsData me,
  }) {
    final int? dc = _displayCreditsRemaining(me);
    final String? fromCredits = _labelForResolvedTierString(_creditsTier);
    if (fromCredits != null) {
      if (dc != null) {
        return '$fromCredits · $dc credits';
      }
      return fromCredits;
    }
    final String? fromApi = _labelForResolvedTierString(me.tier);
    if (fromApi != null) {
      if (dc != null) {
        return '$fromApi · $dc credits';
      }
      return '$fromApi plan active';
    }
    final SubscriptionPlan? subscriptionPlan = bundle.subscription?.plan;
    final String label = switch (subscriptionPlan) {
      SubscriptionPlan.studio => 'Studio',
      SubscriptionPlan.pro => 'Pro',
      SubscriptionPlan.starter => 'Starter',
      SubscriptionPlan.unknown => 'Creator',
      null => 'Creator',
    };
    if (dc != null) {
      return '$label · $dc credits';
    }
    return label;
  }

  Future<void> _send() async {
    final String trimmed = _input.text.trim();
    if (trimmed.isEmpty || _busy) {
      return;
    }
    HapticFeedback.lightImpact();
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
    final List<TippyChatMessage> payload = <TippyChatMessage>[
      ..._lines
          .where((_ChatLine line) => !line.isError && !line.isThinking)
          .map(
            (_ChatLine line) => TippyChatMessage(
              role: line.user ? 'user' : 'assistant',
              content: line.text,
            ),
          ),
    ];
    try {
      final TippyChatResult reply = await _service.sendMessage(
        messages: payload,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final int thinkingIndex = _lines.lastIndexWhere(
          (_ChatLine line) => line.isThinking,
        );
        final _ChatLine replyLine = _ChatLine(user: false, text: reply.message);
        if (thinkingIndex >= 0) {
          _lines[thinkingIndex] = replyLine;
        } else {
          _lines.add(replyLine);
        }
        _creditsRemaining = reply.creditsRemaining;
        _pendingRetryAction = null;
      });
      await _persistConversation();
      await _refreshCreditsSnapshot();
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
        message: error.message,
        routeName: AppRoutes.upgrade,
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
    if (error.status >= 500) {
      return const _TippyErrorHandling(
        message: 'Tippy hit a temporary issue. Your credits were not used.',
        shouldRestoreInput: true,
        showRetryButton: true,
      );
    }
    return _TippyErrorHandling(message: error.message);
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

  void _loadConversation(TippyConversationSummary conversation) {
    HapticFeedback.selectionClick();
    setState(() {
      _conversationId = conversation.id;
      _lines
        ..clear()
        ..addAll(
          conversation.messages.map(
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
            _loadConversation(conversation);
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
        if (!resolveTippyEnabled(bundle)) {
          return _TippyLockedScaffold(
            onUpgrade: () {
              Navigator.of(context).pushNamed(AppRoutes.upgrade);
            },
          );
        }
        final AsyncValue<MeEntitlementsData> meAsync =
            ref.watch(meEntitlementsProvider);
        return meAsync.when(
          data: (MeEntitlementsData me) {
            return _buildChatScaffold(
              context,
              bundle: bundle,
              me: me,
            );
          },
          loading: () => const _TippyLoadingScaffold(
            message: 'Checking your plan...',
          ),
          error: (Object e, StackTrace st) {
            return _TippyErrorScaffold(
              title: 'Could not verify your plan.',
              details: e.toString(),
              onRetry: () {
                ref.invalidate(meEntitlementsProvider);
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
    final ThemeData theme = Theme.of(context);
    final int? displayCredits = _displayCreditsRemaining(me);
    final String creditsLabel = _planSubtitle(bundle, me: me);
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
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
          child: Column(
            children: <Widget>[
              _TippyTopBar(
                creditsLabel: creditsLabel,
                busy: _busy,
                onHistory: _openHistorySheet,
                onNewChat: _startNewConversation,
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  itemCount: _lines.isEmpty ? 1 : _lines.length,
                  itemBuilder: (BuildContext context, int index) {
                    if (_lines.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _TippyWelcomePanel(
                              greeting: _greeting,
                              nudge: _nudge,
                              creditsLabel: creditsLabel,
                              subtitle: TippyPersonality.welcomeSubtitle(
                                resolveTippyFeatureTier(bundle),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _QuickPromptGrid(
                              prompts: TippyPersonality.quickPromptsForBundle(
                                bundle,
                              ),
                              onPrompt: (String prompt) {
                                _input.text = prompt;
                                _send();
                              },
                            ),
                          ],
                        ),
                      );
                    }
                    final _ChatLine line = _lines[index];
                    return _ChatBubble(
                      line: line,
                      onContentPlanDeepLink: line.user || line.isThinking
                          ? null
                          : _openContentPlanById,
                    );
                  },
                ),
              ),
              if (_busy)
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Color(0xFF111827),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF60A5FA),
                  ),
                ),
              if (displayCredits != null && displayCredits <= 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F1D1D).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'You are out of credits for this cycle.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed(AppRoutes.upgrade);
                          },
                          child: const Text('Upgrade'),
                        ),
                      ],
                    ),
                  ),
                ),
              _TippyActionDock(
                busy: _busy,
                compact: _lines.isNotEmpty,
                hasRetry: _pendingRetryAction != null,
                onRetry: _retryLastAction,
                onCreatePlan: _runCreatePlan,
                onGenerateCaption: _runGenerateCaption,
              ),
              SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1220).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 5,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Message Tippy...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.44),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.045),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 12,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy ? null : _send,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Icon(Icons.send_rounded, size: 20),
                      ),
                    ],
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

class _TippyTopBar extends StatelessWidget {
  const _TippyTopBar({
    required this.creditsLabel,
    required this.busy,
    required this.onHistory,
    required this.onNewChat,
  });

  final String creditsLabel;
  final bool busy;
  final VoidCallback onHistory;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Back',
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF9248D2), Color(0xFF38BDF8)],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Tippy AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Row(
                  children: <Widget>[
                    Icon(
                      busy ? Icons.sync_rounded : Icons.verified_rounded,
                      color: busy
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF34D399),
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        creditsLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: onNewChat,
            icon: const Icon(Icons.add_comment_rounded),
            color: Colors.white.withValues(alpha: 0.82),
          ),
          IconButton(
            tooltip: 'Conversation history',
            onPressed: onHistory,
            icon: const Icon(Icons.history_rounded),
            color: Colors.white.withValues(alpha: 0.82),
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
      backgroundColor: const Color(0xFF050816),
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
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: <Color>[
                            Color(0xFF9248D2),
                            Color(0xFF38BDF8),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tippy AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1220).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF4897D2).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
      backgroundColor: const Color(0xFF050816),
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
  });

  final bool busy;
  final bool compact;
  final bool hasRetry;
  final VoidCallback onRetry;
  final VoidCallback onCreatePlan;
  final VoidCallback onGenerateCaption;

  Future<void> _openTools(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Row(
          children: <Widget>[
            if (hasRetry) ...<Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry last request'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            OutlinedButton.icon(
              onPressed: () => _openTools(context),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Tools'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                backgroundColor: Colors.white.withValues(alpha: 0.045),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Column(
        children: <Widget>[
          if (hasRetry) ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry last request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: _TippyToolButton(
                  icon: Icons.auto_awesome_motion_rounded,
                  label: 'Create + Sync Plan',
                  onPressed: busy ? null : onCreatePlan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TippyToolButton(
                  icon: Icons.text_fields_rounded,
                  label: 'AI Caption',
                  onPressed: busy ? null : onGenerateCaption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TippyToolButton extends StatelessWidget {
  const _TippyToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        backgroundColor: Colors.white.withValues(alpha: 0.045),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _QuickPromptGrid extends StatelessWidget {
  const _QuickPromptGrid({
    required this.prompts,
    required this.onPrompt,
  });

  final List<String> prompts;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Start fast',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: prompts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 82,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (BuildContext context, int index) {
            final String prompt = prompts[index];
            return _QuickPromptCard(
              prompt: prompt,
              icon: switch (index) {
                0 => Icons.calendar_month_rounded,
                1 => Icons.sports_esports_rounded,
                2 => Icons.lightbulb_rounded,
                _ => Icons.edit_calendar_rounded,
              },
              onTap: () => onPrompt(prompt),
            );
          },
        ),
      ],
    );
  }
}

class _QuickPromptCard extends StatelessWidget {
  const _QuickPromptCard({
    required this.prompt,
    required this.icon,
    required this.onTap,
  });

  final String prompt;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: const Color(0xFF93C5FD), size: 18),
              const Spacer(),
              Text(
                prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TippyWelcomePanel extends StatelessWidget {
  const _TippyWelcomePanel({
    required this.greeting,
    required this.nudge,
    required this.creditsLabel,
    this.subtitle,
  });

  final String? greeting;
  final String? nudge;
  final String creditsLabel;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF4897D2).withValues(alpha: 0.22),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF9248D2).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  creditsLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            greeting ?? 'Tippy is ready.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
          if (nudge != null && nudge!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              nudge!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
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
  });

  final String id;
  final String title;
  final List<TippyStoredMessage> messages;
  final DateTime? updatedAt;
}

class TippyConversationHistoryStore {
  TippyConversationHistoryStore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? _collection() {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('tippyConversations');
  }

  Future<String?> saveConversation({
    required String? conversationId,
    required List<TippyStoredMessage> messages,
  }) async {
    final CollectionReference<Map<String, dynamic>>? collection = _collection();
    if (collection == null || messages.isEmpty) {
      return conversationId;
    }
    final DocumentReference<Map<String, dynamic>> docRef =
        conversationId == null
            ? collection.doc()
            : collection.doc(conversationId);
    final String title = _titleFromMessages(messages);
    final Map<String, dynamic> payload = <String, dynamic>{
      'title': title,
      'messageCount': messages.length,
      'messages': messages
          .take(60)
          .map((TippyStoredMessage message) => message.toJson())
          .toList(growable: false),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (conversationId == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    await docRef.set(
      payload,
      SetOptions(merge: true),
    );
    return docRef.id;
  }

  Stream<List<TippyConversationSummary>> watchRecent() {
    final CollectionReference<Map<String, dynamic>>? collection = _collection();
    if (collection == null) {
      return Stream<List<TippyConversationSummary>>.value(
        const <TippyConversationSummary>[],
      );
    }
    return collection
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic> data = doc.data();
            final Object? rawMessages = data['messages'];
            final List<TippyStoredMessage> messages = rawMessages is List
                ? rawMessages
                    .map(TippyStoredMessage.fromJson)
                    .where(
                      (TippyStoredMessage message) =>
                          message.content.trim().isNotEmpty,
                    )
                    .toList(growable: false)
                : const <TippyStoredMessage>[];
            final Timestamp? updatedAt = data['updatedAt'] is Timestamp
                ? data['updatedAt'] as Timestamp
                : null;
            return TippyConversationSummary(
              id: doc.id,
              title: data['title'] is String
                  ? data['title'] as String
                  : _titleFromMessages(messages),
              messages: messages,
              updatedAt: updatedAt?.toDate(),
            );
          }).toList(growable: false),
        );
  }

  String _titleFromMessages(List<TippyStoredMessage> messages) {
    final String firstUser = messages
        .firstWhere(
          (TippyStoredMessage message) => message.role == 'user',
          orElse: () => messages.first,
        )
        .content
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (firstUser.isEmpty) {
      return 'Tippy conversation';
    }
    return firstUser.length > 54
        ? '${firstUser.substring(0, 54)}...'
        : firstUser;
  }
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
                      return ListTile(
                        onTap: () => onSelect(conversation),
                        leading: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.white70,
                        ),
                        title: Text(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${conversation.messages.length} messages',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white54,
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

class _TippyLockedScaffold extends StatelessWidget {
  const _TippyLockedScaffold({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
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
  });

  final bool user;
  final String text;
  final bool isError;
  final bool isThinking;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.line,
    this.onContentPlanDeepLink,
  });

  final _ChatLine line;
  final void Function(String planId)? onContentPlanDeepLink;

  @override
  Widget build(BuildContext context) {
    final Alignment align =
        line.user ? Alignment.centerRight : Alignment.centerLeft;
    final Color bg = line.isError
        ? const Color(0xFF7F1D1D).withValues(alpha: 0.9)
        : line.user
            ? const Color(0xFF2563EB).withValues(alpha: 0.92)
            : const Color(0xFF111827).withValues(alpha: 0.96);
    final Color fg = line.isError ? Colors.red.shade100 : Colors.white;
    return Align(
      alignment: align,
      child: Container(
        margin: EdgeInsets.only(
          left: line.user ? 44 : 0,
          right: line.user ? 0 : 44,
          bottom: 10,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(line.user ? 18 : 6),
            bottomRight: Radius.circular(line.user ? 6 : 18),
          ),
          border: Border.all(
            color: line.user
                ? const Color(0xFF60A5FA).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: TippyMessageContent(
          text: line.text,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            height: 1.35,
          ),
          onContentPlanDeepLink: onContentPlanDeepLink,
        ),
      ),
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
