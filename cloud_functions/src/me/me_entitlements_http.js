'use strict';

const admin = require('firebase-admin');

const firestore = admin.firestore();
const {buildUserAccess} = require('../shared/user_tippy_access');
const {getEntitlementsForTier} = require('../shared/entitlements');
const {resolveCreditsForUser} = require('../shared/tippy_credits');

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
        message:
          code === 'TOKEN_EXPIRED'
            ? 'Your session has expired. Please sign in again.'
            : 'Authentication token is invalid.',
        status: 401,
        retryable: false,
        requestId,
      }),
    };
  }
}

function buildTippyFeatures(tier) {
  const t = String(tier || '');
  if (t === 'studio') {
    return [
      'ai_chat',
      'caption_rewrite',
      'content_analysis',
      'content_planner_sync',
      'stream_pc_optimization',
      'advanced_growth_coaching',
      'cross_platform_strategy',
      'studio_priority',
    ];
  }
  if (t === 'pro') {
    return [
      'ai_chat',
      'caption_rewrite',
      'content_analysis',
      'content_planner_sync',
      'growth_reports',
      'stream_optimization',
    ];
  }
  return ['ai_chat_limited', 'basic_posting_tips'];
}

async function handleMeEntitlements(req, res) {
  const requestId = generateRequestId();
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type',
    );
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json(
      buildErrorResponse({
        code: 'INTERNAL_ERROR',
        message: 'Method not allowed.',
        status: 405,
        retryable: false,
        requestId,
      }),
    );
    return;
  }

  const authResult = await verifyFirebaseUser(req, requestId);
  if (!authResult.ok) {
    res.status(authResult.status).json(authResult.payload);
    return;
  }

  const doc = await firestore.collection('users').doc(authResult.uid).get();
  const userData = doc.data() || {};
  const access = buildUserAccess(userData, {
    uid: authResult.uid,
    email: authResult.email,
  });
  const credits = resolveCreditsForUser(userData, access);
  const monthlyCredits = credits.limit;
  const tierEntitlements = getEntitlementsForTier(access.tier);

  res.status(200).json({
    success: true,
    data: {
      uid: authResult.uid,
      email: userData.email || authResult.email || '',
      tier: access.tier,
      effectiveTier: access.tier,
      tierSource: access.tierSource,
      subscriptionStatus: access.status,
      hasStudioAccess: access.hasStudioAccess === true,
      crossPostLimit: access.crossPostLimit,
      aiCreditsMonthlyLimit: monthlyCredits,
      billingRequired: access.billingRequired !== false,
      limits: {
        aiCreditsPerMonth: tierEntitlements.aiCreditsPerMonth,
        analyticsWindowDays: tierEntitlements.analyticsWindowDays,
        contentPlans: tierEntitlements.contentPlans,
        connectedPlatforms: tierEntitlements.connectedPlatforms,
        teamMembers: tierEntitlements.teamMembers,
        crossPostWeeklyLimit: tierEntitlements.crossPostWeeklyLimit,
        schedulingEnabled: tierEntitlements.schedulingEnabled,
      },
      features: tierEntitlements.features,
      tippyAi: {
        enabled: access.canUseTippy,
        monthlyCredits,
        usedCredits: credits.used,
        remainingCredits: credits.remaining,
        plan: access.tier,
        features: buildTippyFeatures(access.tier),
      },
      credits,
    },
    requestId,
  });
}

module.exports = {
  handleMeEntitlements,
};
