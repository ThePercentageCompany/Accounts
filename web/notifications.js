/* FCM shares the existing PWA registration; permission is user initiated. */
(() => {
  const sdk = '13.1.0'; // matches firebase_core_web 4.1.0
  let messaging, modules, audio, optedIn = false;
  const saved = key => {try {return localStorage.getItem(key);} catch (_) {return null;}};
  const store = (key, value) => {try {localStorage.setItem(key, value);} catch (_) {}}
  const installation = saved('tpc-push-installation') || crypto.randomUUID().replaceAll('-', '');
  store('tpc-push-installation', installation);
  const notify = () => window.dispatchEvent(new Event('tpc-pwa-change'));
  async function prepare(config) {
    if (messaging) return messaging;
    modules ||= Promise.all([import(`https://www.gstatic.com/firebasejs/${sdk}/firebase-app.js`),
      import(`https://www.gstatic.com/firebasejs/${sdk}/firebase-messaging.js`)]);
    const [app, fcm] = await modules;
    if (!await fcm.isSupported()) throw Error('Push is unavailable in this browser. On iPhone/iPad, use the installed Home Screen app.');
    const firebase = app.getApps().find(a => a.name === 'tpc-task-push') || app.initializeApp(config, 'tpc-task-push');
    messaging = fcm.getMessaging(firebase);
    fcm.onMessage(messaging, payload => {
      const data = payload.data || {};
      window.dispatchEvent(new CustomEvent('tpc-task-notification', {detail: data}));
      window.tpcPwa?.notificationReceived?.(data);
    });
    return messaging;
  }
  window.tpcNotifications = {
    installation: () => installation,
    enabled: () => saved('tpc-push-enabled') === 'true',
    enableSound: async () => {
      audio ||= new (window.AudioContext || window.webkitAudioContext)();
      await audio.resume(); optedIn = true; store('tpc-sound-enabled', 'true');
    },
    soundEnabled: () => optedIn && audio?.state === 'running',
    play: async (sound, volume, id) => {
      if (!optedIn || audio?.state !== 'running' || sound === 'none') return;
      const key = 'tpc-sound-event:' + id;
      if (id !== 'preview' && saved(key)) return;
      if (id !== 'preview') store(key, String(Date.now()));
      const frequencies = {chime: [659, 880], bell: [1047, 784, 1047], alert: [740, 740, 988]}[sound] || [659, 880];
      frequencies.forEach((frequency, i) => {
        const oscillator = audio.createOscillator(), gain = audio.createGain();
        const start = audio.currentTime + i * .16;
        oscillator.type = sound === 'bell' ? 'sine' : 'triangle'; oscillator.frequency.value = frequency;
        gain.gain.setValueAtTime(0, start); gain.gain.linearRampToValueAtTime(Math.min(1, Math.max(0, volume)) * .22, start + .015);
        gain.gain.exponentialRampToValueAtTime(.001, start + .3);
        oscillator.connect(gain); gain.connect(audio.destination); oscillator.start(start); oscillator.stop(start + .32);
      });
      // Keep device deduplication storage bounded.
      try {Object.keys(localStorage).filter(k => k.startsWith('tpc-sound-event:') && Number(saved(k)) < Date.now() - 86400000).forEach(k => localStorage.removeItem(k));} catch (_) {}
    },
    register: async (configJson, vapidKey, requestPermission) => {
      if (!('Notification' in window)) return JSON.stringify({error: 'This browser does not support notifications here.'});
      if (!requestPermission && (Notification.permission !== 'granted' || saved('tpc-push-enabled') !== 'true')) return 'null';
      const key = vapidKey.trim();
      if (!/^B[A-Za-z0-9_-]{86}$/.test(key)) {
        return JSON.stringify({error: 'The workspace web push key is invalid. Check the public VAPID key in Firebase.'});
      }
      if (requestPermission && Notification.permission !== 'granted') {
        try {
          if (await Notification.requestPermission() !== 'granted') {
            return JSON.stringify({error: 'Allow notifications for this app in your device or browser settings, then try again.'});
          }
        } catch (_) {
          return JSON.stringify({error: 'The browser could not request notification permission. Reopen the installed web app and try again.'});
        }
        if (navigator.userActivation?.isActive === false) {
          return JSON.stringify({error: 'Permission granted. Tap Enable push notifications again to finish registering this device.'});
        }
      }
      let registration = window.tpcPwa.activeRegistration?.();
      let readyTimeout;
      try {
        if (requestPermission && !registration) {
          return JSON.stringify({error: 'The app service worker is starting. Tap Enable push notifications again in a moment.'});
        }
        if (requestPermission) {
          // Start from the tap. Loading Firebase first can expire browser user activation.
          const bytes = Uint8Array.from(atob(key.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
          await registration.pushManager.subscribe({userVisibleOnly: true, applicationServerKey: bytes});
        }
        if (!registration) {
          registration = await Promise.race([
            window.tpcPwa.readyRegistration(),
            new Promise((_, reject) => { readyTimeout = setTimeout(() => reject(Error('Worker not ready')), 8000); }),
          ]);
        }
        if (!requestPermission && !await registration.pushManager.getSubscription()) return 'null';
        let fcm;
        try {
          fcm = await prepare(JSON.parse(configJson));
        } catch (error) {
          modules = undefined;
          return JSON.stringify({error: error.message?.startsWith('Push is unavailable')
            ? error.message
            : 'Could not load Firebase Messaging. Check your connection and reload the app.'});
        }
        const [, api] = await modules;
        const token = await api.getToken(fcm, {vapidKey: key, serviceWorkerRegistration: registration});
        if (!token) return JSON.stringify({error: 'Firebase did not issue a push token. Check the workspace Firebase configuration.'});
        store('tpc-push-enabled', 'true'); notify();
        return JSON.stringify({token, installationId: installation});
      } catch (error) {
        const message = !registration
          ? 'The app service worker is not ready. Reload the app and try again.'
          : error.name === 'NotAllowedError'
            ? 'The browser blocked registration. If notifications are allowed, tap Enable push notifications again from the app.'
            : error.name === 'InvalidStateError'
              ? 'An existing browser push subscription conflicts with this workspace key. Reset this app’s notification permission, reopen it, and enable push again.'
              : error.name === 'InvalidAccessError'
                ? 'The browser rejected the workspace public VAPID key. Check the key in Firebase.'
                : error.name === 'AbortError'
                  ? 'The browser could not connect to its push service. Check your connection and retry.'
                  : error.code === 'messaging/token-subscribe-failed'
                    ? 'Firebase rejected push registration. Check that the web app configuration and VAPID key are from the same Firebase project.'
                    : 'Could not complete push registration. Reopen the app and try again.';
        return JSON.stringify({error: message});
      } finally {
        clearTimeout(readyTimeout);
      }
    },
    disable: async () => {
      store('tpc-push-enabled', 'false');
      if (messaging) {const [, api] = await modules; await api.deleteToken(messaging);}
      const registration = await window.tpcPwa?.readyRegistration?.();
      const subscription = await registration?.pushManager?.getSubscription();
      if (subscription) await subscription.unsubscribe();
      optedIn = false; notify();
    },
  };
})();
