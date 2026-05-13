import { test, expect } from '@playwright/test';

const baseURL = process.env.E2E_BASE_URL?.trim() ?? '';

test.describe('StreamersTip web smoke', () => {
  test('site responds when E2E_BASE_URL is set', async ({ page }) => {
    test.skip(!baseURL, 'Set E2E_BASE_URL to your Next.js origin (staging/prod).');

    const response = await page.goto('/', { waitUntil: 'domcontentloaded' });
    expect(response, 'navigation response').not.toBeNull();
    expect(response!.ok() || response!.status() === 304, `HTTP ${response!.status()}`).toBeTruthy();
  });
});
