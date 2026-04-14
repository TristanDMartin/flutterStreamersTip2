/**
 * Optional Firebase HTTPS handler — prefer Cloudflare Worker for gamification
 * (`cloudflare_workers/mux` POST /gamification/events) to minimize CF usage/cost.
 */
const admin = require('firebase-admin');
const {MISSION_TEMPLATES} = require('./mission_templates');

const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const cumulativeXpForLevel = [
  0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700, 3300, 4000, 4800, 5700,
  6700,
];

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

function readXp(gam) {
  if (!gam || typeof gam !== 'object') return 0;
  return readInt(gam.totalXp) || readInt(gam.total_xp) || readInt(gam.xp);
}

function readTs(val) {
  if (!val) return null;
  if (typeof val.toDate === 'function') return val.toDate();
  if (val instanceof Date) return val;
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
    return {list: undefined, xpGain: 0};
  }
  if (!Array.isArray(list)) {
    return {list: list, xpGain: 0};
  }
  let xpGain = 0;
  const out = list.map((raw) => {
    if (!raw || typeof raw !== 'object') return raw;
    const m = {...raw};
    if (!isMissionRowActive(m, now)) return m;
    const tid = m.templateId || m.template_id;
    const tmpl = tid ? MISSION_TEMPLATES[tid] : null;
    if (!tmpl || !tmpl.progressEventKeys.has(eventType)) return m;
    const target = readInt(m.target) || tmpl.target || 1;
    let progress = readInt(m.progress);
    const rewardXp = readInt(m.rewardXp) || readInt(m.reward_xp) || tmpl.rewardXp || 0;
    const st = String(m.status || 'active').toLowerCase();
    if (st === 'completed' || st === 'claimed' || progress >= target) return m;
    progress += 1;
    m.progress = progress;
    if (progress >= target) {
      m.status = 'completed';
      m.completedAt = Timestamp.now();
      m.rewardClaimed = true;
      xpGain += rewardXp;
    }
    return m;
  });
  return {list: out, xpGain};
}

function isAlreadyExistsError(e) {
  return e.code === 6 ||
    e.code === 'ALREADY_EXISTS' ||
    (e.message && String(e.message).includes('ALREADY_EXISTS'));
}

async function applyGamificationMissions(db, uid, eventType, eventId) {
  const userRef = db.collection('users').doc(uid);
  const auditRef = userRef.collection('gamification_audit').doc(eventId);
  await db.runTransaction(async (tx) => {
    const auditSnap = await tx.get(auditRef);
    if (auditSnap.exists) return;
    const userSnap = await tx.get(userRef);
    const d = userSnap.exists ? userSnap.data() : {};
    const hasDaily = Array.isArray(d.dailyMissions);
    const hasWeekly = Array.isArray(d.missions);
    if (!hasDaily && !hasWeekly) {
      tx.set(auditRef, {
        eventId,
        uid,
        type: eventType,
        xpGained: 0,
        processedAt: FieldValue.serverTimestamp(),
      });
      return;
    }
    const now = new Date();
    const dailyRaw = hasDaily ? d.dailyMissions : undefined;
    const missionsRaw = hasWeekly ? d.missions : undefined;
    const r1 = applyEventToMissionList(dailyRaw, eventType, now);
    const r2 = applyEventToMissionList(missionsRaw, eventType, now);
    const xpGain = r1.xpGain + r2.xpGain;
    const gam = d.gamification && typeof d.gamification === 'object'
      ? d.gamification
      : {};
    const currentXp = readXp(gam);
    const newXp = currentXp + xpGain;
    const level = levelFromTotalXp(newXp);
    const rankTitle = rankTitleForLevel(level);
    const updates = {
      'gamification.totalXp': FieldValue.increment(xpGain),
      'gamification.level': level,
      'gamification.rankTitle': rankTitle,
      'gamification.updatedAt': FieldValue.serverTimestamp(),
    };
    if (r1.list !== undefined) updates.dailyMissions = r1.list;
    if (r2.list !== undefined) updates.missions = r2.list;
    tx.update(userRef, updates);
    tx.set(auditRef, {
      eventId,
      uid,
      type: eventType,
      xpGained: xpGain,
      processedAt: FieldValue.serverTimestamp(),
    });
  });
}

async function handleGamificationEvents(req, res) {
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({error: 'Method not allowed'});
    return;
  }
  const db = admin.firestore();
  try {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({error: 'Missing Authorization: Bearer <id_token>'});
      return;
    }
    const idToken = authHeader.slice(7).trim();
    const decoded = await admin.auth().verifyIdToken(idToken);
    const verifiedUid = decoded.uid;
    const body = typeof req.body === 'string'
      ? JSON.parse(req.body || '{}')
      : (req.body || {});
    if (body === null || typeof body !== 'object' || Array.isArray(body)) {
      res.status(400).json({error: 'Body must be a JSON object'});
      return;
    }
    const eventId = body.eventId;
    const bodyUid = body.uid;
    const eventType = body.type;
    if (typeof eventId !== 'string' || eventId.trim() === '') {
      res.status(400).json({error: 'eventId is required (non-empty string)'});
      return;
    }
    if (typeof bodyUid !== 'string' || bodyUid.trim() === '') {
      res.status(400).json({error: 'uid is required (non-empty string)'});
      return;
    }
    if (typeof eventType !== 'string' || eventType.trim() === '') {
      res.status(400).json({error: 'type is required (non-empty string)'});
      return;
    }
    if (bodyUid.trim() !== verifiedUid) {
      res.status(403).json({error: 'uid must match authenticated user'});
      return;
    }
    const id = eventId.trim();
    const typeStr = eventType.trim();
    try {
      await db.collection('gamification_events').doc(id).create({
        uid: verifiedUid,
        type: typeStr,
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!isAlreadyExistsError(e)) throw e;
    }
    await applyGamificationMissions(db, verifiedUid, typeStr, id);
    res.status(200).json({ok: true});
  } catch (e) {
    console.error('gamificationEvents', e);
    const msg = e.message || 'Internal error';
    if (msg.includes('auth') || msg.includes('token') || msg.includes('Firebase ID token')) {
      res.status(401).json({error: msg});
      return;
    }
    res.status(500).json({error: msg});
  }
}

module.exports = {handleGamificationEvents};
