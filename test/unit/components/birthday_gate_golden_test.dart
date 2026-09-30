import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamers_tip/components/onboarding/account_navigation.dart';
import 'package:streamers_tip/components/onboarding/date_of_birth.dart';
import 'package:streamers_tip/components/onboarding/widgets/date_of_birth_selects.dart';

Map<String, dynamic>? _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

void main() {
  final Map<String, dynamic> golden = jsonDecode(
    File('test/fixtures/birthday-gate.golden.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final DateTime now = DateTime.parse(golden['now'] as String);

  group('birthday gate golden vectors', () {
    for (final dynamic raw in golden['gateVectors'] as List<dynamic>) {
      final Map<String, dynamic> vector = raw as Map<String, dynamic>;
      test(vector['id'] as String, () {
        final Map<String, dynamic> input = _asMap(vector['input'])!;
        final Map<String, dynamic> expected = _asMap(vector['expected'])!;
        final BirthdayGate actual = resolveBirthdayGate(
          userData: _asMap(input['userData']),
          pending: _asMap(input['pending']),
          emailVerified: input['emailVerified'] == true,
          isPasswordProvider: input['isPasswordProvider'] == true,
        );
        expect(actual.required, expected['required']);
        expect(actual.locked, expected['locked']);
        expect(actual.dateOfBirth, expected['dateOfBirth']);
      });
    }
    for (final dynamic raw in golden['eligibilityVectors'] as List<dynamic>) {
      final Map<String, dynamic> vector = raw as Map<String, dynamic>;
      test('eligibility ${vector['id']}', () {
        final Map<String, dynamic> expected = _asMap(vector['expected'])!;
        final AgeEligibility actual = resolveAgeEligibility(
          _asMap(vector['input'])!['dateOfBirth'],
          now: now,
        );
        expect(actual.hasDateOfBirth, expected['hasDateOfBirth']);
        expect(actual.meetsMinimumAge, expected['meetsMinimumAge']);
        expect(actual.isAdult, expected['isAdult']);
      });
    }
  });

  group('validateDateOfBirth', () {
    test('rejects impossible calendar dates', () {
      final DateOfBirthValidation actual =
          validateDateOfBirth(year: 2000, month: 2, day: 30, now: now);
      expect(actual.canSubmit, isFalse);
    });

    test('lets under-age answers submit so the server can lock', () {
      final DateOfBirthValidation actual =
          validateDateOfBirth(year: 2015, month: 1, day: 1, now: now);
      expect(actual.issue, DateOfBirthIssue.underMinimumAge);
      expect(actual.canSubmit, isTrue);
    });

    test('accepts an adult date', () {
      final DateOfBirthValidation actual =
          validateDateOfBirth(year: 2000, month: 6, day: 15, now: now);
      expect(actual.issue, isNull);
      expect(actual.isoDate, '2000-06-15');
    });
  });

  group('birthday navigation', () {
    test('birthday gate routes ahead of the app', () {
      final AccountNavigation actual = navigationFromAccountStatus(
        activationState: 'ACTIVATED',
        allowApp: true,
        birthdayRequired: true,
      );
      expect(actual.route, 'birthday');
    });

    test('BIRTHDAY_REQUIRED state routes to birthday', () {
      final AccountNavigation actual = navigationFromAccountStatus(
        activationState: 'BIRTHDAY_REQUIRED',
        tippyStageHint: 'birthday',
      );
      expect(actual.route, 'birthday');
    });
  });

  group('DateOfBirthParts', () {
    test('clears a day that no longer fits the chosen month', () {
      const DateOfBirthParts input =
          DateOfBirthParts(month: 1, day: 31, year: 2001);
      final DateOfBirthParts actual = input.copyWith(month: 2);
      expect(actual.day, isNull);
      expect(actual.month, 2);
    });

    test('is incomplete until month, day and year are set', () {
      expect(const DateOfBirthParts(month: 1, day: 1).validation, isNull);
    });
  });
}
