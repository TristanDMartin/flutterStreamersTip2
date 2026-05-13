import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.E2E_BASE_URL?.trim() ?? '';

/**
 * Playwright targets the StreamersTip Next.js deployment (or local dev).
 * Set E2E_BASE_URL (e.g. https://your-app.vercel.app). If unset, the smoke
 * spec skips network assertions so CI stays green until the URL is configured.
 */
export default defineConfig({
  testDir: './specs',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: process.env.CI
    ? [['github'], ['html', { open: 'never', outputFolder: 'playwright-report' }]]
    : [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],
  use: {
    baseURL: baseURL || 'http://127.0.0.1:9',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    ...devices['Desktop Chrome'],
  },
  outputDir: 'test-results',
});
