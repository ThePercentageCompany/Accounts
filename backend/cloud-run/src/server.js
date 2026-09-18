import { Storage } from '@google-cloud/storage';
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';
import { loadConfig } from './config.js';
import { GoogleControlStorage } from './google-storage.js';
import { GoogleIdentity } from './google-identity.js';
import { Registry } from './registry.js';
import { AccountsService } from './service.js';
import { createApi } from './http.js';

async function main() {
  const config = loadConfig();
  const secrets = new SecretManagerServiceClient();
  const [version] = await secrets.accessSecretVersion({ name: config.secretVersion });
  const secret = JSON.parse(Buffer.from(version.payload.data).toString('utf8'));
  if (typeof secret.clientSecret !== 'string' || !secret.clientSecret) throw new Error('OAuth secret is invalid');
  const registry = new Registry(new GoogleControlStorage(new Storage(), config.bucket, config.object));
  await registry.read(); // Fail closed on missing permissions/corrupt control data.
  const service = new AccountsService(registry, new GoogleIdentity(config, secret.clientSecret), config);
  const server = createApi(service, config);
  server.listen(config.port, '0.0.0.0', () => console.log(JSON.stringify({ event: 'listening', port: config.port, phase: 1 })));
  process.on('SIGTERM', () => { server.close(); setTimeout(() => process.exit(0), 9_000).unref(); });
}
main().catch(() => {
  console.error('API startup failed. Check operator configuration, credentials and control storage.');
  process.exitCode = 1;
});
