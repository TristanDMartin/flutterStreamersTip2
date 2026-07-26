#!/usr/bin/env node
/**
 * Sync Streamer Academy pages from the website SEO registry into Firestore
 * (and a bundled JSON catalog the Flutter app can use offline).
 *
 * Source of truth for page list:
 *   ../streamerstipReact/lib/seo/pageRegistry.ts
 *   ../streamerstipReact/config/academyPaths.ts
 *
 * Usage:
 *   node scripts/sync_academy_from_website.js
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-streamerstip \
 *     node scripts/sync_academy_from_website.js
 *
 * After website adds a page to pageRegistry.ts, re-run this (or wire it in CI)
 * so the app lists it automatically — no Flutter code change required.
 */

const fs = require('fs');
const path = require('path');

const WEBSITE_ROOT = path.resolve(__dirname, '../../streamerstipReact');
const PAGE_REGISTRY = path.join(WEBSITE_ROOT, 'lib/seo/pageRegistry.ts');
const ACADEMY_PATHS = path.join(WEBSITE_ROOT, 'config/academyPaths.ts');
const BUNDLED_CATALOG = path.join(
  __dirname,
  '..',
  'assets',
  'academy',
  'site_catalog.json',
);
const SITE_ORIGIN = 'https://streamerstip.com';

function loadAdmin() {
  const candidates = [
    path.join(__dirname, '..', 'cloud_functions', 'node_modules', 'firebase-admin'),
    path.join(__dirname, '..', '.seed_modules', 'node_modules', 'firebase-admin'),
  ];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return require(candidate);
    }
  }
  return require('firebase-admin');
}

const SKIP_PATHS = new Set([
  '/',
  '/about',
  '/pricing',
  '/ask-tippy',
  '/discover',
  '/streamer-academy',
  '/creator-tools',
  '/tools',
  '/terms',
  '/privacy',
  '/dmca',
  '/cookie-policy',
  '/guidelines',
  '/contact-support',
]);

const CATEGORIES = [
  {
    id: 'beginner',
    name: 'Beginner',
    description: 'Launch your channel and run your first streams with confidence.',
    iconKey: 'rocket',
    sortOrder: 10,
    keywords: ['beginner', 'first stream', 'setup'],
  },
  {
    id: 'intermediate',
    name: 'Intermediate',
    description: 'Level up overlays, audio, alerts, and channel branding.',
    iconKey: 'settings',
    sortOrder: 20,
    keywords: ['overlays', 'alerts', 'audio'],
  },
  {
    id: 'advanced',
    name: 'Advanced',
    description: 'Dual PC, NDI, automation, and pro audio workflows.',
    iconKey: 'trending',
    sortOrder: 30,
    keywords: ['dual pc', 'ndi', 'automation'],
  },
  {
    id: 'twitch',
    name: 'Twitch',
    description: 'Twitch setup, growth, monetization, and channel tools.',
    iconKey: 'twitch',
    sortOrder: 40,
    keywords: ['twitch'],
  },
  {
    id: 'youtube',
    name: 'YouTube',
    description: 'YouTube Live, Shorts, analytics, and memberships.',
    iconKey: 'youtube',
    sortOrder: 50,
    keywords: ['youtube'],
  },
  {
    id: 'kick',
    name: 'Kick',
    description: 'Kick setup, growth, chat, and monetization.',
    iconKey: 'kick',
    sortOrder: 60,
    keywords: ['kick'],
  },
  {
    id: 'tiktok',
    name: 'TikTok',
    description: 'TikTok Live, clips, gifts, and cross-platform promotion.',
    iconKey: 'tiktok',
    sortOrder: 70,
    keywords: ['tiktok'],
  },
  {
    id: 'obs-and-setup',
    name: 'OBS & Setup',
    description: 'OBS, scenes, bitrate, cameras, and stream quality.',
    iconKey: 'obs',
    sortOrder: 80,
    keywords: ['obs', 'bitrate', 'webcam'],
  },
  {
    id: 'growth',
    name: 'Growth & Strategy',
    description: 'Content strategy, calendars, and audience growth.',
    iconKey: 'growth',
    sortOrder: 90,
    keywords: ['growth', 'content strategy'],
  },
  {
    id: 'equipment',
    name: 'Equipment',
    description: 'Mics, cameras, Stream Deck, and creator gear.',
    iconKey: 'mic',
    sortOrder: 100,
    keywords: ['microphone', 'camera', 'peripherals'],
  },
];

function readText(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing website file: ${filePath}`);
  }
  return fs.readFileSync(filePath, 'utf8');
}

function parseRegistryEntries(source) {
  const entries = [];
  const callRe =
    /\b(guide|hub|tool)\(\s*'(\/[^']+)'\s*,\s*'((?:\\'|[^'])*)'\s*,\s*'((?:\\'|[^'])*)'/g;
  let match;
  while ((match = callRe.exec(source)) !== null) {
    entries.push({
      type: match[1],
      path: match[2],
      title: match[3].replace(/\\'/g, "'"),
      description: match[4].replace(/\\'/g, "'"),
    });
  }
  return entries;
}

function parseAcademyPathMap(source) {
  const map = {};
  const re =
    /'([a-z0-9-]+)'\s*:\s*\{\s*id:\s*'[a-z0-9-]+'\s*,\s*title:\s*'((?:\\'|[^'])*)'\s*,\s*path:\s*'(beginner|intermediate|advanced)'/g;
  let match;
  while ((match = re.exec(source)) !== null) {
    map[match[1]] = {
      id: match[1],
      title: match[2].replace(/\\'/g, "'"),
      path: match[3],
    };
  }
  return map;
}

function slugFromPath(pagePath) {
  return pagePath.replace(/^\//, '').replace(/\/$/, '') || 'home';
}

function resolveCategoryId(pagePath, academyPathMap) {
  const slug = slugFromPath(pagePath);
  if (academyPathMap[slug]) {
    return academyPathMap[slug].path;
  }
  if (slug.startsWith('twitch') || pagePath.startsWith('/twitch')) {
    return 'twitch';
  }
  if (slug.startsWith('youtube') || pagePath.startsWith('/youtube')) {
    return 'youtube';
  }
  if (slug.startsWith('kick') || pagePath.startsWith('/kick')) {
    return 'kick';
  }
  if (slug.startsWith('tiktok') || pagePath.startsWith('/tiktok')) {
    return 'tiktok';
  }
  if (
    /^(obs|microphone|webcam|bitrate|overlay|scene|ndi|dual-pc|audio|stream-alerts|chatbot|custom-overlays)/.test(
      slug,
    ) ||
    pagePath === '/obs'
  ) {
    return 'obs-and-setup';
  }
  if (
    /^(how-to-grow|content-|cross-platform|best-time|creator-score|complete-beginner|featured)/.test(
      slug,
    )
  ) {
    return 'growth';
  }
  if (/^(peripherals|best-streaming|stream-deck)/.test(slug)) {
    return 'equipment';
  }
  return 'beginner';
}

function resolveDifficulty(categoryId, academyPathMap, slug) {
  if (academyPathMap[slug]) {
    return academyPathMap[slug].path;
  }
  if (categoryId === 'advanced') return 'advanced';
  if (categoryId === 'intermediate') return 'intermediate';
  return 'beginner';
}

function buildCatalog() {
  const registrySource = readText(PAGE_REGISTRY);
  const pathsSource = readText(ACADEMY_PATHS);
  const academyPathMap = parseAcademyPathMap(pathsSource);
  const entries = parseRegistryEntries(registrySource).filter((entry) => {
    if (SKIP_PATHS.has(entry.path)) return false;
    if (entry.path.startsWith('/tools')) return false;
    if (entry.path.startsWith('/dashboard')) return false;
    return entry.type === 'guide' || entry.type === 'hub';
  });

  const guides = entries.map((entry, index) => {
    const slug = slugFromPath(entry.path);
    const categoryId = resolveCategoryId(entry.path, academyPathMap);
    const difficulty = resolveDifficulty(categoryId, academyPathMap, slug);
    return {
      id: slug.replace(/\//g, '-'),
      title: entry.title,
      description: entry.description,
      categoryId,
      difficulty,
      estimatedMinutes: entry.type === 'hub' ? 8 : 12,
      author: 'StreamersTip',
      sortOrder: (index + 1) * 10,
      tags: [entry.type, categoryId],
      platforms: inferPlatforms(slug, categoryId),
      keywords: [slug.replace(/-/g, ' ')],
      lessonCount: 0,
      slug,
      webUrl: `${SITE_ORIGIN}${entry.path}`,
      sitePath: entry.path,
      contentMode: 'website',
      source: 'website_page_registry',
      pageType: entry.type,
      isPublished: true,
      status: 'published',
    };
  });

  const guideCountByCategory = {};
  for (const guide of guides) {
    guideCountByCategory[guide.categoryId] =
      (guideCountByCategory[guide.categoryId] || 0) + 1;
  }

  const categories = CATEGORIES.map((category) => ({
    ...category,
    guideCount: guideCountByCategory[category.id] || 0,
    slug: category.id,
    isPublished: true,
    status: 'published',
  }));

  const paths = ['beginner', 'intermediate', 'advanced'].map((pathId, i) => {
    const guideIds = Object.values(academyPathMap)
      .filter((g) => g.path === pathId)
      .map((g) => g.id);
    return {
      id: pathId,
      title:
        pathId === 'beginner'
          ? 'Beginner Creator Path'
          : pathId === 'intermediate'
            ? 'Intermediate Creator Path'
            : 'Advanced Creator Path',
      description: `Structured ${pathId} lessons from Streamer Academy.`,
      sortOrder: (i + 1) * 10,
      unlockLevel: i === 0 ? 0 : i === 1 ? 3 : 8,
      guideIds,
      lessonIds: guideIds.map((id) => `${id}__web`),
      isPublished: true,
      status: 'published',
    };
  });

  return {categories, guides, paths, academyPathMap};
}

function inferPlatforms(slug, categoryId) {
  if (categoryId === 'twitch' || slug.includes('twitch')) return ['Twitch'];
  if (categoryId === 'youtube' || slug.includes('youtube')) return ['YouTube'];
  if (categoryId === 'kick' || slug.includes('kick')) return ['Kick'];
  if (categoryId === 'tiktok' || slug.includes('tiktok')) return ['TikTok'];
  return ['Twitch', 'YouTube', 'Kick', 'TikTok'];
}

async function writeFirestore(catalog) {
  const admin = loadAdmin();
  if (!admin.apps.length) {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT,
    });
  }
  const db = admin.firestore();
  const now = admin.firestore.FieldValue.serverTimestamp();

  console.log('Writing academyCategories...');
  for (const category of catalog.categories) {
    await db.collection('academyCategories').doc(category.id).set(
      {...category, updatedAt: now},
      {merge: true},
    );
  }

  console.log('Writing academyGuides...');
  for (const guide of catalog.guides) {
    const existing = await db.collection('academyGuides').doc(guide.id).get();
    const existingData = existing.exists ? existing.data() : null;
    // Preserve native lesson bodies if already seeded with contentMode native.
    if (existingData && existingData.contentMode === 'native') {
      await db.collection('academyGuides').doc(guide.id).set(
        {
          webUrl: guide.webUrl,
          sitePath: guide.sitePath,
          updatedAt: now,
        },
        {merge: true},
      );
      continue;
    }
    await db.collection('academyGuides').doc(guide.id).set(
      {...guide, updatedAt: now},
      {merge: true},
    );
  }

  console.log('Writing academyPaths...');
  for (const learningPath of catalog.paths) {
    await db.collection('academyPaths').doc(learningPath.id).set(
      {...learningPath, updatedAt: now},
      {merge: true},
    );
  }

  console.log('Writing academyConfig/siteCatalog...');
  await db.collection('academyConfig').doc('siteCatalog').set(
    {
      version: 1,
      origin: SITE_ORIGIN,
      syncedAt: now,
      guideCount: catalog.guides.length,
      paths: catalog.guides.map((g) => g.sitePath),
      guides: catalog.guides.map((g) => ({
        id: g.id,
        title: g.title,
        description: g.description,
        categoryId: g.categoryId,
        webUrl: g.webUrl,
        sitePath: g.sitePath,
        slug: g.slug,
        difficulty: g.difficulty,
        pageType: g.pageType,
      })),
    },
    {merge: true},
  );
}

function writeBundledCatalog(catalog) {
  fs.mkdirSync(path.dirname(BUNDLED_CATALOG), {recursive: true});
  const payload = {
    version: 1,
    origin: SITE_ORIGIN,
    generatedAt: new Date().toISOString(),
    guideCount: catalog.guides.length,
    categories: catalog.categories,
    guides: catalog.guides,
    paths: catalog.paths,
  };
  fs.writeFileSync(BUNDLED_CATALOG, JSON.stringify(payload, null, 2));
  console.log(`Wrote bundled catalog: ${BUNDLED_CATALOG}`);
}

async function main() {
  const catalog = buildCatalog();
  console.log(
    `Parsed website academy pages: guides=${catalog.guides.length} ` +
      `categories=${catalog.categories.length} paths=${catalog.paths.length}`,
  );
  writeBundledCatalog(catalog);
  const skipFirestore = process.argv.includes('--catalog-only');
  if (skipFirestore) {
    console.log('Skipping Firestore write (--catalog-only).');
    return;
  }
  await writeFirestore(catalog);
  console.log('Academy website sync complete.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
