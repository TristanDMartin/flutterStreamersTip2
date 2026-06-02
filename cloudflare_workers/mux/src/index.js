/**
 * StreamersTip Mux API — Cloudflare Worker
 *
 * Routes:
 *   POST /mux/direct-upload — Allocate videoId, pending Firestore doc, Mux URL
 *   POST /videos/delete — Soft-delete video (same contract as Firebase deleteVideo)
 *   POST /webhooks/mux — Mux webhook handler
 *   POST /gamification/events — Trusted gamification events
 */

import {
  allocateVideoIdForNewUpload,
  generateVideoId,
  pendingVideoFields,
  failedUploadFields,
  isVideoDeleted,
} from './video_lifecycle.js';

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
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
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
    status: 'ready',
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

function todayKeyUtc(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

function yesterdayKeyUtc(date = new Date()) {
  const d = new Date(date);
  d.setUTCDate(d.getUTCDate() - 1);
  return todayKeyUtc(d);
}

function buildDailyQualificationUpdates(userData) {
  const today = todayKeyUtc();
  const yesterday = yesterdayKeyUtc();
  const gam =
    userData.gamification && typeof userData.gamification === 'object'
      ? userData.gamification
      : {};
  const prevDate =
    gam.lastActiveDate ||
    userData.lastActiveDate ||
    (userData.progressionSummary && userData.progressionSummary.lastActiveDate) ||
    null;
  if (prevDate === today) {
    return { skipped: true };
  }
  let streakCount = readInt(
    gam.streakCount ?? gam.streakDays ?? userData.streakCount ?? userData.streakDays,
    0,
  );
  let streakExtended = false;
  if (prevDate === yesterday) {
    streakCount = Math.max(1, streakCount) + 1;
    streakExtended = true;
  } else {
    streakCount = 1;
    streakExtended = true;
  }
  const longestStreak = Math.max(
    streakCount,
    readInt(gam.longestStreak ?? userData.longestStreak, 0),
  );
  const mergedGam = {
    ...gam,
    lastActiveDate: today,
    lastQualifiedActivityAt: { __timestamp: true },
    streakCount,
    streakDays: streakCount,
    longestStreak,
    updatedAt: { __timestamp: true },
  };
  return {
    skipped: false,
    streakExtended,
    updates: {
      lastActiveDate: today,
      lastQualifiedActivityAt: { __timestamp: true },
      streakCount,
      streakDays: streakCount,
      longestStreak,
      gamification: mergedGam,
    },
  };
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
  const hasMissions = hasDaily || hasWeekly;
  const now = new Date();
  if (!hasMissions && eventType !== 'activity.day_qualified') {
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
  let dailyRaw = hasDaily ? data.dailyMissions : undefined;
  let missionsRaw = hasWeekly ? data.missions : undefined;
  let xpGain = 0;
  if (hasMissions) {
    const r1 = applyEventToMissionList(dailyRaw, eventType, now);
    const r2 = applyEventToMissionList(missionsRaw, eventType, now);
    dailyRaw = r1.list !== undefined ? r1.list : dailyRaw;
    missionsRaw = r2.list !== undefined ? r2.list : missionsRaw;
    xpGain = r1.xpGain + r2.xpGain;
  }
  if (eventType === 'activity.day_qualified') {
    const qual = buildDailyQualificationUpdates(data);
    if (!qual.skipped && qual.updates && hasMissions && qual.streakExtended) {
      const r3 = applyEventToMissionList(dailyRaw, 'streak.extended', now);
      const r4 = applyEventToMissionList(missionsRaw, 'streak.extended', now);
      dailyRaw = r3.list !== undefined ? r3.list : dailyRaw;
      missionsRaw = r4.list !== undefined ? r4.list : missionsRaw;
      xpGain += r3.xpGain + r4.xpGain;
    }
  }
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
  const patchFields = { gamification: mergedGam };
  if (dailyRaw !== undefined && hasDaily) patchFields.dailyMissions = dailyRaw;
  if (missionsRaw !== undefined && hasWeekly) patchFields.missions = missionsRaw;
  if (eventType === 'activity.day_qualified') {
    const qual = buildDailyQualificationUpdates(data);
    if (!qual.skipped && qual.updates) {
      patchFields.lastActiveDate = qual.updates.lastActiveDate;
      patchFields.lastQualifiedActivityAt = qual.updates.lastQualifiedActivityAt;
      patchFields.streakCount = qual.updates.streakCount;
      patchFields.streakDays = qual.updates.streakDays;
      patchFields.longestStreak = qual.updates.longestStreak;
      patchFields.gamification = {
        ...mergedGam,
        ...qual.updates.gamification,
        totalXp: newXp,
        level,
        rankTitle,
      };
    }
  }
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

function findMissionRow(list, missionId) {
  if (!Array.isArray(list)) return null;
  const index = list.findIndex((raw) => {
    if (!raw || typeof raw !== 'object') return false;
    return String(raw.missionId || raw.id || '').trim() === missionId;
  });
  if (index < 0) return null;
  return { index, mission: { ...list[index] } };
}

function claimMissionInList(list, missionId, now) {
  if (!Array.isArray(list)) {
    return { found: false, updated: false, alreadyClaimed: false, xpGain: 0, list };
  }
  const match = findMissionRow(list, missionId);
  if (!match) {
    return { found: false, updated: false, alreadyClaimed: false, xpGain: 0, list };
  }
  const mission = match.mission;
  const target = readInt(mission.target) || 1;
  const progress = readInt(mission.progress);
  const completed =
    String(mission.status || '').toLowerCase() === 'completed' ||
    String(mission.status || '').toLowerCase() === 'claimed' ||
    String(mission.status || '').toLowerCase() === 'rewarded' ||
    (target > 0 && progress >= target);
  if (!completed) {
    return {
      found: true,
      updated: false,
      alreadyClaimed: false,
      incomplete: true,
      xpGain: 0,
      list,
    };
  }
  const alreadyClaimed =
    mission.rewardClaimed === true ||
    String(mission.status || '').toLowerCase() === 'claimed' ||
    String(mission.status || '').toLowerCase() === 'rewarded';
  if (alreadyClaimed) {
    return {
      found: true,
      updated: false,
      alreadyClaimed: true,
      xpGain: 0,
      list,
    };
  }
  mission.rewardClaimed = true;
  mission.status = 'claimed';
  mission.claimedAt = now;
  if (!mission.completedAt) {
    mission.completedAt = now;
  }
  const next = [...list];
  next[match.index] = mission;
  return {
    found: true,
    updated: true,
    alreadyClaimed: false,
    xpGain: readInt(mission.rewardXp),
    list: next,
  };
}

async function claimMissionReward(env, uid, missionId) {
  const auditPath = `users/${uid}/gamification_claim_audit/${missionId}`;
  const existingAudit = await firestoreGetDocument(env, auditPath);
  if (existingAudit) {
    return {
      missionId,
      alreadyClaimed: true,
      xpGranted: readInt(existingAudit.xpGranted),
    };
  }

  const userPath = `users/${uid}`;
  const data = (await firestoreGetDocument(env, userPath)) || {};
  const now = new Date();
  const daily = claimMissionInList(data.dailyMissions, missionId, now);
  const weekly = claimMissionInList(data.missions, missionId, now);
  const match = daily.found ? daily : weekly;

  if (!daily.found && !weekly.found) {
    return {
      error: 'Mission not found',
      status: 404,
    };
  }
  if (match.incomplete) {
    return {
      error: 'Mission is not complete yet',
      status: 409,
    };
  }
  if (match.alreadyClaimed) {
    await firestoreWrite(
      env,
      'POST',
      `users/${uid}/gamification_claim_audit?documentId=${missionId}`,
      {
        missionId,
        uid,
        xpGranted: 0,
        processedAt: { __timestamp: true },
      }
    );
    return {
      missionId,
      alreadyClaimed: true,
      xpGranted: 0,
    };
  }

  const xpGain = daily.xpGain + weekly.xpGain;
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
  const patchFields = {
    gamification: mergedGam,
  };
  if (daily.found) patchFields.dailyMissions = daily.list;
  if (weekly.found) patchFields.missions = weekly.list;
  await firestorePatchDocument(env, userPath, patchFields);
  await firestoreWrite(
    env,
    'POST',
    `users/${uid}/gamification_claim_audit?documentId=${missionId}`,
    {
      missionId,
      uid,
      xpGranted: xpGain,
      processedAt: { __timestamp: true },
    }
  );
  return {
    missionId,
    alreadyClaimed: false,
    xpGranted: xpGain,
    level,
    totalXp: newXp,
  };
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
      if (path === '/videos/delete' && request.method === 'POST') {
        return await handleDeleteVideo(request, env, cors);
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
      if (path === '/gamification/missions/claim' && request.method === 'POST') {
        return await handleMissionClaim(request, env, cors);
      }
      if (path === '/creator-score/sync' && request.method === 'POST') {
        return await handleCreatorScoreSync(request, env, cors);
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

const CREATOR_SCORE_COUNTABLE_STATUSES = new Set(['ready', 'published', 'active']);
const CREATOR_SCORE_HIDDEN_STATUSES = new Set([
  'draft',
  'scheduled',
  'processing',
  'failed',
  'archived',
  'deleted',
  'hidden',
  'moderation',
  'private',
]);

function readCreatorScoreInt(value, fallback = 0) {
  if (value === undefined || value === null) return fallback;
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === 'string') return parseInt(value, 10) || fallback;
  return fallback;
}

function clampCreatorScore(value, min = 0, max = 100) {
  return Math.max(min, Math.min(max, Math.round(value)));
}

function mapValue(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function creatorCounter(data, names) {
  for (const name of names) {
    const n = readCreatorScoreInt(data[name], -1);
    if (n >= 0) return n;
  }
  const stats = mapValue(data.stats);
  for (const name of names) {
    const n = readCreatorScoreInt(stats[name], -1);
    if (n >= 0) return n;
  }
  return 0;
}

function timestampMillis(value) {
  if (!value) return 0;
  if (value instanceof Date) return value.getTime();
  const date = new Date(value);
  const time = date.getTime();
  return Number.isFinite(time) ? time : 0;
}

function hasCreatorText(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function hasCreatorList(value) {
  return Array.isArray(value) && value.length > 0;
}

function isCreatorScoreCountableVideo(data = {}) {
  if (data.deleted === true || data.isDeleted === true || data.visible === false) return false;
  const status = String(data.status || 'draft').toLowerCase();
  const privacy = String(data.privacy || data.visibility || 'private').toLowerCase();
  return CREATOR_SCORE_COUNTABLE_STATUSES.has(status) &&
    !CREATOR_SCORE_HIDDEN_STATUSES.has(status) &&
    privacy !== 'private';
}

async function queryCreatorVideos(env, uid, fieldName) {
  const rows = await firestoreRunQuery(env, {
    from: [{ collectionId: 'videos' }],
    where: {
      fieldFilter: {
        field: { fieldPath: fieldName },
        op: 'EQUAL',
        value: { stringValue: uid },
      },
    },
    limit: 200,
  });
  return rows.map((row) => row.data || {});
}

async function getCreatorVideos(env, uid) {
  const seen = new Map();
  const results = await Promise.allSettled([
    queryCreatorVideos(env, uid, 'userId'),
    queryCreatorVideos(env, uid, 'creatorId'),
  ]);
  for (const result of results) {
    if (result.status !== 'fulfilled') continue;
    for (const video of result.value) {
      const id = video.__id || JSON.stringify(video);
      seen.set(id, video);
    }
  }
  return Array.from(seen.values());
}

async function getScheduledPostCount(env, uid) {
  try {
    const rows = await firestoreRunQuery(env, {
      from: [{ collectionId: 'scheduled_posts' }],
      where: {
        compositeFilter: {
          op: 'AND',
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: 'userId' },
                op: 'EQUAL',
                value: { stringValue: uid },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: 'status' },
                op: 'EQUAL',
                value: { stringValue: 'scheduled' },
              },
            },
          ],
        },
      },
      limit: 50,
    });
    return rows.length;
  } catch (e) {
    console.warn('creator score scheduled_posts query skipped', uid, e.message || e);
    return 0;
  }
}

async function getCompletedMissionCount(env, uid) {
  try {
    const rows = await firestoreRunQuery(env, {
      from: [{ collectionId: 'progression' }],
      where: {
        compositeFilter: {
          op: 'AND',
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: '__name__' },
                op: 'GREATER_THAN_OR_EQUAL',
                value: {
                  referenceValue:
                    `projects/${env.FIREBASE_PROJECT_ID || 'streamerstip-6cfdb'}/databases/(default)/documents/users/${uid}/progression/`,
                },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: 'completed' },
                op: 'EQUAL',
                value: { booleanValue: true },
              },
            },
          ],
        },
      },
      limit: 100,
    });
    return rows.length;
  } catch (e) {
    console.warn('creator score progression query skipped', uid, e.message || e);
    return 0;
  }
}

function creatorProfileCompletionScore(userData) {
  const checks = [
    hasCreatorText(userData.avatarURL) || hasCreatorText(userData.avatarUrl) || hasCreatorText(userData.photoURL),
    hasCreatorText(userData.bio),
    hasCreatorList(userData.hashtags) || hasCreatorList(userData.tags),
    hasCreatorList(userData.platforms) || hasCreatorList(userData.connectedPlatforms),
    hasCreatorText(userData.displayName) && hasCreatorText(userData.username),
  ];
  return clampCreatorScore((checks.filter(Boolean).length / checks.length) * 100);
}

function creatorConsistencyScore(userData, videos, completedMissions) {
  const now = Date.now();
  const sevenDays = 7 * 24 * 60 * 60 * 1000;
  const thirtyDays = 30 * 24 * 60 * 60 * 1000;
  let recent7 = 0;
  let recent30 = 0;
  for (const video of videos) {
    const at = timestampMillis(video.createdAt || video.publishedAt || video.timestamp);
    if (!at) continue;
    if (now - at <= sevenDays) recent7 += 1;
    if (now - at <= thirtyDays) recent30 += 1;
  }
  const gam = mapValue(userData.gamification);
  const streak = readCreatorScoreInt(userData.streakCount) ||
    readCreatorScoreInt(userData.streakDays) ||
    readCreatorScoreInt(gam.streakCount);
  return clampCreatorScore(
    Math.min(recent7, 3) * 18 +
    Math.min(recent30, 8) * 4 +
    Math.min(streak, 14) * 2 +
    Math.min(completedMissions, 10) * 2
  );
}

function creatorContentScore(userData, videos, scheduledPostCount) {
  const countable = videos.filter(isCreatorScoreCountableVideo);
  const postCount = Math.max(
    countable.length,
    creatorCounter(userData, ['postCount', 'postsCount', 'publishedPostCount'])
  );
  const drafts = creatorCounter(userData, ['draftCount', 'draftsCount']);
  return clampCreatorScore(
    Math.min(postCount, 20) * 4 +
    Math.min(scheduledPostCount, 5) * 4 +
    Math.min(drafts, 8) * 1.5
  );
}

function creatorNetworkingScore(userData) {
  const followers = creatorCounter(userData, ['followersCount', 'followerCount', 'followers']);
  const following = creatorCounter(userData, ['followingCount', 'following']);
  const connections = creatorCounter(userData, ['connectionsCount', 'connectionCount', 'connections']);
  const shares = creatorCounter(userData, ['creatorCardShares', 'profileShares', 'shareCount']);
  return clampCreatorScore(
    Math.min(followers, 250) * 0.16 +
    Math.min(following, 120) * 0.16 +
    Math.min(connections, 80) * 0.28 +
    Math.min(shares, 40) * 0.5
  );
}

function creatorEngagementScore(userData, videos) {
  let likes = creatorCounter(userData, ['totalLikes', 'likesCount', 'likeCount']);
  let comments = creatorCounter(userData, ['totalComments', 'commentsCount', 'commentCount']);
  let bookmarks = creatorCounter(userData, ['totalBookmarks', 'bookmarksCount', 'favoriteCount']);
  let shares = creatorCounter(userData, ['totalShares', 'sharesCount', 'shareCount']);
  let views = creatorCounter(userData, ['totalViews', 'viewsCount', 'viewCount']);
  for (const video of videos) {
    likes += readCreatorScoreInt(video.likes) + readCreatorScoreInt(video.likeCount);
    comments += readCreatorScoreInt(video.comments) + readCreatorScoreInt(video.commentCount);
    bookmarks += readCreatorScoreInt(video.bookmarks) + readCreatorScoreInt(video.favoriteCount);
    shares += readCreatorScoreInt(video.shares) + readCreatorScoreInt(video.shareCount);
    views += readCreatorScoreInt(video.views) + readCreatorScoreInt(video.viewCount);
  }
  return clampCreatorScore(
    Math.min(likes, 500) * 0.06 +
    Math.min(comments, 200) * 0.12 +
    Math.min(bookmarks, 200) * 0.1 +
    Math.min(shares, 120) * 0.12 +
    Math.min(views, 5000) * 0.004
  );
}

function creatorRankLabel(score) {
  if (score >= 90) return 'Elite Creator';
  if (score >= 75) return 'Rising Creator';
  if (score >= 55) return 'Active Creator';
  if (score >= 30) return 'Emerging Creator';
  return 'New Creator';
}

function creatorRecommendations(scores, userData) {
  const recs = [];
  if (scores.consistencyScore < 70) recs.push('Post 2 more clips this week');
  if (scores.contentScore < 70) recs.push('Schedule or publish your next creator post');
  if (scores.networkingScore < 70) recs.push('Collaborate with 1 creator');
  if (scores.engagementScore < 70) recs.push('Reply to comments and share your latest clip');
  if (scores.profileCompletionScore < 90) recs.push('Complete your Creator Card');
  if (!hasCreatorList(userData.platforms) && !hasCreatorList(userData.connectedPlatforms)) {
    recs.push('Connect another platform');
  }
  return recs.slice(0, 4);
}

function creatorLevel(score, userData) {
  const gam = mapValue(userData.gamification);
  const summary = mapValue(userData.progressionSummary);
  const existing =
    readCreatorScoreInt(gam.level) ||
    readCreatorScoreInt(summary.level) ||
    readCreatorScoreInt(userData.level);
  return existing > 0 ? existing : Math.max(1, Math.ceil(score / 8));
}

async function buildCreatorScore(env, uid) {
  const userData = await firestoreGetDocument(env, `users/${uid}`);
  if (!userData) {
    throw new Error('Creator not found');
  }
  const [videos, scheduledPostCount, completedMissions] = await Promise.all([
    getCreatorVideos(env, uid),
    getScheduledPostCount(env, uid),
    getCompletedMissionCount(env, uid),
  ]);
  const countableVideos = videos.filter(isCreatorScoreCountableVideo);
  const scores = {
    consistencyScore: creatorConsistencyScore(userData, countableVideos, completedMissions),
    contentScore: creatorContentScore(userData, videos, scheduledPostCount),
    networkingScore: creatorNetworkingScore(userData),
    engagementScore: creatorEngagementScore(userData, videos),
    profileCompletionScore: creatorProfileCompletionScore(userData),
  };
  const score = clampCreatorScore(
    scores.consistencyScore * 0.30 +
    scores.contentScore * 0.25 +
    scores.networkingScore * 0.20 +
    scores.engagementScore * 0.15 +
    scores.profileCompletionScore * 0.10
  );
  return {
    score,
    rankLabel: creatorRankLabel(score),
    level: creatorLevel(score, userData),
    ...scores,
    recommendations: creatorRecommendations(scores, userData),
    updatedBy: 'cloudflareWorker',
    lastCalculatedAt: { __timestamp: true },
  };
}

async function handleCreatorScoreSync(request, env, cors) {
  const auth = request.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) {
    throw new Error('Missing Authorization: Bearer <firebase_id_token>');
  }
  const idToken = auth.slice(7).trim();
  await verifyFirebaseToken(idToken, env.FIREBASE_WEB_API_KEY);
  const body = await request.json().catch(() => ({}));
  const uid = String(body.uid || '').trim();
  if (!uid) {
    return jsonResponse({ error: 'uid is required' }, 400, {}, cors);
  }
  const score = await buildCreatorScore(env, uid);
  await firestorePatchDocument(env, `users/${uid}/creatorScore/current`, score);
  return jsonResponse(
    {
      ok: true,
      uid,
      score: score.score,
      rankLabel: score.rankLabel,
      level: score.level,
    },
    200,
    {},
    cors
  );
}

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

async function handleMissionClaim(request, env, cors) {
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
  const missionId = String(body.missionId || '').trim();
  const bodyUid = String(body.uid || '').trim();
  if (!missionId) {
    return jsonResponse(
      { error: 'missionId is required (non-empty string)' },
      400,
      {},
      cors
    );
  }
  if (!bodyUid) {
    return jsonResponse(
      { error: 'uid is required (non-empty string)' },
      400,
      {},
      cors
    );
  }
  if (bodyUid !== verifiedUid) {
    return jsonResponse(
      { error: 'uid must match authenticated user' },
      403,
      {},
      cors
    );
  }
  const result = await claimMissionReward(env, verifiedUid, missionId);
  if (result?.error) {
    return jsonResponse({ error: result.error }, result.status || 400, {}, cors);
  }
  return jsonResponse({ ok: true, ...result }, 200, {}, cors);
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

async function firestoreCreateVideoDoc(env, videoId, fields) {
  await firestoreWrite(env, 'POST', `videos?documentId=${videoId}`, fields);
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

  const deps = { firestoreGetDocument };
  let allocation = await allocateVideoIdForNewUpload(env, clientVideoId, uid, deps);
  if (allocation.error) {
    return jsonResponse(
      {
        error: allocation.message,
        code: allocation.error,
        existingVideoId: allocation.existingVideoId || null,
      },
      allocation.status || 409,
      {},
      cors,
    );
  }

  let videoId = allocation.videoId;
  let replacedClientId = allocation.replacedClientId === true;
  const isDraft = body.isDraft === true;

  const writePendingDoc = async (targetId, uploadId = '') => {
    await firestoreCreateVideoDoc(
      env,
      targetId,
      pendingVideoFields({
        videoId: targetId,
        uid,
        body,
        uploadId,
        isDraft,
      }),
    );
  };

  try {
    try {
      await writePendingDoc(videoId, '');
    } catch (createErr) {
      const msg = String(createErr.message || createErr);
      if (msg.includes('409') || msg.includes('ALREADY_EXISTS')) {
        videoId = generateVideoId();
        replacedClientId = true;
        await writePendingDoc(videoId, '');
      } else {
        throw createErr;
      }
    }

    let uploadUrl;
    let uploadId;
    try {
      const mux = await createMuxUpload(env, videoId, uid, isDraft);
      uploadUrl = mux.uploadUrl;
      uploadId = mux.uploadId;
      await firestorePatchDocument(env, `videos/${videoId}`, {
        muxUploadId: uploadId || '',
        muxStatus: 'processing',
        updatedAt: { __timestamp: true },
      });
    } catch (muxErr) {
      await firestorePatchDocument(
        env,
        `videos/${videoId}`,
        failedUploadFields(
          'MUX_UPLOAD_CREATE_FAILED',
          muxErr.message || 'Mux direct upload failed',
        ),
      );
      return jsonResponse(
        {
          error: 'Mux upload session could not be created',
          code: 'MUX_UPLOAD_CREATE_FAILED',
          videoId,
        },
        502,
        {},
        cors,
      );
    }

    return jsonResponse(
      {
        videoId,
        uploadUrl,
        uploadId,
        replacedClientId,
      },
      200,
      {},
      cors,
    );
  } catch (e) {
    const msg = String(e.message || e);
    return jsonResponse(
      {
        error: msg.includes('Firestore') ? 'Firestore write failed' : msg,
        code: 'UPLOAD_INIT_FAILED',
      },
      msg.includes('409') ? 409 : 500,
      {},
      cors,
    );
  }
}

async function handleDeleteVideo(request, env, cors) {
  const auth = request.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) {
    return jsonResponse({ error: 'Missing Authorization' }, 401, {}, cors);
  }
  const idToken = auth.slice(7).trim();
  const { uid } = await verifyFirebaseToken(idToken, env.FIREBASE_WEB_API_KEY);
  const body = await request.json().catch(() => ({}));
  const videoId = String(body.videoId || '').trim();
  if (!videoId) {
    return jsonResponse({ error: 'videoId is required' }, 400, {}, cors);
  }

  const video = await firestoreGetDocument(env, `videos/${videoId}`);
  if (!video || Object.keys(video).length === 0) {
    return jsonResponse({ error: 'Video not found' }, 404, {}, cors);
  }
  const ownerId = String(
    video.userId || video.creatorId || video.creator_id || '',
  ).trim();
  if (!ownerId || ownerId !== uid) {
    return jsonResponse({ error: 'Forbidden' }, 403, {}, cors);
  }
  if (isVideoDeleted(video)) {
    return jsonResponse({ ok: true, skipped: true, videoId }, 200, {}, cors);
  }

  await firestorePatchDocument(env, `videos/${videoId}`, {
    isDeleted: true,
    deleted: true,
    deletedAt: { __timestamp: true },
    deletedBy: uid,
    status: 'deleted',
    visibility: 'private',
    visible: false,
    isReadyForFeed: false,
    updatedAt: { __timestamp: true },
  });

  const indexPaths = [
    `users/${ownerId}/videos/${videoId}`,
    `feeds/for_you/videos/${videoId}`,
    `feeds/following/videos/${videoId}`,
  ];
  const category = String(
    video.category || video.categoryId || video.category_id || '',
  ).trim();
  if (category) {
    indexPaths.push(`feeds/categories/${category}/videos/${videoId}`);
  }
  for (const path of indexPaths) {
    try {
      const token = await getFirestoreAccessToken(env);
      const projectId = env.FIREBASE_PROJECT_ID || 'streamerstip-6cfdb';
      const url = `${FIRESTORE_BASE}/projects/${projectId}/databases/(default)/documents/${path}`;
      await fetch(url, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      });
    } catch (_) {
      /* index may not exist */
    }
  }

  await softDeleteForumPostsForVideo(env, videoId);

  return jsonResponse({ ok: true, videoId }, 200, {}, cors);
}

async function softDeleteForumPostsForVideo(env, videoId) {
  const patchFields = {
    deleted: true,
    status: 'deleted',
    deletedAt: { __timestamp: true },
    deletedReason: 'source_video_deleted',
    updatedAt: { __timestamp: true },
    visible: false,
  };
  for (const field of ['linkedVideoId', 'videoId']) {
    const rows = await firestoreRunQuery(env, {
      from: [{ collectionId: 'forumPosts' }],
      where: {
        fieldFilter: {
          field: { fieldPath: field },
          op: 'EQUAL',
          value: { stringValue: videoId },
        },
      },
      limit: 100,
    });
    for (const row of rows) {
      const docName = row.document?.name || '';
      const postId = docName.split('/').pop();
      if (!postId) continue;
      await firestorePatchDocument(env, `forumPosts/${postId}`, patchFields);
    }
  }
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
  const existing = (await firestoreGetDocument(env, `videos/${videoId}`)) || {};
  if (isVideoDeleted(existing)) {
    console.log('[MuxWebhook] skip deleted video:', videoId);
    return jsonResponse(
      { ok: true, videoId, skipped: true, reason: 'deleted' },
      200,
      {},
      cors,
    );
  }
  const ownerId = String(
    existing.userId ||
      existing.creatorId ||
      existing.creator_id ||
      (data.meta && data.meta.creator_id) ||
      ''
  ).trim();
  const privacy = existing.privacy || 'Everyone';
  const visibility =
    existing.visibility ||
    (privacy === 'Everyone' || privacy === 'Public' || privacy === 'public'
      ? 'public'
      : privacy === 'Private' || privacy === 'private'
        ? 'private'
        : 'public');
  const category = String(
    existing.category ||
      existing.categoryId ||
      existing.category_id ||
      'gaming'
  ).trim();

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
    isReadyForFeed: allGatesPass,
    isDeleted: false,
    visible: allGatesPass,
    playbackReady: allGatesPass,
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

  if (ownerId) {
    fields.userId = ownerId;
    fields.creatorId = ownerId;
    fields.creator_id = ownerId;
  }
  fields.privacy = privacy;
  fields.visibility = visibility;
  if (category) {
    fields.category = category;
    fields.categoryId = category;
    fields.category_id = category;
    fields.categories = Array.isArray(existing.categories)
      ? existing.categories
      : [category];
  }

  const existingCaption = String(existing.caption || '').trim();
  const metadataCaption = String(
    existing.metadata && existing.metadata.preview_manual_caption
      ? existing.metadata.preview_manual_caption
      : '',
  ).trim();
  const resolvedCaption = existingCaption || metadataCaption;
  if (resolvedCaption) {
    fields.caption = resolvedCaption;
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

  if (ownerId && allGatesPass) {
    await firestorePatchDocument(env, `users/${ownerId}/videos/${videoId}`, {
      videoId,
      userId: ownerId,
      status: 'ready',
      visible: true,
      privacy,
      visibility,
      category,
      addedAt: { __timestamp: true },
      updatedAt: { __timestamp: true },
    });
    const isPublic =
      privacy === 'Everyone' ||
      privacy === 'Public' ||
      privacy === 'public';
    if (isPublic) {
      const feedEntry = {
        videoId,
        userId: ownerId,
        privacy,
        category,
        status: 'ready',
        addedAt: { __timestamp: true },
      };
      await firestorePatchDocument(
        env,
        `feeds/for_you/videos/${videoId}`,
        feedEntry
      );
      await firestorePatchDocument(
        env,
        `feeds/following/videos/${videoId}`,
        feedEntry
      );
      if (category) {
        await firestorePatchDocument(
          env,
          `feeds/categories/${category}/videos/${videoId}`,
          feedEntry
        );
      }
    }
  }

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
