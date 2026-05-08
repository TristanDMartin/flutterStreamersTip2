/// Login identifier: email regex vs username (web LoginModal parity).
class AuthLoginInput {
  AuthLoginInput._();

  static final RegExp emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isEmailFormat(String trimmed) => emailRegex.hasMatch(trimmed);
}
