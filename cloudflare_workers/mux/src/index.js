/**
 * StreamersTip Mux API — Cloudflare Worker
 * 
 * Routes:
 *   POST /mux/direct-upload — Create Mux direct upload, return uploadUrl + videoId
 *   POST /webhooks/mux     — Mux webhook handler, updates Firestore on video.asset.ready
 *   POST /api/crosspost/prepare-watermarked — Create/reuse a branded Mux asset for external posting
 *   POST /gamification/events — Trusted gamification events; idempotent by eventId; mission/XP in Worker
 */

const MUX_API = 'https://api.mux.com';
const MUX_STREAM_BASE = 'https://stream.mux.com';
const IMAGE_MUX_BASE = 'https://image.mux.com';
const FIRESTORE_BASE = 'https://firestore.googleapis.com/v1';

function buildMuxPlaybackUrls(playbackId) {
  const safePlaybackId = String(playbackId || '').trim();
  if (!safePlaybackId) {
    return {
      adaptiveHlsUrl: '',
      highHlsUrl: '',
    };
  }

  return {
    adaptiveHlsUrl: `${MUX_STREAM_BASE}/${safePlaybackId}.m3u8`,
    highHlsUrl: `${MUX_STREAM_BASE}/${safePlaybackId}/high.m3u8`,
  };
}

const ALLOWED_ORIGINS = [
  'https://www.streamerstip.com',
  'https://streamerstip.com',
  'http://localhost:3000',
  'http://localhost:5173',
];

/** Comma-separated list for Access-Control-Allow-Headers (preflight). App: Authorization, Content-Type. */
const CORS_ALLOW_HEADERS =
  'Authorization, Content-Type, X-Upload-Type';

function getCorsHeaders(request) {
  const origin = request.headers.get('Origin');
  const allowOrigin = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Headers': CORS_ALLOW_HEADERS,
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

function muxAuthHeader(env) {
  const tokenId = env.MUX_TOKEN_ID;
  const tokenSecret = env.MUX_TOKEN_SECRET;
  if (!tokenId || !tokenSecret) {
    throw new Error('MUX_TOKEN_ID and MUX_TOKEN_SECRET not set');
  }
  return `Basic ${btoa(`${tokenId}:${tokenSecret}`)}`;
}

async function muxRequest(env, path, init = {}) {
  const headers = {
    Authorization: muxAuthHeader(env),
    ...(init.body ? { 'Content-Type': 'application/json' } : {}),
    ...Object.fromEntries(
      Object.entries(init.headers || {}).filter(([, value]) => value !== undefined)
    ),
  };
  const res = await fetch(`${MUX_API}${path}`, {
    ...init,
    headers,
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Mux request failed: ${res.status} ${err}`);
  }
  return res.json();
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

function fromFirestoreValue(v) {
  if (v == null) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue, 10);
  if (v.doubleValue !== undefined) return v.doubleValue;
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.timestampValue !== undefined) return new Date(v.timestampValue);
  if (v.nullValue !== undefined) return null;
  if (v.arrayValue) {
    const vals = v.arrayValue.values || [];
    return vals.map((x) => fromFirestoreValue(x));
  }
  if (v.mapValue && v.mapValue.fields) {
    const o = {};
    for (const [k, val] of Object.entries(v.mapValue.fields)) {
      o[k] = fromFirestoreValue(val);
    }
    return o;
  }
  return null;
}

async function firestoreGetDocument(env, docPath) {
  const token = await getFirestoreAccessToken(env);
  const projectId = env.FIREBASE_PROJECT_ID || 'streamerstip-6cfdb';
  const url = `${FIRESTORE_BASE}/projects/${projectId}/databases/(default)/documents/${docPath}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore GET failed: ${err}`);
  }
  const json = await res.json();
  if (!json.fields) return {};
  const out = {};
  for (const [k, val] of Object.entries(json.fields)) {
    out[k] = fromFirestoreValue(val);
  }
  return out;
}

async function firestorePatchDocument(env, docPath, fields) {
  const keys = Object.keys(fields);
  if (keys.length === 0) return;
  const token = await getFirestoreAccessToken(env);
  const projectId = env.FIREBASE_PROJECT_ID || 'streamerstip-6cfdb';
  const base = `${FIRESTORE_BASE}/projects/${projectId}/databases/(default)/documents`;
  const qs = keys
    .map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`)
    .join('&');
  const url = `${base}/${docPath}?${qs}`;
  const doc = { fields: {} };
  for (const [k, v] of Object.entries(fields)) {
    doc.fields[k] = toFirestoreValue(v);
  }
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(doc),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore PATCH failed: ${err}`);
  }
}

function firestoreDocumentToObject(document) {
  const out = {};
  const fields = document?.fields || {};
  for (const [k, val] of Object.entries(fields)) {
    out[k] = fromFirestoreValue(val);
  }
  out.__name = document?.name || '';
  out.__id =
    typeof document?.name === 'string'
      ? document.name.split('/').pop() || ''
      : '';
  return out;
}

async function firestoreRunQuery(env, structuredQuery) {
  const token = await getFirestoreAccessToken(env);
  const projectId = env.FIREBASE_PROJECT_ID || 'streamerstip-6cfdb';
  const url = `${FIRESTORE_BASE}/projects/${projectId}/databases/(default)/documents:runQuery`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ structuredQuery }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore runQuery failed: ${err}`);
  }

  const rows = await res.json();
  if (!Array.isArray(rows)) return [];

  return rows
    .map((row) => row?.document)
    .filter(Boolean)
    .map((document) => ({
      document,
      data: firestoreDocumentToObject(document),
    }));
}

function isPublicVideoDoc(data = {}) {
  const visibility = data.visibility;
  const privacy = data.privacy;
  return (
    visibility === 'public' ||
    privacy === 'Everyone' ||
    privacy === 'Public' ||
    privacy === 'public' ||
    (visibility == null && privacy == null)
  );
}

function normalizeMuxFeedHlsUrl(url) {
  if (typeof url !== 'string' || !url.trim()) return '';
  const trimmed = url.trim();
  if (!trimmed.includes('stream.mux.com')) return trimmed;

  try {
    const parsed = new URL(trimmed);
    const segments = parsed.pathname.split('/').filter(Boolean);
    if (segments.length === 0) return trimmed;
    const playbackId = segments[0]
      .replace('.m3u8', '')
      .replace('/high', '')
      .replace('/medium', '')
      .replace('/low', '');
    if (!playbackId) return trimmed;
    return `${MUX_STREAM_BASE}/${playbackId}.m3u8`;
  } catch (_) {
    return trimmed;
  }
}

function resolvePlayableFeedUrl(data = {}) {
  return normalizeMuxFeedHlsUrl(
    data.canonicalPlaybackUrl ||
      data.hlsUrl ||
      data.hls_url ||
      data.videoUrl ||
      data.videoURL ||
      ''
  );
}

function buildMuxThumbnailMap(playbackId) {
  const id = String(playbackId || '').trim();
  if (!id) return null;
  return {
    360: `${IMAGE_MUX_BASE}/${id}/thumbnail.jpg?width=360&time=0`,
    540: `${IMAGE_MUX_BASE}/${id}/thumbnail.jpg?width=540&time=0`,
    720: `${IMAGE_MUX_BASE}/${id}/thumbnail.jpg?width=720&time=0`,
    1080: `${IMAGE_MUX_BASE}/${id}/thumbnail.jpg?width=1080&time=0`,
  };
}

function buildFeedFieldBackfillUpdate(data = {}) {
  const status = String(data.status || '').trim().toLowerCase();
  if (status === 'deleted' || status === 'blocked' || status === 'draft') {
    return null;
  }

  const muxPlaybackId =
    typeof data.muxPlaybackId === 'string' && data.muxPlaybackId.trim()
      ? data.muxPlaybackId.trim()
      : '';
  const playableUrl = resolvePlayableFeedUrl(data);

  if (!muxPlaybackId && !playableUrl) return null;
  if (!isPublicVideoDoc(data)) return null;

  const update = {
    status: 'active',
    isReadyForFeed: true,
    playbackReady: true,
    engagementScore:
      typeof data.engagementScore === 'number' ? data.engagementScore : 0,
    updatedAt: { __timestamp: true },
    migratedToCanonicalFeedAt: { __timestamp: true },
  };

  if (!data.publishedAt) {
    update.publishedAt = data.createdAt || { __timestamp: true };
  }

  if (!data.visibility) {
    update.visibility = 'public';
  }

  if (playableUrl) {
    update.hlsUrl = playableUrl;
    update.hls_url = playableUrl;
    update.videoUrl = playableUrl;
    update.videoURL = playableUrl;
    update.canonicalPlaybackUrl = playableUrl;
  }

  if (muxPlaybackId) {
    update.muxAdaptiveHlsUrl = `${MUX_STREAM_BASE}/${muxPlaybackId}.m3u8`;
    update.muxHighHlsUrl = `${MUX_STREAM_BASE}/${muxPlaybackId}/high.m3u8`;
    update.mp4_720_url = `${MUX_STREAM_BASE}/${muxPlaybackId}/high.m3u8`;

    const thumbnails = buildMuxThumbnailMap(muxPlaybackId);
    if (thumbnails) {
      const preferredThumbnail =
        data.thumbnailUrl || data.thumbnailURL || thumbnails[720];
      update.thumbnailUrl = preferredThumbnail;
      update.thumbnailURL = preferredThumbnail;
      update.thumbnails = {
        urls: thumbnails,
        generatedAt: data?.thumbnails?.generatedAt || { __timestamp: true },
        migratedAt: { __timestamp: true },
      };
    }
  }

  return update;
}

function isAbsoluteUrl(value) {
  return typeof value === 'string' && /^https?:\/\//i.test(value);
}

function toPercentString(value, fallbackPercent) {
  if (typeof value === 'string' && value.trim()) {
    return value;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    if (value <= 1) return `${Math.round(value * 100)}%`;
    return `${Math.round(value)}%`;
  }
  return `${fallbackPercent}%`;
}

function toPixelString(value, fallbackPx) {
  if (typeof value === 'string' && value.trim()) {
    return value;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return `${Math.round(value)}px`;
  }
  return `${fallbackPx}px`;
}

function normalizeMuxOverlaySettings(config = {}) {
  const position = String(config.position || '').toLowerCase();
  return {
    vertical_align:
      String(config.vertical_align || (position === 'lower_float' ? 'bottom' : 'bottom')),
    horizontal_align:
      String(config.horizontal_align || (position === 'lower_float' ? 'right' : 'right')),
    vertical_margin: toPixelString(
      config.marginBottom ?? config.vertical_margin,
      74
    ),
    horizontal_margin: toPixelString(
      config.marginRight ?? config.horizontal_margin,
      18
    ),
    width: toPercentString(config.size ?? config.width, 7),
    opacity: toPercentString(config.opacity, 90),
  };
}

function makeConfigSignature(sourceAssetId, overlayUrl, overlaySettings) {
  return JSON.stringify({
    sourceAssetId,
    overlayUrl,
    overlaySettings,
  });
}

function pickBestStaticMp4File(files = []) {
  const mp4Files = files.filter(
    (file) => file && String(file.ext || '').toLowerCase() === 'mp4'
  );
  if (mp4Files.length === 0) return null;

  return mp4Files.sort((a, b) => {
    const aSize = Number(a.filesize || 0);
    const bSize = Number(b.filesize || 0);
    if (bSize !== aSize) return bSize - aSize;
    const aHeight = Number(a.height || 0);
    const bHeight = Number(b.height || 0);
    return bHeight - aHeight;
  })[0];
}

function extractReadyMuxStaticMp4(asset, playbackId) {
  const renditions = asset?.static_renditions;
  if (!renditions || renditions.status !== 'ready') {
    return {
      status: renditions?.status || 'missing',
      url: '',
      name: '',
      filesize: 0,
      contentType: 'video/mp4',
    };
  }

  const bestFile = pickBestStaticMp4File(renditions.files || []);
  if (!bestFile || !playbackId) {
    return {
      status: renditions.status,
      url: '',
      name: '',
      filesize: 0,
      contentType: 'video/mp4',
    };
  }

  return {
    status: 'ready',
    url: `${MUX_STREAM_BASE}/${playbackId}/${bestFile.name}`,
    name: String(bestFile.name || ''),
    filesize: Number(bestFile.filesize || 0),
    contentType: 'video/mp4',
  };
}

async function ensureMuxStaticMp4(env, {
  assetId,
  playbackId,
}) {
  const asset = await getMuxAsset(env, assetId);
  const readyMp4 = extractReadyMuxStaticMp4(asset, playbackId);
  if (readyMp4.status === 'ready' && readyMp4.url) {
    return {
      status: 'ready',
      asset,
      ...readyMp4,
    };
  }

  const renditionsStatus = String(asset?.static_renditions?.status || '').trim();
  if (renditionsStatus === 'preparing') {
    return {
      status: 'preparing',
      asset,
      url: '',
      name: '',
      filesize: 0,
      contentType: 'video/mp4',
    };
  }

  await muxRequest(env, `/video/v1/assets/${assetId}/mp4-support`, {
    method: 'PUT',
    body: JSON.stringify({
      mp4_support: 'capped-1080p',
    }),
  });

  return {
    status: 'preparing',
    asset,
    url: '',
    name: '',
    filesize: 0,
    contentType: 'video/mp4',
  };
}

function sanitizeYoutubeTitle(caption, fallbackTitle = 'StreamersTip video') {
  const raw = String(caption || '').replace(/\s+/g, ' ').trim();
  if (!raw) return fallbackTitle;
  return raw.slice(0, 100);
}

function sanitizeYoutubeDescription(caption) {
  const raw = String(caption || '').trim();
  if (!raw) return 'Posted from StreamersTip';
  return raw.slice(0, 5000);
}

function mapPrivacyToYoutubeStatus(rawPrivacy) {
  const normalized = String(rawPrivacy || '').trim().toLowerCase();
  if (normalized === 'private' || normalized === 'followers' || normalized === 'friends') {
    return 'private';
  }
  if (normalized === 'unlisted') return 'unlisted';
  return 'public';
}

async function getYoutubePlatformAuth(env, uid) {
  return firestoreGetDocument(env, `users/${uid}/platform_auth/youtube`);
}

async function refreshYoutubeAccessToken(env, {
  refreshToken,
}) {
  const clientId = String(env.YOUTUBE_CLIENT_ID || '').trim();
  const clientSecret = String(env.YOUTUBE_CLIENT_SECRET || '').trim();
  if (!clientId || !clientSecret) {
    throw new Error('YOUTUBE_CLIENT_ID and YOUTUBE_CLIENT_SECRET must be configured');
  }
  if (!refreshToken) {
    throw new Error('YouTube refresh token is missing');
  }

  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    grant_type: 'refresh_token',
    refresh_token: refreshToken,
  });

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: body.toString(),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok || !json.access_token) {
    throw new Error(
      `YouTube token refresh failed: ${json.error_description || json.error || res.status}`
    );
  }
  return json;
}

async function uploadVideoToYoutube({
  accessToken,
  sourceUrl,
  sourceContentLength,
  title,
  description,
  privacyStatus,
}) {
  const sourceResponse = await fetch(sourceUrl, {
    headers: {
      Accept: 'video/mp4,application/octet-stream;q=0.9,*/*;q=0.1',
    },
  });
  if (!sourceResponse.ok || !sourceResponse.body) {
    throw new Error(`Unable to fetch cross-post source video: ${sourceResponse.status}`);
  }

  const contentType =
    sourceResponse.headers.get('content-type') || 'video/mp4';
  const contentLengthHeader =
    sourceContentLength ||
    sourceResponse.headers.get('content-length') ||
    '';
  if (!contentLengthHeader) {
    throw new Error('Cross-post source did not provide a content length');
  }

  const metadata = {
    snippet: {
      title,
      description,
    },
    status: {
      privacyStatus,
    },
  };

  const initRes = await fetch(
    'https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': contentType,
        'X-Upload-Content-Length': String(contentLengthHeader),
      },
      body: JSON.stringify(metadata),
    }
  );

  if (!initRes.ok) {
    const errText = await initRes.text();
    throw new Error(`YouTube upload init failed: ${initRes.status} ${errText}`);
  }

  const uploadUrl = initRes.headers.get('Location');
  if (!uploadUrl) {
    throw new Error('YouTube upload init did not return a resumable upload URL');
  }

  const uploadRes = await fetch(uploadUrl, {
    method: 'PUT',
    headers: {
      'Content-Type': contentType,
      'Content-Length': String(contentLengthHeader),
    },
    body: sourceResponse.body,
  });

  const uploadJson = await uploadRes.json().catch(() => ({}));
  if (!uploadRes.ok || !uploadJson.id) {
    throw new Error(
      `YouTube upload failed: ${uploadRes.status} ${JSON.stringify(uploadJson)}`
    );
  }

  return uploadJson;
}

async function resolveCrossPostUploadSource(env, prepared) {
  const video = prepared.video || {};
  if (prepared.variant === 'clean') {
    const candidateUrls = [
      video.muxStaticMp4Url,
      video.mp4_1080_url,
      video.mp4_720_url,
      video.mp4_480_url,
    ]
      .map((value) => String(value || '').trim())
      .filter((value) => value && !value.endsWith('.m3u8'));
    if (candidateUrls.length > 0) {
      return {
        status: 'ready',
        url: candidateUrls[0],
        contentType: 'video/mp4',
        filesize: 0,
      };
    }
  }

  const assetId = String(prepared.assetId || prepared.sourceAssetId || '').trim();
  const playbackId = String(prepared.playbackId || '').trim();
  if (!assetId || !playbackId) {
    return {
      status: 'preparing',
      url: '',
      contentType: 'video/mp4',
      filesize: 0,
    };
  }

  const mp4 = await ensureMuxStaticMp4(env, { assetId, playbackId });
  const docPath = `videos/${String(prepared.videoId || video.id || video.videoId || '').trim() || ''}`;
  if (docPath !== 'videos/') {
    if (prepared.variant === 'watermarked') {
      await firestorePatchDocument(env, docPath, {
        crossPostWatermark: {
          ...(video.crossPostWatermark && typeof video.crossPostWatermark === 'object'
            ? video.crossPostWatermark
            : {}),
          assetId,
          playbackId,
          mp4Url: mp4.url || '',
          mp4Status: mp4.status,
          updatedAt: { __timestamp: true },
        },
      });
    } else if (mp4.url) {
      await firestorePatchDocument(env, docPath, {
        muxStaticMp4Url: mp4.url,
        muxStaticMp4Status: mp4.status,
        updatedAt: { __timestamp: true },
      });
    }
  }

  return {
    status: mp4.status,
    url: mp4.url || '',
    contentType: mp4.contentType || 'video/mp4',
    filesize: mp4.filesize || 0,
  };
}

async function ensureWatermarkedCrossPostAsset(env, {
  uid,
  videoId,
  requiresWatermark,
  watermarkImageUrl,
  watermarkConfig,
  subscriptionTier,
}) {
  const docPath = `videos/${videoId}`;
  const video = await firestoreGetDocument(env, docPath);
  if (!video) {
    throw new Error('Video not found');
  }

  const ownerId = String(video.userId || video.creatorId || video.creator_id || '').trim();
  if (!ownerId || ownerId !== uid) {
    throw new Error('Forbidden');
  }

  if (!requiresWatermark) {
    const cleanPlaybackUrl =
      String(video.videoUrl || video.hlsUrl || video.playbackUrl || '').trim();
    if (!cleanPlaybackUrl) {
      throw new Error('Clean playback URL is not ready yet');
    }
    return {
      videoId,
      variant: 'clean',
      sourceAssetId: String(video.muxAssetId || '').trim(),
      assetId: String(video.muxAssetId || '').trim(),
      playbackId: String(video.muxPlaybackId || '').trim(),
      playbackUrl: cleanPlaybackUrl,
      thumbnailUrl: String(video.thumbnailUrl || '').trim(),
      status: String(video.status || 'ready'),
      video,
    };
  }

  const sourceAssetId = String(video.muxAssetId || '').trim();
  if (!sourceAssetId) {
    throw new Error('Source Mux asset is not ready for watermark preparation yet');
  }

  const overlayUrl = isAbsoluteUrl(watermarkImageUrl)
    ? watermarkImageUrl
    : env.CROSSPOST_WATERMARK_IMAGE_URL;
  if (!isAbsoluteUrl(overlayUrl)) {
    throw new Error('CROSSPOST_WATERMARK_IMAGE_URL must be configured with a public PNG/JPG URL');
  }

  const overlaySettings = normalizeMuxOverlaySettings(watermarkConfig || {});
  const configSignature = makeConfigSignature(sourceAssetId, overlayUrl, overlaySettings);
  const existing = video.crossPostWatermark;
  if (
    existing &&
    typeof existing === 'object' &&
    existing.configSignature === configSignature &&
    typeof existing.playbackUrl === 'string' &&
    existing.playbackUrl.trim() &&
    existing.status === 'ready'
  ) {
    return {
      videoId,
      variant: 'watermarked',
      sourceAssetId,
      assetId: String(existing.assetId || '').trim(),
      playbackId: String(existing.playbackId || '').trim(),
      playbackUrl: existing.playbackUrl.trim(),
      thumbnailUrl: String(existing.thumbnailUrl || '').trim(),
      status: 'ready',
      video,
      reused: true,
    };
  }

  if (
    existing &&
    typeof existing === 'object' &&
    existing.configSignature === configSignature &&
    typeof existing.assetId === 'string' &&
    existing.assetId.trim()
  ) {
    const existingAssetId = existing.assetId.trim();
    try {
      const muxAsset = await getMuxAsset(env, existingAssetId);
      const playbackIds = muxAsset.playback_ids || [];
      const publicPlayback =
        playbackIds.find((p) => p?.policy === 'public') || playbackIds[0];
      const playbackId = publicPlayback?.id || '';
      const status = muxAsset.status || existing.status || 'preparing';
      const playbackUrl = playbackId ? `${MUX_STREAM_BASE}/${playbackId}.m3u8` : '';
      const thumbnailUrl = playbackId
        ? `${IMAGE_MUX_BASE}/${playbackId}/thumbnail.jpg?width=720&time=0`
        : '';

      await firestorePatchDocument(env, docPath, {
        crossPostWatermark: {
          ...existing,
          assetId: existingAssetId,
          playbackId,
          playbackUrl,
          thumbnailUrl,
          status,
          updatedAt: { __timestamp: true },
        },
      });

      if (status === 'ready' && playbackUrl) {
        return {
          videoId,
          variant: 'watermarked',
          sourceAssetId,
          assetId: existingAssetId,
          playbackId,
          playbackUrl,
          thumbnailUrl,
          status,
          video,
          reused: true,
        };
      }
    } catch (e) {
      console.log('[crosspost-watermark] branded asset refresh failed', e.message);
    }
  }

  const created = await createWatermarkedMuxAsset(env, {
    sourceAssetId,
    videoId,
    overlayUrl,
    overlaySettings,
  });
  const createdAssetId = String(created.id || '').trim();
  if (!createdAssetId) {
    throw new Error('Mux did not return a branded asset id');
  }

  await firestorePatchDocument(env, docPath, {
    crossPostWatermark: {
      status: 'preparing',
      sourceAssetId,
      assetId: createdAssetId,
      playbackId: '',
      playbackUrl: '',
      thumbnailUrl: '',
      overlayUrl,
      overlaySettings,
      configSignature,
      subscriptionTier: subscriptionTier || 'starter',
      updatedAt: { __timestamp: true },
    },
  });

  return {
    videoId,
    variant: 'watermarked',
    sourceAssetId,
    assetId: createdAssetId,
    playbackId: '',
    playbackUrl: '',
    thumbnailUrl: '',
    status: 'preparing',
    video,
    reused: false,
  };
}

async function createWatermarkedMuxAsset(env, {
  sourceAssetId,
  videoId,
  overlayUrl,
  overlaySettings,
}) {
  const payload = {
    inputs: [
      {
        url: `mux://assets/${sourceAssetId}`,
      },
      {
        url: overlayUrl,
        overlay_settings: overlaySettings,
      },
    ],
    playback_policies: ['public'],
    video_quality: 'basic',
    passthrough: `${videoId}:watermarked`,
    static_renditions: {
      resolution: 'highest',
    },
    mp4_support: 'capped-1080p',
    meta: {
      external_id: videoId,
      source_asset_id: sourceAssetId,
      variant: 'crosspost_watermarked',
    },
  };
  const json = await muxRequest(env, '/video/v1/assets', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  return json.data;
}

async function getMuxAsset(env, assetId) {
  const json = await muxRequest(env, `/video/v1/assets/${assetId}`, {
    method: 'GET',
    headers: { 'Content-Type': undefined },
  });
  return json.data;
}

/** Mirrors mission_templates_config.dart + GamificationConstants (Dart). */
const cumulativeXpForLevel = [
  0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700, 3300, 4000, 4800, 5700,
  6700,
];

const MISSION_TEMPLATES = {
  daily_post_content_v1: {
    target: 1,
    rewardXp: 40,
    progressEventKeys: new Set([
      'content.video_uploaded',
      'content.post_created',
      'content.thread_created',
      'content.published',
    ]),
  },
  daily_comments_v1: {
    target: 2,
    rewardXp: 16,
    progressEventKeys: new Set(['engagement.comment_created']),
  },
  daily_plan_item_v1: {
    target: 1,
    rewardXp: 15,
    progressEventKeys: new Set(['content.plan_item_completed']),
  },
  daily_academy_lesson_v1: {
    target: 1,
    rewardXp: 20,
    progressEventKeys: new Set(['academy.lesson_completed']),
  },
  daily_streak_v1: {
    target: 1,
    rewardXp: 10,
    progressEventKeys: new Set(['activity.day_qualified', 'streak.extended']),
  },
  daily_creator_tool_v1: {
    target: 1,
    rewardXp: 12,
    progressEventKeys: new Set([
      'tool.caption_generated',
      'tool.tippy_used',
      'resource.tool_opened',
      'tool.caption_generator_opened',
    ]),
  },
  weekly_publish_3_v1: {
    target: 3,
    rewardXp: 80,
    progressEventKeys: new Set([
      'content.published',
      'content.video_uploaded',
      'content.post_created',
      'content.thread_created',
    ]),
  },
  weekly_active_days_v1: {
    target: 5,
    rewardXp: 50,
    progressEventKeys: new Set([
      'activity.day_qualified',
      'goal.active_days_target_hit',
    ]),
  },
  weekly_plan_items_5_v1: {
    target: 5,
    rewardXp: 75,
    progressEventKeys: new Set(['content.plan_item_completed']),
  },
  weekly_connect_2_v1: {
    target: 2,
    rewardXp: 20,
    progressEventKeys: new Set([
      'engagement.connection_created',
      'engagement.follow_created',
    ]),
  },
  weekly_lessons_3_v1: {
    target: 3,
    rewardXp: 60,
    progressEventKeys: new Set(['academy.lesson_completed']),
  },
  weekly_cross_post_2_v1: {
    target: 2,
    rewardXp: 30,
    progressEventKeys: new Set(['content.cross_posted']),
  },
  onboard_profile_v1: {
    target: 1,
    rewardXp: 30,
    progressEventKeys: new Set(['profile.completed']),
  },
  onboard_platform_v1: {
    target: 1,
    rewardXp: 25,
    progressEventKeys: new Set([
      'platform.connected',
      'milestone.first_platform_connected',
    ]),
  },
  onboard_first_post_v1: {
    target: 1,
    rewardXp: 40,
    progressEventKeys: new Set([
      'content.video_uploaded',
      'content.post_created',
      'content.thread_created',
      'milestone.first_post',
    ]),
  },
  onboard_first_lesson_v1: {
    target: 1,
    rewardXp: 20,
    progressEventKeys: new Set([
      'academy.lesson_completed',
      'milestone.first_lesson',
    ]),
  },
  onboard_first_plan_v1: {
    target: 1,
    rewardXp: 25,
    progressEventKeys: new Set([
      'content.plan_created',
      'milestone.first_plan',
    ]),
  },
};

function rankTitleForLevel(level) {
  if (level <= 2) return 'New Creator';
  if (level <= 4) return 'Active Creator';
  if (level <= 6) return 'Rising Creator';
  if (level <= 8) return 'Consistent Creator';
  if (level <= 10) return 'Community Builder';
  if (level <= 12) return 'Growth Creator';
  if (level <= 14) return 'Pro Creator';
  return 'Elite Creator';
}

function levelFromTotalXp(totalXp) {
  const t = cumulativeXpForLevel;
  let level = 1;
  for (let lv = 2; lv <= t.length; lv++) {
    if (totalXp >= t[lv - 1]) level = lv;
  }
  if (level < t.length) return level;
  let floor = t[t.length - 1];
  let lv = t.length;
  while (totalXp >= floor + 1000) {
    lv++;
    floor += 1000;
  }
  return lv;
}

function readInt(v) {
  if (v === undefined || v === null) return 0;
  if (typeof v === 'number' && !Number.isNaN(v)) return Math.trunc(v);
  if (typeof v === 'string') return parseInt(v, 10) || 0;
  return 0;
}

function readTs(val) {
  if (!val) return null;
  if (val instanceof Date) return val;
  if (typeof val.toDate === 'function') return val.toDate();
  return null;
}

function isMissionRowActive(m, now) {
  const status = String(m.status || 'active').toLowerCase();
  if (status === 'completed' || status === 'claimed' || status === 'rewarded') {
    return false;
  }
  if (m.rewardClaimed === true) return false;
  const exp = readTs(m.expiresAt);
  const start = readTs(m.startsAt);
  if (exp && exp < now) return false;
  if (start && start > now) return false;
  return true;
}

function applyEventToMissionList(list, eventType, now) {
  if (list === undefined || list === null) {
    return { list: undefined, xpGain: 0 };
  }
  if (!Array.isArray(list)) {
    return { list: list, xpGain: 0 };
  }
  let xpGain = 0;
  const out = list.map((raw) => {
    if (!raw || typeof raw !== 'object') return raw;
    const m = { ...raw };
    if (!isMissionRowActive(m, now)) return m;
    const tid = m.templateId || m.template_id;
    const tmpl = tid ? MISSION_TEMPLATES[tid] : null;
    if (!tmpl || !tmpl.progressEventKeys.has(eventType)) return m;
    const target = readInt(m.target) || tmpl.target || 1;
    let progress = readInt(m.progress);
    const rewardXp = readInt(m.rewardXp) || tmpl.rewardXp || 0;
    const st = String(m.status || 'active').toLowerCase();
    if (st === 'completed' || st === 'claimed' || progress >= target) return m;
    progress += 1;
    m.progress = progress;
    if (progress >= target) {
      m.status = 'completed';
      m.completedAt = new Date();
      m.rewardClaimed = true;
      xpGain += rewardXp;
    }
    return m;
  });
  return { list: out, xpGain };
}

/** Merges `gamification` and mission arrays; preserves existing gamification keys (Part B: lib/features/gamification/firestore_user_shape.md). */
async function applyGamificationMissions(env, uid, eventType, eventId) {
  const auditPath = `users/${uid}/gamification_audit/${eventId}`;
  const existingAudit = await firestoreGetDocument(env, auditPath);
  if (existingAudit) return;
  const userPath = `users/${uid}`;
  const data = (await firestoreGetDocument(env, userPath)) || {};
  const hasDaily = Array.isArray(data.dailyMissions);
  const hasWeekly = Array.isArray(data.missions);
  const now = new Date();
  if (!hasDaily && !hasWeekly) {
    await firestoreWrite(
      env,
      'POST',
      `users/${uid}/gamification_audit?documentId=${eventId}`,
      {
        eventId,
        uid,
        type: eventType,
        xpGained: 0,
        processedAt: { __timestamp: true },
      }
    );
    return;
  }
  const dailyRaw = hasDaily ? data.dailyMissions : undefined;
  const missionsRaw = hasWeekly ? data.missions : undefined;
  const r1 = applyEventToMissionList(dailyRaw, eventType, now);
  const r2 = applyEventToMissionList(missionsRaw, eventType, now);
  const xpGain = r1.xpGain + r2.xpGain;
  const gam =
    data.gamification && typeof data.gamification === 'object'
      ? data.gamification
      : {};
  const currentXp =
    readInt(gam.totalXp) ||
    readInt(gam.total_xp) ||
    readInt(gam.xp);
  const newXp = currentXp + xpGain;
  const level = levelFromTotalXp(newXp);
  const rankTitle = rankTitleForLevel(level);
  const mergedGam = {
    ...gam,
    totalXp: newXp,
    level,
    rankTitle,
    updatedAt: { __timestamp: true },
  };
  const patchFields = {};
  if (r1.list !== undefined) patchFields.dailyMissions = r1.list;
  if (r2.list !== undefined) patchFields.missions = r2.list;
  patchFields.gamification = mergedGam;
  await firestorePatchDocument(env, userPath, patchFields);
  await firestoreWrite(
    env,
    'POST',
    `users/${uid}/gamification_audit?documentId=${eventId}`,
    {
      eventId,
      uid,
      type: eventType,
      xpGained: xpGain,
      processedAt: { __timestamp: true },
    }
  );
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
        static_renditions: {
          resolution: 'highest',
        },
        mp4_support: 'capped-1080p',
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
      if (path === '/api/crosspost/prepare-watermarked' && request.method === 'POST') {
        return await handlePrepareWatermarkedCrossPost(request, env, cors);
      }
      if (path === '/api/crosspost/publish' && request.method === 'POST') {
        return await handleCrossPostPublish(request, env, cors);
      }
      if (path === '/webhooks/mux' && request.method === 'POST') {
        return await handleMuxWebhook(request, env, cors);
      }
      if (path === '/mux/backfill-assets' && request.method === 'POST') {
        return await handleBackfillAssets(request, env, cors);
      }
      if (path === '/mux/backfill-feed-fields' && request.method === 'POST') {
        return await handleBackfillFeedFields(request, env, cors);
      }
      if (path === '/media/upload' && request.method === 'POST') {
        return await handleMediaUpload(request, env, cors);
      }
      if (path === '/gamification/events' && request.method === 'POST') {
        return await handleGamificationEvent(request, env, cors);
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

async function handleGamificationEvent(request, env, cors) {
  const auth = request.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) {
    throw new Error('Missing Authorization: Bearer <firebase_id_token>');
  }
  const idToken = auth.slice(7).trim();
  const { uid: verifiedUid } = await verifyFirebaseToken(
    idToken,
    env.FIREBASE_WEB_API_KEY
  );
  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, {}, cors);
  }
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    return jsonResponse({ error: 'Body must be a JSON object' }, 400, {}, cors);
  }
  const eventId = body.eventId;
  const bodyUid = body.uid;
  const eventType = body.type;
  if (typeof eventId !== 'string' || eventId.trim() === '') {
    return jsonResponse(
      { error: 'eventId is required (non-empty string)' },
      400,
      {},
      cors
    );
  }
  if (typeof bodyUid !== 'string' || bodyUid.trim() === '') {
    return jsonResponse(
      { error: 'uid is required (non-empty string)' },
      400,
      {},
      cors
    );
  }
  if (typeof eventType !== 'string' || eventType.trim() === '') {
    return jsonResponse(
      { error: 'type is required (non-empty string)' },
      400,
      {},
      cors
    );
  }
  if (bodyUid.trim() !== verifiedUid) {
    return jsonResponse(
      { error: 'uid must match authenticated user' },
      403,
      {},
      cors
    );
  }
  const id = eventId.trim();
  const typeStr = eventType.trim();
  try {
    await firestoreWrite(env, 'POST', `gamification_events?documentId=${id}`, {
      uid: verifiedUid,
      type: typeStr,
      createdAt: { __timestamp: true },
    });
  } catch (e) {
    const msg = String(e.message || '');
    if (msg.includes('409') || msg.includes('ALREADY_EXISTS')) {
      const auditPath = `users/${verifiedUid}/gamification_audit/${id}`;
      const audit = await firestoreGetDocument(env, auditPath);
      if (!audit) {
        await applyGamificationMissions(env, verifiedUid, typeStr, id);
      }
      return jsonResponse({ ok: true }, 200, {}, cors);
    }
    throw e;
  }
  await applyGamificationMissions(env, verifiedUid, typeStr, id);
  return jsonResponse({ ok: true }, 200, {}, cors);
}

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

async function handlePrepareWatermarkedCrossPost(request, env, cors) {
  const auth = request.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) {
    return jsonResponse(
      { error: 'Missing Authorization: Bearer <firebase_id_token>' },
      401,
      {},
      cors
    );
  }

  const idToken = auth.slice(7).trim();
  const { uid } = await verifyFirebaseToken(idToken, env.FIREBASE_WEB_API_KEY);

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, {}, cors);
  }

  const videoId = String(body?.videoId || '').trim();
  if (!videoId) {
    return jsonResponse({ error: 'videoId is required' }, 400, {}, cors);
  }

  const requiresWatermark = body?.requiresWatermark === true;
  if (!requiresWatermark) {
    return jsonResponse(
      { error: 'requiresWatermark must be true for branded asset preparation' },
      400,
      {},
      cors
    );
  }

  const docPath = `videos/${videoId}`;
  const video = await firestoreGetDocument(env, docPath);
  if (!video) {
    return jsonResponse({ error: 'Video not found' }, 404, {}, cors);
  }

  const ownerId = String(video.userId || video.creatorId || video.creator_id || '').trim();
  if (!ownerId || ownerId !== uid) {
    return jsonResponse({ error: 'Forbidden' }, 403, {}, cors);
  }

  const sourceAssetId = String(video.muxAssetId || '').trim();
  if (!sourceAssetId) {
    return jsonResponse(
      { error: 'Source Mux asset is not ready for watermark preparation yet' },
      409,
      {},
      cors
    );
  }

  const overlayUrl = isAbsoluteUrl(body?.watermarkImageUrl)
    ? body.watermarkImageUrl
    : env.CROSSPOST_WATERMARK_IMAGE_URL;
  if (!isAbsoluteUrl(overlayUrl)) {
    return jsonResponse(
      { error: 'CROSSPOST_WATERMARK_IMAGE_URL must be configured with a public PNG/JPG URL' },
      503,
      {},
      cors
    );
  }

  const overlaySettings = normalizeMuxOverlaySettings(body?.watermarkConfig || {});
  const configSignature = makeConfigSignature(
    sourceAssetId,
    overlayUrl,
    overlaySettings
  );

  const existing = video.crossPostWatermark;
  if (
    existing &&
    typeof existing === 'object' &&
    existing.configSignature === configSignature &&
    typeof existing.assetId === 'string' &&
    existing.assetId.trim()
  ) {
    const existingAssetId = existing.assetId.trim();
    try {
      const muxAsset = await getMuxAsset(env, existingAssetId);
      const playbackIds = muxAsset.playback_ids || [];
      const publicPlayback =
        playbackIds.find((p) => p?.policy === 'public') || playbackIds[0];
      const playbackId = publicPlayback?.id || existing.playbackId || '';
      const status = muxAsset.status || existing.status || 'preparing';
      const thumbnailUrl = playbackId
        ? `${IMAGE_MUX_BASE}/${playbackId}/thumbnail.jpg?width=720&time=0`
        : null;
      const playbackUrl = playbackId
        ? `${MUX_STREAM_BASE}/${playbackId}.m3u8`
        : null;

      await firestorePatchDocument(env, docPath, {
        crossPostWatermark: {
          ...existing,
          assetId: existingAssetId,
          playbackId,
          playbackUrl,
          thumbnailUrl,
          status,
          updatedAt: { __timestamp: true },
        },
      });

      return jsonResponse(
        {
          ok: true,
          videoId,
          assetId: existingAssetId,
          playbackId,
          playbackUrl,
          thumbnailUrl,
          status,
          reused: true,
        },
        200,
        {},
        cors
      );
    } catch (e) {
      console.log('[crosspost-watermark] existing branded asset refresh failed', e.message);
    }
  }

  const created = await createWatermarkedMuxAsset(env, {
    sourceAssetId,
    videoId,
    overlayUrl,
    overlaySettings,
  });

  const createdAssetId = String(created.id || '').trim();
  if (!createdAssetId) {
    return jsonResponse(
      { error: 'Mux did not return a branded asset id' },
      502,
      {},
      cors
    );
  }

  await firestorePatchDocument(env, docPath, {
    crossPostWatermark: {
      status: 'preparing',
      sourceAssetId,
      assetId: createdAssetId,
      playbackId: '',
      playbackUrl: '',
      thumbnailUrl: '',
      overlayUrl,
      overlaySettings,
      configSignature,
      subscriptionTier: body?.subscriptionTier || 'starter',
      updatedAt: { __timestamp: true },
    },
  });

  return jsonResponse(
    {
      ok: true,
      videoId,
      assetId: createdAssetId,
      status: 'preparing',
      reused: false,
    },
    202,
    {},
    cors
  );
}

async function handleCrossPostPublish(request, env, cors) {
  const auth = request.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) {
    return jsonResponse(
      { error: 'Missing Authorization: Bearer <firebase_id_token>' },
      401,
      {},
      cors
    );
  }

  const idToken = auth.slice(7).trim();
  const { uid } = await verifyFirebaseToken(idToken, env.FIREBASE_WEB_API_KEY);

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, {}, cors);
  }

  const platform = String(body?.platform || '').trim().toLowerCase();
  const videoId = String(body?.videoId || '').trim();
  if (!platform) {
    return jsonResponse({ error: 'platform is required' }, 400, {}, cors);
  }
  if (!videoId) {
    return jsonResponse({ error: 'videoId is required' }, 400, {}, cors);
  }

  let prepared;
  try {
    prepared = await ensureWatermarkedCrossPostAsset(env, {
      uid,
      videoId,
      requiresWatermark: body?.requiresWatermark === true,
      watermarkImageUrl: body?.watermarkImageUrl,
      watermarkConfig: body?.watermarkConfig,
      subscriptionTier: body?.subscriptionTier,
    });
  } catch (e) {
    const message = String(e.message || e);
    const status =
      message === 'Forbidden' ? 403 :
      message === 'Video not found' ? 404 :
      message.includes('not ready') ? 409 :
      message.includes('configured') ? 503 : 500;
    return jsonResponse({ error: message }, status, {}, cors);
  }

  if (prepared.status !== 'ready' || !prepared.playbackUrl) {
    return jsonResponse(
      {
        error: 'Cross-post source is still preparing',
        status: prepared.status,
        videoId,
        platform,
        sourceVariant: prepared.variant,
        retryable: true,
      },
      409,
      {},
      cors
    );
  }

  const uploadSource = await resolveCrossPostUploadSource(env, prepared);
  if (uploadSource.status !== 'ready' || !uploadSource.url) {
    return jsonResponse(
      {
        error: 'Cross-post MP4 source is still preparing',
        status: uploadSource.status,
        videoId,
        platform,
        sourceVariant: prepared.variant,
        retryable: true,
      },
      409,
      {},
      cors
    );
  }

  if (platform !== 'youtube') {
    const platformMessage = `Cross-post adapter for ${platform} is not implemented in this repo yet.`;
    return jsonResponse(
      {
        error: platformMessage,
        platform,
        videoId,
        sourceVariant: prepared.variant,
        sourcePlaybackUrl: prepared.playbackUrl,
        sourceUploadUrl: uploadSource.url,
        thumbnailUrl: prepared.thumbnailUrl,
        requiresWatermark: body?.requiresWatermark === true,
        adapterStatus: 'missing',
        retryable: false,
      },
      501,
      {},
      cors
    );
  }

  const youtubeAuth = await getYoutubePlatformAuth(env, uid);
  if (!youtubeAuth) {
    return jsonResponse(
      {
        error: 'YouTube is not connected for this user',
        platform,
        videoId,
      },
      409,
      {},
      cors
    );
  }

  const refreshToken = String(youtubeAuth.refreshToken || '').trim();
  if (!refreshToken) {
    return jsonResponse(
      {
        error: 'YouTube connection is missing a refresh token',
        platform,
        videoId,
      },
      409,
      {},
      cors
    );
  }

  let refreshed;
  try {
    refreshed = await refreshYoutubeAccessToken(env, { refreshToken });
  } catch (e) {
    return jsonResponse(
      {
        error: String(e.message || e),
        platform,
        videoId,
      },
      502,
      {},
      cors
    );
  }

  const newRefreshToken = String(refreshed.refresh_token || '').trim();
  await firestorePatchDocument(env, `users/${uid}/platform_auth/youtube`, {
    accessToken: String(refreshed.access_token || '').trim(),
    refreshToken: newRefreshToken || refreshToken,
    tokenType: String(refreshed.token_type || youtubeAuth.tokenType || 'Bearer'),
    scope: String(refreshed.scope || youtubeAuth.scope || ''),
    expiresAt: new Date(
      Date.now() + Number(refreshed.expires_in || 3600) * 1000
    ),
    updatedAt: { __timestamp: true },
  });

  const video = prepared.video || {};
  const caption = String(body?.caption || video.caption || '').trim();
  const uploadResult = await uploadVideoToYoutube({
    accessToken: String(refreshed.access_token || '').trim(),
    sourceUrl: uploadSource.url,
    sourceContentLength: uploadSource.filesize || 0,
    title: sanitizeYoutubeTitle(caption),
    description: sanitizeYoutubeDescription(caption),
    privacyStatus: mapPrivacyToYoutubeStatus(
      body?.privacy || video.visibility || video.privacy
    ),
  });

  await firestorePatchDocument(env, `videos/${videoId}`, {
    lastCrossPostResult: {
      platform: 'youtube',
      externalVideoId: String(uploadResult.id || ''),
      sourceVariant: prepared.variant,
      sourceUploadUrl: uploadSource.url,
      requiresWatermark: body?.requiresWatermark === true,
      publishedAt: { __timestamp: true },
      status: 'success',
    },
    updatedAt: { __timestamp: true },
  });

  return jsonResponse(
    {
      ok: true,
      platform: 'youtube',
      videoId,
      externalVideoId: String(uploadResult.id || ''),
      sourceVariant: prepared.variant,
      requiresWatermark: body?.requiresWatermark === true,
      adapterStatus: 'published',
    },
    200,
    {},
    cors
  );
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
  if (
    eventType !== 'video.asset.ready' &&
    eventType !== 'video.asset.static_renditions.ready'
  ) {
    console.log('[MuxWebhook] ignored type:', eventType);
    return jsonResponse({ received: eventType }, 200, {}, cors);
  }

  const data = payload.data || payload.object || payload;
  if (!data) return jsonResponse({ ok: true }, 200, {}, cors);

  const passthrough = String(data.passthrough ?? data.passthrough_id ?? '').trim();
  if (!passthrough) {
    console.log('[MuxWebhook] no passthrough, assetId:', data.id);
    return jsonResponse({ ok: true, warn: 'no passthrough' }, 200, {}, cors);
  }
  const isWatermarkedVariant = passthrough.endsWith(':watermarked');
  const videoId = isWatermarkedVariant
    ? passthrough.slice(0, -':watermarked'.length)
    : passthrough;

  const playbackIds = data.playback_ids || [];
  const publicPlayback = playbackIds.find((p) => p?.policy === 'public') || playbackIds[0];
  if (!publicPlayback?.id) {
    console.log('[MuxWebhook] no playback id, videoId:', videoId, 'assetId:', data.id);
    return jsonResponse({ ok: true, warn: 'no playback id' }, 200, {}, cors);
  }

  const playbackId = publicPlayback.id;
  const { adaptiveHlsUrl, highHlsUrl } = buildMuxPlaybackUrls(playbackId);
  const hlsUrl = adaptiveHlsUrl;
  const playbackUrl = adaptiveHlsUrl;
  const thumbnailUrl = `${IMAGE_MUX_BASE}/${playbackId}/thumbnail.jpg?width=720&time=0`;
  const staticMp4 = extractReadyMuxStaticMp4(data, playbackId);
  const duration = data.duration != null ? Math.round(data.duration) : null;
  const isDraft = (data.meta && data.meta.is_draft === 'true');

  const DURATION_MIN = 1;
  const DURATION_MAX = 300;

  const durationOk = duration != null && duration >= DURATION_MIN && duration <= DURATION_MAX;
  const hasThumbnail = thumbnailUrl != null && thumbnailUrl.length > 0;
  const allGatesPass = durationOk && hasThumbnail && !isDraft;

  const processingState = allGatesPass ? 'ready' : 'failed';
  const isReadyForFeed = allGatesPass;

  if (isWatermarkedVariant) {
    const existing = (await firestoreGetDocument(env, `videos/${videoId}`)) || {};
    const crossPostWatermark =
      existing.crossPostWatermark && typeof existing.crossPostWatermark === 'object'
        ? existing.crossPostWatermark
        : {};
    await firestoreWrite(env, 'PATCH', `videos/${videoId}`, {
      crossPostWatermark: {
        ...crossPostWatermark,
        sourceAssetId: crossPostWatermark.sourceAssetId || '',
        assetId: data.id || '',
        playbackId,
        playbackUrl,
        thumbnailUrl,
        mp4Url: staticMp4.url || crossPostWatermark.mp4Url || '',
        mp4Status: staticMp4.status || crossPostWatermark.mp4Status || '',
        status: 'ready',
        updatedAt: { __timestamp: true },
      },
    });
    return jsonResponse(
      { ok: true, videoId, variant: 'crosspost_watermarked', status: 'ready' },
      200,
      {},
      cors
    );
  }

  const fields = {
    hlsUrl,
    hls_url: hlsUrl,
    muxAdaptiveHlsUrl: adaptiveHlsUrl,
    muxHighHlsUrl: highHlsUrl,
    mp4_720_url: highHlsUrl,
    muxStaticMp4Url: staticMp4.url || '',
    muxStaticMp4Status: staticMp4.status || '',
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
      const { adaptiveHlsUrl, highHlsUrl } = buildMuxPlaybackUrls(playbackId);
      const hlsUrl = adaptiveHlsUrl;
      const thumbnailUrl = `${IMAGE_MUX_BASE}/${playbackId}/thumbnail.jpg?width=720&time=0`;
      const userId = (data.meta && data.meta.creator_id) ? String(data.meta.creator_id) : '';

      const fields = {
        hlsUrl,
        hls_url: hlsUrl,
        muxAdaptiveHlsUrl: adaptiveHlsUrl,
        muxHighHlsUrl: highHlsUrl,
        mp4_720_url: highHlsUrl,
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

async function handleBackfillFeedFields(request, env, cors) {
  const secret = request.headers.get('X-Backfill-Secret');
  if (!env.MUX_BACKFILL_SECRET || secret !== env.MUX_BACKFILL_SECRET) {
    return jsonResponse({ error: 'Unauthorized' }, 401, {}, cors);
  }

  const body = await request.json().catch(() => ({}));
  const dryRun = body?.dryRun !== false;
  const limit = Math.max(
    1,
    Math.min(500, Number.parseInt(String(body?.limit || '200'), 10) || 200)
  );

  const rows = await firestoreRunQuery(env, {
    from: [{ collectionId: 'videos' }],
    orderBy: [
      {
        field: { fieldPath: 'createdAt' },
        direction: 'DESCENDING',
      },
    ],
    limit,
  });

  let scanned = 0;
  let candidates = 0;
  let updated = 0;
  const results = [];

  for (const row of rows) {
    scanned += 1;
    const data = row?.data || {};
    const videoId = String(data.__id || '').trim();
    if (!videoId) continue;

    const update = buildFeedFieldBackfillUpdate(data);
    if (!update) continue;

    candidates += 1;
    results.push({
      videoId,
      muxPlaybackId: String(data.muxPlaybackId || '').trim(),
      currentStatus: String(data.status || ''),
      ready: data.isReadyForFeed === true,
      playableUrl: resolvePlayableFeedUrl(data),
    });

    if (!dryRun) {
      await firestoreWrite(env, 'PATCH', `videos/${videoId}`, update);
      updated += 1;
    }
  }

  return jsonResponse(
    {
      scanned,
      candidates,
      updated,
      dryRun,
      results,
    },
    200,
    {},
    cors
  );
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
