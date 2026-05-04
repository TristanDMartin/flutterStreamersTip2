/**
 * Privileged moderation: JWT custom claim `admin` and/or Firestore admin
 * fields on users/{uid} (same model as client rules).
 */
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

const db = () => admin.firestore();
const FieldValue = admin.firestore.FieldValue;

function isFirestoreAdminUserData(d) {
  if (!d || typeof d !== 'object') {
    return false;
  }
  if (d.role === 'admin' || d.isAdmin === true) {
    return true;
  }
  return !!(d.admin && d.admin.isAdmin === true);
}

async function requireAdminAccess(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const uid = request.auth.uid;
  const record = await admin.auth().getUser(uid);
  if (record.customClaims && record.customClaims.admin === true) {
    return uid;
  }
  const snap = await db().collection('users').doc(uid).get();
  if (snap.exists && isFirestoreAdminUserData(snap.data())) {
    return uid;
  }
  throw new HttpsError('permission-denied', 'Admin access required');
}

async function readAdminUsername(adminUid) {
  const snap = await db().collection('users').doc(adminUid).get();
  const d = snap.data() || {};
  return d.username || d.displayName || adminUid;
}

async function appendAdminLog(entry) {
  await db().collection('admin_logs').add({
    adminUid: entry.adminUid,
    adminUsername: entry.adminUsername,
    adminId: entry.adminUid,
    action: entry.action,
    targetType: entry.targetType,
    targetId: entry.targetId,
    reason: entry.reason || null,
    metadata: entry.metadata || {},
    data: entry.metadata || {},
    createdAt: FieldValue.serverTimestamp(),
    timestamp: FieldValue.serverTimestamp(),
  });
}

function adminExecute(region) {
  return onCall({region}, async (request) => {
    const adminUid = await requireAdminAccess(request);
    const body = request.data || {};
    const action = typeof body.action === 'string' ? body.action : '';
    const payload =
      body.payload != null && typeof body.payload === 'object' ? body.payload : {};
    const adminUsername = await readAdminUsername(adminUid);

    switch (action) {
      case 'banUser': {
        const targetUid = payload.targetUid;
        const reason = String(payload.reason || 'policy_violation');
        if (!targetUid || typeof targetUid !== 'string') {
          throw new HttpsError('invalid-argument', 'targetUid required');
        }
        await db().collection('users').doc(targetUid).set(
          {
            accountStatus: 'banned',
            bannedBy: adminUid,
            bannedAt: FieldValue.serverTimestamp(),
            banReason: reason,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        await admin.auth().revokeRefreshTokens(targetUid);
        await appendAdminLog({
          adminUid,
          adminUsername,
          action: 'ban_user',
          targetType: 'user',
          targetId: targetUid,
          reason,
          metadata: {},
        });
        return {ok: true};
      }
      case 'unbanUser': {
        const targetUid = payload.targetUid;
        if (!targetUid || typeof targetUid !== 'string') {
          throw new HttpsError('invalid-argument', 'targetUid required');
        }
        await db().collection('users').doc(targetUid).set(
          {
            accountStatus: 'active',
            bannedBy: FieldValue.delete(),
            bannedAt: FieldValue.delete(),
            banReason: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        await appendAdminLog({
          adminUid,
          adminUsername,
          action: 'unban_user',
          targetType: 'user',
          targetId: targetUid,
          reason: null,
          metadata: {},
        });
        return {ok: true};
      }
      case 'removeVideo': {
        const videoId = payload.videoId;
        const reason = String(payload.reason || 'policy_violation');
        if (!videoId || typeof videoId !== 'string') {
          throw new HttpsError('invalid-argument', 'videoId required');
        }
        await db().collection('videos').doc(videoId).set(
          {
            status: 'removed',
            visibility: 'admin_removed',
            moderationStatus: 'removed',
            removedBy: adminUid,
            removedAt: FieldValue.serverTimestamp(),
            removalReason: reason,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        await appendAdminLog({
          adminUid,
          adminUsername,
          action: 'remove_video',
          targetType: 'video',
          targetId: videoId,
          reason,
          metadata: {},
        });
        return {ok: true};
      }
      case 'restoreVideo': {
        const videoId = payload.videoId;
        if (!videoId || typeof videoId !== 'string') {
          throw new HttpsError('invalid-argument', 'videoId required');
        }
        await db().collection('videos').doc(videoId).set(
          {
            status: 'ready',
            visibility: 'public',
            moderationStatus: 'clean',
            removedBy: FieldValue.delete(),
            removedAt: FieldValue.delete(),
            removalReason: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        await appendAdminLog({
          adminUid,
          adminUsername,
          action: 'restore_video',
          targetType: 'video',
          targetId: videoId,
          reason: null,
          metadata: {},
        });
        return {ok: true};
      }
      case 'dismissReport': {
        const reportId = payload.reportId;
        const reason = String(payload.reason || 'dismissed');
        if (!reportId || typeof reportId !== 'string') {
          throw new HttpsError('invalid-argument', 'reportId required');
        }
        await db().collection('reports').doc(reportId).set(
          {
            status: 'dismissed',
            reviewedBy: adminUid,
            reviewedAt: FieldValue.serverTimestamp(),
            actionTaken: 'dismissed',
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        await appendAdminLog({
          adminUid,
          adminUsername,
          action: 'dismiss_report',
          targetType: 'report',
          targetId: reportId,
          reason,
          metadata: {},
        });
        return {ok: true};
      }
      case 'resolveReport': {
        const reportId = payload.reportId;
        const reason = String(payload.reason || 'resolved');
        const actionTaken = String(payload.actionTaken || 'resolved');
        if (!reportId || typeof reportId !== 'string') {
          throw new HttpsError('invalid-argument', 'reportId required');
        }
        await db().collection('reports').doc(reportId).set(
          {
            status: 'resolved',
            reviewedBy: adminUid,
            reviewedAt: FieldValue.serverTimestamp(),
            actionTaken,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        await appendAdminLog({
          adminUid,
          adminUsername,
          action: 'resolve_report',
          targetType: 'report',
          targetId: reportId,
          reason,
          metadata: {actionTaken},
        });
        return {ok: true};
      }
      default:
        throw new HttpsError('invalid-argument', `Unknown action: ${action}`);
    }
  });
}

function adminDashboardStats(region) {
  return onCall({region}, async (request) => {
    await requireAdminAccess(request);
    const countEq = async (coll, field, value) => {
      const snap = await db()
        .collection(coll)
        .where(field, '==', value)
        .count()
        .get();
      return snap.data().count;
    };
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startTs = admin.firestore.Timestamp.fromDate(start);
    let newUsersToday = 0;
    try {
      const nu = await db()
        .collection('users')
        .where('createdAt', '>=', startTs)
        .count()
        .get();
      newUsersToday = nu.data().count;
    } catch (e) {
      console.warn('adminDashboardStats newUsersToday', e.message);
    }
    const [
      openReports,
      flaggedVideos,
      failedUploads,
      bannedUsers,
      processingVideos,
      totalUploads,
    ] = await Promise.all([
      countEq('reports', 'status', 'open'),
      countEq('videos', 'moderationStatus', 'flagged'),
      countEq('videos', 'status', 'failed'),
      countEq('users', 'accountStatus', 'banned'),
      countEq('videos', 'status', 'processing'),
      db().collection('videos').count().get().then((s) => s.data().count),
    ]);
    return {
      ok: true,
      openReports,
      flaggedVideos,
      failedUploads,
      bannedUsers,
      newUsersToday,
      totalUploads,
      processingVideos,
    };
  });
}

module.exports = {adminExecute, adminDashboardStats};
