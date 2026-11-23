import { defineConfig } from 'vitest/config';
import { fileURLToPath } from 'node:url';

export default defineConfig({
  // Vitest transforms the TSX itself. The React plugin is only needed for
  // Fast Refresh in a dev server, and pinning it here would tie the test
  // runner to a second copy of Vite.
  esbuild: {
    jsx: 'automatic',
  },
  test: {
    environment: 'jsdom',
    globals: true,
    globalSetup: ['./__tests__/helpers/hosted-setup.ts'],
    setupFiles: ['./__tests__/setup.ts'],
    include: ['__tests__/**/*.test.{ts,tsx}'],
    css: false,
  },
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./', import.meta.url)),
    },
  },
});
