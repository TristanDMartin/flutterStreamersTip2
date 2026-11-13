/// Production Cloudflare Worker. Release builds keep this host unless
/// `CLOUDFLARE_WORKER_BASE_URL` is set.
const String kProductionCloudflareWorkerBase =
    'https://streamerstip-mux-api.streamerstip.workers.dev';

const String _cloudflareWorkerOverride = String.fromEnvironment(
  'CLOUDFLARE_WORKER_BASE_URL',
);

/// Mux upload, R2 media, cross-post, and the default base for content
/// planning, creator score, and gamification events.
const String kCloudflareWorkerBaseUrl = _cloudflareWorkerOverride == ''
    ? kProductionCloudflareWorkerBase
    : _cloudflareWorkerOverride;

/// Uses [explicitDefine] when it is non-empty. Otherwise the shared worker.
String resolveCloudflareBackedUrl({
  required String explicitDefine,
}) {
  final String trimmed = explicitDefine.trim();
  if (trimmed.isEmpty) {
    return kCloudflareWorkerBaseUrl;
  }
  return trimmed;
}

bool isProductionCloudflareWorker(String url) {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final Uri? uri = Uri.tryParse(trimmed);
  final String host = (uri?.host ?? '').toLowerCase();
  if (host == 'streamerstip-mux-api.streamerstip.workers.dev') {
    return true;
  }
  return trimmed.contains('streamerstip-mux-api.streamerstip.workers.dev');
}
