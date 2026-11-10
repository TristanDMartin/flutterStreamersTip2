import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.E2E_BASE_URL?.trim() ?? '';

/**
 * Playwright targets the StreamersTip Next.js deployment (or local dev).
 * CI starts this job only when E2E_BASE_URL is set. An empty URL skips the
 * GitHub job and must not be reported as a successful Playwright run.
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
