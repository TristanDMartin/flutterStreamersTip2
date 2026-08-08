'use strict';

/**
 * Calendar event reminder scheduling via Google Cloud Tasks.
 *
 * Ownership:
 *   users/{uid}/bookmarks/{eventId} onCreate → schedule
 *   onDelete → cancel
 *   Cloud Tasks → POST deliverEventReminder → FCM (+ Activity)
 *
 * Queue (one-time):
 *   gcloud tasks queues create event-reminders --location=us-central1 \
 *     --project=streamerstip-6cfdb
 *
 * Env (optional overrides):
 *   EVENT_REMINDER_QUEUE=event-reminders
 *   EVENT_REMINDER_LOCATION=us-central1
 *   EVENT_REMINDER_HANDLER_URL=https://us-central1-PROJECT.cloudfunctions.net/deliverEventReminder
 *   EVENT_REMINDER_TASK_SECRET=<random>
 *   EVENT_REMINDER_SERVICE_ACCOUNT=PROJECT@appspot.gserviceaccount.com
 */

const {CloudTasksClient} = require('@google-cloud/tasks');
const admin = require('firebase-admin');

const MAX_SCHEDULE_AHEAD_MS = 29 * 24 * 60 * 60 * 1000; // Cloud Tasks ~30d limit
const QUEUE_ID = () => process.env.EVENT_REMINDER_QUEUE || 'event-reminders';
const LOCATION = () => process.env.EVENT_REMINDER_LOCATION || 'us-central1';

let tasksClient = null;

function getTasksClient() {
  if (!tasksClient) {
    tasksClient = new CloudTasksClient();
  }
  return tasksClient;
}

function projectId() {
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
  if (process.env.GCP_PROJECT) return process.env.GCP_PROJECT;
  if (process.env.FIREBASE_CONFIG) {
    try {
      return JSON.parse(process.env.FIREBASE_CONFIG).projectId;
    } catch (_) {
      // fall through
    }
  }
  return admin.app().options.projectId || 'streamerstip-6cfdb';
}

function handlerUrl() {
  if (process.env.EVENT_REMINDER_HANDLER_URL) {
    return process.env.EVENT_REMINDER_HANDLER_URL;
  }
  const project = projectId();
  const location = LOCATION();
  return `https://${location}-${project}.cloudfunctions.net/deliverEventReminder`;
}

function serviceAccountEmail() {
  if (process.env.EVENT_REMINDER_SERVICE_ACCOUNT) {
    return process.env.EVENT_REMINDER_SERVICE_ACCOUNT;
  }
  return `${projectId()}@appspot.gserviceaccount.com`;
}

function taskAuthSecret() {
  if (process.env.EVENT_REMINDER_TASK_SECRET) {
    return process.env.EVENT_REMINDER_TASK_SECRET;
  }
  try {
    const functions = require('firebase-functions');
    const cfg = functions.config();
    return (cfg && cfg.event_reminder && cfg.event_reminder.task_secret) || '';
  } catch (_) {
    return '';
  }
}

function sanitizeTaskId(uid, eventId) {
  const raw = `er_${uid}_${eventId}`.replace(/[^a-zA-Z0-9_-]/g, '_');
  return raw.slice(0, 500);
}

function parseNotifyAt(raw) {
  if (!raw) return null;
  if (typeof raw.toDate === 'function') {
    try {
      return raw.toDate();
    } catch (_) {
      return null;
    }
  }
  if (raw instanceof Date) return raw;
  if (typeof raw === 'number') {
    return new Date(raw > 1e12 ? raw : raw * 1000);
  }
  if (typeof raw === 'string') {
    const d = new Date(raw);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof raw === 'object' && typeof raw.seconds === 'number') {
    return new Date(raw.seconds * 1000);
  }
  return null;
}

/**
 * Create (or replace) a Cloud Task for an event reminder.
 * Returns the full task resource name for cancel.
 */
async function scheduleEventReminderTask({
  uid,
  eventId,
  runAt,
  title,
  creatorId,
  creatorName,
}) {
  const notifyAt = runAt instanceof Date ? runAt : parseNotifyAt(runAt);
  if (!notifyAt || Number.isNaN(notifyAt.getTime())) {
    throw new Error('Invalid notifyAt');
  }

  const now = Date.now();
  if (notifyAt.getTime() <= now + 5000) {
    // Due now / past — deliver immediately; no durable task needed.
    await deliverEventReminderPayload({
      uid,
      eventId,
      title,
      creatorId,
      creatorName,
      phase: 'deliver',
    });
    return `immediate:${uid}:${eventId}`;
  }

  let scheduleAt = notifyAt;
  let phase = 'deliver';
  if (notifyAt.getTime() - now > MAX_SCHEDULE_AHEAD_MS) {
    // Cloud Tasks max ~30 days — re-check later and schedule the real fire.
    scheduleAt = new Date(now + MAX_SCHEDULE_AHEAD_MS);
    phase = 'reschedule';
  }

  const client = getTasksClient();
  const project = projectId();
  const location = LOCATION();
  const queue = QUEUE_ID();
  const parent = client.queuePath(project, location, queue);
  const taskId = sanitizeTaskId(uid, eventId);
  const name = client.taskPath(project, location, queue, taskId);
  const url = handlerUrl();
  const secret = taskAuthSecret();

  const payload = {
    uid,
    eventId,
    title: title || 'Event',
    creatorId: creatorId || '',
    creatorName: creatorName || '',
    notifyAt: notifyAt.toISOString(),
    phase,
  };

  const httpRequest = {
    httpMethod: 'POST',
    url,
    headers: {
      'Content-Type': 'application/json',
      ...(secret ? {'X-Event-Reminder-Secret': secret} : {}),
    },
    body: Buffer.from(JSON.stringify(payload)).toString('base64'),
    oidcToken: {
      serviceAccountEmail: serviceAccountEmail(),
      audience: url,
    },
  };

  const task = {
    name,
    httpRequest,
    scheduleTime: {
      seconds: Math.floor(scheduleAt.getTime() / 1000),
    },
  };

  try {
    // Delete existing same-named task so notifyAt updates replace cleanly.
    try {
      await client.deleteTask({name});
    } catch (err) {
      if (err.code !== 5 /* NOT_FOUND */) {
        // Ignore race; create may still succeed or return ALREADY_EXISTS
      }
    }
    const [created] = await client.createTask({parent, task});
    console.log(
      `✅ Cloud Tasks reminder scheduled: ${created.name} at ${scheduleAt.toISOString()} phase=${phase}`,
    );
    return created.name;
  } catch (err) {
    if (err.code === 6 /* ALREADY_EXISTS */) {
      console.log(`ℹ️ Reminder task already exists: ${name}`);
      return name;
    }
    console.error('❌ Failed to schedule Cloud Tasks reminder:', err.message || err);
    throw err;
  }
}

async function cancelEventReminderTask(taskName) {
  if (!taskName || typeof taskName !== 'string') return false;
  if (taskName.startsWith('immediate:') || taskName.startsWith('task_')) {
    // Legacy setTimeout ids — nothing to cancel in Cloud Tasks.
    return false;
  }
  const client = getTasksClient();
  try {
    await client.deleteTask({name: taskName});
    console.log(`✅ Cancelled Cloud Tasks reminder: ${taskName}`);
    return true;
  } catch (err) {
    if (err.code === 5 /* NOT_FOUND */) {
      return false;
    }
    console.error('❌ Failed to cancel Cloud Tasks reminder:', err.message || err);
    return false;
  }
}

async function deliverEventReminderPayload(data) {
  const {
    uid,
    eventId,
    title,
    creatorId,
    creatorName,
    notifyAt,
    phase = 'deliver',
  } = data || {};

  if (!uid || !eventId) {
    return {success: false, reason: 'Missing uid/eventId'};
  }

  if (phase === 'reschedule') {
    const runAt = parseNotifyAt(notifyAt) || new Date(notifyAt);
    const taskName = await scheduleEventReminderTask({
      uid,
      eventId,
      runAt,
      title,
      creatorId,
      creatorName,
    });
    await admin
      .firestore()
      .collection('users')
      .doc(uid)
      .collection('bookmarks')
      .doc(eventId)
      .set({scheduledTaskId: taskName, updatedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
    return {success: true, phase: 'reschedule', taskName};
  }

  const bookmarkRef = admin
    .firestore()
    .collection('users')
    .doc(uid)
    .collection('bookmarks')
    .doc(eventId);
  const bookmarkDoc = await bookmarkRef.get();

  if (!bookmarkDoc.exists) {
    console.log(`Bookmark ${eventId} no longer exists for user ${uid}`);
    return {success: false, reason: 'Bookmark not found'};
  }

  const bookmarkData = bookmarkDoc.data() || {};
  if (bookmarkData.notify === false) {
    console.log(`Notifications disabled for bookmark ${eventId}`);
    return {success: false, reason: 'Notifications disabled'};
  }

  if (bookmarkData.notifiedAt) {
    console.log(`Already notified for bookmark ${eventId}`);
    return {success: true, reason: 'Already notified'};
  }

  const displayTitle = title || bookmarkData.title || 'Event';
  const hostId = creatorId || bookmarkData.creatorId || '';
  const hostLabel =
    creatorName ||
    bookmarkData.creatorName ||
    hostId ||
    'Creator';
  const hostUsername =
    bookmarkData.creatorUsername ||
    bookmarkData.username ||
    '';

  const reminderActionUrl = hostUsername
    ? `/streamer/${encodeURIComponent(hostUsername)}?tab=calendar`
    : '/profile?tab=calendar';

  const tokensSnapshot = await admin
    .firestore()
    .collection('users')
    .doc(uid)
    .collection('deviceTokens')
    .get();
  const tokens = tokensSnapshot.docs.map((doc) => doc.id);

  let sentCount = 0;
  if (tokens.length > 0) {
    const message = {
      notification: {
        title: 'Upcoming event',
        body: `${hostLabel} — ${displayTitle}`,
      },
      data: {
        type: 'calendar_event_reminder',
        eventId: String(eventId),
        creatorId: String(hostId),
        route: reminderActionUrl,
        deeplink: `streamerstip://event/${eventId}`,
        schemaVersion: '1',
      },
      tokens,
    };
    try {
      const messaging = admin.messaging();
      const response = messaging.sendEachForMulticast
        ? await messaging.sendEachForMulticast(message)
        : await messaging.sendMulticast(message);
      sentCount = response.successCount || 0;
      console.log(`Sent event reminder to ${sentCount}/${tokens.length} devices`);
    } catch (error) {
      console.error('Error sending event reminder FCM:', error);
    }
  } else {
    console.log(`No FCM tokens for user ${uid} — writing Activity only`);
  }

  // Canonical Activity row (idempotent doc id)
  const activityId = `cal_reminder_${eventId}`.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 700);
  await admin
    .firestore()
    .collection('notifications')
    .doc(uid)
    .collection('items')
    .doc(activityId)
    .set(
      {
        type: 'calendar_event_reminder',
        userId: uid,
        actor: {
          id: hostId || 'streamerstip',
          username: hostUsername || hostLabel,
          displayName: hostLabel,
          avatarURL: null,
        },
        title: 'Upcoming event',
        body: `${hostLabel} — ${displayTitle}`,
        message: `${hostLabel} — ${displayTitle}`,
        eventId,
        actionType: 'navigate',
        actionUrl: reminderActionUrl,
        metadata: {
          eventId,
          creatorId: hostId,
          eventTitle: displayTitle,
        },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        status: 'pending',
        platform: 'both',
        schemaVersion: 1,
      },
      {merge: true},
    );

  await bookmarkRef.update({
    notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    scheduledTaskId: admin.firestore.FieldValue.delete(),
  });

  return {success: true, sentCount, activityId};
}

function assertTaskRequestAuthorized(req) {
  const secret = taskAuthSecret();
  if (!secret) {
    // OIDC-only when secret unset — still require Cloud Tasks UA or OIDC header.
    const auth = req.get('authorization') || '';
    if (auth.toLowerCase().startsWith('bearer ')) return true;
    // Emulator / local
    if (process.env.FUNCTIONS_EMULATOR === 'true') return true;
    return false;
  }
  const header = req.get('x-event-reminder-secret') || '';
  return header === secret;
}

module.exports = {
  scheduleEventReminderTask,
  cancelEventReminderTask,
  deliverEventReminderPayload,
  assertTaskRequestAuthorized,
  parseNotifyAt,
  sanitizeTaskId,
  handlerUrl,
  QUEUE_ID,
  LOCATION,
  projectId,
};
