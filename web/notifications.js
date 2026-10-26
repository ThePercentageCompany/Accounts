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
      if (requestPermission) {
        if (await Notification.requestPermission() !== 'granted') throw Error('Browser notifications were not enabled. In-app alerts remain available.');
      } else if (Notification.permission !== 'granted' || saved('tpc-push-enabled') !== 'true') return 'null';
      const fcm = await prepare(JSON.parse(configJson));
      const [, api] = await modules;
      const registration = await window.tpcPwa.readyRegistration();
      const token = await api.getToken(fcm, {vapidKey, serviceWorkerRegistration: registration});
      if (!token) throw Error('No push token was issued. Check Firebase Web Push configuration.');
      store('tpc-push-enabled', 'true'); notify();
      return JSON.stringify({token, installationId: installation});
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
