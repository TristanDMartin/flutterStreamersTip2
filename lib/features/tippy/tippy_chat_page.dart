import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gamification/gamification_providers.dart';
import '../gamification/models/subscription_plan.dart';
import '../gamification/models/user_progress_bundle.dart';
import '../../routing/app_routes.dart';
import 'tippy_access.dart';
import 'tippy_chat_service.dart';
import 'tippy_message_content.dart';

class TippyChatPage extends ConsumerStatefulWidget {
  const TippyChatPage({super.key});

  @override
  ConsumerState<TippyChatPage> createState() => _TippyChatPageState();
}

class _TippyChatPageState extends ConsumerState<TippyChatPage> {
  static const List<String> _quickPrompts = <String>[
    'Plan my next 7 days of content',
    'Give me 10 gaming short-form hooks',
    'What should I post today?',
    'Review my consistency and fix it',
  ];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatLine> _lines = <_ChatLine>[];
  late final TippyChatService _service = TippyChatService();
  bool _busy = false;
  int? _creditsRemaining;
  String? _greeting;
  String? _nudge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    if (!_service.hasApiBase) {
      return;
    }
    try {
      final TippyCreditsInfo credits = await _service.fetchCreditsInfo();
      final String? nudge = await _service.fetchNudge();
      if (!mounted) {
        return;
      }
      setState(() {
        _greeting = credits.greeting;
        _creditsRemaining = credits.creditsRemaining;
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
        _lines.add(
          _ChatLine(
            user: false,
            text: result.planId == null
                ? 'Created a new 7-day plan.'
                : 'Created a new 7-day plan: ${result.planId}',
          ),
        );
      });
    } on TippyUpgradeRequiredException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(_ChatLine(user: false, text: e.message, isError: true));
      });
      await Navigator.of(context).pushNamed(AppRoutes.upgrade);
    } on TippyChatException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(_ChatLine(user: false, text: e.message, isError: true));
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
      final TippyCaptionResult result = await _service.createCaption(prompt: prompt);
      if (!mounted) {
        return;
      }
      final String hashtags = result.hashtags.isEmpty
          ? ''
          : '\n\nHashtags: ${result.hashtags.join(' ')}';
      final String title = result.title == null ? '' : '${result.title}\n\n';
      setState(() {
        _lines.add(
          _ChatLine(
            user: false,
            text: '$title${result.caption}$hashtags'.trim(),
          ),
        );
      });
    } on TippyUpgradeRequiredException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(_ChatLine(user: false, text: e.message, isError: true));
      });
      await Navigator.of(context).pushNamed(AppRoutes.upgrade);
    } on TippyChatException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(_ChatLine(user: false, text: e.message, isError: true));
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

  String _planSubtitle(UserProgressBundle bundle) {
    final SubscriptionPlan? plan = bundle.subscription?.plan;
    final String label = switch (plan) {
      SubscriptionPlan.studio => 'Studio',
      SubscriptionPlan.pro => 'Pro',
      SubscriptionPlan.starter => 'Starter',
      SubscriptionPlan.unknown => 'Creator',
      null => 'Creator',
    };
    if (_creditsRemaining != null) {
      return '$label · $_creditsRemaining credits';
    }
    return label;
  }

  Future<void> _send() async {
    final String trimmed = _input.text.trim();
    if (trimmed.isEmpty || _busy) {
      return;
    }
    if (!_service.hasApiBase) {
      setState(() {
        _lines.add(
          _ChatLine(
            user: false,
            text: 'Add your API base at build time: '
                'flutter run '
                '--dart-define=TIPPY_API_BASE=https://your-domain.com',
            isError: true,
          ),
        );
      });
      _scrollToEnd();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _lines.add(_ChatLine(user: true, text: trimmed));
      _busy = true;
      _input.clear();
    });
    _scrollToEnd();
    final List<TippyChatMessage> payload = <TippyChatMessage>[
      ..._lines
          .where((_ChatLine line) => !line.isError)
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
        _lines.add(_ChatLine(user: false, text: reply.message));
        _creditsRemaining = reply.creditsRemaining;
      });
    } on TippyUpgradeRequiredException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(_ChatLine(user: false, text: e.message, isError: true));
      });
      await Navigator.of(context).pushNamed(AppRoutes.upgrade);
    } on TippyAuthException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(_ChatLine(user: false, text: e.message, isError: true));
      });
    } on TippyChatException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lines.add(_ChatLine(user: false, text: e.message, isError: true));
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
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
        return _buildChatScaffold(context, bundle);
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

  Widget _buildChatScaffold(BuildContext context, UserProgressBundle bundle) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Tippy AI'),
            Text(
              _planSubtitle(bundle),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _lines.isEmpty ? 1 : _lines.length,
              itemBuilder: (BuildContext context, int index) {
                if (_lines.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Plan posts, brainstorm hooks, ask gaming questions, '
                          'or paste a script for feedback.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _quickPrompts
                              .map(
                                (String prompt) => ActionChip(
                                  label: Text(prompt),
                                  onPressed: () {
                                    _input.text = prompt;
                                    _send();
                                  },
                                ),
                              )
                              .toList(growable: false),
                        ),
                        if (_greeting != null) ...<Widget>[
                          const SizedBox(height: 14),
                          Text(
                            _greeting!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (_nudge != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF4897D2)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              _nudge!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
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
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _runCreatePlan,
                    icon: const Icon(Icons.auto_awesome_motion_rounded, size: 16),
                    label: const Text('Create Plan'),
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

class _TippyLockedScaffold extends StatelessWidget {
  const _TippyLockedScaffold({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
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
  });

  final bool user;
  final String text;
  final bool isError;
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
    final Color fg =
        line.isError ? Colors.red.shade100 : Colors.white;
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
