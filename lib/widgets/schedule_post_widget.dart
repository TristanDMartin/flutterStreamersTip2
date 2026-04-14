import 'package:flutter/material.dart';
import '../models/scheduled_post.dart';

class SchedulePostWidget extends StatefulWidget {
  final List<PlatformKey> selectedPlatforms;
  final String caption;
  final List<PostMedia> media;
  final Function(PostSchedule?) onScheduleChanged;
  final PostSchedule? initialSchedule;

  const SchedulePostWidget({
    super.key,
    required this.selectedPlatforms,
    required this.caption,
    required this.media,
    required this.onScheduleChanged,
    this.initialSchedule,
  });

  @override
  State<SchedulePostWidget> createState() => _SchedulePostWidgetState();
}

class _SchedulePostWidgetState extends State<SchedulePostWidget> {
  bool _isScheduled = false;
  DateTime _selectedDateTime = DateTime.now().add(const Duration(minutes: 30));
  TimezoneInfo _selectedTimezone = TimezoneInfo.commonTimezones.first;
  bool _showAdvanced = false;
  Map<String, DateTime> _platformOverrides = {};
  bool _suggestBestTime = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSchedule != null) {
      _isScheduled = true;
      _selectedDateTime = widget.initialSchedule!.scheduledAtUtc;
      _selectedTimezone = TimezoneInfo.commonTimezones.firstWhere(
        (tz) => tz.name == widget.initialSchedule!.timezone,
        orElse: () => TimezoneInfo.commonTimezones.first,
      );
      _platformOverrides = widget.initialSchedule!.perPlatform.map(
        (key, value) => MapEntry(key, value.scheduledAtUtc),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeUntilPublish = _isScheduled
        ? _selectedDateTime.difference(DateTime.now())
        : Duration.zero;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.11),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9248D2).withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (_isScheduled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildScheduleHero(timeUntilPublish),
            ),
            _buildDateTimePicker(),
            const SizedBox(height: 12),
            _buildTimezoneSelector(),
            const SizedBox(height: 12),
            _buildBestTimeSuggestion(),
            const SizedBox(height: 12),
            _buildAdvancedSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF9248D2).withValues(alpha: 0.18),
              border: Border.all(
                color: const Color(0xFF9248D2).withValues(alpha: 0.32),
              ),
            ),
            child: const Icon(
              Icons.schedule,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Schedule Post',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isScheduled
                      ? 'Publishing across ${widget.selectedPlatforms.length} platform${widget.selectedPlatforms.length == 1 ? '' : 's'}'
                      : 'Turn this on to publish later instead of right away',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isScheduled,
            onChanged: (value) {
              setState(() {
                _isScheduled = value;
                if (!value) {
                  _platformOverrides.clear();
                  _showAdvanced = false;
                }
              });
              _updateSchedule();
            },
            activeColor: const Color(0xFF9248D2),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleHero(Duration timeUntilPublish) {
    final isSoon = timeUntilPublish.inMinutes >= 0 && timeUntilPublish.inHours < 24;
    final summaryText = _formatScheduleSummary();
    final helperText = widget.selectedPlatforms.isEmpty
        ? 'Choose at least one platform to make scheduling actionable.'
        : isSoon
            ? 'Your post is lined up soon. You can fine-tune each platform below.'
            : 'Keep the cadence steady and let StreamersTip handle the timing.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9248D2).withValues(alpha: 0.24),
            const Color(0xFF2F8FFF).withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSummaryChip(Icons.schedule_send, summaryText),
              _buildSummaryChip(
                Icons.public,
                _selectedTimezone.displayName,
              ),
              if (widget.selectedPlatforms.isNotEmpty)
                _buildSummaryChip(
                  Icons.apps_rounded,
                  '${widget.selectedPlatforms.length} destination${widget.selectedPlatforms.length == 1 ? '' : 's'}',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            helperText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schedule Date & Time',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _selectDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDateTime(_selectedDateTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimezoneSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timezone',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _selectTimezone,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.language,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedTimezone.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestTimeSuggestion() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _suggestBestTime,
              onChanged: widget.selectedPlatforms.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _suggestBestTime = value ?? false;
                        if (_suggestBestTime) {
                          _applyBestTimeSuggestion();
                        }
                      });
                    },
              activeColor: const Color(0xFF9248D2),
              checkColor: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suggest best time',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.selectedPlatforms.isEmpty
                        ? 'Select a destination platform first.'
                        : 'Use an analytics-style default slot to get started faster.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showAdvanced = !_showAdvanced;
              });
            },
            child: Row(
              children: [
                const Text(
                  'Advanced',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _showAdvanced ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 12),
            _buildPlatformOverrides(),
          ],
        ],
      ),
    );
  }

  Widget _buildPlatformOverrides() {
    if (widget.selectedPlatforms.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Add a platform above to unlock per-platform scheduling.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontSize: 12.5,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Per-platform scheduling',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        ...widget.selectedPlatforms
            .map((platform) => _buildPlatformOverride(platform)),
      ],
    );
  }

  Widget _buildPlatformOverride(PlatformKey platform) {
    final platformName = _getPlatformName(platform);
    final overrideTime = _platformOverrides[platform.name];
    final isOverride = overrideTime != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Checkbox(
              value: isOverride,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _platformOverrides[platform.name] = _selectedDateTime;
                  } else {
                    _platformOverrides.remove(platform.name);
                  }
                });
                _updateSchedule();
              },
              activeColor: const Color(0xFF9248D2),
              checkColor: Colors.white,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            platformName,
            style: TextStyle(
              color: isOverride ? Colors.white : Colors.white70,
              fontSize: 12.5,
              fontWeight: isOverride ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (isOverride) ...[
            const Spacer(),
            GestureDetector(
              onTap: () => _selectPlatformDateTime(platform),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatDateTime(overrideTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  String _getPlatformName(PlatformKey platform) {
    switch (platform) {
      case PlatformKey.youtube:
        return 'YouTube';
      case PlatformKey.tiktok:
        return 'TikTok';
      case PlatformKey.instagram:
        return 'Instagram';
      case PlatformKey.x:
        return 'X (Twitter)';
      case PlatformKey.facebook:
        return 'Facebook';
      case PlatformKey.linkedin:
        return 'LinkedIn';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (targetDate == today) {
      dateStr = 'Today';
    } else if (targetDate == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }

    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr at $timeStr';
  }

  String _formatScheduleSummary() {
    final difference = _selectedDateTime.difference(DateTime.now());
    if (difference.inMinutes < 0) return 'Schedule needs updating';
    if (difference.inMinutes < 60) {
      return 'In ${difference.inMinutes} min';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes.remainder(60);
      if (minutes == 0) return 'In $hours hr';
      return 'In ${hours}h ${minutes}m';
    }
    if (difference.inDays < 7) {
      return 'In ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    }
    return _formatDateTime(_selectedDateTime);
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final minTime = now.add(const Duration(minutes: 5));

    final date = await showDatePicker(
      context: context,
      initialDate:
          _selectedDateTime.isBefore(minTime) ? minTime : _selectedDateTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9248D2),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF9248D2),
                onPrimary: Colors.white,
                surface: Color(0xFF1A1A1A),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        final selected = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        setState(() {
          _selectedDateTime = _normalizeMinimumTime(selected);
        });
        _updateSchedule();
      }
    }
  }

  Future<void> _selectTimezone() async {
    final selected = await showModalBottomSheet<TimezoneInfo>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Timezone',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...TimezoneInfo.commonTimezones.map((tz) => ListTile(
                  title: Text(
                    tz.displayName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    tz.name,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: _selectedTimezone.name == tz.name
                      ? const Icon(Icons.check, color: Color(0xFF9248D2))
                      : null,
                  onTap: () => Navigator.pop(context, tz),
                )),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedTimezone = selected;
      });
      _updateSchedule();
    }
  }

  Future<void> _selectPlatformDateTime(PlatformKey platform) async {
    final currentTime = _platformOverrides[platform.name] ?? _selectedDateTime;

    final date = await showDatePicker(
      context: context,
      initialDate: currentTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9248D2),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(currentTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF9248D2),
                onPrimary: Colors.white,
                surface: Color(0xFF1A1A1A),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _platformOverrides[platform.name] = _normalizeMinimumTime(
            DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            ),
          );
        });
        _updateSchedule();
      }
    }
  }

  void _applyBestTimeSuggestion() {
    // Simulate analytics-based best time suggestion
    final now = DateTime.now();
    final bestTime = DateTime(
      now.year,
      now.month,
      now.day + 1,
      14, // 2 PM
      0,
    );

    setState(() {
      _selectedDateTime = _normalizeMinimumTime(bestTime);
    });
    _updateSchedule();
  }

  DateTime _normalizeMinimumTime(DateTime value) {
    final minimum = DateTime.now().add(const Duration(minutes: 5));
    if (value.isBefore(minimum)) {
      return minimum;
    }
    return value;
  }

  void _updateSchedule() {
    if (!_isScheduled) {
      widget.onScheduleChanged(null);
      return;
    }

    final scheduledAt = _normalizeMinimumTime(_selectedDateTime);
    if (scheduledAt != _selectedDateTime) {
      _selectedDateTime = scheduledAt;
    }

    final schedule = PostSchedule(
      scheduledAtUtc: scheduledAt.toUtc(),
      timezone: _selectedTimezone.name,
      perPlatform: _platformOverrides.map(
        (key, value) => MapEntry(
          key,
          PlatformSchedule(
            scheduledAtUtc: _normalizeMinimumTime(value).toUtc(),
            timezone: _selectedTimezone.name,
          ),
        ),
      ),
      createdAtUtc: DateTime.now().toUtc(),
      updatedAtUtc: DateTime.now().toUtc(),
    );

    widget.onScheduleChanged(schedule);
  }
}
