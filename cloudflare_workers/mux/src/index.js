/**
 * StreamersTip Mux API — Cloudflare Worker
 * 
 * Routes:
 *   POST /mux/direct-upload — Create Mux direct upload, return uploadUrl + videoId
 *   POST /webhooks/mux     — Mux webhook handler, updates Firestore on video.asset.ready
 */

const MUX_API = 'https://api.mux.com';
const MUX_STREAM_BASE = 'https://stream.mux.com';
const IMAGE_MUX_BASE = 'https://image.mux.com';
const FIRESTORE_BASE = 'https://firestore.googleapis.com/v1';

const ALLOWED_ORIGINS = [
  'https://www.streamerstip.com',
  'https://streamerstip.com',
  'http://localhost:3000',
  'http://localhost:5173',
];

function getCorsHeaders(request) {
  const origin = request.headers.get('Origin');
  const allowOrigin = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, X-Upload-Type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  };
}

function jsonResponse(body, status = 200, headers = {}, corsHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders, ...headers },
  });
}

function corsPreflight(corsHeaders) {
  return new Response(null, { status: 204, headers: corsHeaders });
}

/** Verify Firebase ID token via Firebase Auth REST API (token in body, avoids URL encoding issues) */
async function verifyFirebaseToken(idToken, apiKey) {
  const token = (idToken || '').trim();
  if (!token) throw new Error('Empty token');
  if (!apiKey) throw new Error('FIREBASE_WEB_API_KEY not configured');
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: token }),
    }
  );
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = body.error?.message || body.error || 'Invalid or expired token';
    throw new Error(msg);
  }
  const user = body.users?.[0];
  if (!user?.localId) throw new Error('Invalid token payload');
  return { uid: user.localId, email: user.email };
}

/** Get Google OAuth2 access token from service account */
async function getFirestoreAccessToken(env) {
  const sa = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON || '{}');
  if (!sa.client_email || !sa.private_key) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON not configured');
  }

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/datastore',
  };

  const header = { alg: 'RS256', typ: 'JWT' };
  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const payloadB64 = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const signatureInput = `${headerB64}.${payloadB64}`;

  const pemContents = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    encoder.encode(signatureInput)
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
  const jwt = `${signatureInput}.${sigB64}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  if (!tokenRes.ok) {
    const err = await tokenRes.text();
    throw new Error(`Failed to get access token: ${err}`);
  }
  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}

/** Firestore REST: create document (POST to collection) or patch (PATCH to document) */
async function firestoreWrite(env, method, path, fields) {
  const token = await getFirestoreAccessToken(env);
  const projectId = env.FIREBASE_PROJECT_ID || 'streamerstip-6cfdb';
  const base = `${FIRESTORE_BASE}/projects/${projectId}/databases/(default)/documents`;

  const doc = { fields: {} };
  for (const [k, v] of Object.entries(fields)) {
    if (k.startsWith('metadata.') && typeof v !== 'object') {
      const inner = k.split('.')[1];
      doc.fields.metadata = doc.fields.metadata || { mapValue: { fields: {} } };
      doc.fields.metadata.mapValue.fields[inner] = toFirestoreValue(v);
    } else if (!k.includes('.')) {
      doc.fields[k] = toFirestoreValue(v);
    }
  }

  const isCreate = method === 'POST';
  let url;
  if (isCreate && path.includes('?documentId=')) {
    const [collection, rest] = path.split('?');
    const docId = rest.replace('documentId=', '');
    url = `${base}/${collection}?documentId=${docId}`;
  } else {
    url = `${base}/${path}`;
  }

  const res = await fetch(url, {
    method: isCreate ? 'POST' : 'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(doc),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore failed: ${err}`);
  }
  return res;
}

function toFirestoreValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'object' && v !== null && v.__timestamp) {
    return { timestampValue: new Date().toISOString() };
  }
  if (Array.isArray(v)) {
    return { arrayValue: { values: v.map((x) => toFirestoreValue(x)) } };
  }
  if (typeof v === 'object' && v !== null && !Array.isArray(v)) {
    const fields = {};
    for (const [k, val] of Object.entries(v)) {
      fields[k] = toFirestoreValue(val);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(v) };
}

/** Create Mux direct upload */
async function createMuxUpload(env, videoId, userId, isDraft = false) {
  const tokenId = env.MUX_TOKEN_ID;
  const tokenSecret = env.MUX_TOKEN_SECRET;
  if (!tokenId || !tokenSecret) {
    throw new Error('MUX_TOKEN_ID and MUX_TOKEN_SECRET not set');
  }

  const meta = { creator_id: userId };
  if (isDraft) meta.is_draft = 'true';

  const auth = btoa(`${tokenId}:${tokenSecret}`);
  const res = await fetch(`${MUX_API}/video/v1/uploads`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Basic ${auth}`,
    },
    body: JSON.stringify({
      cors_origin: '*',
      new_asset_settings: {
        playback_policies: ['public'],
        video_quality: 'basic',
        passthrough: videoId,
        meta,
      },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Mux create upload failed: ${res.status} ${err}`);
  }
  const data = await res.json();
  return { uploadUrl: data.data.url, uploadId: data.data.id };
}

/** Verify Mux webhook signature */
async function verifyMuxSignature(payload, signatureHeader, secret) {
  if (!signatureHeader || !secret) return false;
  const parts = signatureHeader.split(',');
  let t, v1;
  for (const p of parts) {
    const [key, val] = p.split('=');
    if (key === 't') t = val;
    if (key === 'v1') v1 = val;
  }
  if (!t || !v1) return false;

  const signedPayload = `${t}.${payload}`;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const sig = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(signedPayload)
  );
  const expected = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  if (expected !== v1) return false;

  const now = Math.floor(Date.now() / 1000);
  const tolerance = 300;
  return Math.abs(now - parseInt(t, 10)) <= tolerance;
}

const RATE_LIMIT_UID_PER_HOUR = 10;
const RATE_LIMIT_IP_PER_HOUR = 30;
const RATE_LIMIT_WINDOW_SEC = 3600;
const WEBHOOK_MAX_BODY_BYTES = 65536;

/** Rate limit: per-UID and per-IP. Returns { allowed, limited } */
async function checkRateLimit(env, uid, ip) {
  const kv = env.RATE_LIMIT_KV;
  if (!kv) throw new Error('RATE_LIMIT_KV not configured - rate limiting required');
  const window = Math.floor(Date.now() / 1000 / (RATE_LIMIT_WINDOW_SEC / 60)) * 60;
  const uidKey = `rl:uid:${uid}:${window}`;
  const ipKey = `rl:ip:${ip}:${window}`;
  const [uidCount, ipCount] = await Promise.all([
    kv.get(uidKey),
    kv.get(ipKey),
  ]);
  const uidNum = parseInt(uidCount || '0', 10);
  const ipNum = parseInt(ipCount || '0', 10);
  if (uidNum >= RATE_LIMIT_UID_PER_HOUR || ipNum >= RATE_LIMIT_IP_PER_HOUR) {
    return { allowed: false };
  }
  await Promise.all([
    kv.put(uidKey, String(uidNum + 1), { expirationTtl: RATE_LIMIT_WINDOW_SEC + 60 }),
    kv.put(ipKey, String(ipNum + 1), { expirationTtl: RATE_LIMIT_WINDOW_SEC + 60 }),
  ]);
  return { allowed: true };
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const cors = getCorsHeaders(request);

    if (request.method === 'OPTIONS') {
      return corsPreflight(cors);
    }

    try {
      if (path === '/health' && request.method === 'GET') {
        return await handleHealth(request, env, cors);
      }
      if (path === '/mux/direct-upload' && request.method === 'POST') {
        return await handleDirectUpload(request, env, cors);
      }
      if (path === '/webhooks/mux' && request.method === 'POST') {
        return await handleMuxWebhook(request, env, cors);
      }
      if (path === '/mux/backfill-assets' && request.method === 'POST') {
        return await handleBackfillAssets(request, env, cors);
      }
      if (path === '/media/upload' && request.method === 'POST') {
        return await handleMediaUpload(request, env, cors);
      }

      return jsonResponse({ error: 'Not found' }, 404, {}, cors);
    } catch (e) {
      return jsonResponse(
        { error: e.message || 'Internal error' },
        e.message?.includes('token') ? 401 : e.message?.includes('Invalid') ? 400 : 500,
        {},
        cors
      );
    }
  },
};

async function handleHealth(request, env, cors) {
  const checks = { worker: 'ok' };
  if (env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    try {
      await getFirestoreAccessToken(env);
      checks.firestore = 'ok';
    } catch (e) {
      checks.firestore = 'error';
    }
  }
  return jsonResponse(checks, 200, {}, cors);
}

async function handleDirectUpload(request, env, cors) {
  const auth = request.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) {
    throw new Error('Missing Authorization: Bearer <firebase_id_token>');
  }
  const idToken = auth.slice(7).trim();
  const { uid } = await verifyFirebaseToken(idToken, env.FIREBASE_WEB_API_KEY);

  const body = await request.json().catch(() => ({}));
  const clientVideoId = body.videoId?.trim();
  const clientUserId = body.userId?.trim();
  if (clientUserId && clientUserId !== uid) {
    throw new Error('userId must match authenticated user');
  }
  const videoId = (clientVideoId && clientVideoId.length > 0)
    ? clientVideoId
    : `vid_${Date.now()}_${Math.random().toString(36).slice(2, 11)}`;

  const ip = request.headers.get('CF-Connecting-IP') || request.headers.get('X-Forwarded-For') || 'unknown';
  let rateLimitResult;
  try {
    rateLimitResult = await checkRateLimit(env, uid, ip);
  } catch (e) {
    if (e.message?.includes('RATE_LIMIT_KV')) {
      return jsonResponse({ error: 'Service misconfigured' }, 503, {}, cors);
    }
    throw e;
  }
  if (!rateLimitResult.allowed) {
    return jsonResponse({ error: 'Rate limit exceeded. Try again later.' }, 429, {}, cors);
  }

  const isDraft = body.isDraft === true;
  const { uploadUrl, uploadId } = await createMuxUpload(env, videoId, uid, isDraft);

  await firestoreWrite(env, 'POST', `videos?documentId=${videoId}`, {
    id: videoId,
    userId: uid,
    creatorId: uid,
    creator_id: uid,
    status: 'uploading',
    processingState: 'uploading',
    isReadyForFeed: false,
    videoUrl: '',
    thumbnailUrl: '',
    hasMuxPlaybackId: false,
    caption: body.caption || '',
    hashtags: body.hashtags || [],
    privacy: body.privacy || 'public',
    visibility: body.visibility || body.privacy || 'public',
    allowComments: body.allowComments !== false,
    category: body.category || 'general',
    views: 0,
    likes: 0,
    comments: 0,
    isMux: true,
    muxStatus: 'processing',
    muxUploadId: uploadId || '',
    createdAt: { __timestamp: true },
    updatedAt: { __timestamp: true },
  });

  return jsonResponse({ videoId, uploadUrl, uploadId }, 200, {}, cors);
}

async function handleMuxWebhook(request, env, cors) {
  const contentLength = parseInt(request.headers.get('Content-Length') || '0', 10);
  if (contentLength > WEBHOOK_MAX_BODY_BYTES) {
    return jsonResponse({ error: 'Payload too large' }, 413, {}, cors);
  }
  const rawBody = await request.text();
  const signature = request.headers.get('Mux-Signature');
  const secret = env.MUX_WEBHOOK_SECRET;
  if (!secret) {
    return jsonResponse({ error: 'Webhook not configured' }, 503, {}, cors);
  }
  if (!signature || !(await verifyMuxSignature(rawBody, signature, secret))) {
    return jsonResponse({ error: 'Invalid or missing signature' }, 401, {}, cors);
  }

  const payload = JSON.parse(rawBody || '{}');
  const eventType = payload.type || 'unknown';
  if (eventType !== 'video.asset.ready') {
    console.log('[MuxWebhook] ignored type:', eventType);
    return jsonResponse({ received: eventType }, 200, {}, cors);
  }

  const data = payload.data || payload.object || payload;
  if (!data) return jsonResponse({ ok: true }, 200, {}, cors);

  const videoId = String(data.passthrough ?? data.passthrough_id ?? '').trim();
  if (!videoId) {
    console.log('[MuxWebhook] no passthrough, assetId:', data.id);
    return jsonResponse({ ok: true, warn: 'no passthrough' }, 200, {}, cors);
  }

  const playbackIds = data.playback_ids || [];
  const publicPlayback = playbackIds.find((p) => p?.policy === 'public') || playbackIds[0];
  if (!publicPlayback?.id) {
    console.log('[MuxWebhook] no playback id, videoId:', videoId, 'assetId:', data.id);
    return jsonResponse({ ok: true, warn: 'no playback id' }, 200, {}, cors);
  }

  const playbackId = publicPlayback.id;
  const hlsUrl = `${MUX_STREAM_BASE}/${playbackId}/high.m3u8`;
  const thumbnailUrl = `${IMAGE_MUX_BASE}/${playbackId}/thumbnail.jpg?width=720&time=0`;
  const duration = data.duration != null ? Math.round(data.duration) : null;
  const isDraft = (data.meta && data.meta.is_draft === 'true');

  const DURATION_MIN = 1;
  const DURATION_MAX = 300;

  const durationOk = duration != null && duration >= DURATION_MIN && duration <= DURATION_MAX;
  const hasThumbnail = thumbnailUrl != null && thumbnailUrl.length > 0;
  const allGatesPass = durationOk && hasThumbnail && !isDraft;

  const processingState = allGatesPass ? 'ready' : 'failed';
  const isReadyForFeed = allGatesPass;

  const fields = {
    hlsUrl,
    hls_url: hlsUrl,
    mp4_720_url: hlsUrl,
    videoUrl: hlsUrl,
    videoURL: hlsUrl,
    canonicalPlaybackUrl: hlsUrl,
    playbackUrl: hlsUrl,
    thumbnailUrl,
    thumbnailURL: thumbnailUrl,
    thumbnails: {
      urls: { 360: thumbnailUrl, 540: thumbnailUrl, 720: thumbnailUrl },
      generatedAt: { __timestamp: true },
    },
    status: isDraft ? 'draft' : (allGatesPass ? 'ready' : 'failed'),
    processingState,
    isReadyForFeed,
    transcodingStatus: 'completed',
    muxAssetId: data.id || '',
    muxPlaybackId: playbackId,
    hasMuxPlaybackId: true,
    isMux: true,
    muxStatus: 'ready',
    processingStatus: {
      transcoding: 'completed',
      thumbnail: 'completed',
      playback: 'completed',
    },
    transcodedAt: { __timestamp: true },
    updatedAt: { __timestamp: true },
  };

  if (duration != null) {
    fields['metadata.duration'] = duration;
    fields['duration'] = duration;
  }

  if (allGatesPass) {
    fields['publishedAt'] = { __timestamp: true };
  }

  if (!allGatesPass) {
    console.log('[MuxWebhook] gates failed:', {
      videoId,
      durationOk,
      hasThumbnail,
      isDraft,
      duration,
    });
  }

  console.log('[MuxWebhook] updating Firestore:', {
    eventType,
    assetId: data.id,
    playbackId,
    videoId,
    status: fields.status,
    processingState,
    isReadyForFeed,
  });
  await firestoreWrite(env, 'PATCH', `videos/${videoId}`, fields);

  return jsonResponse({ ok: true, videoId, isReadyForFeed }, 200, {}, cors);
}

/** Backfill Firestore from Mux assets (for assets that webhook missed) */
async function handleBackfillAssets(request, env, cors) {
  const secret = request.headers.get('X-Backfill-Secret');
  if (!env.MUX_BACKFILL_SECRET || secret !== env.MUX_BACKFILL_SECRET) {
    return jsonResponse({ error: 'Unauthorized' }, 401, {}, cors);
  }
  const body = await request.json().catch(() => ({}));
  const assetIds = Array.isArray(body.assetIds) ? body.assetIds : [];
  if (assetIds.length === 0) {
    return jsonResponse({ error: 'assetIds array required' }, 400, {}, cors);
  }

  const tokenId = env.MUX_TOKEN_ID;
  const tokenSecret = env.MUX_TOKEN_SECRET;
  if (!tokenId || !tokenSecret) {
    return jsonResponse({ error: 'Mux not configured' }, 503, {}, cors);
  }
  const auth = btoa(`${tokenId}:${tokenSecret}`);
  const results = [];

  for (const assetId of assetIds) {
    try {
      const res = await fetch(`${MUX_API}/video/v1/assets/${assetId}`, {
        headers: { 'Authorization': `Basic ${auth}` },
      });
      if (!res.ok) {
        results.push({ assetId, status: 'error', error: `Mux ${res.status}` });
        continue;
      }
      const json = await res.json();
      const data = json.data || json;
      const passthrough = String(data.passthrough ?? data.passthrough_id ?? '').trim();
      const playbackIds = data.playback_ids || [];
      const publicPlayback = playbackIds.find((p) => p?.policy === 'public') || playbackIds[0];
      const playbackId = publicPlayback?.id;
      if (!playbackId) {
        results.push({ assetId, status: 'error', error: 'no playback id' });
        continue;
      }
      const hlsUrl = `${MUX_STREAM_BASE}/${playbackId}/high.m3u8`;
      const thumbnailUrl = `${IMAGE_MUX_BASE}/${playbackId}/thumbnail.jpg?width=720&time=0`;
      const userId = (data.meta && data.meta.creator_id) ? String(data.meta.creator_id) : '';

      const fields = {
        hlsUrl,
        hls_url: hlsUrl,
        mp4_720_url: hlsUrl,
        videoUrl: hlsUrl,
        videoURL: hlsUrl,
        canonicalPlaybackUrl: hlsUrl,
        thumbnailUrl,
        thumbnailURL: thumbnailUrl,
        thumbnails: {
          urls: { 360: thumbnailUrl, 540: thumbnailUrl, 720: thumbnailUrl },
          generatedAt: { __timestamp: true },
        },
        status: 'ready',
        transcodingStatus: 'completed',
        muxAssetId: String(assetId),
        muxPlaybackId: playbackId,
        hasMuxPlaybackId: true,
        isMux: true,
        muxStatus: 'ready',
        processingStatus: {
          transcoding: 'completed',
          thumbnail: 'completed',
          playback: 'completed',
        },
        transcodedAt: { __timestamp: true },
        updatedAt: { __timestamp: true },
      };
      if (data.duration != null) {
        fields['metadata.duration'] = Math.round(data.duration);
      }

      if (passthrough) {
        await firestoreWrite(env, 'PATCH', `videos/${passthrough}`, fields);
        results.push({ assetId, status: 'patched', videoId: passthrough });
      } else if (userId) {
        await firestoreWrite(env, 'POST', `videos?documentId=${assetId}`, {
          id: assetId,
          userId,
          creatorId: userId,
          creator_id: userId,
          createdAt: { __timestamp: true },
          ...fields,
        });
        results.push({ assetId, status: 'created', videoId: assetId });
      } else {
        results.push({ assetId, status: 'skip', error: 'no passthrough or creator_id' });
      }
    } catch (e) {
      results.push({ assetId, status: 'error', error: e.message });
    }
  }

  return jsonResponse({ results }, 200, {}, cors);
}

const MAX_AVATAR_BYTES = 5 * 1024 * 1024;
const MAX_CHAT_BYTES = 10 * 1024 * 1024;

/** Upload avatar or chat media to R2 */
async function handleMediaUpload(request, env, cors) {
  const auth = request.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) {
    return jsonResponse({ error: 'Missing Authorization: Bearer <token>' }, 401, {}, cors);
  }
  const idToken = auth.slice(7).trim();
  const { uid } = await verifyFirebaseToken(idToken, env.FIREBASE_WEB_API_KEY);

  const bucket = env.MEDIA_BUCKET;
  const baseUrl = env.MEDIA_PUBLIC_BASE_URL;
  if (!bucket || !baseUrl) {
    return jsonResponse({ error: 'Media upload not configured' }, 503, {}, cors);
  }

  const type = request.headers.get('X-Upload-Type') || 'avatar';
  const maxBytes = type === 'chat' ? MAX_CHAT_BYTES : MAX_AVATAR_BYTES;

  let file;
  let contentType = 'image/jpeg';
  try {
    const formData = await request.formData();
    file = formData.get('file');
    if (!file || typeof file.arrayBuffer !== 'function') {
      return jsonResponse({ error: 'Missing file in form data' }, 400, {}, cors);
    }
    const ct = file.type;
    if (ct) contentType = ct;
  } catch (e) {
    return jsonResponse({ error: 'Invalid multipart body: ' + e.message }, 400, {}, cors);
  }

  const buf = await file.arrayBuffer();
  if (buf.byteLength > maxBytes) {
    return jsonResponse({ error: `File too large. Max ${maxBytes / 1024 / 1024}MB` }, 413, {}, cors);
  }

  const ext = type === 'chat' ? 'gif' : (contentType.includes('png') ? 'png' : 'jpg');
  const key = type === 'chat'
    ? `chat/${uid}/${Date.now()}.${ext}`
    : `avatars/${uid}/${Date.now()}.${ext}`;

  await bucket.put(key, buf, {
    httpMetadata: { contentType },
  });

  const url = baseUrl.endsWith('/') ? baseUrl + key : baseUrl + '/' + key;
  return jsonResponse({ url }, 200, {}, cors);
}
