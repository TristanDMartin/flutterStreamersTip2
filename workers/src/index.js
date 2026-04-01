/**
 * StreamersTip Mux API — Cloudflare Worker
 * Replaces Firebase createMuxDirectUpload + muxWebhook
 *
 * Routes:
 *   POST /mux/direct-upload  — Create Mux upload URL, create Firestore doc
 *   POST /webhooks/mux       — Mux webhook (video.asset.ready)
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': 'https://www.streamerstip.com',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS, ...extra },
  });
}

function corsPreflight() {
  return new Response(null, {
    status: 204,
    headers: CORS_HEADERS,
  });
}

async function verifyFirebaseToken(idToken) {
  const res = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
  );
  if (!res.ok) return null;
  const data = await res.json();
  if (!data.aud || !data.sub) return null;
  return { uid: data.sub };
}

function generateVideoId() {
  return crypto.randomUUID ? crypto.randomUUID() : 'v_' + Date.now() + '_' + Math.random().toString(36).slice(2, 11);
}

async function createMuxUpload(videoId, userId, env) {
  const auth = btoa(`${env.MUX_TOKEN_ID}:${env.MUX_TOKEN_SECRET}`);
  const res = await fetch(`${env.MUX_API || 'https://api.mux.com'}/video/v1/uploads`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Basic ${auth}`,
    },
    body: JSON.stringify({
      cors_origin: '*',
      new_asset_settings: {
        playback_policies: ['public'],
        video_quality: 'basic',
        passthrough: videoId,
        meta: { creator_id: userId },
      },
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Mux create upload failed: ${res.status} ${err}`);
  }
  const data = await res.json();
  return {
    uploadUrl: data.data.url,
    uploadId: data.data.id,
  };
}

async function createFirestoreDoc(projectId, videoId, userId, accessToken) {
  const doc = {
    name: `projects/${projectId}/databases/(default)/documents/videos/${videoId}`,
    fields: {
      id: { stringValue: videoId },
      userId: { stringValue: userId },
      creatorId: { stringValue: userId },
      creator_id: { stringValue: userId },
      status: { stringValue: 'uploading' },
      processingState: { stringValue: 'uploading' },
      isReadyForFeed: { booleanValue: false },
      views: { integerValue: '0' },
      likes: { integerValue: '0' },
      comments: { integerValue: '0' },
      createdAt: { timestampValue: new Date().toISOString() },
      updatedAt: { timestampValue: new Date().toISOString() },
    },
  };
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/videos?documentId=${videoId}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({ document: doc }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore create failed: ${res.status} ${err}`);
  }
}

async function updateFirestoreDoc(projectId, videoId, updates, accessToken) {
  const keys = Object.keys(updates);
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/videos/${videoId}?updateMask.fieldPaths=${keys.join('&updateMask.fieldPaths=')}`;
  const fields = {};
  for (const [k, v] of Object.entries(updates)) {
    if (typeof v === 'string') fields[k] = { stringValue: v };
    else if (typeof v === 'boolean') fields[k] = { booleanValue: v };
    else if (typeof v === 'number') fields[k] = { integerValue: String(v) };
    else if (v && typeof v === 'object' && v.timestampValue) fields[k] = v;
    else if (v && typeof v === 'object' && v.mapValue) fields[k] = v;
    else if (typeof v === 'object') fields[k] = { mapValue: { fields: v } };
  }
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({ document: { name: `projects/${projectId}/databases/(default)/documents/videos/${videoId}`, fields } }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore update failed: ${res.status} ${err}`);
  }
}

async function getGoogleAccessToken(serviceAccountJson) {
  const sa = typeof serviceAccountJson === 'string' ? JSON.parse(serviceAccountJson) : serviceAccountJson;
  const header = { alg: 'RS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const encodedPayload = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const signatureInput = `${encodedHeader}.${encodedPayload}`;
  const b64 = sa.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\n/g, '');
  const binary = atob(b64);
  const keyBytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) keyBytes[i] = binary.charCodeAt(i);
  const privateKey = await crypto.subtle.importPKCS8(
    keyBytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }
  );
  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    privateKey,
    new TextEncoder().encode(signatureInput)
  );
  const encodedSig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const jwt = `${signatureInput}.${encodedSig}`;
  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!tokenRes.ok) throw new Error('Failed to get Google access token');
  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}

function verifyMuxSignature(rawBody, signatureHeader, secret) {
  if (!signatureHeader) return false;
  const parts = signatureHeader.split(',');
  let t, v1;
  for (const p of parts) {
    const [key, val] = p.split('=');
    if (key === 't') t = val;
    if (key === 'v1') v1 = val;
  }
  if (!t || !v1) return false;
  const payload = `${t}.${rawBody}`;
  return crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  ).then((key) =>
    crypto.subtle.sign('HMAC', key, new TextEncoder().encode(payload))
  ).then((sig) => {
    const hex = Array.from(new Uint8Array(sig))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
    return hex === v1 && Math.abs(Date.now() / 1000 - parseInt(t, 10)) < 300;
  });
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') return corsPreflight();

    if (url.pathname === '/mux/direct-upload' && request.method === 'POST') {
      try {
        const auth = request.headers.get('Authorization');
        if (!auth?.startsWith('Bearer ')) {
          return jsonResponse({ error: 'Missing or invalid Authorization' }, 401);
        }
        const token = auth.slice(7);
        const user = await verifyFirebaseToken(token);
        if (!user) return jsonResponse({ error: 'Invalid token' }, 401);

        const body = await request.json().catch(() => ({}));
        const videoId = generateVideoId();
        const { uploadUrl, uploadId } = await createMuxUpload(videoId, user.uid, env);

        const projectId = env.FIREBASE_PROJECT_ID;
        const sa = env.FIREBASE_SERVICE_ACCOUNT_JSON;
        if (projectId && sa) {
          try {
            const accessToken = await getGoogleAccessToken(sa);
            await createFirestoreDoc(projectId, videoId, user.uid, accessToken);
          } catch (e) {
            console.error('Firestore create error:', e);
          }
        }

        return jsonResponse({ videoId, uploadUrl, uploadId });
      } catch (e) {
        console.error('direct-upload error:', e);
        return jsonResponse({ error: e.message || 'Internal error' }, 500);
      }
    }

    if (url.pathname === '/webhooks/mux' && request.method === 'POST') {
      try {
        const rawBody = await request.text();
        const sig = request.headers.get('Mux-Signature');
        const secret = env.MUX_WEBHOOK_SECRET;
        if (secret) {
          const valid = await verifyMuxSignature(rawBody, sig, secret);
          if (!valid) return jsonResponse({ error: 'Invalid signature' }, 401);
        }
        const payload = JSON.parse(rawBody);
        if (payload.type !== 'video.asset.ready') {
          return jsonResponse({ received: true });
        }
        const data = payload.data || payload.object || payload;
        const videoId = (data.passthrough ?? data.passthrough_id || '').toString().trim();
        if (!videoId) return jsonResponse({ error: 'No passthrough' }, 400);
        const playbackIds = data.playback_ids || [];
        const publicPlayback = playbackIds.find((p) => p?.policy === 'public') || playbackIds[0];
        if (!publicPlayback?.id) return jsonResponse({ error: 'No playback ID' }, 400);

        const streamBase = env.MUX_STREAM_BASE || 'https://stream.mux.com';
        const hlsUrl = `${streamBase}/${publicPlayback.id}.m3u8`;
        const duration = data.duration != null ? Math.round(data.duration) : null;
        const now = new Date().toISOString();

        // Feed eligibility gates (spec §.3)
        const durationOk = duration != null && duration >= 1 && duration <= 300;
        const hasThumbnail = !!(data.thumbnail_url || data.max_stored_frame_rate > 0 ||
          (data.tracks && data.tracks.some((t) => t.type === 'video')));
        const isReadyForFeed = durationOk && hasThumbnail;

        const updates = {
          hlsUrl,
          hls_url: hlsUrl,
          videoUrl: hlsUrl,
          videoURL: hlsUrl,
          canonicalPlaybackUrl: hlsUrl,
          status: 'active',
          processingState: 'ready',
          isReadyForFeed,
          transcodingStatus: 'completed',
          muxAssetId: data.id,
          muxPlaybackId: publicPlayback.id,
          publishedAt: { timestampValue: now },
          transcodedAt: { timestampValue: now },
          updatedAt: { timestampValue: now },
        };
        if (duration != null) updates.duration = duration;
        if (duration != null) updates.metadata = { mapValue: { fields: { duration: { integerValue: String(duration) } } } };

        const projectId = env.FIREBASE_PROJECT_ID;
        const sa = env.FIREBASE_SERVICE_ACCOUNT_JSON;
        if (projectId && sa) {
          try {
            const accessToken = await getGoogleAccessToken(sa);
            await updateFirestoreDoc(projectId, videoId, updates, accessToken);
          } catch (e) {
            console.error('Firestore webhook update error:', e);
            return jsonResponse({ error: 'Firestore update failed' }, 500);
          }
        }

        return jsonResponse({ ok: true });
      } catch (e) {
        console.error('webhook error:', e);
        return jsonResponse({ error: e.message || 'Internal error' }, 500);
      }
    }

    return jsonResponse({ error: 'Not found' }, 404);
  },
};
