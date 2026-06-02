const admin = require('firebase-admin');

const firestore = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const DEV_MOCK_ENABLED = String(process.env.TIPPY_DEV_MOCK || 'false') === 'true';
const RATE_LIMIT_WINDOW_SECONDS = 60;
const RATE_LIMIT_REQUESTS_PER_WINDOW = 20;
const DAILY_REQUEST_LIMITS = {
  starter: 10,
  pro: 75,
  studio: 200,
};
const {buildUserAccess} = require('../shared/user_tippy_access');
const {
  buildCreditWrite,
  resolveCreditsForUser,
} = require('../shared/tippy_credits');
const {runAnthropicTippy} = require('./anthropic_tippy');

function emitRequestLog(payload) {
  console.log(JSON.stringify(payload));
}

function buildSuccessResponse({data, credits, requestId}) {
  return {
    success: true,
    data,
    credits,
    requestId,
  };
}

function buildErrorResponse({
  code,
  message,
  status,
  retryable,
  requestId,
}) {
  return {
    success: false,
    error: {
      code,
      message,
      status,
      retryable,
    },
    requestId,
  };
}

function generateRequestId() {
  return `req_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

function resolveIsDevEnvironment(req) {
  const host = String(req.headers.host || '').toLowerCase();
  const origin = String(req.headers.origin || '').toLowerCase();
  return host.includes('localhost') || origin.includes('localhost');
}

async function verifyFirebaseUser(req, requestId) {
  const authHeader = String(req.headers.authorization || '');
  if (!authHeader.startsWith('Bearer ')) {
    return {
      ok: false,
      status: 401,
      payload: buildErrorResponse({
        code: 'AUTH_REQUIRED',
        message: 'Authentication token is required.',
        status: 401,
        retryable: false,
        requestId,
      }),
    };
  }
  const idToken = authHeader.slice(7).trim();
  if (idToken.length === 0) {
    return {
      ok: false,
      status: 401,
      payload: buildErrorResponse({
        code: 'INVALID_TOKEN',
        message: 'Authentication token is invalid.',
        status: 401,
        retryable: false,
        requestId,
      }),
    };
  }
  try {
    const decoded = await admin.auth().verifyIdToken(idToken, true);
    return {
      ok: true,
      uid: decoded.uid,
      email: decoded.email || '',
    };
  } catch (err) {
    const code = String(err.code || '').includes('id-token-expired')
      ? 'TOKEN_EXPIRED'
      : 'INVALID_TOKEN';
    return {
      ok: false,
      status: 401,
      payload: buildErrorResponse({
        code,
        message: code === 'TOKEN_EXPIRED'
          ? 'Your session has expired. Please sign in again.'
          : 'Authentication token is invalid.',
        status: 401,
        retryable: false,
        requestId,
      }),
    };
  }
}

async function readCurrentCredits(uid, email = '') {
  const doc = await firestore.collection('users').doc(uid).get();
  const userData = doc.data() || {};
  const access = buildUserAccess(userData, {uid, email});
  const credits = resolveCreditsForUser(userData, access);
  return {credits, access, userData};
}

function readCreatorName(userData) {
  const raw = userData.username ||
    userData.displayName ||
    userData.display_name ||
    userData.name ||
    'creator';
  return String(raw).trim().replace(/^@+/, '') || 'creator';
}

function latestUserMessage(body) {
  if (!body || !Array.isArray(body.messages)) {
    return '';
  }
  for (let i = body.messages.length - 1; i >= 0; i--) {
    const msg = body.messages[i] || {};
    if (String(msg.role || '').toLowerCase() === 'user') {
      return String(msg.content || '').trim();
    }
  }
  return '';
}

function conversationText(body) {
  if (!body || !Array.isArray(body.messages)) {
    return '';
  }
  return body.messages
    .map((msg) => String((msg && msg.content) || '').trim())
    .filter((text) => text.length > 0)
    .join('\n')
    .toLowerCase();
}

function hasPlanContext(body) {
  const prompt = String((body && body.prompt) || '').trim();
  const latest = latestUserMessage(body);
  const text = `${prompt}\n${latest}\n${conversationText(body)}`.trim();
  if (text.length < 24) {
    return false;
  }
  const normalized = text.replace(/\s+/g, ' ').trim().toLowerCase();
  const genericRequests = new Set([
    'create a content plan',
    'make a content plan',
    'turn this conversation into a content plan',
    'sync it to my content planner',
    'add it to my content planner',
  ]);
  return !genericRequests.has(normalized);
}

function wantsContentPlanSync(path, body) {
  if (path === '/tippy/create-plan' || path === '/tippy/create-content-plan') {
    return true;
  }
  const latest = latestUserMessage(body).toLowerCase();
  const allText = conversationText(body);
  const mentionsPlanner =
    latest.includes('content planner') ||
    latest.includes('planner') ||
    allText.includes('content planner');
  const mentionsPlanLikeThing =
    latest.includes('content plan') ||
    latest.includes('this plan') ||
    latest.includes('calendar') ||
    allText.includes('content plan') ||
    allText.includes('content calendar');
  const wantsWrite =
    latest.includes('sync') ||
    latest.includes('add') ||
    latest.includes('create') ||
    latest.includes('save') ||
    latest.includes('put') ||
    latest.includes('send');
  return mentionsPlanner && mentionsPlanLikeThing && wantsWrite;
}

function normalizeTippyPath(rawPath) {
  const path = String(rawPath || '');
  if (path === '/api/tippy') {
    return '/tippy/chat';
  }
  if (path.startsWith('/api/tippy/')) {
    return `/tippy/${path.slice('/api/tippy/'.length)}`;
  }
  return path;
}

function sanitizeText(value, fallback = '') {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  return text.length > 0 ? text.slice(0, 500) : fallback;
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

function normalizeContentPlanPlatform(raw) {
  const value = sanitizeText(raw, '').toLowerCase();
  if (value.includes('youtube')) return 'youtube';
  if (value.includes('tiktok')) return 'tiktok';
  if (value.includes('instagram')) return 'instagram';
  if (value.includes('twitch')) return 'twitch';
  if (value.includes('kick')) return 'kick';
  if (value.includes('twitter') || value.includes('x')) return 'twitter';
  if (value.includes('facebook')) return 'facebook';
  if (value.includes('streamerstip')) return 'streamerstip';
  return value.length > 0 ? 'custom' : 'streamerstip';
}

function normalizeContentPlanType(raw) {
  const value = sanitizeText(raw, '').toLowerCase();
  const known = new Set([
    'stream',
    'clip',
    'video',
    'short',
    'story',
    'post',
    'collab',
    'other',
  ]);
  return known.has(value) ? value : 'post';
}

function sanitizeGeneratedPlan(raw, uid) {
  const source = raw && typeof raw === 'object' ? raw : {};
  const now = new Date();
  const nestedTimestamp = admin.firestore.Timestamp.fromDate(now);
  const rawItems = Array.isArray(source.items) ? source.items : [];
  const title = sanitizeText(
    source.title,
    'Custom Content Plan',
  );
  const description = sanitizeText(
    source.description,
    'AI-generated content plan created by Tippy.',
  );
  const contentType = normalizeContentPlanType(
    source.contentType || source.type || (rawItems[0] && rawItems[0].contentType),
  );
  const platformTargets = Array.isArray(source.platformTargets)
    ? source.platformTargets.map((p) => sanitizeText(p, '')).filter(Boolean).slice(0, 5)
    : Array.isArray(source.platforms)
      ? source.platforms.map((p) => sanitizeText(p, '')).filter(Boolean).slice(0, 5)
      : ['StreamersTip'];
  const safeItems = rawItems.slice(0, 31).map((item, index) => {
    const data = item && typeof item === 'object' ? item : {};
    const scheduledAt = addDays(now, index);
    const rawPlatforms = Array.isArray(data.platform)
      ? data.platform
      : Array.isArray(data.platforms)
        ? data.platforms
        : data.platform
          ? [data.platform]
          : [];
    const platformSchedules = rawPlatforms.length > 0
      ? rawPlatforms
      : ['streamerstip'];
    return {
      id: firestore.collection('_contentPlanItemIds').doc().id,
      title: sanitizeText(data.title, `Content idea ${index + 1}`),
      description: sanitizeText(data.description || data.caption, ''),
      type: normalizeContentPlanType(data.contentType || data.type),
      platforms: platformSchedules
        .map((p) => ({
          platform: normalizeContentPlanPlatform(p),
          scheduledAt: admin.firestore.Timestamp.fromDate(scheduledAt),
          status: 'scheduled',
        }))
        .slice(0, 5),
      tags: Array.isArray(data.tags)
        ? data.tags.map((tag) => sanitizeText(tag, '')).filter(Boolean).slice(0, 10)
        : [],
      thumbnailUrl: null,
      notes: sanitizeText(data.notes || data.hook, ''),
      videoId: null,
      caption: sanitizeText(data.caption, ''),
      status: 'scheduled',
      profileCalendar: 'public',
      source: 'tippy_ai',
      createdAt: nestedTimestamp,
      updatedAt: nestedTimestamp,
    };
  });
  if (safeItems.length === 0) {
    const scheduledAt = addDays(now, 0);
    safeItems.push({
      id: firestore.collection('_contentPlanItemIds').doc().id,
      title: sanitizeText(title, 'Plan step'),
      description,
      type: 'post',
      platforms: [
        {
          platform: 'streamerstip',
          scheduledAt: admin.firestore.Timestamp.fromDate(scheduledAt),
          status: 'scheduled',
        },
      ],
      tags: [],
      thumbnailUrl: null,
      notes: '',
      videoId: null,
      caption: '',
      status: 'scheduled',
      profileCalendar: 'public',
      source: 'tippy_ai',
      createdAt: nestedTimestamp,
      updatedAt: nestedTimestamp,
    });
  }
  const startDate = safeItems[0].platforms[0].scheduledAt;
  const endDate = safeItems[safeItems.length - 1].platforms[0].scheduledAt;
  return {
    plan: {
      id: null,
      userId: uid,
      ownerUid: uid,
      title,
      description,
      contentType,
      platformTargets,
      platform: platformTargets[0] || 'StreamersTip',
      status: 'planned',
      scheduledFor: null,
      scheduledAt: null,
      startDate,
      endDate,
      items: safeItems,
      consistencyGoal: null,
      customFrequency: null,
      isActive: true,
      source: 'tippy_ai',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdBy: 'tippy_ai',
      aiPromptId: sanitizeText(source.aiPromptId, '') || null,
      tippyConversationId: sanitizeText(source.tippyConversationId, '') || null,
    },
  };
}

function serializeContentPlanItemsForClient(items) {
  return items.map((item) => ({
    id: item.id,
    title: item.title,
    description: item.description,
    caption: item.caption,
    type: item.type,
    status: item.status,
    notes: item.notes,
    platforms: (item.platforms || []).map((p) => {
      const ts = p.scheduledAt;
      const scheduledAt =
        ts && typeof ts.toDate === 'function'
          ? ts.toDate().toISOString()
          : null;
      return {
        platform: p.platform,
        status: p.status,
        scheduledAt,
      };
    }),
  }));
}

async function writeContentPlan(uid, generatedPlan) {
  const sanitized = sanitizeGeneratedPlan(generatedPlan, uid);
  const planRef = firestore
    .collection('users')
    .doc(uid)
    .collection('contentPlans')
    .doc();
  const plan = {
    ...sanitized.plan,
    id: planRef.id,
    ownerUid: uid,
    userId: uid,
    source: 'tippy_ai',
    status: sanitized.plan.status || 'planned',
    createdBy: 'tippy_ai',
    updatedAt: FieldValue.serverTimestamp(),
  };
  console.log(`Tippy content plan save uid=${uid} path=users/${uid}/contentPlans/${planRef.id}`);
  await planRef.set(plan);
  return {
    planId: planRef.id,
    itemCount: plan.items.length,
    title: plan.title,
    description: plan.description,
    items: serializeContentPlanItemsForClient(plan.items),
  };
}

function titleCaseTier(tier) {
  const t = String(tier || 'creator').trim().toLowerCase();
  if (t === 'studio') return 'Studio';
  if (t === 'pro') return 'Pro';
  if (t === 'starter') return 'Starter';
  return 'Creator';
}

async function countScheduledPostsThisWeek(uid) {
  const now = new Date();
  const weekEnd = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  const snap = await firestore.collection('scheduled_posts')
    .where('authorId', '==', uid)
    .where('status', '==', 'scheduled')
    .limit(25)
    .get();
  let count = 0;
  snap.forEach((doc) => {
    const data = doc.data() || {};
    const scheduledAt = data.schedule && data.schedule.scheduledAtUtc;
    if (!scheduledAt || typeof scheduledAt.toDate !== 'function') {
      return;
    }
    const date = scheduledAt.toDate();
    if (date >= now && date <= weekEnd) {
      count++;
    }
  });
  return count;
}

async function reserveCreditAtomically(uid, email = '') {
  const userRef = firestore.collection('users').doc(uid);
  return firestore.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const userData = userSnap.data() || {};
    const access = buildUserAccess(userData, {uid, email});
    if (!access.canUseTippy) {
      return {
        ok: false,
        reason: 'UPGRADE_REQUIRED',
      };
    }
    const current = resolveCreditsForUser(userData, access);
    if (current.remaining <= 0) {
      return {
        ok: false,
        reason: 'INSUFFICIENT_CREDITS',
        credits: current,
      };
    }
    const nextCredits = {
      remaining: current.remaining - 1,
      used: current.used + 1,
      limit: current.limit,
      tier: current.tier,
      resetAt: current.resetAt,
    };
    tx.set(
      userRef,
      buildCreditWrite(nextCredits, access),
      {merge: true},
    );
    return {
      ok: true,
      previousCredits: current,
      credits: nextCredits,
      access,
    };
  });
}

async function rollbackReservedCreditAtomically(uid, email = '') {
  const userRef = firestore.collection('users').doc(uid);
  return firestore.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const userData = userSnap.data() || {};
    const access = buildUserAccess(userData, {uid, email});
    const current = resolveCreditsForUser(userData, access);
    const restored = {
      remaining: current.remaining + 1,
      used: current.used > 0 ? current.used - 1 : 0,
      limit: current.limit,
      tier: current.tier,
      resetAt: current.resetAt,
    };
    tx.set(
      userRef,
      buildCreditWrite(restored, access),
      {merge: true},
    );
    return restored;
  });
}

async function executeAiAction({
  uid,
  email = '',
  path,
  body,
  requestId,
  req,
}) {
  const isDev = resolveIsDevEnvironment(req);
  if (DEV_MOCK_ENABLED && isDev) {
    if (path === '/tippy/chat') {
      return {message: `Mock reply for user ${uid}.`};
    }
    if (path === '/tippy/create-plan' || path === '/tippy/create-content-plan') {
      const context = latestUserMessage(body) || String(body.prompt || '').trim();
      return {
        plan: {
          title: context
            ? `Content Plan: ${context.slice(0, 48)}`
            : 'Custom Content Plan',
          description: 'AI-generated content plan created from the Tippy chat.',
          items: [
            {
              title: context || 'Draft the first content idea',
              caption: context || 'Add details for this content plan.',
              platform: [],
              contentType: 'short',
            },
          ],
        },
      };
    }
    if (path === '/tippy/ai-caption') {
      return {
        caption: `Mock caption for ${String(body.prompt || 'your content')}.`,
        hashtags: ['#streamer', '#creator'],
        title: 'Mock title',
      };
    }
    return {
      summary: 'Mock analysis summary.',
      actionItems: ['Improve opening hook', 'Add direct CTA'],
    };
  }
  const apiKey = String(process.env.ANTHROPIC_API_KEY || '').trim();
  if (apiKey.length > 0) {
    let snapshot = null;
    try {
      snapshot = await readCurrentCredits(uid, email);
    } catch (err) {
      console.warn(
        'Tippy creator context load failed:',
        err && err.message ? err.message : err,
      );
    }
    const userData = snapshot ? snapshot.userData : {};
    const access = snapshot ? snapshot.access : buildUserAccess(userData, {uid, email});
    return runAnthropicTippy({
      apiKey,
      path,
      body,
      requestId,
      tippyContext: {
        tier: access.tier,
        creatorName: readCreatorName(userData),
        userData,
        extras: {
          category: typeof body.category === 'string' ? body.category : undefined,
        },
      },
    });
  }
  return {
    error: buildErrorResponse({
      code: 'SERVICE_UNAVAILABLE',
      message: 'AI provider is unavailable.',
      status: 503,
      retryable: true,
      requestId,
    }),
    status: 503,
  };
}

function buildRateLimitKey() {
  const bucket = Math.floor(Date.now() / (RATE_LIMIT_WINDOW_SECONDS * 1000));
  return String(bucket);
}

async function ensureRateLimit(uid) {
  const bucket = buildRateLimitKey();
  const key = `${uid}_${bucket}`;
  const rateRef = firestore.collection('tippy_rate_limits').doc(key);
  return firestore.runTransaction(async (tx) => {
    const snap = await tx.get(rateRef);
    const data = snap.data() || {};
    const count = Number(data.count || 0);
    if (count >= RATE_LIMIT_REQUESTS_PER_WINDOW) {
      return {ok: false};
    }
    tx.set(
      rateRef,
      {
        uid,
        bucket,
        count: count + 1,
        expiresAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return {ok: true};
  });
}

function dailyLimitKey(uid, date = new Date()) {
  const day = date.toISOString().slice(0, 10);
  return {day, key: `${uid}_${day}`};
}

function dailyRequestLimitForTier(tier) {
  const normalized = String(tier || '').trim().toLowerCase();
  return DAILY_REQUEST_LIMITS[normalized] || DAILY_REQUEST_LIMITS.starter;
}

async function ensureDailyRequestLimit(uid, tier) {
  const limit = dailyRequestLimitForTier(tier);
  const {day, key} = dailyLimitKey(uid);
  const dailyRef = firestore.collection('tippy_daily_limits').doc(key);
  return firestore.runTransaction(async (tx) => {
    const snap = await tx.get(dailyRef);
    const data = snap.data() || {};
    const count = Number(data.count || 0);
    if (count >= limit) {
      return {ok: false, limit, count};
    }
    tx.set(
      dailyRef,
      {
        uid,
        day,
        tier,
        limit,
        count: count + 1,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return {ok: true, limit, count: count + 1};
  });
}

async function writeTelemetry({
  uid,
  path,
  status,
  code,
  requestId,
  tier = 'unknown',
}) {
  await firestore.collection('tippy_usage_events').add({
    uid,
    path,
    status,
    code,
    tier,
    requestId,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function writeTelemetrySafe(payload) {
  try {
    await writeTelemetry(payload);
  } catch (err) {
    console.error('tippy telemetry write failed', err);
  }
}

function parseJsonBody(req) {
  if (typeof req.body === 'object' && req.body != null) {
    return req.body;
  }
  if (typeof req.body === 'string' && req.body.trim().length > 0) {
    try {
      return JSON.parse(req.body);
    } catch (_) {
      return null;
    }
  }
  return {};
}

function validateRequestBody(path, body, requestId) {
  if (body == null) {
    return {
      status: 400,
      payload: buildErrorResponse({
        code: 'INVALID_ARGUMENT',
        message: 'Invalid request payload.',
        status: 400,
        retryable: false,
        requestId,
      }),
    };
  }
  if (path === '/tippy/chat') {
    if (!Array.isArray(body.messages) || body.messages.length === 0) {
      return {
        status: 400,
        payload: buildErrorResponse({
          code: 'INVALID_ARGUMENT',
          message: 'messages is required.',
          status: 400,
          retryable: false,
          requestId,
        }),
      };
    }
  }
  if (path === '/tippy/create-plan' || path === '/tippy/create-content-plan') {
    if (!hasPlanContext(body)) {
      return {
        status: 400,
        payload: buildErrorResponse({
          code: 'INVALID_ARGUMENT',
          message: 'Content plan context is required.',
          status: 400,
          retryable: false,
          requestId,
        }),
      };
    }
  }
  if (path === '/tippy/ai-caption') {
    if (typeof body.prompt !== 'string' || body.prompt.trim().length === 0) {
      return {
        status: 400,
        payload: buildErrorResponse({
          code: 'INVALID_ARGUMENT',
          message: 'prompt is required.',
          status: 400,
          retryable: false,
          requestId,
        }),
      };
    }
  }
  if (path === '/tippy/analyze-content') {
    if (typeof body.content !== 'string' || body.content.trim().length === 0) {
      return {
        status: 400,
        payload: buildErrorResponse({
          code: 'INVALID_ARGUMENT',
          message: 'content is required.',
          status: 400,
          retryable: false,
          requestId,
        }),
      };
    }
  }
  return null;
}

async function handleCreditsGet({uid, email = '', requestId, res}) {
  const snapshot = await readCurrentCredits(uid, email);
  const credits = snapshot.credits;
  const tier = snapshot.access.tier;
  if (credits.needsReset) {
    await firestore.collection('users').doc(uid).set(
      buildCreditWrite(credits, snapshot.access),
      {merge: true},
    );
  }
  const creatorName = readCreatorName(snapshot.userData);
  let scheduledThisWeek = 0;
  try {
    scheduledThisWeek = await countScheduledPostsThisWeek(uid);
  } catch (err) {
    console.warn(
      'Unable to count scheduled posts for Tippy greeting:',
      err && err.message ? err.message : err,
    );
  }
  const tierLabel = titleCaseTier(tier);
  const itemLabel = scheduledThisWeek === 1 ? 'item' : 'items';
  const data = {
    greeting:
      `Hey ${creatorName}! You're on the ${tierLabel} plan with ` +
      `${credits.remaining} of ${credits.limit} AI credits left this month. ` +
      'Ask me anything about growing your channel.',
    nudge: scheduledThisWeek > 0
      ? `You have ${scheduledThisWeek} ${itemLabel} scheduled this week. ` +
        'Want me to draft a caption for your next post?'
      : 'Try one short-form post with a direct question CTA.',
    scheduledThisWeek,
  };
  await writeTelemetrySafe({
    uid,
    path: '/tippy/credits',
    status: 200,
    code: 'OK',
    tier,
    requestId,
  });
  res.status(200).json(
    buildSuccessResponse({
      data,
      credits,
      requestId,
    }),
  );
  return snapshot;
}

async function handleAiAction({
  uid,
  email,
  path,
  req,
  res,
  requestId,
  startedAtMs,
}) {
  const body = parseJsonBody(req);
  const effectivePath = wantsContentPlanSync(path, body)
    ? '/tippy/create-content-plan'
    : path;
  const creditCheckStartedAtMs = Date.now();
  const snapshot = await readCurrentCredits(uid, email);
  const tier = snapshot.access.tier;
  const creditsBefore = snapshot.credits.remaining;
  emitRequestLog({
    requestId,
    endpoint: effectivePath,
    uid,
    tier,
    step: 'credit_check_complete',
    latencyMs: Date.now() - creditCheckStartedAtMs,
  });
  const rate = await ensureRateLimit(uid);
  if (!rate.ok) {
    await writeTelemetrySafe({
      uid,
      path,
      status: 429,
      code: 'RATE_LIMITED',
      tier,
      requestId,
    });
    res.status(429).json(
      buildErrorResponse({
        code: 'RATE_LIMITED',
        message: 'Too many requests. Try again soon.',
        status: 429,
        retryable: true,
        requestId,
      }),
    );
    emitRequestLog({
      requestId,
      endpoint: effectivePath,
      uid,
      tier,
      creditsBefore,
      creditsAfter: creditsBefore,
      status: 429,
      latencyMs: Date.now() - startedAtMs,
      errorCode: 'RATE_LIMITED',
      failureReason: 'per_user_rate_limit',
    });
    return;
  }
  const validation = validateRequestBody(effectivePath, body, requestId);
  if (validation != null) {
    await writeTelemetrySafe({
      uid,
      path,
      status: validation.status,
      code: validation.payload.error.code,
      tier,
      requestId,
    });
    res.status(validation.status).json(validation.payload);
    emitRequestLog({
      requestId,
      endpoint: effectivePath,
      uid,
      tier,
      creditsBefore,
      creditsAfter: creditsBefore,
      status: validation.status,
      latencyMs: Date.now() - startedAtMs,
      errorCode: validation.payload.error.code,
      failureReason: 'request_validation_failed',
    });
    return;
  }
  const dailyLimit = await ensureDailyRequestLimit(uid, tier);
  if (!dailyLimit.ok) {
    await writeTelemetrySafe({
      uid,
      path,
      status: 429,
      code: 'RATE_LIMITED',
      tier,
      requestId,
    });
    res.status(429).json(
      buildErrorResponse({
        code: 'RATE_LIMITED',
        message:
          `Daily Tippy limit reached (${dailyLimit.limit}/day). ` +
          'Try again tomorrow.',
        status: 429,
        retryable: true,
        requestId,
      }),
    );
    emitRequestLog({
      requestId,
      endpoint: effectivePath,
      uid,
      tier,
      creditsBefore,
      creditsAfter: creditsBefore,
      status: 429,
      latencyMs: Date.now() - startedAtMs,
      errorCode: 'RATE_LIMITED',
      failureReason: 'per_user_daily_limit',
    });
    return;
  }
  const reservation = await reserveCreditAtomically(uid, email);
  if (!reservation.ok) {
    const isUpgradeRequired = reservation.reason === 'UPGRADE_REQUIRED';
    const code = isUpgradeRequired ? 'UPGRADE_REQUIRED' : 'INSUFFICIENT_CREDITS';
    const message = isUpgradeRequired
      ? 'Upgrade required to access Tippy AI.'
      : 'You have used all AI credits for this month.';
    await writeTelemetrySafe({
      uid,
      path,
      status: 402,
      code,
      tier,
      requestId,
    });
    res.status(402).json(
      buildErrorResponse({
        code,
        message,
        status: 402,
        retryable: false,
        requestId,
      }),
    );
    emitRequestLog({
      requestId,
      endpoint: effectivePath,
      uid,
      tier,
      creditsBefore,
      creditsAfter: creditsBefore,
      status: 402,
      latencyMs: Date.now() - startedAtMs,
      errorCode: code,
      failureReason: code === 'UPGRADE_REQUIRED'
        ? 'plan_not_eligible'
        : 'monthly_credit_limit_reached',
    });
    return;
  }
  const aiStartedAtMs = Date.now();
  emitRequestLog({
    requestId,
    endpoint: effectivePath,
    uid,
    tier,
    step: 'ai_request_start',
    latencyMs: aiStartedAtMs - startedAtMs,
  });
  let aiResult;
  try {
    aiResult = await executeAiAction({
      uid,
      email,
      path: effectivePath,
      body,
      requestId,
      req,
    });
  } catch (err) {
    console.error('Tippy AI action failed', err);
    aiResult = {
      error: buildErrorResponse({
        code: 'AI_PROVIDER_ERROR',
        message: 'Tippy AI is temporarily unavailable. Please try again.',
        status: 502,
        retryable: true,
        requestId,
      }),
      status: 502,
    };
  }
  if (aiResult.error != null) {
    await rollbackReservedCreditAtomically(uid, email);
    await writeTelemetrySafe({
      uid,
      path,
      status: aiResult.status || 500,
      code: aiResult.error.error.code,
      tier,
      requestId,
    });
    res.status(aiResult.status || 500).json(aiResult.error);
    emitRequestLog({
      requestId,
      endpoint: effectivePath,
      uid,
      tier,
      creditsBefore: reservation.previousCredits.remaining,
      creditsAfter: reservation.previousCredits.remaining,
      status: aiResult.status || 500,
      latencyMs: Date.now() - startedAtMs,
      errorCode: aiResult.error.error.code,
      failureReason: 'ai_provider_failure',
    });
    return;
  }
  emitRequestLog({
    requestId,
    endpoint: effectivePath,
    uid,
    tier,
    step: 'ai_complete',
    latencyMs: Date.now() - aiStartedAtMs,
  });
  let data = aiResult;
  if (effectivePath === '/tippy/create-content-plan') {
    const saveStartedAtMs = Date.now();
    let saved;
    try {
      saved = await writeContentPlan(uid, aiResult.plan || aiResult);
    } catch (err) {
      console.error('Tippy content plan save failed', err);
      await rollbackReservedCreditAtomically(uid, email);
      await writeTelemetrySafe({
        uid,
        path: effectivePath,
        status: 500,
        code: 'INTERNAL_ERROR',
        tier,
        requestId,
      });
      res.status(500).json(
        buildErrorResponse({
          code: 'INTERNAL_ERROR',
          message: 'Could not save the content plan. Your credits were not used.',
          status: 500,
          retryable: true,
          requestId,
        }),
      );
      return;
    }
    const planDeepLink = `streamerstip://content-plan/${saved.planId}`;
    data = {
      ...aiResult,
      ...saved,
      message:
        `I created "${saved.title}" and added ${saved.itemCount} items ` +
        'to your content planner.\n' +
        planDeepLink,
    };
    emitRequestLog({
      requestId,
      endpoint: effectivePath,
      uid,
      tier,
      step: 'firestore_save_complete',
      latencyMs: Date.now() - saveStartedAtMs,
    });
  }
  await writeTelemetrySafe({
    uid,
    path: effectivePath,
    status: 200,
    code: 'OK',
    tier,
    requestId,
  });
  res.status(200).json(
    buildSuccessResponse({
      data,
      credits: reservation.credits,
      requestId,
    }),
  );
  emitRequestLog({
    requestId,
    endpoint: effectivePath,
    uid,
    tier,
    creditsBefore: reservation.previousCredits.remaining,
    creditsAfter: reservation.credits.remaining,
    status: 200,
    latencyMs: Date.now() - startedAtMs,
    failureReason: null,
  });
}

async function handleTippyRequest(req, res) {
  const startedAtMs = Date.now();
  const requestId = generateRequestId();
  const allowedPaths = new Set([
    '/tippy/chat',
    '/tippy/create-plan',
    '/tippy/create-content-plan',
    '/tippy/ai-caption',
    '/tippy/analyze-content',
    '/tippy/credits',
  ]);
  const path = normalizeTippyPath(req.path);
  if (!allowedPaths.has(path)) {
    res.status(500).json(
      buildErrorResponse({
        code: 'INTERNAL_ERROR',
        message: 'Unknown Tippy endpoint path.',
        status: 500,
        retryable: false,
        requestId,
      }),
    );
    emitRequestLog({
      requestId,
      endpoint: path,
      uid: 'anonymous',
      tier: 'unknown',
      status: 500,
      latencyMs: Date.now() - startedAtMs,
      errorCode: 'INTERNAL_ERROR',
      failureReason: 'unknown_endpoint',
    });
    return;
  }
  if (path === '/tippy/credits' && req.method !== 'GET') {
    res.status(500).json(
      buildErrorResponse({
        code: 'INTERNAL_ERROR',
        message: 'Method not allowed.',
        status: 500,
        retryable: false,
        requestId,
      }),
    );
    emitRequestLog({
      requestId,
      endpoint: path,
      uid: 'anonymous',
      tier: 'unknown',
      status: 500,
      latencyMs: Date.now() - startedAtMs,
      errorCode: 'INTERNAL_ERROR',
      failureReason: 'invalid_method',
    });
    return;
  }
  if (path !== '/tippy/credits' && req.method !== 'POST') {
    res.status(500).json(
      buildErrorResponse({
        code: 'INTERNAL_ERROR',
        message: 'Method not allowed.',
        status: 500,
        retryable: false,
        requestId,
      }),
    );
    emitRequestLog({
      requestId,
      endpoint: path,
      uid: 'anonymous',
      tier: 'unknown',
      status: 500,
      latencyMs: Date.now() - startedAtMs,
      errorCode: 'INTERNAL_ERROR',
      failureReason: 'invalid_method',
    });
    return;
  }
  const authResult = await verifyFirebaseUser(req, requestId);
  if (!authResult.ok) {
    await writeTelemetrySafe({
      uid: 'anonymous',
      path,
      status: authResult.status,
      code: authResult.payload.error.code,
      tier: 'anonymous',
      requestId,
    });
    res.status(authResult.status).json(authResult.payload);
    emitRequestLog({
      requestId,
      endpoint: path,
      uid: 'anonymous',
      tier: 'anonymous',
      status: authResult.status,
      latencyMs: Date.now() - startedAtMs,
      errorCode: authResult.payload.error.code,
      failureReason: 'auth_failed',
    });
    return;
  }
  emitRequestLog({
    requestId,
    endpoint: path,
    uid: authResult.uid,
    step: 'auth_validation_complete',
    latencyMs: Date.now() - startedAtMs,
  });
  if (path === '/tippy/credits') {
    const snapshot = await handleCreditsGet({
      uid: authResult.uid,
      email: authResult.email,
      requestId,
      res,
    });
    emitRequestLog({
      requestId,
      endpoint: path,
      uid: authResult.uid,
      tier: snapshot.access.tier,
      creditsBefore: snapshot.credits.remaining,
      creditsAfter: snapshot.credits.remaining,
      status: 200,
      latencyMs: Date.now() - startedAtMs,
      failureReason: null,
    });
    return;
  }
  await handleAiAction({
    uid: authResult.uid,
    email: authResult.email,
    path,
    req,
    res,
    requestId,
    startedAtMs,
  });
}

function resolveDayKey(rawTimestamp) {
  if (!rawTimestamp) {
    return 'unknown_day';
  }
  if (typeof rawTimestamp.toDate === 'function') {
    return rawTimestamp.toDate().toISOString().slice(0, 10);
  }
  if (rawTimestamp instanceof Date) {
    return rawTimestamp.toISOString().slice(0, 10);
  }
  return 'unknown_day';
}

function incrementCount(map, key) {
  map[key] = (map[key] || 0) + 1;
}

async function verifyAdminUser(req) {
  const authHeader = String(req.headers.authorization || '');
  if (!authHeader.startsWith('Bearer ')) {
    return {ok: false, status: 401, message: 'Authentication required.'};
  }
  const idToken = authHeader.slice(7).trim();
  if (idToken.length === 0) {
    return {ok: false, status: 401, message: 'Invalid authentication token.'};
  }
  try {
    const decoded = await admin.auth().verifyIdToken(idToken, true);
    const user = await admin.auth().getUser(decoded.uid);
    const isAdmin = user.customClaims?.admin === true;
    if (!isAdmin) {
      return {ok: false, status: 401, message: 'Admin access required.'};
    }
    return {ok: true, uid: decoded.uid};
  } catch (_) {
    return {ok: false, status: 401, message: 'Invalid authentication token.'};
  }
}

async function handleTippyUsageReport(req, res) {
  const requestId = generateRequestId();
  if (req.method !== 'GET') {
    res.status(500).json(
      buildErrorResponse({
        code: 'INTERNAL_ERROR',
        message: 'Method not allowed.',
        status: 500,
        retryable: false,
        requestId,
      }),
    );
    return;
  }
  const auth = await verifyAdminUser(req);
  if (!auth.ok) {
    res.status(auth.status).json(
      buildErrorResponse({
        code: 'AUTH_REQUIRED',
        message: auth.message,
        status: auth.status,
        retryable: false,
        requestId,
      }),
    );
    return;
  }
  const daysRaw = Number(req.query.days || 7);
  const days = Number.isFinite(daysRaw) && daysRaw > 0 && daysRaw <= 31
    ? Math.floor(daysRaw)
    : 7;
  const sinceDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  const sinceTimestamp = admin.firestore.Timestamp.fromDate(sinceDate);
  const snapshot = await firestore
    .collection('tippy_usage_events')
    .where('createdAt', '>=', sinceTimestamp)
    .orderBy('createdAt', 'desc')
    .limit(5000)
    .get();
  const byDay = {};
  const byTier = {};
  const byCode = {};
  const byPath = {};
  snapshot.docs.forEach((doc) => {
    const data = doc.data() || {};
    const day = resolveDayKey(data.createdAt);
    const tier = String(data.tier || 'unknown');
    const code = String(data.code || 'UNKNOWN');
    const path = String(data.path || 'unknown');
    incrementCount(byDay, day);
    incrementCount(byTier, tier);
    incrementCount(byCode, code);
    incrementCount(byPath, path);
  });
  res.status(200).json(
    buildSuccessResponse({
      data: {
        days,
        since: sinceDate.toISOString(),
        totalEvents: snapshot.size,
        byDay,
        byTier,
        byCode,
        byPath,
      },
      credits: null,
      requestId,
    }),
  );
}

module.exports = {
  handleTippyRequest,
  handleTippyUsageReport,
};
