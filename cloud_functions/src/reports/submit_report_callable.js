'use strict';

const admin = require('firebase-admin');
const {HttpsError} = require('firebase-functions/v2/https');
const {resolveOwnerId} = require('../videos/video_owner');
const {canAccountUseProduct} = require('../shared/account_status');
const {
  parseReportRequest,
  buildReportId,
  isRateLimited,
  nextRateLimit,
} = require('./report_request');

const FieldValue = admin.firestore.FieldValue;
const firestore = admin.firestore();

const EVIDENCE_MESSAGE_LIMIT = 20;
const EVIDENCE_TEXT_LIMIT = 2000;

function resolveMessageSender(data) {
  return data?.from || data?.senderId || data?.userId || null;
}

function snapshotMessage(doc) {
  const data = doc.data() || {};
  const text = String(data.text || data.content || data.message || '');
  return {
    messageId: doc.id,
    senderId: resolveMessageSender(data),
    type: data.type || 'text',
    text: text.slice(0, EVIDENCE_TEXT_LIMIT),
    mediaUrl: data.gifUrl || data.imageUrl || data.mediaUrl || null,
    sentAt: data.timestamp || data.createdAt || null,
  };
}

async function requireChatParticipants(chatId, uids) {
  const chat = await firestore.collection('chats').doc(chatId).get();
  const participants = chat.exists ? chat.data().participants || [] : [];
  if (!uids.every((uid) => participants.includes(uid))) {
    throw new HttpsError('permission-denied', 'Not a participant in this chat.');
  }
}

async function loadRecentMessagesFrom(chatId, senderId) {
  const snap = await firestore.collection('chats').doc(chatId).collection('messages')
      .orderBy('timestamp', 'desc').limit(EVIDENCE_MESSAGE_LIMIT * 3).get();
  return snap.docs.map(snapshotMessage)
      .filter((message) => message.senderId === senderId)
      .slice(0, EVIDENCE_MESSAGE_LIMIT);
}

async function requireDoc(ref) {
  const doc = await ref.get();
  if (!doc.exists) throw new HttpsError('not-found', 'Reported content not found.');
  return doc;
}

/** Server-resolved target: owner, admin-panel fields, evidence, counter refs. */
async function resolveTarget(request, reporterId) {
  const {targetType, targetId, videoId, postId, chatId} = request;
  const videos = firestore.collection('videos');
  const posts = firestore.collection('forumPosts');
  if (targetType === 'video') {
    const doc = await requireDoc(videos.doc(targetId));
    return {ownerId: resolveOwnerId(doc.data()), fields: {videoId: targetId},
      counterRef: doc.ref, counterField: 'reportCount'};
  }
  if (targetType === 'videoComment') {
    const doc = await requireDoc(videos.doc(videoId).collection('comments').doc(targetId));
    return {ownerId: resolveOwnerId(doc.data()), fields: {videoId, commentId: targetId},
      counterRef: videos.doc(videoId), counterField: 'commentReportCount'};
  }
  if (targetType === 'thread') {
    const doc = await requireDoc(posts.doc(targetId));
    return {ownerId: resolveOwnerId(doc.data()), fields: {postId: targetId},
      counterRef: doc.ref, counterField: 'reportCount'};
  }
  if (targetType === 'threadComment') {
    const doc = await requireDoc(posts.doc(postId).collection('comments').doc(targetId));
    return {ownerId: resolveOwnerId(doc.data()), fields: {postId, commentId: targetId},
      counterRef: posts.doc(postId), counterField: 'commentReportCount'};
  }
  if (targetType === 'message') {
    await requireChatParticipants(chatId, [reporterId]);
    const doc = await requireDoc(
        firestore.collection('chats').doc(chatId).collection('messages').doc(targetId));
    const evidence = snapshotMessage(doc);
    return {ownerId: evidence.senderId, fields: {chatId, messageId: targetId},
      evidence: {messages: [evidence]}};
  }
  await requireDoc(firestore.collection('users').doc(targetId));
  if (!chatId) return {ownerId: targetId, fields: {userId: targetId}};
  await requireChatParticipants(chatId, [reporterId, targetId]);
  const messages = await loadRecentMessagesFrom(chatId, targetId);
  return {ownerId: targetId, fields: {userId: targetId, chatId}, evidence: {messages}};
}

function buildReportDoc({request, reporterId, target}) {
  return {
    reportType: request.targetType,
    targetType: request.targetType,
    targetId: request.targetId,
    ...target.fields,
    creatorId: target.ownerId,
    reporterId,
    reason: request.reason,
    additionalDetails: request.details,
    evidence: target.evidence || null,
    status: 'pending',
    reviewedBy: null,
    reviewedAt: null,
    actionTaken: null,
    source: 'submitReport',
    timestamp: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
  };
}

function incrementCounter(tx, doc, field) {
  if (!doc?.exists) return;
  tx.update(doc.ref, {
    [field]: FieldValue.increment(1),
    lastReportedAt: FieldValue.serverTimestamp(),
  });
}

async function writeReport({request, reporterId, target}) {
  const collection = request.targetType === 'user' ? 'user_reports' : 'reports';
  const reportRef = firestore.collection(collection).doc(buildReportId({...request, reporterId}));
  const limitRef = firestore.collection('reportRateLimits').doc(reporterId);
  const ownerRef = firestore.collection('users').doc(target.ownerId);
  return firestore.runTransaction(async (tx) => {
    const [existing, limit, owner, counter] = await Promise.all([
      tx.get(reportRef),
      tx.get(limitRef),
      tx.get(ownerRef),
      target.counterRef ? tx.get(target.counterRef) : null,
    ]);
    if (existing.exists) return {duplicate: true, reportId: reportRef.id};
    const nowMs = Date.now();
    if (isRateLimited(limit.data(), nowMs)) {
      throw new HttpsError('resource-exhausted', 'Too many reports. Try again later.');
    }
    tx.set(reportRef, buildReportDoc({request, reporterId, target}));
    tx.set(limitRef, nextRateLimit(limit.data(), nowMs));
    incrementCounter(tx, counter, target.counterField);
    incrementCounter(tx, owner, 'reportCount');
    return {duplicate: false, reportId: reportRef.id};
  });
}

async function handleSubmitReport(req) {
  const reporterId = req.auth?.uid;
  if (!reporterId) throw new HttpsError('unauthenticated', 'Sign in to report content.');
  if (req.auth.token?.email_verified !== true) {
    throw new HttpsError('failed-precondition', 'Verify your email to report content.');
  }
  if (!(await canAccountUseProduct(reporterId))) {
    throw new HttpsError('permission-denied', 'Account is restricted.');
  }
  const parsed = parseReportRequest(req.data);
  if (!parsed.ok) throw new HttpsError('invalid-argument', parsed.reason);
  const target = await resolveTarget(parsed.request, reporterId);
  if (!target.ownerId) throw new HttpsError('failed-precondition', 'Content owner unresolved.');
  if (target.ownerId === reporterId) {
    throw new HttpsError('invalid-argument', 'You cannot report your own content.');
  }
  const result = await writeReport({request: parsed.request, reporterId, target});
  return {ok: true, ...result};
}

module.exports = {handleSubmitReport};
