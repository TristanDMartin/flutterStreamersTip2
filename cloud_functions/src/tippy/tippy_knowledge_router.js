const KNOWLEDGE_CHUNKS = [
  {
    id: 'short-form-hooks',
    keywords: ['hook', 'intro', 'retention', 'short', 'reel', 'tiktok'],
    text:
      'For short-form videos, lead with the result, conflict, or surprise in '
      + 'the first two seconds. Keep one idea per clip and make the payoff clear.',
  },
  {
    id: 'streamer-growth',
    keywords: ['stream', 'twitch', 'youtube', 'kick', 'creator', 'growth'],
    text:
      'Streamer growth works best when live moments are repackaged into '
      + 'discoverable clips, then tied back to a repeatable schedule and niche.',
  },
  {
    id: 'content-plan',
    keywords: ['plan', 'calendar', 'schedule', 'post', 'campaign'],
    text:
      'A useful content plan should define the audience, platform, format, '
      + 'posting cadence, and the next concrete production step.',
  },
  {
    id: 'caption-writing',
    keywords: ['caption', 'hashtag', 'description', 'title'],
    text:
      'Good captions add context without repeating the video. Use searchable '
      + 'terms naturally and keep hashtags specific to the audience and platform.',
  },
];

function normalizeText(value) {
  return String(value || '').toLowerCase();
}

function readGoalText(goals) {
  if (!Array.isArray(goals)) {
    return '';
  }
  return goals
    .map((goal) => {
      if (!goal || typeof goal !== 'object') {
        return String(goal || '');
      }
      return [
        goal.title,
        goal.description,
        goal.category,
        goal.platform,
      ].filter(Boolean).join(' ');
    })
    .join(' ');
}

function selectKnowledgeChunks({prompt = '', goals = [], niche = ''} = {}) {
  const haystack = normalizeText(
    `${prompt} ${readGoalText(goals)} ${niche}`,
  );
  if (!haystack.trim()) {
    return [];
  }
  return KNOWLEDGE_CHUNKS.filter((chunk) =>
    chunk.keywords.some((keyword) => haystack.includes(keyword)),
  ).slice(0, 3);
}

function buildKnowledgeBlock(chunks) {
  if (!Array.isArray(chunks) || chunks.length === 0) {
    return '';
  }
  const lines = chunks
    .map((chunk) => `- ${chunk.text}`)
    .filter((line) => line.length > 2);
  if (lines.length === 0) {
    return '';
  }
  return `Relevant creator guidance:\n${lines.join('\n')}`;
}

module.exports = {
  buildKnowledgeBlock,
  selectKnowledgeChunks,
};
