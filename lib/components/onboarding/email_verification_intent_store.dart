import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'email_verification.dart';

const String kEmailVerificationIntentStorageKey =
    'st_email_verification_intent_v1';

class EmailVerificationIntentStore {
  static Future<void> save(EmailVerificationIntent intent) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kEmailVerificationIntentStorageKey,
      jsonEncode(<String, dynamic>{
        'uid': intent.uid,
        'normalizedEmail': intent.normalizedEmail,
        'onboardingSessionId': intent.onboardingSessionId,
        'origin': intent.origin,
        'createdAt': intent.createdAt.toIso8601String(),
        'expiresAt': intent.expiresAt.toIso8601String(),
        'consumedAt': intent.consumedAt?.toIso8601String(),
      }),
    );
  }

  static Future<EmailVerificationIntent?> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(kEmailVerificationIntentStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      final EmailVerificationIntent intent = EmailVerificationIntent(
        uid: json['uid'] as String? ?? '',
        normalizedEmail: json['normalizedEmail'] as String? ?? '',
        onboardingSessionId: json['onboardingSessionId'] as String?,
        origin: json['origin'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        consumedAt: json['consumedAt'] == null
            ? null
            : DateTime.parse(json['consumedAt'] as String),
      );
      if (isEmailVerificationIntentExpired(intent)) {
        await clear();
        return null;
      }
      return intent;
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(kEmailVerificationIntentStorageKey);
  }
}
