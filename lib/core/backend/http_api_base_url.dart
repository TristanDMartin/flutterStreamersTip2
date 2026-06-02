/// Production website API host used when no override is configured.
const String kStreamersTipProductionApiHost = 'https://streamerstip.com';

/// Resolves an HTTP API base URL for website-backed endpoints.
///
/// Order: [explicitOverride] → [envDefineValue] → [productionDefault].
String resolveHttpApiBaseUrl({
  String? explicitOverride,
  required String envDefineValue,
  String productionDefault = kStreamersTipProductionApiHost,
}) {
  final String configured = (explicitOverride ?? envDefineValue).trim();
  if (configured.isNotEmpty) {
    return configured;
  }
  return productionDefault.trim();
}
