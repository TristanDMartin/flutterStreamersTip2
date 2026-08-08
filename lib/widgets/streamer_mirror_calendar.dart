import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/support_shell_style.dart';
import '../models/calendar_event.dart';

enum StreamerMirrorCalendarMode { month, week }

/// Month/week grid matching website [StreamerMirrorCalendar].
class StreamerMirrorCalendar extends StatefulWidget {
  const StreamerMirrorCalendar({
    super.key,
    required this.events,
    this.onEventTap,
  });

  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent>? onEventTap;

  @override
  State<StreamerMirrorCalendar> createState() =>
      _StreamerMirrorCalendarState();
}

class _StreamerMirrorCalendarState extends State<StreamerMirrorCalendar> {
  static const Color _accent = Color(0xFF9248d2);
  static const List<String> _weekdayLabels = <String>[
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  StreamerMirrorCalendarMode _viewMode = StreamerMirrorCalendarMode.month;
  late DateTime _navDate;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _navDate = DateTime(now.year, now.month, now.day);
    _jumpToNearestEventMonth(allowSetState: false);
  }

  @override
  void didUpdateWidget(covariant StreamerMirrorCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameEventIds(oldWidget.events, widget.events)) {
      _jumpToNearestEventMonth();
    }
  }

  bool _sameEventIds(
    List<CalendarEvent> a,
    List<CalendarEvent> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) {
        return false;
      }
    }
    return true;
  }

  void _jumpToNearestEventMonth({bool allowSetState = true}) {
    if (widget.events.isEmpty) {
      return;
    }
    final DateTime now = DateTime.now();
    final List<CalendarEvent> sorted = List<CalendarEvent>.from(widget.events)
      ..sort(
        (CalendarEvent a, CalendarEvent b) => a.date.compareTo(b.date),
      );
    CalendarEvent target = sorted.first;
    for (final CalendarEvent event in sorted) {
      if (!event.date.isBefore(now)) {
        target = event;
        break;
      }
    }
    final DateTime nextNav = DateTime(
      target.date.year,
      target.date.month,
      target.date.day,
    );
    if (_navDate.year == nextNav.year &&
        _navDate.month == nextNav.month &&
        _navDate.day == nextNav.day) {
      return;
    }
    if (allowSetState && mounted) {
      setState(() => _navDate = nextNav);
    } else {
      _navDate = nextNav;
    }
  }

  String _dateKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Map<String, List<CalendarEvent>> _eventsByDate() {
    final Map<String, List<CalendarEvent>> map =
        <String, List<CalendarEvent>>{};
    for (final CalendarEvent event in widget.events) {
      final String key = _dateKey(event.date);
      map.putIfAbsent(key, () => <CalendarEvent>[]).add(event);
    }
    return map;
  }

  List<DateTime?> _buildDays() {
    if (_viewMode == StreamerMirrorCalendarMode.week) {
      final DateTime start = _navDate.subtract(
        Duration(days: _navDate.weekday % 7),
      );
      return List<DateTime?>.generate(
        7,
        (int i) => DateTime(start.year, start.month, start.day + i),
      );
    }
    final DateTime first = DateTime(_navDate.year, _navDate.month, 1);
    final DateTime last = DateTime(_navDate.year, _navDate.month + 1, 0);
    final List<DateTime?> days = <DateTime?>[];
    for (int i = 0; i < first.weekday % 7; i++) {
      days.add(null);
    }
    for (int day = 1; day <= last.day; day++) {
      days.add(DateTime(_navDate.year, _navDate.month, day));
    }
    return days;
  }

  void _goPrev() {
    setState(() {
      if (_viewMode == StreamerMirrorCalendarMode.month) {
        _navDate = DateTime(_navDate.year, _navDate.month - 1, 1);
      } else {
        _navDate = _navDate.subtract(const Duration(days: 7));
      }
    });
  }

  void _goNext() {
    setState(() {
      if (_viewMode == StreamerMirrorCalendarMode.month) {
        _navDate = DateTime(_navDate.year, _navDate.month + 1, 1);
      } else {
        _navDate = _navDate.add(const Duration(days: 7));
      }
    });
  }

  void _goToday() {
    final DateTime now = DateTime.now();
    setState(() {
      _navDate = DateTime(now.year, now.month, now.day);
    });
  }

  String get _navLabel {
    if (_viewMode == StreamerMirrorCalendarMode.month) {
      return DateFormat('MMMM yyyy').format(_navDate);
    }
    final DateTime start = _navDate.subtract(
      Duration(days: _navDate.weekday % 7),
    );
    return 'Week of ${DateFormat('MMM d, yyyy').format(start)}';
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final DateTime today = DateTime.now();
    final String todayKey = _dateKey(
      DateTime(today.year, today.month, today.day),
    );
    final Map<String, List<CalendarEvent>> byDate = _eventsByDate();
    final List<DateTime?> days = _buildDays();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildToolbar(shell),
          const SizedBox(height: 12),
          Row(
            children: _weekdayLabels
                .map(
                  (String label) => Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: shell.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (BuildContext context, int index) {
              final DateTime? day = days[index];
              if (day == null) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: shell.chipUnselectedBg.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }
              final String key = _dateKey(day);
              final bool isToday = key == todayKey;
              final List<CalendarEvent> dayEvents =
                  byDate[key] ?? const <CalendarEvent>[];
              return _DayCell(
                day: day,
                isToday: isToday,
                events: dayEvents,
                onEventTap: widget.onEventTap,
                shell: shell,
                accent: _accent,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(StSupportShellStyle shell) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _ModeToggle(
          mode: _viewMode,
          onChanged: (StreamerMirrorCalendarMode mode) {
            setState(() => _viewMode = mode);
          },
        ),
        _ToolbarChip(
          label: 'Today',
          onTap: _goToday,
          shell: shell,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _goPrev,
              icon: Icon(Icons.chevron_left, color: shell.muted),
              tooltip: 'Previous',
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120),
              child: Text(
                _navLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: shell.onChrome,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _goNext,
              icon: Icon(Icons.chevron_right, color: shell.muted),
              tooltip: 'Next',
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.onChanged,
  });

  final StreamerMirrorCalendarMode mode;
  final ValueChanged<StreamerMirrorCalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: StreamerMirrorCalendarMode.values.map((
          StreamerMirrorCalendarMode value,
        ) {
          final bool isSelected = value == mode;
          return GestureDetector(
            onTap: () => onChanged(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF9248d2)
                    : shell.chipUnselectedBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                value == StreamerMirrorCalendarMode.month ? 'Month' : 'Week',
                style: TextStyle(
                  color: isSelected ? Colors.white : shell.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.label,
    required this.onTap,
    required this.shell,
  });

  final String label;
  final VoidCallback onTap;
  final StSupportShellStyle shell;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: shell.chipUnselectedBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: shell.mutedStrong,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.events,
    required this.onEventTap,
    required this.shell,
    required this.accent,
  });

  final DateTime day;
  final bool isToday;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent>? onEventTap;
  final StSupportShellStyle shell;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
            : shell.chipUnselectedBg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday ? const Color(0xFF3B82F6) : shell.surfaceCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${day.day}',
            style: TextStyle(
              color: isToday ? const Color(0xFF60A5FA) : shell.mutedStrong,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length.clamp(0, 3),
              itemBuilder: (BuildContext context, int index) {
                final CalendarEvent event = events[index];
                final bool isPast = event.date.isBefore(DateTime.now());
                final Color chipColor = isPast
                    ? shell.muted.withValues(alpha: 0.55)
                    : accent.withValues(alpha: 0.8);
                final Color chipBorder = isPast ? shell.muted : accent;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: GestureDetector(
                    onTap: onEventTap == null
                        ? null
                        : () => onEventTap!(event),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: chipBorder),
                      ),
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPast
                              ? shell.mutedStrong
                              : Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (events.length > 3)
            Text(
              '+${events.length - 3}',
              style: TextStyle(
                color: shell.muted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
