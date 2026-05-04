/**
 * Server-side Anthropic Messages API for Tippy (never expose API keys to clients).
 */

const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';
const ANTHROPIC_VERSION = '2023-06-01';
const DEFAULT_MODEL = 'claude-sonnet-4-20250514';

function buildErrorPayload(code, message, status, requestId, retryable) {
  return {
    success: false,
    error: {
      code,
      message,
      status,
      retryable: retryable === true,
    },
    requestId,
  };
}

function extractTextFromMessage(body) {
  if (!body || typeof body !== 'object') {
    return '';
  }
  const content = body.content;
  if (!Array.isArray(content)) {
    return '';
  }
  const parts = [];
  for (const block of content) {
    if (block && block.type === 'text' && typeof block.text === 'string') {
      parts.push(block.text);
    }
  }
  return parts.join('\n').trim();
}

function cleanPublicAiText(text) {
  const lines = String(text || '').split(/\r?\n/);
  while (
    lines.length > 0 &&
    /^\s*(model|provider|system|assistant)\s*:\s*[-\w.]+/i.test(lines[0])
  ) {
    lines.shift();
  }
  return lines.join('\n').trim();
}

function sanitizeChatMessages(messages) {
  const out = [];
  let system = '';
  for (const m of messages) {
    if (!m || typeof m !== 'object') {
      continue;
    }
    const role = String(m.role || '').toLowerCase();
    const content = typeof m.content === 'string' ? m.content.trim() : '';
    if (!content) {
      continue;
    }
    if (role === 'system') {
      system = system ? `${system}\n\n${content}` : content;
      continue;
    }
    if (role !== 'user' && role !== 'assistant') {
      continue;
    }
    out.push({role, content});
  }
  while (out.length > 0 && out[0].role === 'assistant') {
    out.shift();
  }
  if (out.length === 0) {
    out.push({role: 'user', content: 'Hello.'});
  }
  return {system, messages: out};
}

async function postAnthropic({
  apiKey,
  model,
  maxTokens,
  system,
  messages,
}) {
  const fetch = (await import('node-fetch')).default;
  const body = {
    model,
    max_tokens: maxTokens,
    messages,
  };
  if (system && system.trim().length > 0) {
    body.system = system.trim();
  }
  const res = await fetch(ANTHROPIC_URL, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': ANTHROPIC_VERSION,
    },
    body: JSON.stringify(body),
  });
  const raw = await res.text();
  let parsed = null;
  try {
    parsed = JSON.parse(raw);
  } catch (_) {
    parsed = null;
  }
  return {ok: res.ok, status: res.status, parsed, raw};
}

function resolveModel() {
  const m = String(process.env.ANTHROPIC_MODEL || '').trim();
  if (m.length > 0) {
    return m;
  }
  return DEFAULT_MODEL;
}

function readProviderErrorMessage(result) {
  return result &&
    result.parsed &&
    result.parsed.error &&
    typeof result.parsed.error.message === 'string'
    ? result.parsed.error.message
    : '';
}

function isModelSelectionError(result) {
  const msg = readProviderErrorMessage(result).trim().toLowerCase();
  return msg.startsWith('model:') || msg.includes('model_not_found');
}

async function postAnthropicWithModelFallback(params) {
  const primaryModel = String(params.model || '').trim() || DEFAULT_MODEL;
  const primary = await postAnthropic({
    ...params,
    model: primaryModel,
  });
  if (primary.ok || primaryModel === DEFAULT_MODEL || !isModelSelectionError(primary)) {
    return {
      ...primary,
      attemptedModel: primaryModel,
    };
  }
  console.warn(
    'Anthropic model rejected, retrying with default model:',
    primaryModel,
  );
  const fallback = await postAnthropic({
    ...params,
    model: DEFAULT_MODEL,
  });
  return {
    ...fallback,
    attemptedModel: DEFAULT_MODEL,
  };
}

function tryParseJson(text) {
  const t = String(text || '').trim();
  if (!t) {
    return null;
  }
  const start = t.indexOf('{');
  const end = t.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return null;
  }
  try {
    return JSON.parse(t.slice(start, end + 1));
  } catch (_) {
    return null;
  }
}

/**
 * @param {object} params
 * @param {string} params.apiKey
 * @param {string} params.path
 * @param {object} params.body
 * @param {string} params.requestId
 * @returns {Promise<object>}
 */
async function runAnthropicTippy({apiKey, path, body, requestId}) {
  const model = resolveModel();
  if (path === '/tippy/chat') {
    const raw = Array.isArray(body.messages) ? body.messages : [];
    const {system, messages} = sanitizeChatMessages(raw);
    const sys =
      system ||
      'You are Tippy, a concise, practical AI coach for streamers and short-form '
      + 'creators. Be direct and actionable. If a user asks you to add, save, '
      + 'create, or sync a plan/calendar to their content planner, never say you '
      + 'cannot do it. The backend can create planner documents; acknowledge that '
      + 'Tippy is creating it or ask one concise clarifying question if needed.';
    const maxTokens = 4096;
    const result = await postAnthropicWithModelFallback({
      apiKey,
      model,
      maxTokens,
      system: sys,
      messages,
    });
    if (!result.ok) {
      if (readProviderErrorMessage(result).length > 0) {
        console.warn(
          'Anthropic chat request failed:',
          readProviderErrorMessage(result),
        );
      }
      return {
        error: buildErrorPayload(
          'AI_PROVIDER_ERROR',
          'Tippy AI is temporarily unavailable. Please try again.',
          502,
          requestId,
          result.status === 429 || result.status >= 500,
        ),
        status: 502,
      };
    }
    const text = cleanPublicAiText(extractTextFromMessage(result.parsed));
    if (!text) {
      return {
        error: buildErrorPayload(
          'AI_PROVIDER_ERROR',
          'Empty model response.',
          502,
          requestId,
          true,
        ),
        status: 502,
      };
    }
    return {message: text};
  }
  if (path === '/tippy/create-plan' || path === '/tippy/create-content-plan') {
    const user =
      'Create a practical 14-day content plan for a gaming / creator streamer. '
      + 'Reply with JSON only, no markdown fence, shape: '
      + '{"title":"","description":"","items":[{"title":"","caption":"",'
      + '"platform":["TikTok","YouTube Shorts","Instagram Reels"],'
      + '"contentType":"short"}]}';
    const result = await postAnthropicWithModelFallback({
      apiKey,
      model,
      maxTokens: 4096,
      system:
        'You output valid JSON only for a content planner. Include 7 to 14 items.',
      messages: [{role: 'user', content: user}],
    });
    if (!result.ok) {
      return {
        error: buildErrorPayload(
          'AI_PROVIDER_ERROR',
          'Plan generation failed.',
          502,
          requestId,
          true,
        ),
        status: 502,
      };
    }
    const text = extractTextFromMessage(result.parsed);
    const j = tryParseJson(text);
    if (j && Array.isArray(j.items)) {
      return {plan: j};
    }
    return {
      plan: {
        title: '7-Day StreamersTip Growth Plan',
        description: 'AI-generated content plan created by Tippy.',
        items: [],
      },
    };
  }
  if (path === '/tippy/ai-caption') {
    const prompt = String(body.prompt || '').trim();
    const user =
      `Write a short-form video caption for this idea/context:\n${prompt}\n\n`
      + 'Reply with JSON only: '
      + '{"title":"","caption":"","hashtags":["#tag1","#tag2"]}';
    const result = await postAnthropicWithModelFallback({
      apiKey,
      model,
      maxTokens: 2048,
      system:
        'You write punchy social captions. Output valid JSON only.',
      messages: [{role: 'user', content: user}],
    });
    if (!result.ok) {
      return {
        error: buildErrorPayload(
          'AI_PROVIDER_ERROR',
          'Caption generation failed.',
          502,
          requestId,
          true,
        ),
        status: 502,
      };
    }
    const text = extractTextFromMessage(result.parsed);
    const j = tryParseJson(text);
    if (j && typeof j.caption === 'string') {
      const hashtags = Array.isArray(j.hashtags)
        ? j.hashtags.map((h) => String(h)).filter((h) => h.length > 0)
        : [];
      return {
        caption: j.caption.trim(),
        hashtags,
        title:
          typeof j.title === 'string' && j.title.trim().length > 0
            ? j.title.trim()
            : null,
      };
    }
    return {
      caption: text,
      hashtags: [],
      title: null,
    };
  }
  if (path === '/tippy/analyze-content') {
    const content = String(body.content || '').trim();
    const user =
      `Analyze this script or post for a streamer/creator. Content:\n${content}\n\n`
      + 'Reply with JSON only: '
      + '{"summary":"","actionItems":["",""]}';
    const result = await postAnthropicWithModelFallback({
      apiKey,
      model,
      maxTokens: 4096,
      system: 'You give constructive feedback. Output valid JSON only.',
      messages: [{role: 'user', content: user}],
    });
    if (!result.ok) {
      return {
        error: buildErrorPayload(
          'AI_PROVIDER_ERROR',
          'Analysis failed.',
          502,
          requestId,
          true,
        ),
        status: 502,
      };
    }
    const text = extractTextFromMessage(result.parsed);
    const j = tryParseJson(text);
    if (j && typeof j.summary === 'string') {
      const actionItems = Array.isArray(j.actionItems)
        ? j.actionItems.map((x) => String(x)).filter((x) => x.length > 0)
        : [];
      return {
        summary: j.summary.trim(),
        actionItems,
      };
    }
    return {
      summary: text,
      actionItems: [],
    };
  }
  return {
    error: buildErrorPayload(
      'INTERNAL_ERROR',
      'Unknown Tippy path.',
      500,
      requestId,
      false,
    ),
    status: 500,
  };
}

module.exports = {
  runAnthropicTippy,
};
