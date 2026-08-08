#!/usr/bin/env node
'use strict';

/**
 * Create Cloud Tasks queue: event-reminders
 *
 *   cd cloud_functions && node scripts/ensure_event_reminder_queue.js
 *
 * Loads credentials from streamerstipReact/.env.local when present
 * (FIREBASE_ADMIN_CLIENT_EMAIL + FIREBASE_ADMIN_PRIVATE_KEY).
 */

const path = require('path');
const fs = require('fs');

function loadEnv() {
  const candidates = [
    path.resolve(__dirname, '../../../streamerstipReact/.env.local'),
    path.resolve(__dirname, '../../.env.local'),
    path.resolve(__dirname, '../.env'),
  ];
  for (const file of candidates) {
    if (!fs.existsSync(file)) continue;
    try {
      require('dotenv').config({path: file});
    } catch (_) {
      // dotenv optional — parse manually
      const text = fs.readFileSync(file, 'utf8');
      for (const line of text.split('\n')) {
        const m = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
        if (!m || process.env[m[1]]) continue;
        let v = m[2].trim();
        if (
          (v.startsWith('"') && v.endsWith('"')) ||
          (v.startsWith("'") && v.endsWith("'"))
        ) {
          v = v.slice(1, -1);
        }
        process.env[m[1]] = v.replace(/\\n/g, '\n');
      }
    }
    break;
  }
}

loadEnv();

const {CloudTasksClient} = require('@google-cloud/tasks');

function buildClient() {
  const project =
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.FIREBASE_ADMIN_PROJECT_ID ||
    process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ||
    'streamerstip-6cfdb';

  if (
    process.env.FIREBASE_ADMIN_CLIENT_EMAIL &&
    process.env.FIREBASE_ADMIN_PRIVATE_KEY
  ) {
    return {
      client: new CloudTasksClient({
        projectId: project,
        credentials: {
          client_email: process.env.FIREBASE_ADMIN_CLIENT_EMAIL,
          private_key: process.env.FIREBASE_ADMIN_PRIVATE_KEY.replace(
            /\\n/g,
            '\n',
          ),
        },
      }),
      project,
    };
  }

  return {client: new CloudTasksClient(), project};
}

async function main() {
  const {client, project} = buildClient();
  const location = process.env.EVENT_REMINDER_LOCATION || 'us-central1';
  const queue = process.env.EVENT_REMINDER_QUEUE || 'event-reminders';
  const parent = client.locationPath(project, location);
  const name = client.queuePath(project, location, queue);

  console.log(`Project: ${project}`);
  console.log(`Queue:   ${name}`);

  try {
    await client.getQueue({name});
    console.log('Queue already exists.');
    return;
  } catch (err) {
    if (err.code !== 5) {
      console.error(err.message || err);
      if (String(err.message || '').includes('SERVICE_DISABLED')) {
        console.error(
          '\nEnable Cloud Tasks API first:\n' +
            `https://console.developers.google.com/apis/api/cloudtasks.googleapis.com/overview?project=${project}`,
        );
      }
      process.exit(1);
    }
  }

  const [created] = await client.createQueue({
    parent,
    queue: {
      name,
      retryConfig: {
        maxAttempts: 5,
        maxRetryDuration: {seconds: 3600},
        minBackoff: {seconds: 10},
        maxBackoff: {seconds: 300},
      },
    },
  });
  console.log(`Created queue: ${created.name}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
