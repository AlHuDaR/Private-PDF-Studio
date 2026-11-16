'use strict';
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('offline_worker.js').catch(() => {
      // No telemetry or document data. Offline readiness must be verified manually.
    });
  });
}
