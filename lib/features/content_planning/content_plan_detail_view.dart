import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/support_shell_style.dart';
import 'content_planning_contract.dart';
import 'content_planning_models.dart';
import 'content_planning_provider.dart';
import 'content_planning_repository.dart';

/// Editable plan view backed by `users/{uid}/contentPlans/{id}` or
/// `contentPlans/{id}` (see [FirestoreContentPlanningRepository]).
class ContentPlanDetailView extends ConsumerStatefulWidget {
  const ContentPlanDetailView({
    super.key,
    required this.plan,
  });

  final ContentPlan plan;

  @override
  ConsumerState<ContentPlanDetailView> createState() =>
      _ContentPlanDetailViewState();
}

class _ContentPlanDetailViewState extends ConsumerState<ContentPlanDetailView> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _platform;
  late final TextEditingController _contentType;
  late final TextEditingController _caption;
  late final TextEditingController _hashtags;
  late final TextEditingController _notes;
  late final TextEditingController _checklist;
  late final TextEditingController _draftIdeas;
  late String _status;
  DateTime? _scheduledAt;
  bool _saving = false;
  late List<ContentPlanItem> _items;

  static const List<({String value, String label})> _statusChoices =
      kContentItemStatusChoices;

  static const List<({String value, String label})> _itemStepStatusChoices =
      <({String value, String label})>[
    (value: '', label: 'Unset'),
    ...kContentItemStatusChoices,
  ];

  @override
  void initState() {
    super.initState();
    final ContentPlan plan = widget.plan;
    _title = TextEditingController(text: plan.title);
    _description = TextEditingController(text: plan.description ?? '');
    _platform = TextEditingController(text: plan.platform ?? '');
    _contentType = TextEditingController(text: plan.contentType ?? '');
    _caption = TextEditingController(text: plan.caption ?? '');
    _hashtags = TextEditingController(text: plan.hashtags.join(', '));
    _notes = TextEditingController(text: plan.notes ?? '');
    _checklist = TextEditingController(text: plan.checklist.join('\n'));
    _draftIdeas = TextEditingController(text: plan.draftIdeas.join('\n'));
    _status = normalizeContentItemStatus(plan.status);
    _scheduledAt = plan.scheduledAt;
    _items = List<ContentPlanItem>.from(plan.items);
    _title.addListener(_onPlanSummaryChanged);
    _platform.addListener(_onPlanSummaryChanged);
    _contentType.addListener(_onPlanSummaryChanged);
    _caption.addListener(_onPlanSummaryChanged);
    _checklist.addListener(_onPlanSummaryChanged);
    _draftIdeas.addListener(_onPlanSummaryChanged);
  }

  void _onPlanSummaryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _title.removeListener(_onPlanSummaryChanged);
    _platform.removeListener(_onPlanSummaryChanged);
    _contentType.removeListener(_onPlanSummaryChanged);
    _caption.removeListener(_onPlanSummaryChanged);
    _checklist.removeListener(_onPlanSummaryChanged);
    _draftIdeas.removeListener(_onPlanSummaryChanged);
    _title.dispose();
    _description.dispose();
    _platform.dispose();
    _contentType.dispose();
    _caption.dispose();
    _hashtags.dispose();
    _notes.dispose();
    _checklist.dispose();
    _draftIdeas.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _scheduledAt ?? now.add(const Duration(days: 1));
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
      initialDate: initial,
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _openItemEditor(int index) async {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ContentPlanItem? updated =
        await showModalBottomSheet<ContentPlanItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _EditPlanItemSheet(
            shell: shell,
            scheme: scheme,
            initial: _items[index],
            statusChoices: _itemStepStatusChoices,
          ),
        );
      },
    );
    if (updated != null && mounted) {
      setState(() {
        _items = List<ContentPlanItem>.from(_items)..[index] = updated;
      });
    }
  }

  Future<void> _save() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _saving) {
      return;
    }
    setState(() => _saving = true);
    final ContentPlan updated = ContentPlan(
      id: widget.plan.id,
      title: _title.text.trim().isEmpty ? 'Untitled plan' : _title.text.trim(),
      itemCount: _items.isNotEmpty ? _items.length : widget.plan.itemCount,
      userId: user.uid,
      description: _emptyToNull(_description.text),
      platform: _emptyToNull(_platform.text),
      contentType: _emptyToNull(_contentType.text),
      caption: _emptyToNull(_caption.text),
      hashtags: _splitComma(_hashtags.text),
      status: _status,
      scheduledAt: _scheduledAt,
      createdAt: widget.plan.createdAt,
      updatedAt: widget.plan.updatedAt,
      source: normalizeContentSource(widget.plan.source) ?? 'flutter',
      notes: _emptyToNull(_notes.text),
      checklist: _splitLines(_checklist.text),
      draftIdeas: _splitLines(_draftIdeas.text),
      items: _items,
    );
    try {
      await ref.read(contentPlanningRepositoryProvider).updatePlan(
            userId: user.uid,
            plan: updated,
          );
      ref.invalidate(contentPlansProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Plan updated'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } on ContentPlanningException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _appBarTitle() {
    final String t = _title.text.trim();
    if (t.isEmpty) {
      return widget.plan.title;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    final DateTime? localSchedule = _scheduledAt?.toLocal();
    final String scheduleLabel = localSchedule == null
        ? 'Tap to set date & time'
        : '${l10n.formatMediumDate(localSchedule)} · '
            '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(localSchedule))}';
    final bool hasPlatform = _platform.text.trim().isNotEmpty;
    final bool hasCaption = _caption.text.trim().isNotEmpty;
    final bool hasSchedule = _scheduledAt != null;
    final int checklistCount = _splitLines(_checklist.text).length;
    final int ideaCount = _splitLines(_draftIdeas.text).length;
    final int readyCount = <bool>[hasPlatform, hasCaption, hasSchedule]
        .where((bool value) => value)
        .length;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: shell.pageGradient,
              ),
            ),
            child: const SizedBox.expand(),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                floating: false,
                elevation: 0,
                scrolledUnderElevation: 0.5,
                centerTitle: false,
                backgroundColor: shell.scaffold.withValues(alpha: 0.92),
                surfaceTintColor: Colors.transparent,
                foregroundColor: shell.onChrome,
                iconTheme: IconThemeData(color: shell.onChrome),
                title: Text(
                  _appBarTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    color: shell.onChrome,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                actions: <Widget>[
                  if (_saving)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(<Widget>[
                    _PlanDetailHero(
                      shell: shell,
                      scheme: scheme,
                      title: _appBarTitle(),
                      status: _status,
                      scheduleLabel: scheduleLabel,
                      platform: _platform.text,
                      contentType: _contentType.text,
                      readyCount: readyCount,
                      totalReadinessCount: 3,
                      checklistCount: checklistCount,
                      ideaCount: ideaCount,
                      stepCount: _items.length,
                    ),
                    const SizedBox(height: 14),
                    _PlanReadinessSection(
                      shell: shell,
                      scheme: scheme,
                      hasPlatform: hasPlatform,
                      hasCaption: hasCaption,
                      hasSchedule: hasSchedule,
                    ),
                    const SizedBox(height: 14),
                    _PlanEditSection(
                      shell: shell,
                      scheme: scheme,
                      title: 'Plan setup',
                      subtitle: 'Name, channel, and format',
                      children: <Widget>[
                        _PlanShellField(
                          shell: shell,
                          scheme: scheme,
                          controller: _title,
                          label: 'Title',
                        ),
                        _PlanShellField(
                          shell: shell,
                          scheme: scheme,
                          controller: _description,
                          label: 'Description',
                          maxLines: 3,
                        ),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _PlanShellField(
                                shell: shell,
                                scheme: scheme,
                                controller: _platform,
                                label: 'Platform',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PlanShellField(
                                shell: shell,
                                scheme: scheme,
                                controller: _contentType,
                                label: 'Content type',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _PlanEditSection(
                      shell: shell,
                      scheme: scheme,
                      title: 'Workflow',
                      subtitle: contentItemStatusLabel(_status),
                      children: <Widget>[
                        if (!_statusChoices
                            .any((c) => c.value == _status)) ...<Widget>[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: scheme.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.error.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              'Stored status "$_status" — pick a workflow '
                              'below.',
                              style: TextStyle(
                                color: shell.onChrome,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        _PlanStatusSelector(
                          shell: shell,
                          scheme: scheme,
                          status: _status,
                          choices: _statusChoices,
                          onChanged: (String status) {
                            setState(() => _status = status);
                          },
                        ),
                        const SizedBox(height: 16),
                        _PlanScheduleTile(
                          shell: shell,
                          scheme: scheme,
                          scheduleLabel: scheduleLabel,
                          hasSchedule: hasSchedule,
                          onTap: _pickSchedule,
                          onClear: hasSchedule
                              ? () {
                                  setState(() => _scheduledAt = null);
                                }
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _PlanEditSection(
                      shell: shell,
                      scheme: scheme,
                      title: 'Post copy',
                      subtitle: hasCaption ? 'Caption ready' : 'Caption needed',
                      children: <Widget>[
                        _PlanShellField(
                          shell: shell,
                          scheme: scheme,
                          controller: _caption,
                          label: 'Caption',
                          maxLines: 4,
                        ),
                        _PlanShellField(
                          shell: shell,
                          scheme: scheme,
                          controller: _hashtags,
                          label: 'Hashtags',
                          hint: 'streaming, clips, growth',
                        ),
                        _PlanShellField(
                          shell: shell,
                          scheme: scheme,
                          controller: _notes,
                          label: 'Notes',
                          maxLines: 4,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _PlanEditSection(
                      shell: shell,
                      scheme: scheme,
                      title: 'Prep list',
                      subtitle: '$checklistCount checklist · $ideaCount ideas',
                      children: <Widget>[
                        _PlanShellField(
                          shell: shell,
                          scheme: scheme,
                          controller: _checklist,
                          label: 'Checklist',
                          maxLines: 5,
                        ),
                        _PlanShellField(
                          shell: shell,
                          scheme: scheme,
                          controller: _draftIdeas,
                          label: 'Draft ideas',
                          maxLines: 5,
                        ),
                      ],
                    ),
                    if (_items.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      _PlanEditSection(
                        shell: shell,
                        scheme: scheme,
                        title: 'Plan steps',
                        subtitle: '${_items.length} items · tap a step to edit',
                        children: <Widget>[
                          for (int i = 0; i < _items.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PlanItemTile(
                                shell: shell,
                                scheme: scheme,
                                item: _items[i],
                                onTap: () => _openItemEditor(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                    SizedBox(height: 32 + bottomInset),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Material(
        color: shell.scaffold.withValues(alpha: 0.96),
        elevation: 8,
        shadowColor: shell.shadowSoft,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Icon(Icons.save_rounded, color: scheme.onPrimary),
              label: Text(
                _saving ? 'Saving…' : 'Save changes',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanEditSection extends StatelessWidget {
  const _PlanEditSection({
    required this.shell,
    required this.scheme,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final StSupportShellStyle shell;
  final ColorScheme scheme;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: shell.surfaceCardBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shell.shadowSoft,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      scheme.primary,
                      scheme.secondary,
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _PlanDetailHero extends StatelessWidget {
  const _PlanDetailHero({
    required this.shell,
    required this.scheme,
    required this.title,
    required this.status,
    required this.scheduleLabel,
    required this.platform,
    required this.contentType,
    required this.readyCount,
    required this.totalReadinessCount,
    required this.checklistCount,
    required this.ideaCount,
    required this.stepCount,
  });

  final StSupportShellStyle shell;
  final ColorScheme scheme;
  final String title;
  final String status;
  final String scheduleLabel;
  final String platform;
  final String contentType;
  final int readyCount;
  final int totalReadinessCount;
  final int checklistCount;
  final int ideaCount;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final double progress = totalReadinessCount == 0
        ? 0
        : (readyCount / totalReadinessCount).clamp(0.0, 1.0);
    final String destination = <String>[
      if (platform.trim().isNotEmpty) platform.trim(),
      if (contentType.trim().isNotEmpty) contentType.trim(),
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: shell.surfaceCardBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shell.shadowSoft,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: <Color>[scheme.primary, scheme.secondary],
                  ),
                ),
                child: Icon(
                  Icons.view_agenda_rounded,
                  color: scheme.onPrimary,
                  size: 23,
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
                        fontSize: 21,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      destination.isEmpty
                          ? contentItemStatusLabel(status)
                          : destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: shell.muted.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _PlanHeroStat(
                  shell: shell,
                  label: 'Ready',
                  value: '$readyCount/$totalReadinessCount',
                ),
              ),
              Expanded(
                child: _PlanHeroStat(
                  shell: shell,
                  label: 'Status',
                  value: contentItemStatusLabel(status),
                ),
              ),
              Expanded(
                child: _PlanHeroStat(
                  shell: shell,
                  label: 'Steps',
                  value: stepCount == 0 ? '$checklistCount' : '$stepCount',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(Icons.event_rounded, color: shell.iconDim, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  scheduleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: shell.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (ideaCount > 0)
                Text(
                  '$ideaCount ideas',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanHeroStat extends StatelessWidget {
  const _PlanHeroStat({
    required this.shell,
    required this.label,
    required this.value,
  });

  final StSupportShellStyle shell;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: shell.onChrome,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: shell.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PlanReadinessSection extends StatelessWidget {
  const _PlanReadinessSection({
    required this.shell,
    required this.scheme,
    required this.hasPlatform,
    required this.hasCaption,
    required this.hasSchedule,
  });

  final StSupportShellStyle shell;
  final ColorScheme scheme;
  final bool hasPlatform;
  final bool hasCaption;
  final bool hasSchedule;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _PlanReadinessTile(
            shell: shell,
            scheme: scheme,
            icon: Icons.public_rounded,
            label: 'Platform',
            complete: hasPlatform,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PlanReadinessTile(
            shell: shell,
            scheme: scheme,
            icon: Icons.notes_rounded,
            label: 'Caption',
            complete: hasCaption,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PlanReadinessTile(
            shell: shell,
            scheme: scheme,
            icon: Icons.schedule_rounded,
            label: 'Time',
            complete: hasSchedule,
          ),
        ),
      ],
    );
  }
}

class _PlanReadinessTile extends StatelessWidget {
  const _PlanReadinessTile({
    required this.shell,
    required this.scheme,
    required this.icon,
    required this.label,
    required this.complete,
  });

  final StSupportShellStyle shell;
  final ColorScheme scheme;
  final IconData icon;
  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final Color color = complete ? const Color(0xFF22C55E) : scheme.error;
    return Container(
      height: 82,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            complete ? 'Set' : 'Missing',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanStatusSelector extends StatelessWidget {
  const _PlanStatusSelector({
    required this.shell,
    required this.scheme,
    required this.status,
    required this.choices,
    required this.onChanged,
  });

  final StSupportShellStyle shell;
  final ColorScheme scheme;
  final String status;
  final List<({String value, String label})> choices;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final ({String value, String label}) choice in choices)
          ChoiceChip(
            label: Text(choice.label),
            selected: status == choice.value,
            onSelected: (_) => onChanged(choice.value),
            selectedColor: scheme.primary.withValues(alpha: 0.22),
            backgroundColor: shell.chipUnselectedBg,
            labelStyle: TextStyle(
              color: status == choice.value
                  ? scheme.primary
                  : shell.chipUnselectedFg,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            side: BorderSide(
              color: status == choice.value
                  ? scheme.primary.withValues(alpha: 0.45)
                  : shell.chipUnselectedBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
      ],
    );
  }
}

class _PlanScheduleTile extends StatelessWidget {
  const _PlanScheduleTile({
    required this.shell,
    required this.scheme,
    required this.scheduleLabel,
    required this.hasSchedule,
    required this.onTap,
    this.onClear,
  });

  final StSupportShellStyle shell;
  final ColorScheme scheme;
  final String scheduleLabel;
  final bool hasSchedule;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: shell.chipUnselectedBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: shell.surfaceCardBorder),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: <Color>[scheme.primary, scheme.secondary],
                  ),
                ),
                child: Icon(
                  Icons.event_rounded,
                  color: scheme.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      hasSchedule ? 'Publish window' : 'Schedule',
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scheduleLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear schedule',
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, color: shell.iconDim),
                )
              else
                Icon(Icons.chevron_right_rounded, color: shell.iconDim),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanShellField extends StatelessWidget {
  const _PlanShellField({
    required this.shell,
    required this.scheme,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  final StSupportShellStyle shell;
  final ColorScheme scheme;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          color: shell.onChrome,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: shell.chipUnselectedBg,
          labelStyle: TextStyle(
            color: shell.muted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          hintStyle: TextStyle(
            color: shell.iconDim,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: shell.chipUnselectedBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: shell.chipUnselectedBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: scheme.primary.withValues(alpha: 0.65),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _PlanItemTile extends StatelessWidget {
  const _PlanItemTile({
    required this.shell,
    required this.scheme,
    required this.item,
    required this.onTap,
  });

  final StSupportShellStyle shell;
  final ColorScheme scheme;
  final ContentPlanItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String secondary =
        item.caption ?? item.description ?? item.notes ?? item.platformsSummary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: shell.chipUnselectedBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: shell.surfaceCardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.view_timeline_rounded,
                color: scheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: TextStyle(
                        color: shell.onChrome,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.status != null &&
                        item.status!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        item.status!,
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                    if (item.type != null && item.type!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        item.type!,
                        style: TextStyle(
                          color: shell.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (secondary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        secondary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: shell.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                color: shell.iconDim,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditPlanItemSheet extends StatefulWidget {
  const _EditPlanItemSheet({
    required this.shell,
    required this.scheme,
    required this.initial,
    required this.statusChoices,
  });

  final StSupportShellStyle shell;
  final ColorScheme scheme;
  final ContentPlanItem initial;
  final List<({String value, String label})> statusChoices;

  @override
  State<_EditPlanItemSheet> createState() => _EditPlanItemSheetState();
}

class _EditPlanItemSheetState extends State<_EditPlanItemSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _caption;
  late final TextEditingController _type;
  late final TextEditingController _notes;
  late final TextEditingController _tags;
  late String _stepStatus;

  @override
  void initState() {
    super.initState();
    final ContentPlanItem i = widget.initial;
    _title = TextEditingController(text: i.title);
    _description = TextEditingController(text: i.description ?? '');
    _caption = TextEditingController(text: i.caption ?? '');
    _type = TextEditingController(text: i.type ?? '');
    _notes = TextEditingController(text: i.notes ?? '');
    _tags = TextEditingController(text: i.tags.join(', '));
    _stepStatus = i.status ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _caption.dispose();
    _type.dispose();
    _notes.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _submit() {
    final String titleTrim = _title.text.trim();
    final ContentPlanItem next = ContentPlanItem(
      id: widget.initial.id,
      title: titleTrim.isEmpty ? 'Untitled step' : titleTrim,
      description: _emptyToNull(_description.text),
      caption: _emptyToNull(_caption.text),
      type: _emptyToNull(_type.text),
      status: _stepStatus.isEmpty ? null : _stepStatus,
      notes: _emptyToNull(_notes.text),
      tags: _splitComma(_tags.text),
      platforms: widget.initial.platforms,
    );
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = widget.shell;
    final ColorScheme scheme = widget.scheme;
    final double maxH = MediaQuery.sizeOf(context).height * 0.9;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: shell.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: shell.surfaceCardBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shell.shadowSoft,
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: shell.onChrome.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Edit step',
                        style: TextStyle(
                          color: shell.onChrome,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: shell.onChrome),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _PlanShellField(
                        shell: shell,
                        scheme: scheme,
                        controller: _title,
                        label: 'Title',
                      ),
                      _PlanShellField(
                        shell: shell,
                        scheme: scheme,
                        controller: _description,
                        label: 'Description',
                        maxLines: 3,
                      ),
                      _PlanShellField(
                        shell: shell,
                        scheme: scheme,
                        controller: _caption,
                        label: 'Caption',
                        maxLines: 3,
                      ),
                      _PlanShellField(
                        shell: shell,
                        scheme: scheme,
                        controller: _type,
                        label: 'Content type',
                      ),
                      _PlanShellField(
                        shell: shell,
                        scheme: scheme,
                        controller: _notes,
                        label: 'Notes',
                        maxLines: 3,
                      ),
                      _PlanShellField(
                        shell: shell,
                        scheme: scheme,
                        controller: _tags,
                        label: 'Tags',
                        hint: 'comma separated',
                      ),
                      Text(
                        'Step status',
                        style: TextStyle(
                          color: shell.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final ({String value, String label}) choice
                              in widget.statusChoices)
                            ChoiceChip(
                              label: Text(choice.label),
                              selected: _stepStatus == choice.value,
                              onSelected: (_) {
                                setState(() => _stepStatus = choice.value);
                              },
                              selectedColor:
                                  scheme.primary.withValues(alpha: 0.22),
                              backgroundColor: shell.chipUnselectedBg,
                              labelStyle: TextStyle(
                                color: _stepStatus == choice.value
                                    ? scheme.primary
                                    : shell.chipUnselectedFg,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              side: BorderSide(
                                color: _stepStatus == choice.value
                                    ? scheme.primary.withValues(alpha: 0.45)
                                    : shell.chipUnselectedBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                        ],
                      ),
                      if (widget
                          .initial.platformsSummary.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        Text(
                          'Platforms (read-only)',
                          style: TextStyle(
                            color: shell.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.initial.platformsSummary,
                          style: TextStyle(
                            color: shell.onChrome.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side:
                                    BorderSide(color: shell.surfaceCardBorder),
                                foregroundColor: shell.onChrome,
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: _submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: const Text(
                                'Apply',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
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

String? _emptyToNull(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _splitComma(String value) {
  return value
      .split(',')
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
}

List<String> _splitLines(String value) {
  return value
      .split('\n')
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
}
