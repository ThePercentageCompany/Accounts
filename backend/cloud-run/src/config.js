export function loadConfig(env = process.env) {
  const required = (key) => {
    const value = env[key]?.trim();
    if (!value) throw new Error(`Missing operator configuration: ${key}`);
    return value;
  };
  const origin = (key) => {
    const value = required(key);
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.origin !== value || url.username || url.password) {
      throw new Error(`${key} must be an exact HTTPS origin without a path`);
    }
    return value;
  };
  const config = {
    port: Number(env.PORT || 8080),
    appOrigin: origin('APP_ORIGIN'), apiOrigin: origin('API_ORIGIN'),
    clientId: required('GOOGLE_OAUTH_CLIENT_ID'),
    secretVersion: required('GOOGLE_OAUTH_SECRET_VERSION'),
    bucket: required('CONTROL_BUCKET'), object: env.CONTROL_OBJECT || 'control/registry-v1.json',
    kmsKey: required('GOOGLE_REFRESH_KMS_KEY'),
    taskQueue: required('SETUP_TASK_QUEUE'), workerEmail: required('SETUP_WORKER_EMAIL'),
    workerOrigin: origin('SETUP_WORKER_ORIGIN'),
    sessionMs: 8 * 60 * 60 * 1000, oauthMs: 10 * 60 * 1000,
  };
  if (!Number.isInteger(config.port) || config.port < 1 || config.port > 65535) throw new Error('Invalid PORT');
  if (!/^projects\/[^/]+\/secrets\/[^/]+\/versions\/[^/]+$/.test(config.secretVersion)) throw new Error('Invalid Secret Manager version');
  if (!/^projects\/[^/]+\/locations\/[^/]+\/keyRings\/[^/]+\/cryptoKeys\/[^/]+$/.test(config.kmsKey)) throw new Error('Invalid KMS key');
  if (!/^projects\/[^/]+\/locations\/[^/]+\/queues\/[^/]+$/.test(config.taskQueue)) throw new Error('Invalid setup task queue');
  if (!/^[a-zA-Z0-9-]+@[a-zA-Z0-9-]+\.iam\.gserviceaccount\.com$/.test(config.workerEmail)) throw new Error('Invalid setup worker service account');
  if (!new URL(config.workerOrigin).hostname.endsWith('.run.app')) throw new Error('SETUP_WORKER_ORIGIN must be the default Cloud Run service origin');
  return Object.freeze(config);
}
