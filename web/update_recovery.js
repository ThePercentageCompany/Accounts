(() => {
  const status = document.getElementById('status');
  const button = document.getElementById('action');
  let registration, applying = false, installing = false;
  const show = (message, label, enabled = true) => {
    status.textContent = message;
    button.textContent = label;
    button.disabled = !enabled;
  };
  const ready = () => {
    if (applying || !registration || status.textContent.startsWith('Update installed successfully')) return;
    if (registration.waiting) show('The latest version is downloaded and ready to install. Your saved local changes will be kept.', 'Install latest version');
    else if (!installing) show('The current app files are installed on this device. Open the app to use them.', 'Open updated app');
  };
  const watch = worker => {
    if (!worker) return;
    const changed = () => {
      installing = worker.state === 'installing';
      if (installing) show('Downloading app files. Keep this page open until the download finishes.', 'Downloading...', false);
      else if (worker.state === 'installed' || worker.state === 'activated') ready();
      else if (worker.state === 'redundant') show('The download could not finish. Reconnect and try again.', 'Try again');
    };
    worker.addEventListener('statechange', changed);
    changed();
  };
  const check = async () => {
    try {
      if (!('serviceWorker' in navigator)) {
        show('This browser does not support installed app updates. Open TPC Accounts in a supported browser.', 'Open app');
        return;
      }
      show('Checking for the latest app files...', 'Checking...', false);
      registration = await navigator.serviceWorker.register(new URL('tpc-sw.js', location.href), {scope: new URL('./', location.href).pathname, updateViaCache:'none'});
      registration.addEventListener('updatefound', () => watch(registration.installing));
      watch(registration.installing);
      if (navigator.onLine) await registration.update();
      else if (!registration.waiting) {
        show('You are offline. Connect to download the latest version.', 'Try again');
        return;
      }
      watch(registration.installing);
      ready();
    } catch (_) {
      show('Unable to check for updates. Reconnect and try again. Your saved local changes are still on this device.', 'Try again');
    }
  };
  navigator.serviceWorker?.addEventListener('controllerchange', () => {
    if (applying) {
      applying = false;
      try {sessionStorage.setItem('tpc-update-applied', 'true');} catch (_) {}
      show('Update installed successfully. Open the app to continue; your saved changes will resume syncing.', 'Open updated app');
    } else ready();
  });
  button.addEventListener('click', () => {
    if (registration?.waiting) {
      applying = true;
      show('Installing the downloaded version...', 'Installing...', false);
      registration.waiting.postMessage({type:'ACTIVATE_UPDATE'});
    } else if (button.textContent.startsWith('Open')) location.replace(new URL('./', location.href));
    else check();
  });
  check();
})();
