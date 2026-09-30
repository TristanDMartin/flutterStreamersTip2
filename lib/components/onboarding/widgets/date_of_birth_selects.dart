import 'package:flutter/material.dart';

import '../date_of_birth.dart';

class DateOfBirthParts {
  const DateOfBirthParts({this.month, this.day, this.year});

  final int? month;
  final int? day;
  final int? year;

  DateOfBirthValidation? get validation {
    if (month == null || day == null || year == null) {
      return null;
    }
    return validateDateOfBirth(year: year!, month: month!, day: day!);
  }

  DateOfBirthParts copyWith({int? month, int? day, int? year}) {
    final DateOfBirthParts next = DateOfBirthParts(
      month: month ?? this.month,
      day: day ?? this.day,
      year: year ?? this.year,
    );
    final bool dayOverflows = next.month != null &&
        next.day != null &&
        next.day! > daysInDobMonth(month: next.month!, year: next.year ?? 2000);
    return dayOverflows
        ? DateOfBirthParts(month: next.month, year: next.year)
        : next;
  }
}

/// Month / Day / Year dropdowns shared by signup and the birthday step.
class DateOfBirthSelects extends StatelessWidget {
  const DateOfBirthSelects({
    super.key,
    required this.value,
    required this.onChanged,
    this.isEnabled = true,
  });

  final DateOfBirthParts value;
  final ValueChanged<DateOfBirthParts> onChanged;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final int dayCount =
        daysInDobMonth(month: value.month ?? 1, year: value.year ?? 2000);
    return Row(
      children: <Widget>[
        Expanded(
          flex: 4,
          child: _DobDropdown(
            hint: 'Month',
            value: value.month,
            isEnabled: isEnabled,
            items: List<int>.generate(12, (int i) => i + 1),
            labelFor: (int item) => kDobMonthLabels[item - 1].substring(0, 3),
            onChanged: (int? item) => onChanged(value.copyWith(month: item)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _DobDropdown(
            hint: 'Day',
            value: value.day,
            isEnabled: isEnabled,
            items: List<int>.generate(dayCount, (int i) => i + 1),
            labelFor: (int item) => '$item',
            onChanged: (int? item) => onChanged(value.copyWith(day: item)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: _DobDropdown(
            hint: 'Year',
            value: value.year,
            isEnabled: isEnabled,
            items: dobYearOptions(),
            labelFor: (int item) => '$item',
            onChanged: (int? item) => onChanged(value.copyWith(year: item)),
          ),
        ),
      ],
    );
  }
}

class _DobDropdown extends StatelessWidget {
  const _DobDropdown({
    required this.hint,
    required this.value,
    required this.isEnabled,
    required this.items,
    required this.labelFor,
    required this.onChanged,
  });

  final String hint;
  final int? value;
  final bool isEnabled;
  final List<int> items;
  final String Function(int item) labelFor;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    const OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFF475569)),
    );
    return DropdownButtonFormField<int>(
      key: ValueKey<String>('$hint-$value-${items.length}'),
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      dropdownColor: const Color(0xFF1E293B),
      iconEnabledColor: Colors.white70,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      hint: Text(hint, style: const TextStyle(color: Colors.white54)),
      decoration: const InputDecoration(
        filled: true,
        fillColor: Color(0xCC1E293B),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: border,
        enabledBorder: border,
      ),
      items: items
          .map(
            (int item) => DropdownMenuItem<int>(
              value: item,
              child: Text(labelFor(item)),
            ),
          )
          .toList(),
      onChanged: isEnabled ? onChanged : null,
    );
  }
}
