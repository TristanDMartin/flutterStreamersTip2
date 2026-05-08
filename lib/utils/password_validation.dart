/// Password rules aligned with web `utils/passwordValidation.ts` (AUTH_PARITY),
/// minus simple-sequence blocking (product choice).
class PasswordRequirements {
  PasswordRequirements._();

  static const int minLength = 8;

  static final RegExp _specialChar = RegExp(
    r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]''',
  );

  static bool hasMinLength(String p) => p.length >= minLength;

  static bool hasUpperCase(String p) => RegExp(r'[A-Z]').hasMatch(p);

  static bool hasLowerCase(String p) => RegExp(r'[a-z]').hasMatch(p);

  static bool hasNumber(String p) => RegExp(r'[0-9]').hasMatch(p);

  static bool hasSpecialChar(String p) => _specialChar.hasMatch(p);

  static bool isValid(String p) =>
      hasMinLength(p) &&
      hasUpperCase(p) &&
      hasLowerCase(p) &&
      hasNumber(p) &&
      hasSpecialChar(p);

  static const List<String> weakSubstrings = <String>[
    'password',
    'password123',
    '12345678',
    'qwerty',
    'abc123',
    'letmein',
    'welcome',
    'monkey',
    '1234567890',
    'admin',
  ];

  static bool containsWeakSubstring(String p) {
    final String lower = p.toLowerCase();
    for (final String w in weakSubstrings) {
      if (lower.contains(w)) {
        return true;
      }
    }
    return false;
  }

  static bool hasTripleRepeatedCharacter(String p) {
    for (int i = 0; i < p.length - 2; i++) {
      if (p[i] == p[i + 1] && p[i + 1] == p[i + 2]) {
        return true;
      }
    }
    return false;
  }

  static Map<String, bool> checklist(String password) {
    return <String, bool>{
      'length': hasMinLength(password),
      'uppercase': hasUpperCase(password),
      'lowercase': hasLowerCase(password),
      'number': hasNumber(password),
      'special': hasSpecialChar(password),
      'notWeak': !containsWeakSubstring(password),
      'notTripleRepeat': !hasTripleRepeatedCharacter(password),
    };
  }

  static bool meetsSignupPolicy(String p) =>
      isValid(p) && !containsWeakSubstring(p) && !hasTripleRepeatedCharacter(p);

  static String? signupRejectReason(String p) {
    if (!hasMinLength(p)) {
      return 'Password must be at least $minLength characters.';
    }
    if (!hasUpperCase(p)) {
      return 'Include at least one uppercase letter.';
    }
    if (!hasLowerCase(p)) {
      return 'Include at least one lowercase letter.';
    }
    if (!hasNumber(p)) {
      return 'Include at least one number.';
    }
    if (!hasSpecialChar(p)) {
      return 'Include at least one special character.';
    }
    if (containsWeakSubstring(p)) {
      return 'Password contains a common phrase. Choose something stronger.';
    }
    if (hasTripleRepeatedCharacter(p)) {
      return 'Avoid repeated characters like aaa.';
    }
    return null;
  }
}
