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
import 'tippy_access.dart';
import 'tippy_chat_service.dart';
import 'tippy_message_content.dart';

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
  static const List<String> _quickPrompts = <String>[
    'Create a 14-day content plan and sync it to my content planner',
    'Give me 10 gaming short-form hooks',
    'What should I post today?',
    'Turn my next idea into a scheduled post',
  ];
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
    setState(() {
      _busy = true;
    });
    try {
      final TippyPlanResult result = await _service.createPlan();
      if (!mounted) {
        return;
      }
      setState(() {
        _creditsRemaining = result.creditsRemaining ?? _creditsRemaining;
        _pendingRetryAction = null;
        _lines.add(
          _ChatLine(
            user: false,
            text: result.message ??
                (result.planId == null
                    ? 'Created a new content plan and added it to your planner.'
                    : 'Created a new content plan: ${result.planId}'),
          ),
        );
      });
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
          loading: () {
            final ColorScheme scheme = Theme.of(context).colorScheme;
            return Scaffold(
              backgroundColor: scheme.surface,
              appBar: AppBar(
                backgroundColor: scheme.surfaceContainerHighest,
                foregroundColor: scheme.onSurface,
                title: const Text('Tippy AI'),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Checking your plan…',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          error: (Object e, StackTrace st) {
            final ColorScheme scheme = Theme.of(context).colorScheme;
            return Scaffold(
              backgroundColor: scheme.surface,
              appBar: AppBar(
                backgroundColor: scheme.surfaceContainerHighest,
                foregroundColor: scheme.onSurface,
                title: const Text('Tippy AI'),
              ),
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SelectableText.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: Colors.redAccent,
                          height: 1.35,
                        ),
                        children: <InlineSpan>[
                          const TextSpan(
                            text: 'Could not verify your plan. ',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: e.toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(meEntitlementsProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace st) => Scaffold(
        appBar: AppBar(title: const Text('Tippy AI')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: SelectableText.rich(
            TextSpan(
              style: const TextStyle(color: Colors.redAccent, height: 1.35),
              children: <InlineSpan>[
                const TextSpan(
                  text: 'Could not load your plan. ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: e.toString()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatScaffold(
    BuildContext context, {
    required UserProgressBundle bundle,
    required MeEntitlementsData me,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int? displayCredits = _displayCreditsRemaining(me);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Tippy AI'),
            Text(
              _planSubtitle(bundle, me: me),
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Conversation history',
            onPressed: _openHistorySheet,
            icon: const Icon(Icons.menu_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _TippyStatusStrip(
            creditsLabel: _planSubtitle(bundle, me: me),
            busy: _busy,
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _lines.isEmpty ? 1 : _lines.length,
              itemBuilder: (BuildContext context, int index) {
                if (_lines.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _TippyWelcomePanel(
                          greeting: _greeting,
                          nudge: _nudge,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Start fast',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _quickPrompts
                              .map(
                                (String prompt) => ActionChip(
                                  avatar: const Icon(
                                    Icons.bolt_rounded,
                                    size: 15,
                                  ),
                                  label: Text(prompt),
                                  onPressed: () {
                                    _input.text = prompt;
                                    _send();
                                  },
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  );
                }
                final _ChatLine line = _lines[index];
                return _ChatBubble(line: line);
              },
            ),
          ),
          if (_busy)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Color(0xFF1E293B),
            ),
          if (displayCredits != null && displayCredits <= 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
          if (_pendingRetryAction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _retryLastAction,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry last request'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _runCreatePlan,
                    icon:
                        const Icon(Icons.auto_awesome_motion_rounded, size: 16),
                    label: const Text('Create + Sync Plan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _runGenerateCaption,
                    icon: const Icon(Icons.text_fields_rounded, size: 16),
                    label: const Text('AI Caption'),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Material(
              color: const Color(0xFF1E293B),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                          hintText: 'Message Tippy…',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        backgroundColor: theme.colorScheme.primary,
                      ),
                      child: const Icon(Icons.send_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TippyStatusStrip extends StatelessWidget {
  const _TippyStatusStrip({
    required this.creditsLabel,
    required this.busy,
  });

  final String creditsLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            busy ? Icons.sync_rounded : Icons.verified_rounded,
            color: busy ? const Color(0xFF93C5FD) : const Color(0xFF34D399),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              creditsLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            busy ? 'Working' : 'Ready',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TippyWelcomePanel extends StatelessWidget {
  const _TippyWelcomePanel({
    required this.greeting,
    required this.nudge,
  });

  final String? greeting;
  final String? nudge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4897D2).withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF9248D2).withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  greeting ?? 'Tippy is ready.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.24,
                  ),
                ),
                if (nudge != null && nudge!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    nudge!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.28,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        title: const Text('Tippy AI'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SelectableText.rich(
              TextSpan(
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.35,
                  fontSize: 15,
                ),
                children: const <InlineSpan>[
                  TextSpan(
                    text: 'Tippy is included on Pro and Studio, '
                        'or when your account has the Tippy entitlement.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onUpgrade,
              child: const Text('View plans'),
            ),
          ],
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
  const _ChatBubble({required this.line});

  final _ChatLine line;

  @override
  Widget build(BuildContext context) {
    final Alignment align =
        line.user ? Alignment.centerRight : Alignment.centerLeft;
    final Color bg = line.isError
        ? const Color(0xFF7F1D1D).withValues(alpha: 0.85)
        : line.user
            ? const Color(0xFF9248D2).withValues(alpha: 0.95)
            : const Color(0xFF1E293B);
    final Color fg = line.isError ? Colors.red.shade100 : Colors.white;
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TippyMessageContent(
          text: line.text,
          style: TextStyle(
            color: fg,
            fontSize: 14,
            height: 1.35,
          ),
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
