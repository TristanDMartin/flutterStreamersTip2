import { test } from '@playwright/test';

/**
 * Backfill with real selectors once the Next.js app exposes stable
 * data-testid attributes (see /qa/STREAMERSTIP_QA_CHECKLIST.md).
 *
 * Suggested env (GitHub Secrets / local .env):
 *   QA_STARTER_EMAIL, QA_STARTER_PASSWORD
 *   QA_PRO_EMAIL, QA_PRO_PASSWORD
 *   QA_STUDIO_EMAIL, QA_STUDIO_PASSWORD
 *   QA_ADMIN_EMAIL, QA_ADMIN_PASSWORD
 */
const baseURL = process.env.E2E_BASE_URL?.trim() ?? '';

test.describe('Auth flows (placeholder)', () => {
  test('sign up / login / logout — implement with data-testid', async () => {
    test.skip(!baseURL, 'Configure E2E_BASE_URL and add web data-testid hooks.');
  });

  test('forgot password — implement with data-testid', async () => {
    test.skip(!baseURL, 'Configure E2E_BASE_URL and add web data-testid hooks.');
  });
});
