#!/usr/bin/env node
/**
 * Repairs Firestore video documents that are already safe to show in Home and
 * Discover but are missing canonical feed metadata.
 *
 * Defaults to dry-run. Writes require --apply.
 *
 * Usage:
 *   node scripts/video_feed_visibility_backfill.js
 *   node scripts/video_feed_visibility_backfill.js --apply
 *   node scripts/video_feed_visibility_backfill.js --limit=100
 */

const DEFAULT_PROJECT_ID = 'streamerstip-6cfdb';
const FIREBASE_TOOLS_ROOT =
  process.env.FIREBASE_TOOLS_ROOT || '/usr/local/lib/node_modules/firebase-tools';

const args = new Set(process.argv.slice(2));
const apply = args.has('--apply');
const verbose = args.has('--verbose');
const limitArg = process.argv
  .slice(2)
  .find((arg) => arg.startsWith('--limit='));
const limit = Math.max(
  1,
  Math.min(1000, Number.parseInt(limitArg?.split('=')[1] || '500', 10) || 500),
);
const projectId = process.env.FIREBASE_PROJECT || DEFAULT_PROJECT_ID;

const visibleStatuses = new Set(['ready', 'published', 'active']);

function requireFirebaseTools(modulePath) {
  return require(`${FIREBASE_TOOLS_ROOT}/lib/${modulePath}`);
}

function firestoreValueToJs(value) {
  if (!value) return undefined;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('nullValue' in value) return null;
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(firestoreValueToJs);
  }
  if ('mapValue' in value) {
    const out = {};
    for (const [key, child] of Object.entries(value.mapValue.fields || {})) {
      out[key] = firestoreValueToJs(child);
    }
    return out;
  }
  return undefined;
}

function jsToFirestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(jsToFirestoreValue) } };
  }
  if (typeof value === 'object') {
    const fields = {};
    for (const [key, child] of Object.entries(value)) {
      fields[key] = jsToFirestoreValue(child);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(value) };
}

function firestoreDocToJs(doc) {
  const out = {};
  for (const [key, value] of Object.entries(doc.fields || {})) {
    out[key] = firestoreValueToJs(value);
  }
  out.id = doc.name.split('/').pop();
  return out;
}

function getOwnerId(data) {
  for (const key of [
    'ownerId',
    'userId',
    'user_id',
    'authorId',
    'uid',
    'creatorId',
    'creator_id',
    'videoOwnerId',
  ]) {
    const value = data[key];
    if (typeof value === 'string' && value.trim()) return value.trim();
  }
  const meta = data.meta;
  if (meta && typeof meta === 'object') {
    for (const key of ['creator_id', 'creatorId', 'userId']) {
      const value = meta[key];
      if (typeof value === 'string' && value.trim()) return value.trim();
    }
  }
  return '';
}

function looksLikeFirebaseUid(value) {
  const trimmed = String(value || '').trim();
  return trimmed.length >= 20 &&
    trimmed.length <= 40 &&
    /^[A-Za-z0-9]+$/.test(trimmed);
}

function inferOwnerIdFromVideoId(videoId) {
  const idx = String(videoId || '').indexOf('_');
  if (idx <= 0) return '';
  const candidate = videoId.slice(0, idx).trim();
  return looksLikeFirebaseUid(candidate) ? candidate : '';
}

function isPublicVideo(data) {
  return data.visibility === 'public' ||
    data.privacy === 'Everyone' ||
    data.privacy === 'Public' ||
    data.privacy === 'public' ||
    (data.visibility == null && data.privacy == null);
}

function looksLikeBadPlaybackUrl(url) {
  const lower = String(url || '').toLowerCase();
  return !lower ||
    lower.includes('.png') ||
    lower.includes('.jpg') ||
    lower.includes('.jpeg') ||
    lower.includes('.webp') ||
    lower.includes('.gif') ||
    lower.includes('/thumbnail') ||
    lower.startsWith('file://') ||
    lower.startsWith('/') ||
    lower.includes('placehold.co') ||
    lower.includes('placeholder') ||
    lower.includes('original.mp4');
}

function normalizeMuxHlsUrl(url) {
  if (!url || !String(url).includes('stream.mux.com')) return String(url || '');
  try {
    const parsed = new URL(String(url).trim());
    const [first] = parsed.pathname.split('/').filter(Boolean);
    if (!first) return String(url).trim();
    const playbackId = first.replace('.m3u8', '');
    return `https://stream.mux.com/${playbackId}.m3u8`;
  } catch (_) {
    return String(url).trim();
  }
}

function resolvePlaybackUrl(data) {
  for (const key of [
    'canonicalPlaybackUrl',
    'hlsUrl',
    'hls_url',
    'playbackUrl',
    'videoUrl',
    'videoURL',
  ]) {
    const value = data[key];
    if (typeof value === 'string' && value.trim() && !looksLikeBadPlaybackUrl(value)) {
      return normalizeMuxHlsUrl(value.trim());
    }
  }
  for (const key of ['muxPlaybackId', 'playbackId', 'mux_playback_id']) {
    const value = data[key];
    if (typeof value === 'string' && value.trim()) {
      return `https://stream.mux.com/${value.trim()}.m3u8`;
    }
  }
  return '';
}

function rejectReason(data) {
  const status = String(data.status || '').toLowerCase();
  if (data.isDeleted === true || data.deleted === true) return 'deleted_flag';
  if (data.deletedAt != null) return 'deletedAt';
  if (status === 'deleted' || status === 'removed') return `status:${status}`;
  if (!visibleStatuses.has(status)) return `status:${status}`;
  if (data.visible === false) return 'visible:false';
  if (data.isReadyForFeed !== true) return 'isReadyForFeed:not_true';
  if (!isPublicVideo(data)) return 'visibility';
  if (!getOwnerId(data) && !inferOwnerIdFromVideoId(data.id)) return 'missing_owner';
  if (!resolvePlaybackUrl(data)) return 'not_ready_for_playback';
  return null;
}

async function firestoreFetch(token, path, init = {}) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}`,
    {
      ...init,
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        ...(init.headers || {}),
      },
    },
  );
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${response.status} ${JSON.stringify(body.error || body)}`);
  }
  return body;
}

async function listVideoDocs(token) {
  const docs = [];
  let pageToken = '';
  do {
    const page = await firestoreFetch(
      token,
      `videos?pageSize=${limit}${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`,
    );
    docs.push(...(page.documents || []).map(firestoreDocToJs));
    pageToken = page.nextPageToken || '';
  } while (pageToken && docs.length < limit);
  return docs.slice(0, limit);
}

async function documentExists(token, path) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  return response.ok;
}

async function patchDocument(token, path, patch) {
  const fields = {};
  const updateMask = [];
  for (const [key, value] of Object.entries(patch)) {
    fields[key] = jsToFirestoreValue(value);
    updateMask.push(`updateMask.fieldPaths=${encodeURIComponent(key)}`);
  }
  const query = updateMask.join('&');
  await firestoreFetch(token, `${path}?${query}`, {
    method: 'PATCH',
    body: JSON.stringify({ fields }),
  });
}

function buildPatch(data, ownerId) {
  const status = String(data.status || '').toLowerCase();
  const playbackUrl = resolvePlaybackUrl(data);
  if (!visibleStatuses.has(status)) return null;
  if (data.isDeleted === true || data.deleted === true || data.deletedAt != null) return null;
  if (!isPublicVideo(data)) return null;
  if (!playbackUrl) return null;
  if (!ownerId) return null;

  const patch = {};
  if (data.isReadyForFeed !== true) patch.isReadyForFeed = true;
  if (data.visible !== true) patch.visible = true;
  if (data.playbackReady !== true) patch.playbackReady = true;
  if (data.visibility !== 'public') patch.visibility = 'public';
  if (!data.privacy) patch.privacy = 'Everyone';
  if (!data.canonicalPlaybackUrl) patch.canonicalPlaybackUrl = playbackUrl;
  if (!data.hlsUrl) patch.hlsUrl = playbackUrl;
  if (!data.hls_url) patch.hls_url = playbackUrl;
  if (!data.videoUrl) patch.videoUrl = playbackUrl;
  if (!data.videoURL) patch.videoURL = playbackUrl;
  if (!data.playbackUrl) patch.playbackUrl = playbackUrl;
  for (const key of ['ownerId', 'userId', 'creatorId', 'creator_id']) {
    if (!data[key]) patch[key] = ownerId;
  }
  if (!data.publishedAt && (data.createdAt || data.updatedAt)) {
    patch.publishedAt = data.createdAt || data.updatedAt;
  }
  if (Object.keys(patch).length > 0) {
    patch.updatedAt = new Date();
  }
  return Object.keys(patch).length > 0 ? patch : null;
}

async function main() {
  const auth = requireFirebaseTools('auth');
  const apiv2 = requireFirebaseTools('apiv2');
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error('Firebase CLI is not logged in. Run firebase login first.');
  }
  auth.setRefreshToken(account.tokens.refresh_token);
  const token = await apiv2.getAccessToken();
  const docs = await listVideoDocs(token);

  const summary = {
    scanned: docs.length,
    eligibleBefore: 0,
    plannedPatches: 0,
    appliedPatches: 0,
    skipped: {},
  };
  const planned = [];

  for (const data of docs) {
    const beforeReject = rejectReason(data);
    if (beforeReject == null) summary.eligibleBefore += 1;

    const explicitOwner = getOwnerId(data);
    const inferredOwner = explicitOwner || inferOwnerIdFromVideoId(data.id);
    let ownerId = explicitOwner;
    let ownerSource = explicitOwner ? 'existing' : '';
    if (!ownerId && inferredOwner) {
      const exists = await documentExists(token, `users/${inferredOwner}`);
      if (exists) {
        ownerId = inferredOwner;
        ownerSource = 'video_id_prefix';
      }
    }

    const patch = buildPatch(data, ownerId);
    if (!patch) {
      const reason = beforeReject || 'no_patch_needed';
      summary.skipped[reason] = (summary.skipped[reason] || 0) + 1;
      continue;
    }

    summary.plannedPatches += 1;
    planned.push({
      videoId: data.id,
      beforeReject,
      ownerSource,
      patchKeys: Object.keys(patch),
      patch,
    });
  }

  console.log(
    JSON.stringify(
      {
        mode: apply ? 'apply' : 'dry-run',
        projectId,
        summary,
        planned,
      },
      null,
      2,
    ),
  );

  if (!apply) {
    console.log('Dry run only. Re-run with --apply to write these patches.');
    return;
  }

  for (const item of planned) {
    if (verbose) {
      console.log(`Patching videos/${item.videoId}: ${item.patchKeys.join(', ')}`);
    }
    await patchDocument(token, `videos/${item.videoId}`, item.patch);
    summary.appliedPatches += 1;
  }

  console.log(
    JSON.stringify(
      {
        mode: 'apply-complete',
        projectId,
        appliedPatches: summary.appliedPatches,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error('Video feed visibility backfill failed:', error.message);
  process.exit(1);
});
