{{flutter_js}}
{{flutter_build_config}}

// Record data and credentials are never cached by this worker. Updates wait
// until existing tabs close; IndexedDB queues survive application upgrades.
if ('serviceWorker' in navigator && window.isSecureContext) {
  navigator.serviceWorker.register('offline_worker.js', {updateViaCache: 'none'})
    .then(registration => registration.update())
    .catch(error => console.warn('Offline app shell unavailable:', error));
}
_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});
