{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href},
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      document.getElementById('launch')?.remove();
    } catch (_) {
      const launch = document.getElementById('launch');
      if (launch) launch.querySelector('p').textContent = 'Unable to open the app. Reconnect and try again.';
    }
  }
});
