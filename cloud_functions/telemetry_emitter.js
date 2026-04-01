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
