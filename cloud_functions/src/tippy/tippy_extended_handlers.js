const admin = require('firebase-admin');
const {loadTippyPromptContext} = require('./tippy_prompt_context');

const firestore = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

function cleanText(value, fallback = '') {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  return text || fallback;
}

function normalizeList(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((item) => cleanText(item))
    .filter(Boolean)
    .slice(0, 10);
}

async function handleTippyContextGet({uid, email = ''}) {
  const context = await loadTippyPromptContext(uid, email);
  return {
    tier: context.tier,
    creatorName: context.creatorName,
    memory: context.memory,
    goals: context.goals,
    analyticsProfile: context.analyticsProfile,
  };
}

async function handleGoalsPost({uid, body = {}}) {
  const title = cleanText(body.title || body.goal, 'Creator goal');
  const description = cleanText(body.description || body.notes);
  const goalRef = body.id
    ? firestore
      .collection('users')
      .doc(uid)
      .collection('creatorGoals')
      .doc(String(body.id))
    : firestore
      .collection('users')
      .doc(uid)
      .collection('creatorGoals')
      .doc();
  const payload = {
    id: goalRef.id,
    title,
    description,
    status: cleanText(body.status, 'active'),
    tags: normalizeList(body.tags),
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (!body.id) {
    payload.createdAt = FieldValue.serverTimestamp();
  }
  await goalRef.set(payload, {merge: true});
  return {
    goalId: goalRef.id,
    title,
    description,
    status: payload.status,
  };
}

async function handleApproveSchedule({uid, body = {}}) {
  const proposalId = cleanText(body.proposalId || body.id);
  if (!proposalId) {
    return {error: 'proposalId is required.', status: 400};
  }
  const ref = firestore
    .collection('users')
    .doc(uid)
    .collection('scheduleProposals')
    .doc(proposalId);
  await ref.set(
    {
      status: 'approved',
      approvedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  return {proposalId, status: 'approved'};
}

async function handleProposeSchedule({body = {}}) {
  const prompt = cleanText(body.prompt || body.topic, 'your next post');
  return {
    proposal: {
      title: `Schedule idea for ${prompt.slice(0, 48)}`,
      items: [
        {
          title: prompt,
          platform: cleanText(body.platform, 'streamerstip'),
          status: 'proposed',
        },
      ],
    },
  };
}

async function handleGrowthProgram() {
  return {
    program: {
      title: 'Creator Growth Program',
      steps: [
        'Pick one weekly content theme.',
        'Clip the best live moments into short-form posts.',
        'Review performance and repeat the strongest format.',
      ],
    },
  };
}

async function handleGenerateMission() {
  return {
    mission: {
      title: 'Post one focused creator clip',
      description:
        'Choose a recent highlight, add a clear hook, and publish it today.',
    },
  };
}

async function handleHookIdeas({body = {}}) {
  const topic = cleanText(body.prompt || body.topic, 'this clip');
  return {
    hooks: [
      `I did not expect ${topic} to end like this`,
      `Here is the fastest way to improve ${topic}`,
      `The mistake most creators make with ${topic}`,
    ],
  };
}

async function handlePostAnalysis({body = {}}) {
  const content = cleanText(body.content || body.prompt, 'this post');
  return {
    summary: `Review: ${content.slice(0, 160)}`,
    actionItems: [
      'Make the first line more specific.',
      'Add a clear next action for viewers.',
    ],
  };
}

module.exports = {
  handleApproveSchedule,
  handleGenerateMission,
  handleGoalsPost,
  handleGrowthProgram,
  handleHookIdeas,
  handlePostAnalysis,
  handleProposeSchedule,
  handleTippyContextGet,
};
