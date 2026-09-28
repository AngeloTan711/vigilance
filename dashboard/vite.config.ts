import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The dashboard is a pure API client of the Phase 3 backend (Bearer tokens,
// no cookies/session), so no proxy is required — VITE_API_BASE_URL points at
// the Laravel app. The proxy below only exists for local dev convenience.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: process.env.VITE_PROXY_TARGET ?? 'http://127.0.0.1:8000',
        changeOrigin: true,
      },
    },
  },
});
