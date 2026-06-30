const DEFAULT_MODEL = 'claude-sonnet-4-20250514';

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

function resolveModelForPath(path, body = {}) {
  const normalizedPath = normalizePath(path);
  const routeEnv = ROUTE_MODEL_ENV[normalizedPath];
  const requestedModel =
    body && typeof body === 'object' ? String(body.model || '').trim() : '';

  return (
    readEnvModel(routeEnv) ||
    readEnvModel('TIPPY_ANTHROPIC_MODEL') ||
    readEnvModel('ANTHROPIC_MODEL') ||
    requestedModel ||
    DEFAULT_MODEL
  );
}

module.exports = {
  DEFAULT_MODEL,
  resolveModelForPath,
};
