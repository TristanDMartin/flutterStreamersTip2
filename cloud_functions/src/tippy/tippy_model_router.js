const DEFAULT_MODEL = 'claude-sonnet-4-6';
const FALLBACK_MODELS = ['claude-haiku-4-5-20251001'];

const RETIRED_MODEL_REPLACEMENTS = {
  'claude-sonnet-4-20250514': 'claude-sonnet-4-6',
  'claude-opus-4-20250514': 'claude-opus-4-8',
  'claude-3-7-sonnet-20250219': 'claude-sonnet-4-6',
  'claude-3-5-sonnet-20241022': 'claude-sonnet-4-6',
  'claude-3-5-sonnet-20240620': 'claude-sonnet-4-6',
  'claude-3-5-haiku-20241022': 'claude-haiku-4-5-20251001',
  'claude-3-haiku-20240307': 'claude-haiku-4-5-20251001',
};

const ROUTE_MODEL_ENV = {
  '/tippy/analyze-content': 'TIPPY_ANALYZE_MODEL',
  '/tippy/ai-caption': 'TIPPY_CAPTION_MODEL',
  '/tippy/chat': 'TIPPY_CHAT_MODEL',
  '/tippy/create-content-plan': 'TIPPY_PLAN_MODEL',
  '/tippy/create-plan': 'TIPPY_PLAN_MODEL',
  '/tippy/hook-ideas': 'TIPPY_HOOKS_MODEL',
};

function normalizePath(path) {
  return String(path || '').trim();
}

function readEnvModel(name) {
  if (!name) {
    return '';
  }
  return String(process.env[name] || '').trim();
}

function normalizeModel(model) {
  const value = String(model || '').trim();
  return RETIRED_MODEL_REPLACEMENTS[value] || value;
}

function uniqueModels(models) {
  const seen = new Set();
  const out = [];
  for (const model of models) {
    const normalized = normalizeModel(model);
    if (!normalized || seen.has(normalized)) {
      continue;
    }
    seen.add(normalized);
    out.push(normalized);
  }
  return out;
}

function readEnvModelList(name) {
  const value = String(process.env[name] || '').trim();
  if (!value) {
    return [];
  }
  return value.split(',').map((model) => model.trim()).filter(Boolean);
}

function resolveModelForPath(path, body = {}) {
  const normalizedPath = normalizePath(path);
  const routeEnv = ROUTE_MODEL_ENV[normalizedPath];
  const requestedModel =
    body && typeof body === 'object' ? String(body.model || '').trim() : '';

  return normalizeModel(
    readEnvModel(routeEnv) ||
    readEnvModel('TIPPY_ANTHROPIC_MODEL') ||
    readEnvModel('ANTHROPIC_MODEL') ||
    requestedModel ||
    DEFAULT_MODEL
  );
}

function resolveFallbackModelsForPath(path, body = {}) {
  const primary = resolveModelForPath(path, body);
  return uniqueModels([
    primary,
    ...readEnvModelList('TIPPY_ANTHROPIC_FALLBACK_MODELS'),
    DEFAULT_MODEL,
    ...FALLBACK_MODELS,
  ]);
}

module.exports = {
  DEFAULT_MODEL,
  FALLBACK_MODELS,
  RETIRED_MODEL_REPLACEMENTS,
  normalizeModel,
  resolveFallbackModelsForPath,
  resolveModelForPath,
};
