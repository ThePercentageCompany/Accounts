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
    sessionMs: 8 * 60 * 60 * 1000, oauthMs: 10 * 60 * 1000,
  };
  if (!Number.isInteger(config.port) || config.port < 1 || config.port > 65535) throw new Error('Invalid PORT');
  if (!/^projects\/[^/]+\/secrets\/[^/]+\/versions\/[^/]+$/.test(config.secretVersion)) throw new Error('Invalid Secret Manager version');
  if (!/^projects\/[^/]+\/locations\/[^/]+\/keyRings\/[^/]+\/cryptoKeys\/[^/]+$/.test(config.kmsKey)) throw new Error('Invalid KMS key');
  return Object.freeze(config);
}
