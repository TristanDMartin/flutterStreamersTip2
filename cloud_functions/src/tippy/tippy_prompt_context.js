const admin = require('firebase-admin');

const firestore = admin.firestore();

function pickString(data, keys, fallback = '') {
  for (const key of keys) {
    const value = data && data[key];
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
  }
  return fallback;
}

function readTier(userData) {
  return pickString(
    userData,
    ['subscriptionTier', 'subscription_tier', 'tier', 'plan'],
    'starter',
  ).toLowerCase();
}

function readCreatorName(userData, email = '') {
  return pickString(
    userData,
    ['username', 'displayName', 'display_name', 'name'],
    email ? email.split('@')[0] : 'creator',
  ).replace(/^@+/, '') || 'creator';
}

async function readGoals(uid) {
  const snap = await firestore
    .collection('users')
    .doc(uid)
    .collection('creatorGoals')
    .orderBy('updatedAt', 'desc')
    .limit(5)
    .get()
    .catch(() => null);
  if (!snap) {
    return [];
  }
  return snap.docs.map((doc) => ({id: doc.id, ...doc.data()}));
}

async function readMemory(uid) {
  const userRef = firestore.collection('users').doc(uid);
  const [brainSnap, legacySnap] = await Promise.all([
    userRef.collection('creatorMemory').doc('main').get().catch(() => null),
    userRef.collection('tippyMemory').doc('summary').get().catch(() => null),
  ]);
  const brain = brainSnap && brainSnap.exists ? brainSnap.data() || {} : {};
  const legacy = legacySnap && legacySnap.exists ? legacySnap.data() || {} : {};
  const platforms =
    (brain.platformIntelligence && brain.platformIntelligence.platforms) ||
    (brain.platforms && brain.platforms.primary && brain.platforms.primary.value) ||
    [];
  return {
    ...legacy,
    ...brain,
    platforms,
    memoryReady:
      Object.keys(brain).length > 0 ||
      legacy.memoryReady === true ||
      Object.keys(legacy).length > 0,
  };
}

async function loadTippyPromptContext(uid, email = '', options = {}) {
  const userDoc = await firestore.collection('users').doc(uid).get();
  const userData = userDoc.exists ? userDoc.data() || {} : {};
  const [memory, goals] = await Promise.all([
    readMemory(uid),
    readGoals(uid),
  ]);
  const tier = readTier(userData);
  return {
    uid,
    email,
    tier,
    creatorName: readCreatorName(userData, email),
    userData,
    memory: {
      ...memory,
      memoryReady: memory.memoryReady === true ||
        Object.keys(memory).length > 0,
    },
    goals,
    analyticsProfile: userData.analyticsProfile || {},
    extras: {
      category: options.category || '',
      surface: options.surface || '',
    },
  };
}

function buildMemoryAwareGreeting(creatorName, memory = {}, tierLabel = 'Creator') {
  const niche =
    memory.niche?.labels?.[0] ||
    memory.niche?.primaryCategoryId ||
    memory.primaryNiche ||
    '';
  if (niche) {
    return `Hey ${creatorName}, your ${tierLabel} coaching is ready. ` +
      `Want to work on ${niche} content today?`;
  }
  return `Hey ${creatorName}, your ${tierLabel} coaching is ready.`;
}

function buildUiPayload({memory = {}, goals = [], analyticsProfile = {}, path}) {
  return {
    path,
    memoryReady: memory.memoryReady === true,
    activeGoals: Array.isArray(goals) ? goals.slice(0, 3) : [],
    analyticsReady: Object.keys(analyticsProfile || {}).length > 0,
  };
}

module.exports = {
  buildMemoryAwareGreeting,
  buildUiPayload,
  loadTippyPromptContext,
};
