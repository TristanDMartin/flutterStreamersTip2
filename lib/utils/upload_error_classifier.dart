import '../services/mux_upload_service.dart';

/// Classifies upload/publish failures for structured UI and logs.
enum UploadFailureKind {
  appCheck,
  firestoreRules,
  auth,
  storage,
  mux,
  network,
  unknown,
}

class UploadFailureClassification {
  const UploadFailureClassification({
    required this.kind,
    required this.userMessage,
    required this.logLabel,
  });

  final UploadFailureKind kind;
  final String userMessage;
  final String logLabel;

  static UploadFailureClassification classify(Object error) {
    final String raw = error.toString();
    final String lower = raw.toLowerCase();
    if (lower.contains('app attestation failed') ||
        lower.contains('appcheck') ||
        lower.contains('app check') ||
        lower.contains('too many attempts') ||
        lower.contains('placeholder token')) {
      return UploadFailureClassification(
        kind: UploadFailureKind.appCheck,
        logLabel: 'App Check',
        userMessage:
            'App Check blocked this request. Register your debug token in '
            'Firebase Console → App Check → your Android app → Manage debug '
            'tokens, then fully restart the app.',
      );
    }
    if (lower.contains('permission-denied') ||
        lower.contains('permission_denied') ||
        lower.contains('insufficient permissions')) {
      return UploadFailureClassification(
        kind: UploadFailureKind.firestoreRules,
        logLabel: 'Firestore rules',
        userMessage:
            'Firestore rejected this save (permission denied). Your account '
            'may be restricted, or the video document is missing owner fields. '
            'Try again after a full app restart.',
      );
    }
    if (lower.contains('unauthenticated') ||
        lower.contains('not signed in') ||
        lower.contains('authentication')) {
      return UploadFailureClassification(
        kind: UploadFailureKind.auth,
        logLabel: 'Auth',
        userMessage: 'Please sign in again to publish.',
      );
    }
    if (lower.contains('firebase_storage') ||
        lower.contains('storage/') ||
        lower.contains('object-not-found') && lower.contains('storage')) {
      return UploadFailureClassification(
        kind: UploadFailureKind.storage,
        logLabel: 'Storage',
        userMessage: 'Cloud storage upload failed. Please try again.',
      );
    }
    if (error is WorkerMuxUploadException) {
      return UploadFailureClassification(
        kind: UploadFailureKind.mux,
        logLabel: 'Mux Worker',
        userMessage: error.message,
      );
    }
    if (lower.contains('mux upload service') ||
        lower.contains('cloudflare worker') ||
        lower.contains('direct-upload') ||
        lower.contains('mux worker')) {
      return UploadFailureClassification(
        kind: UploadFailureKind.mux,
        logLabel: 'Mux Worker',
        userMessage: raw.length > 220 ? '${raw.substring(0, 220)}…' : raw,
      );
    }
    if (lower.contains('mux') || lower.contains('upload url')) {
      return UploadFailureClassification(
        kind: UploadFailureKind.mux,
        logLabel: 'Mux',
        userMessage: 'Video upload to Mux failed. Please try again.',
      );
    }
    if (lower.contains('socketexception') ||
        lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('unavailable')) {
      return UploadFailureClassification(
        kind: UploadFailureKind.network,
        logLabel: 'Network',
        userMessage: 'Network error. Check your connection and try again.',
      );
    }
    return UploadFailureClassification(
      kind: UploadFailureKind.unknown,
      logLabel: 'Upload',
      userMessage: raw.length > 200 ? '${raw.substring(0, 200)}…' : raw,
    );
  }
}
