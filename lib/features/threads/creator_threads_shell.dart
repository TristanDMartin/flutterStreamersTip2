import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../core/theme/support_shell_style.dart';
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
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
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
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: _categoryId == null,
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
          ...module.threads.map(
            (ThreadDto thread) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ThreadCard(thread: thread, onTap: () => onOpen(thread)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.onTap,
  });

  final ThreadDto thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _Pill(
                    label: thread.resolvedCategoryLabel,
                    color: scheme.primary,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.local_fire_department_outlined,
                    size: 14,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    thread.momentumLabelText,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.62),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                thread.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                thread.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.62),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${thread.replyCount} replies · '
                '${thread.participantCount} participants · '
                '${thread.helpfulCount} helpful',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
