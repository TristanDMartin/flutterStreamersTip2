import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../core/design/st_spacing.dart';
import '../../core/theme/support_shell_style.dart';
import '../../models/forum_author.dart';
import '../../services/discussion_author_service.dart';
import '../../utils/avatar_url_resolver.dart';
import '../../widgets/status_aware_avatar.dart';
import 'threads_contract.dart';
import 'threads_models.dart';
import 'threads_repository.dart';
import 'typed_create_thread_screen.dart';

/// Creator Threads shell — consumes [ThreadsRepository] only (no forum heuristics).
class CreatorThreadsShell extends StatefulWidget {
  const CreatorThreadsShell({
    super.key,
    required this.repository,
    this.embeddedInHome = true,
    this.onOpenThread,
  });

  final ThreadsRepository repository;
  final bool embeddedInHome;
  final ValueChanged<ThreadDto>? onOpenThread;

  @override
  State<CreatorThreadsShell> createState() => _CreatorThreadsShellState();
}

class _CreatorThreadsShellState extends State<CreatorThreadsShell> {
  String _filter = 'for_you';
  String? _categoryId;
  bool _isLoading = true;
  String? _errorMessage;
  List<ThreadFeedModuleDto> _modules = const <ThreadFeedModuleDto>[];
  bool _searchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final String viewerId =
          firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
      final List<ThreadFeedModuleDto> modules =
          await widget.repository.listModules(viewerId: viewerId);
      List<ThreadFeedModuleDto> next = modules;
      if (_filter != 'for_you' ||
          (_categoryId != null && _categoryId!.isNotEmpty) ||
          _searchController.text.trim().isNotEmpty) {
        final List<ThreadDto> feed = await widget.repository.listFeed(
          filter: _filter,
          categoryId: _categoryId,
          searchQuery: _searchController.text.trim(),
          viewerId: viewerId,
        );
        next = <ThreadFeedModuleDto>[
          ThreadFeedModuleDto(
            moduleId: 'featured',
            title: kFeedFilterLabels[normalizeFeedFilter(_filter)] ??
                'Discussions',
            threads: feed,
          ),
        ];
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _modules = next;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openStarter(TippyStarterPreset preset) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TypedCreateThreadScreen(
          repository: widget.repository,
          initialPreset: preset,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double topPad = widget.embeddedInHome
        ? MediaQuery.paddingOf(context).top + 66
        : MediaQuery.paddingOf(context).top + 8;
    // Scaffold uses extendBody + floating glass dock; last tilted cards need
    // safe-area + dock height + overhang clearance.
    final double bottomPad = widget.embeddedInHome
        ? MediaQuery.paddingOf(context).bottom +
            STSpacing.bottomNavBarHeight +
            36
        : MediaQuery.paddingOf(context).bottom + 24;
    return ColoredBox(
      color: const Color(0xFF071120),
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverToBoxAdapter(child: SizedBox(height: topPad)),
            SliverToBoxAdapter(child: _buildHeader(shell, scheme)),
            SliverToBoxAdapter(child: _buildTippyStarter(scheme)),
            SliverToBoxAdapter(child: _buildFilters(scheme)),
            SliverToBoxAdapter(child: _buildCategoryRail(scheme)),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyCard(
                  title: 'Threads Are Taking A Beat',
                  message: _errorMessage!,
                  actionLabel: 'Try Again',
                  onAction: _load,
                ),
              )
            else if (_modules.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyCard(
                  title: 'No personalized discussions yet',
                  message:
                      'Tippy is still learning what conversations fit you.',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final ThreadFeedModuleDto module = _modules[index];
                    return _ModuleSection(
                      module: module,
                      onOpen: (ThreadDto thread) {
                        widget.onOpenThread?.call(thread);
                      },
                    );
                  },
                  childCount: _modules.length,
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(StSupportShellStyle shell, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  kThreadsProductName,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Talk growth, content, gear, and creator life.',
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () {
              setState(() => _searchExpanded = !_searchExpanded);
            },
            icon: Icon(Icons.search_rounded, color: scheme.onSurface),
          ),
          IconButton(
            tooltip: 'Saved',
            onPressed: () {},
            icon: Icon(
              Icons.bookmark_border_rounded,
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTippyStarter(ColorScheme scheme) {
    final List<TippyStarterPreset> starters =
        widget.repository.getTippyStarters();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Tippy: What are you working through today?',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: starters
                  .map(
                    (TippyStarterPreset preset) => ActionChip(
                      label: Text(preset.label),
                      onPressed: () => _openStarter(preset),
                      backgroundColor: scheme.primary.withValues(alpha: 0.14),
                      labelStyle: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            if (_searchExpanded) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                style: TextStyle(color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search creator discussions',
                  hintStyle: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.42),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _load(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(ColorScheme scheme) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: kFeedFilters.map((String id) {
          final bool selected = _filter == id;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(kFeedFilterLabels[id] ?? id),
              selected: selected,
              onSelected: (_) {
                setState(() => _filter = id);
                _load();
              },
              selectedColor: scheme.primary.withValues(alpha: 0.22),
              labelStyle: TextStyle(
                color: selected
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildCategoryRail(ColorScheme scheme) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: _categoryId == null,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onSelected: (_) {
                setState(() => _categoryId = null);
                _load();
              },
            ),
          ),
          ...kCanonicalCategoryIds.map((String id) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(kCategoryLabels[id] ?? id),
                selected: _categoryId == id,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) {
                  setState(() => _categoryId = id);
                  _load();
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
class _ModuleSection extends StatelessWidget {
  const _ModuleSection({
    required this.module,
    required this.onOpen,
  });

  final ThreadFeedModuleDto module;
  final ValueChanged<ThreadDto> onOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            module.title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (module.subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              module.subtitle!,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...module.threads.asMap().entries.map(
            (MapEntry<int, ThreadDto> entry) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ThreadCard(
                thread: entry.value,
                tiltIndex: entry.key,
                onTap: () => onOpen(entry.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadCard extends StatefulWidget {
  const _ThreadCard({
    required this.thread,
    required this.onTap,
    required this.tiltIndex,
  });

  final ThreadDto thread;
  final VoidCallback onTap;
  final int tiltIndex;

  @override
  State<_ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends State<_ThreadCard> {
  bool _isHovered = false;

  double get _restAngle {
    switch (widget.tiltIndex % 3) {
      case 0:
        return -0.055; // ~-3.15deg
      case 1:
        return 0.044; // ~2.5deg
      default:
        return -0.035; // ~-2deg
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ThreadDto thread = widget.thread;
    final String category = _threadCardCategoryLabel(thread);
    final String typeLabel = threadTypeLabel(thread.type);
    final String quote = thread.body.trim().isNotEmpty
        ? thread.body.trim()
        : (thread.title.trim().isNotEmpty
            ? thread.title.trim()
            : 'Open thread');
    final bool showTitle = thread.title.trim().isNotEmpty &&
        thread.title.trim() != quote;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateZ(_isHovered ? 0 : _restAngle)
            ..translateByDouble(0, _isHovered ? -6.0 : 0.0, 0, 1),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _Pill(
                          label: category,
                          color: scheme.primary,
                        ),
                        const Spacer(),
                        Text(
                          thread.momentumLabelText,
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.45),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (showTitle) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        thread.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      '“$quote”',
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.78),
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ThreadCardAuthorRow(
                      thread: thread,
                      meta: '$typeLabel · $category',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${thread.replyCount} replies · ${thread.helpfulCount} helpful',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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

class _ThreadCardAuthorRow extends StatelessWidget {
  const _ThreadCardAuthorRow({
    required this.thread,
    this.meta,
  });

  final ThreadDto thread;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String authorId = thread.authorId.trim();
    if (authorId.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<ForumAuthor?>(
      stream: DiscussionAuthorService().watchForumAuthor(authorId),
      builder: (
        BuildContext context,
        AsyncSnapshot<ForumAuthor?> snapshot,
      ) {
        final ForumAuthor? liveAuthor = snapshot.data;
        final String username = _safeUsername(
          liveUsername: liveAuthor?.username,
          fallbackUsername: thread.authorUsername,
          fallbackDisplayName: liveAuthor?.displayName ??
              thread.authorDisplayName,
          authorId: authorId,
        );
        final String? avatarUrl = pickBestAvatarUrl(
          liveAuthor?.avatarUrl,
          thread.authorAvatarUrl,
        );
        return Row(
          children: <Widget>[
            StatusAwareAvatar(
              userId: authorId,
              avatarURL: avatarUrl,
              radius: 21,
              showOnlineIndicator: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (meta != null && meta!.trim().isNotEmpty)
                    Text(
                      meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _safeUsername({
  required String? liveUsername,
  required String? fallbackUsername,
  required String? fallbackDisplayName,
  required String authorId,
}) {
  final String live = (liveUsername ?? '').trim();
  if (_isDisplayableHandle(live, authorId)) {
    return live;
  }
  final String fallback = (fallbackUsername ?? '').trim();
  if (_isDisplayableHandle(fallback, authorId)) {
    return fallback;
  }
  final String display = (fallbackDisplayName ?? '').trim();
  if (_isDisplayableHandle(display, authorId)) {
    return display;
  }
  return 'Creator';
}

bool _isDisplayableHandle(String value, String authorId) {
  if (value.isEmpty) {
    return false;
  }
  if (value == authorId) {
    return false;
  }
  return !_looksLikeOpaqueDocumentId(value);
}

String _threadCardCategoryLabel(ThreadDto thread) {
  final String canonical = normalizeCategoryId(thread.categoryId);
  final String? mapped = kCategoryLabels[canonical];
  if (mapped != null && mapped.isNotEmpty) {
    return mapped;
  }
  final String label = (thread.categoryLabel ?? '').trim();
  if (label.isNotEmpty && !_looksLikeOpaqueDocumentId(label)) {
    return label;
  }
  final String raw = thread.categoryId.trim();
  if (raw.isNotEmpty && !_looksLikeOpaqueDocumentId(raw)) {
    return raw;
  }
  return 'Discussion';
}

bool _looksLikeOpaqueDocumentId(String value) {
  if (value.contains(' ') || value.contains('_') || value.contains('-')) {
    return false;
  }
  return RegExp(r'^[A-Za-z0-9]{18,28}$').hasMatch(value);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.profileViewBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.62),
                  fontSize: 14,
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
