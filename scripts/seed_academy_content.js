#!/usr/bin/env node
/**
 * Seed demo Streamer Academy content into Firestore.
 *
 * Emulator:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
 *   GCLOUD_PROJECT=demo-streamerstip \
 *   node scripts/seed_academy_content.js
 *
 * Production (requires Application Default Credentials):
 *   node scripts/seed_academy_content.js
 *
 * Idempotent: uses fixed document IDs and merge writes.
 */

const path = require('path');
const Module = require('module');

// Prefer firebase-admin from cloud_functions when run from repo root.
const cloudFunctionsNodeModules = path.join(
  __dirname,
  '..',
  'cloud_functions',
  'node_modules',
);
Module._nodeModulePaths = ((original) => {
  return function patchedNodeModulePaths(from) {
    const paths = original.call(this, from);
    if (!paths.includes(cloudFunctionsNodeModules)) {
      paths.unshift(cloudFunctionsNodeModules);
    }
    return paths;
  };
})(Module._nodeModulePaths);

const admin = require('firebase-admin');

const CATEGORIES = [
  {
    id: 'getting-started',
    name: 'Getting Started',
    description: 'Launch your channel and run your first stream with confidence.',
    iconKey: 'rocket',
    sortOrder: 10,
    guideCount: 1,
    keywords: ['beginner', 'first stream', 'setup'],
  },
  {
    id: 'streaming-setup',
    name: 'Streaming Setup',
    description: 'OBS, audio, camera, and scene fundamentals for cleaner streams.',
    iconKey: 'settings',
    sortOrder: 20,
    guideCount: 1,
    keywords: ['OBS', 'audio', 'microphone', 'scenes'],
  },
  {
    id: 'audience-growth',
    name: 'Audience Growth',
    description: 'Grow followers with hooks, consistency, and community habits.',
    iconKey: 'trending',
    sortOrder: 30,
    guideCount: 1,
    keywords: ['Twitch growth', 'TikTok hooks', 'followers'],
  },
];

const GUIDES = [
  {
    id: 'first-stream-checklist',
    title: 'Start Your First Stream',
    description:
      'Choose a platform, set up OBS, configure audio, and run a safe test stream.',
    categoryId: 'getting-started',
    difficulty: 'beginner',
    estimatedMinutes: 25,
    author: 'StreamersTip',
    sortOrder: 10,
    tags: ['beginner', 'OBS', 'first stream'],
    platforms: ['Twitch', 'YouTube', 'Kick'],
    keywords: ['beginner streaming setup', 'OBS', 'test stream'],
    lessonCount: 3,
    slug: 'start-your-first-stream',
  },
  {
    id: 'obs-audio-basics',
    title: 'OBS and Audio Fundamentals',
    description:
      'Build a clean scene layout and fix the most common microphone mistakes.',
    categoryId: 'streaming-setup',
    difficulty: 'beginner',
    estimatedMinutes: 20,
    author: 'StreamersTip',
    sortOrder: 10,
    tags: ['OBS', 'audio setup'],
    platforms: ['Twitch', 'YouTube'],
    keywords: ['OBS', 'audio setup', 'microphone'],
    lessonCount: 2,
    slug: 'obs-and-audio-fundamentals',
  },
  {
    id: 'first-100-followers',
    title: 'Grow Your First 100 Followers',
    description:
      'Define your niche, improve your profile, and ship a weekly content plan.',
    categoryId: 'audience-growth',
    difficulty: 'intermediate',
    estimatedMinutes: 30,
    author: 'StreamersTip',
    sortOrder: 10,
    tags: ['growth', 'hooks', 'content calendar'],
    platforms: ['Twitch', 'TikTok', 'YouTube'],
    keywords: ['Twitch growth', 'TikTok hooks', 'content calendar'],
    lessonCount: 3,
    slug: 'grow-your-first-100-followers',
  },
];

const LESSONS = [
  {
    id: 'choose-your-platform',
    guideId: 'first-stream-checklist',
    title: 'Choose your platform',
    sortOrder: 10,
    estimatedMinutes: 8,
    contentBlocks: [
      {
        type: 'heading',
        content: 'Pick where you will start',
        level: 2,
      },
      {
        type: 'paragraph',
        content:
          'You do not need every platform on day one. Choose one live platform ' +
          'and one short-form platform so your energy stays focused.',
      },
      {
        type: 'list',
        content: '',
        items: [
          'Twitch: strong live community tools',
          'YouTube: discoverable VODs and Shorts',
          'Kick: growing live audience with simpler discovery',
        ],
      },
      {
        type: 'tip',
        content:
          'Tippy tip: commit to one main live platform for 30 days before expanding.',
      },
    ],
    applyAction: {
      title: 'Add platform decision to Content Planner',
      plannerItemTitle: 'Choose my primary streaming platform',
      plannerItemDescription:
        'Decide between Twitch, YouTube, or Kick and write why it fits my niche.',
      plannerItemType: 'task',
      tags: ['academy', 'getting-started'],
    },
  },
  {
    id: 'create-your-channel',
    guideId: 'first-stream-checklist',
    title: 'Create your channel',
    sortOrder: 20,
    estimatedMinutes: 8,
    contentBlocks: [
      {
        type: 'heading',
        content: 'Make the first impression clear',
        level: 2,
      },
      {
        type: 'paragraph',
        content:
          'Your username, avatar, banner, and about section should explain who ' +
          'you are and what viewers get when they hang out with you.',
      },
      {
        type: 'checklist',
        content: '',
        items: [
          'Username is easy to say and search',
          'Avatar is readable at small sizes',
          'About section includes schedule + niche',
        ],
      },
    ],
  },
  {
    id: 'run-a-test-stream',
    guideId: 'first-stream-checklist',
    title: 'Run a test stream',
    sortOrder: 30,
    estimatedMinutes: 9,
    contentBlocks: [
      {
        type: 'heading',
        content: 'Ship a private rehearsal',
        level: 2,
      },
      {
        type: 'paragraph',
        content:
          'Go live privately or with a trusted friend. Check audio levels, ' +
          'overlay readability, and chat pace before your first public stream.',
      },
      {
        type: 'quiz',
        content: 'What is the main goal of a test stream?',
        options: [
          'Go viral immediately',
          'Validate audio, scenes, and comfort before going public',
          'Connect every social platform at once',
        ],
        correctIndex: 1,
      },
    ],
  },
  {
    id: 'set-up-obs',
    guideId: 'obs-audio-basics',
    title: 'Set up OBS',
    sortOrder: 10,
    estimatedMinutes: 10,
    contentBlocks: [
      {
        type: 'heading',
        content: 'Build one clean starter scene',
        level: 2,
      },
      {
        type: 'paragraph',
        content:
          'Create a Game Capture or Display Capture scene, add your webcam, ' +
          'and keep overlays minimal until your framing feels natural.',
      },
      {
        type: 'warning',
        content:
          'Avoid stacking too many animated overlays on day one. Clarity beats clutter.',
      },
    ],
  },
  {
    id: 'configure-microphone',
    guideId: 'obs-audio-basics',
    title: 'Configure your microphone',
    sortOrder: 20,
    estimatedMinutes: 10,
    contentBlocks: [
      {
        type: 'heading',
        content: 'Clean audio wins more viewers than fancy graphics',
        level: 2,
      },
      {
        type: 'paragraph',
        content:
          'Set input levels so peaks stay under clipping, reduce background noise, ' +
          'and keep a consistent mic distance.',
      },
      {
        type: 'list',
        content: '',
        items: [
          'Use a pop filter if you have one',
          'Mute desktop audio while calibrating',
          'Record 30 seconds and listen back',
        ],
      },
    ],
  },
  {
    id: 'define-your-niche',
    guideId: 'first-100-followers',
    title: 'Define your content niche',
    sortOrder: 10,
    estimatedMinutes: 10,
    contentBlocks: [
      {
        type: 'heading',
        content: 'Be specific enough to be memorable',
        level: 2,
      },
      {
        type: 'paragraph',
        content:
          'A clear niche helps discovery and community. Combine a format + ' +
          'audience + signature vibe instead of trying to cover everything.',
      },
    ],
    applyAction: {
      title: 'Add niche statement to Content Planner',
      plannerItemTitle: 'Write my niche statement',
      plannerItemDescription:
        'Write one sentence: I help [audience] with [format/vibe].',
      plannerItemType: 'task',
      tags: ['academy', 'growth'],
    },
  },
  {
    id: 'improve-your-profile',
    guideId: 'first-100-followers',
    title: 'Improve your profile',
    sortOrder: 20,
    estimatedMinutes: 10,
    contentBlocks: [
      {
        type: 'paragraph',
        content:
          'Update panels, social links, and highlights so a new viewer understands ' +
          'what to expect in under 10 seconds.',
      },
    ],
  },
  {
    id: 'weekly-content-plan',
    guideId: 'first-100-followers',
    title: 'Create a weekly content plan',
    sortOrder: 30,
    estimatedMinutes: 10,
    contentBlocks: [
      {
        type: 'heading',
        content: 'Consistency beats intensity',
        level: 2,
      },
      {
        type: 'paragraph',
        content:
          'Plan 2–3 live sessions and 3–5 short clips. Protect recovery days so ' +
          'you can sustain the streak.',
      },
    ],
    applyAction: {
      title: 'Add weekly streaming routine to Content Planner',
      plannerItemTitle: 'Build my weekly streaming routine',
      plannerItemDescription:
        'Schedule live days, clip days, and one analytics review.',
      plannerItemType: 'task',
      tags: ['academy', 'content-calendar'],
    },
  },
];

const PATHS = [
  {
    id: 'path-first-stream',
    title: 'Start Your First Stream',
    description:
      'Choose your platform, create your channel, and ship a confident test stream.',
    lessonIds: [
      'choose-your-platform',
      'create-your-channel',
      'set-up-obs',
      'configure-microphone',
      'run-a-test-stream',
    ],
    sortOrder: 10,
    unlockLevel: 0,
    iconKey: 'play',
  },
  {
    id: 'path-first-100',
    title: 'Grow Your First 100 Followers',
    description:
      'Define your niche, improve your profile, and lock in a weekly content plan.',
    lessonIds: [
      'define-your-niche',
      'improve-your-profile',
      'weekly-content-plan',
    ],
    sortOrder: 20,
    unlockLevel: 0,
    iconKey: 'growth',
  },
];

const XP_REWARDS = {
  openFirstGuideOfDay: 5,
  completeLesson: 15,
  completeQuiz: 20,
  completeCategory: 75,
  finishLearningPath: 150,
  sevenDayStreak: 100,
  applyToContentPlanner: 25,
};

async function main() {
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    process.env.GCLOUD_PROJECT =
      process.env.GCLOUD_PROJECT || 'demo-streamerstip';
    admin.initializeApp({projectId: process.env.GCLOUD_PROJECT});
  } else {
    admin.initializeApp();
  }

  const db = admin.firestore();
  const now = admin.firestore.FieldValue.serverTimestamp();

  console.log('Seeding academyCategories...');
  for (const category of CATEGORIES) {
    await db.collection('academyCategories').doc(category.id).set(
      {
        ...category,
        isPublished: true,
        status: 'published',
        updatedAt: now,
      },
      {merge: true},
    );
  }

  console.log('Seeding academyGuides...');
  for (const guide of GUIDES) {
    await db.collection('academyGuides').doc(guide.id).set(
      {
        ...guide,
        isPublished: true,
        status: 'published',
        updatedAt: now,
      },
      {merge: true},
    );
  }

  console.log('Seeding academyLessons...');
  for (const lesson of LESSONS) {
    await db.collection('academyLessons').doc(lesson.id).set(
      {
        ...lesson,
        isPublished: true,
        status: 'published',
        updatedAt: now,
      },
      {merge: true},
    );
  }

  console.log('Seeding academyPaths...');
  for (const path of PATHS) {
    await db.collection('academyPaths').doc(path.id).set(
      {
        ...path,
        isPublished: true,
        status: 'published',
        updatedAt: now,
      },
      {merge: true},
    );
  }

  console.log('Seeding academyConfig/xpRewards...');
  await db.collection('academyConfig').doc('xpRewards').set(
    {
      ...XP_REWARDS,
      updatedAt: now,
    },
    {merge: true},
  );

  console.log('Academy seed complete.');
  console.log(
    `Categories=${CATEGORIES.length} Guides=${GUIDES.length} ` +
      `Lessons=${LESSONS.length} Paths=${PATHS.length}`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
