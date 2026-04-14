/// Base URL for trusted gamification events (**POST** `/gamification/events`).
///
/// **Prefer the Cloudflare Worker** (default below): fewer Cloud Functions, predictable
/// pricing. Use Firebase HTTPS only if you explicitly need it.
///
/// **Worker (recommended default):**
/// `https://streamerstip-mux-api.streamerstip.workers.dev`
///
/// **Firebase HTTPS (optional fallback):** full function URL:
/// `https://<region>-<projectId>.cloudfunctions.net/gamificationEvents`
///
/// Override at build time:
/// `--dart-define=GAMIFICATION_EVENTS_BASE_URL=https://us-central1-PROJECT.cloudfunctions.net/gamificationEvents`
const String kGamificationEventsBaseUrl = String.fromEnvironment(
  'GAMIFICATION_EVENTS_BASE_URL',
  defaultValue: 'https://streamerstip-mux-api.streamerstip.workers.dev',
);
