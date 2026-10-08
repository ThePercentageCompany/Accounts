/* Browser capabilities are optional. No permission prompt occurs on startup. */
(() => {
  let registration, installPrompt, updateRequested = false, pushSubscribed = false, notificationVersion = 0;
  const base = new URL('./', document.baseURI);
  const emit = () => window.dispatchEvent(new Event('tpc-pwa-change'));
  const task = data => {
    if (!/^[A-Za-z0-9_-]{43}$/.test(data.companyId) || !/^[A-Za-z0-9_-]{43}$/.test(data.taskId)) return;
    location.hash = `task=${data.companyId}:${data.taskId}`;
    window.dispatchEvent(new Event('tpc-pwa-change'));
  };
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault(); installPrompt = event; emit();
  });
  window.addEventListener('appinstalled', () => {installPrompt = null; emit();});
  for (const event of ['online', 'offline', 'hashchange']) window.addEventListener(event, emit);
  const scheduleSync = () => {
    if (registration?.sync) registration.sync.register('tpc-outbox').catch(() => {});
  };
  window.addEventListener('online', scheduleSync);
  window.addEventListener('tpc-outbox-pending', scheduleSync);
  window.tpcPwa = {
    status: () => JSON.stringify({online: navigator.onLine,
      installed: matchMedia('(display-mode: standalone)').matches || navigator.standalone === true,
      installable: !!installPrompt, updateAvailable: !!registration?.waiting,
      pushSupported: 'PushManager' in window && 'Notification' in window && !!registration,
      pushSubscribed, notificationVersion,
      permission: 'Notification' in window ? Notification.permission : 'unsupported',
      taskLink: location.hash.startsWith('#task=') ? location.hash.slice(6) : ''}),
    install: async () => {
      if (!installPrompt) return false;
      await installPrompt.prompt();
      const result = await installPrompt.userChoice;
      installPrompt = null; emit(); return result.outcome === 'accepted';
    },
    subscribe: async key => {
      if (!registration || !('PushManager' in window)) throw Error('Notifications are unsupported.');
      if (await Notification.requestPermission() !== 'granted') throw Error('Notification permission was not granted. Change your browser settings to enable it.');
      const raw = atob(key.replace(/-/g, '+').replace(/_/g, '/'));
      const applicationServerKey = Uint8Array.from(raw, c => c.charCodeAt(0));
      await navigator.serviceWorker.ready;
      let subscription = await registration.pushManager.getSubscription();
      const existingKey = subscription?.options?.applicationServerKey;
      if (subscription && existingKey && (new Uint8Array(existingKey).length !== applicationServerKey.length ||
          new Uint8Array(existingKey).some((byte, i) => byte !== applicationServerKey[i]))) {
        if (!await subscription.unsubscribe()) throw Error('Could not update notification credentials.');
        subscription = null;
      }
      subscription ||= await registration.pushManager.subscribe({userVisibleOnly: true, applicationServerKey});
      pushSubscribed = true; emit(); return JSON.stringify(subscription.toJSON());
    },
    unsubscribe: async () => {
      const subscription = await registration?.pushManager.getSubscription();
      if (subscription && !await subscription.unsubscribe()) throw Error('Could not unsubscribe this browser.');
      pushSubscribed = false;
      emit();
    },
    subscription: async () => JSON.stringify((await registration?.pushManager.getSubscription())?.toJSON() || null),
    pendingWork: async () => {
      if (Object.keys(localStorage).some(k =>
        /^flutter\.(saas_records_|saas_document_|saas_employee_write_|tpc_saas_registration_)/.test(k))) return true;
      return new Promise((resolve, reject) => {
        const request = indexedDB.open('tpc_offline_v1');
        request.onerror = () => reject(Error('Device storage unavailable.'));
        request.onsuccess = () => {
          const db = request.result;
          if (!db.objectStoreNames.contains('partitions')) {db.close(); resolve(false); return;}
          const tx = db.transaction('partitions');
          const read = tx.objectStore('partitions').getAll();
          read.onsuccess = () => resolve(read.result.some(p =>
            (p.operations || []).length || Object.keys(p.aux || {}).some(k => k.startsWith('saas_') || k.startsWith('tpc_saas_registration_'))));
          read.onerror = () => reject(Error('Device storage unavailable.'));
          tx.oncomplete = () => db.close();
        };
      });
    },
    update: async () => {
      if (!registration?.waiting) return;
      if (await window.tpcPwa.pendingWork()) throw Error('Sync saved changes first.');
      updateRequested = true;
      registration.waiting.postMessage({type:'ACTIVATE_UPDATE'});
    },
    checkUpdate: async () => {await registration?.update(); emit();},
    clearTask: () => {if (location.hash.startsWith('#task=')) history.replaceState(null, '', location.pathname + location.search);},
  };
  if ('serviceWorker' in navigator && window.isSecureContext) {
    navigator.serviceWorker.register(new URL('tpc-sw.js', base), {scope: base.pathname, updateViaCache:'none'})
      .then(reg => {
        registration = reg; navigator.serviceWorker.ready.then(async () => {pushSubscribed = !!await reg.pushManager?.getSubscription(); emit();}); emit(); scheduleSync();
        reg.addEventListener('updatefound', () => reg.installing?.addEventListener('statechange', emit));
      }).catch(() => emit());
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (updateRequested) location.reload(); // Other tabs retain their open forms.
      emit();
    });
    navigator.serviceWorker.addEventListener('message', event => {
      if (event.data?.type === 'NOTIFICATION_RECEIVED') {notificationVersion++; emit();}
      if (event.data?.type === 'OPEN_TASK') task(event.data);
    });
  }
})();
