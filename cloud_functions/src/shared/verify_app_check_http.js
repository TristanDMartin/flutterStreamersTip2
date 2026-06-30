'use strict';

const admin = require('firebase-admin');

function appCheckDisabled() {
  return (
    process.env.FUNCTIONS_EMULATOR === 'true' ||
    process.env.APP_CHECK_DISABLED === 'true' ||
    process.env.DISABLE_APP_CHECK === 'true'
  );
}

function readAppCheckToken(req) {
  return String(
      req.headers['x-firebase-appcheck'] ||
      req.headers['X-Firebase-AppCheck'] ||
      '',
  ).trim();
}

async function verifyAppCheckHttp(req, {requestId = ''} = {}) {
  if (appCheckDisabled()) {
    return {ok: true, requestId};
  }
  const token = readAppCheckToken(req);
  if (!token) {
    return {
      ok: false,
      status: 401,
      code: 'APP_CHECK_REQUIRED',
      message: 'App Check token is required.',
      requestId,
    };
  }
  try {
    await admin.appCheck().verifyToken(token);
    return {ok: true, requestId};
  } catch (err) {
    return {
      ok: false,
      status: 401,
      code: 'APP_CHECK_INVALID',
      message: 'App Check token is invalid.',
      requestId,
    };
  }
}

module.exports = {
  verifyAppCheckHttp,
};
