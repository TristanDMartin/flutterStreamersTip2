/// Redacts Firebase UIDs, emails, and labeled identifiers from strings shown
/// in UI, logs, and crash reports.
class SensitiveDataRedactor {
  SensitiveDataRedactor._();

  static const String _redactedToken = '[redacted]';
  static const String _maskedIdPlaceholder = '••••';

  /// Typical Firebase Auth UID length.
  static const int _firebaseUidLength = 28;

  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  static final RegExp _firebaseUidPattern = RegExp(
    r'\b[a-zA-Z0-9]{28}\b',
  );

  static final RegExp _labeledIdPattern = RegExp(
    r'(uid|userId|user_id|targetUid|creatorId|reporterUserId|'
    r'reportedUserId|followerId|followingId|senderId|recipientId)'
    r'\s*[:=]\s*["'
    "'"
    r']?([a-zA-Z0-9\-]{20,128})',
    caseSensitive: false,
  );

  static final RegExp _firestorePathPattern = RegExp(
    r'(users|videos|chats|comments|bookmarks|drafts|avatars)/'
    r'([a-zA-Z0-9_-]{20,128})',
    caseSensitive: false,
  );

  /// Masks an identifier for admin UI (first/last 4 chars).
  static String maskId(String id) {
    final String trimmed = id.trim();
    if (trimmed.isEmpty) {
      return _maskedIdPlaceholder;
    }
    if (trimmed.length <= 8) {
      return _maskedIdPlaceholder;
    }
    return '${trimmed.substring(0, 4)}…${trimmed.substring(trimmed.length - 4)}';
  }

  /// Redacts sensitive substrings; safe for logs and analytics in release.
  static String redact(String input) {
    if (input.isEmpty) {
      return input;
    }
    String result = input;
    result = result.replaceAllMapped(
      _emailPattern,
      (_) => _redactedToken,
    );
    result = result.replaceAllMapped(
      _labeledIdPattern,
      (Match match) => '${match.group(1)}: $_redactedToken',
    );
    result = result.replaceAllMapped(
      _firestorePathPattern,
      (Match match) => '${match.group(1)}/$_redactedToken',
    );
    result = result.replaceAllMapped(
      _firebaseUidPattern,
      (_) => _redactedToken,
    );
    return result;
  }

  /// Whether [value] looks like a Firebase Auth UID.
  static bool looksLikeFirebaseUid(String value) {
    final String trimmed = value.trim();
    return trimmed.length == _firebaseUidLength &&
        RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed);
  }

  /// Redacts [input] for on-screen error text in production.
  static String redactForDisplay(String input) {
    return redact(input);
  }
}
