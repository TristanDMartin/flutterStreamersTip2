/// Mirrors web `lib/signupSecurity/dateOfBirth.ts` + `lib/account/birthdayGate.ts`.
/// Golden vectors: `contracts/birthday-gate.golden.json`.
library;

const int kMinimumSignupAge = 13;
const int kAdultAge = 18;
const int kMaxReasonableAge = 120;
const int kDobYearOptionCount = 101;
const String kAgeGateUnderMinimumAge = 'under_minimum_age';

const List<String> kDobMonthLabels = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

int daysInDobMonth({required int month, required int year}) {
  if (month < 1 || month > 12) {
    return 31;
  }
  return DateTime.utc(year > 0 ? year : 2000, month + 1, 0).day;
}

/// Starts at the current year so the picker does not reveal the age cutoff.
List<int> dobYearOptions({DateTime? now}) {
  final int newest = (now ?? DateTime.now()).year;
  return List<int>.generate(kDobYearOptionCount, (int i) => newest - i);
}

int calculateAge(DateTime birth, DateTime now) {
  final bool hadBirthday = now.month > birth.month ||
      (now.month == birth.month && now.day >= birth.day);
  return now.year - birth.year - (hadBirthday ? 0 : 1);
}

enum DateOfBirthIssue { invalidDate, futureDate, unreasonableAge, underMinimumAge }

class DateOfBirthValidation {
  const DateOfBirthValidation({this.isoDate, this.issue});

  final String? isoDate;
  final DateOfBirthIssue? issue;

  /// Calendar-valid date; under-age answers still submit so the server locks.
  bool get canSubmit =>
      isoDate != null &&
      (issue == null || issue == DateOfBirthIssue.underMinimumAge);
}

String _pad2(int value) => value.toString().padLeft(2, '0');

DateOfBirthValidation validateDateOfBirth({
  required int year,
  required int month,
  required int day,
  DateTime? now,
}) {
  final DateTime today = now ?? DateTime.now();
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > daysInDobMonth(month: month, year: year)) {
    return const DateOfBirthValidation(issue: DateOfBirthIssue.invalidDate);
  }
  final DateTime birth = DateTime.utc(year, month, day);
  final String iso = '$year-${_pad2(month)}-${_pad2(day)}';
  if (birth.isAfter(DateTime.utc(today.year, today.month, today.day))) {
    return DateOfBirthValidation(isoDate: iso, issue: DateOfBirthIssue.futureDate);
  }
  final int age = calculateAge(birth, today);
  if (age > kMaxReasonableAge) {
    return DateOfBirthValidation(
      isoDate: iso,
      issue: DateOfBirthIssue.unreasonableAge,
    );
  }
  if (age < kMinimumSignupAge) {
    return DateOfBirthValidation(
      isoDate: iso,
      issue: DateOfBirthIssue.underMinimumAge,
    );
  }
  return DateOfBirthValidation(isoDate: iso);
}

final RegExp _storedDobPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

String? readStoredDateOfBirth(Object? value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  final RegExpMatch? match = _storedDobPattern.firstMatch(trimmed);
  if (match == null) {
    return null;
  }
  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int day = int.parse(match.group(3)!);
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > daysInDobMonth(month: month, year: year)) {
    return null;
  }
  return trimmed;
}

class AgeEligibility {
  const AgeEligibility({
    required this.hasDateOfBirth,
    required this.meetsMinimumAge,
    required this.isAdult,
  });

  final bool hasDateOfBirth;
  final bool meetsMinimumAge;
  final bool isAdult;
}

AgeEligibility resolveAgeEligibility(Object? storedDateOfBirth, {DateTime? now}) {
  final String? iso = readStoredDateOfBirth(storedDateOfBirth);
  if (iso == null) {
    return const AgeEligibility(
      hasDateOfBirth: false,
      meetsMinimumAge: false,
      isAdult: false,
    );
  }
  final int age =
      calculateAge(DateTime.parse('${iso}T00:00:00Z'), now ?? DateTime.now());
  return AgeEligibility(
    hasDateOfBirth: true,
    meetsMinimumAge: age >= kMinimumSignupAge,
    isAdult: age >= kAdultAge,
  );
}

class BirthdayGate {
  const BirthdayGate({
    required this.required,
    required this.locked,
    this.dateOfBirth,
  });

  final bool required;
  final bool locked;
  final String? dateOfBirth;
}

String? _ageGateStatus(Map<String, dynamic>? record) {
  final Object? gate = record?['ageGate'];
  if (gate is! Map) {
    return null;
  }
  final Object? status = gate['status'];
  return status is String ? status : null;
}

/// Server decides via `/api/account/status`; kept for golden parity.
BirthdayGate resolveBirthdayGate({
  Map<String, dynamic>? userData,
  Map<String, dynamic>? pending,
  required bool emailVerified,
  required bool isPasswordProvider,
}) {
  if (_ageGateStatus(userData) == kAgeGateUnderMinimumAge ||
      _ageGateStatus(pending) == kAgeGateUnderMinimumAge) {
    return const BirthdayGate(required: true, locked: true);
  }
  final String? dob = readStoredDateOfBirth(userData?['dateOfBirth']) ??
      readStoredDateOfBirth(pending?['dateOfBirth']);
  if (dob != null) {
    return BirthdayGate(required: false, locked: false, dateOfBirth: dob);
  }
  if (isPasswordProvider && !emailVerified) {
    return const BirthdayGate(required: false, locked: false);
  }
  return const BirthdayGate(required: true, locked: false);
}
