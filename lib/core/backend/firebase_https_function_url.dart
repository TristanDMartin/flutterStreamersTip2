import 'package:firebase_core/firebase_core.dart';

/// Resolves a Firebase HTTPS Cloud Function base URL.
///
/// Order: [explicitOverride] → [envDefineValue] → project-derived default.
String resolveFirebaseHttpsFunctionUrl({
  String? explicitOverride,
  required String envDefineValue,
  required String functionName,
  String region = 'us-central1',
}) {
  final String configured = (explicitOverride ?? envDefineValue).trim();
  if (configured.isNotEmpty) {
    return configured;
  }
  return buildFirebaseHttpsFunctionUrlFromProject(
    functionName: functionName,
    region: region,
  );
}

/// `https://{region}-{projectId}.cloudfunctions.net/{functionName}` or `''`.
String buildFirebaseHttpsFunctionUrlFromProject({
  required String functionName,
  String region = 'us-central1',
}) {
  try {
    final String projectId = Firebase.app().options.projectId;
    if (projectId.isEmpty) {
      return '';
    }
    return 'https://$region-$projectId.cloudfunctions.net/$functionName';
  } catch (_) {
    return '';
  }
}
