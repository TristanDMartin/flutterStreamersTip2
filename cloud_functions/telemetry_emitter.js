// Lightweight telemetry emitter.
// Configure TELEMETRY_WEBHOOK_URL to send to Slack/Discord/log sink.
// Falls back to console logging if not set.

const fetch = (...args) => import('node-fetch').then(({default: f}) => f(...args));

const webhookUrl = process.env.TELEMETRY_WEBHOOK_URL || '';

async function emitTelemetry(eventType, payload = {}) {
  const body = {
    eventType,
    payload,
    timestamp: new Date().toISOString(),
    source: 'cloud_functions',
  };

  if (!webhookUrl) {
    console.log('[telemetry]', JSON.stringify(body));
    return;
  }

  try {
    await fetch(webhookUrl, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body),
    });
  } catch (err) {
    console.error('❌ telemetry emit failed', err);
  }
}

module.exports = {emitTelemetry};
// Lightweight telemetry emitter stub.
// Configure a webhook endpoint via env TELEMETRY_WEBHOOK_URL (e.g., Slack/Discord or log sink proxy).
// Usage examples:
//   emitTelemetry('rule_denial', {rule: 'follows/create', count: 1});
//   emitTelemetry('follow_churn_spike', {userId: 'alice', ratePerMin: 42});
//   emitTelemetry('feed_error', {tab: 'following', error: 'timeout'});
//   emitTelemetry('media_qos', {videoId: 'v123', stallMs: 320, ttfpMs: 900, region: 'us-east'});

const fetch = (...args) => import('node-fetch').then(({default: f}) => f(...args));

const webhookUrl = process.env.TELEMETRY_WEBHOOK_URL || '';

async function emitTelemetry(eventType, payload) {
  const body = {
    eventType,
    payload,
    timestamp: new Date().toISOString(),
    source: 'cloud_functions',
  };

  if (!webhookUrl) {
    // Fallback to console logging if no sink is configured
    console.log('[telemetry]', JSON.stringify(body));
    return;
  }

  try {
    await fetch(webhookUrl, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body),
    });
  } catch (err) {
    console.error('❌ telemetry emit failed', err);
  }
}

module.exports = {emitTelemetry};
