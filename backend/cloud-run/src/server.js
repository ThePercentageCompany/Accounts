import { Storage } from '@google-cloud/storage';
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';
import { KeyManagementServiceClient } from '@google-cloud/kms';
import { CloudTasksClient } from '@google-cloud/tasks';
import { OAuth2Client } from 'google-auth-library';
import { loadConfig } from './config.js';
import { GoogleControlStorage } from './google-storage.js';
import { GoogleIdentity } from './google-identity.js';
import { Registry } from './registry.js';
import { AccountsService } from './service.js';
import { createApi } from './http.js';
import { RefreshTokenVault } from './crypto.js';
import { GoogleConnection } from './google-connection.js';
import { GoogleWorkspace } from './google-workspace.js';
import { WorkspaceService } from './workspace-service.js';
import { SetupQueue } from './setup-queue.js';
import { readOAuthSecret } from './integrity.js';
import { EmployeeSheets } from './employee-sheets.js';
import { EmployeeService } from './employee-service.js';
import { BusinessSheets } from './business-sheets.js';
import { BusinessService } from './business-service.js';
import { DocumentDrive } from './document-drive.js';
import { DocumentService, DocumentSheets } from './document-service.js';
import webPush from 'web-push';
import { NotificationService } from './notification-service.js';
import { bytesFromProto, verifyCrc } from './integrity.js';

async function main() {
  const config = loadConfig();
  const secrets = new SecretManagerServiceClient();
  const clientSecret = await readOAuthSecret(secrets, config.secretVersion);
  const registry = new Registry(new GoogleControlStorage(new Storage(), config.bucket, config.object));
  await registry.read(); // Fail closed on missing permissions/corrupt control data.
  const service = new AccountsService(registry, new GoogleIdentity(config, clientSecret), config);
  const queue = new SetupQueue(new CloudTasksClient(), new OAuth2Client(), config);
  const google = new GoogleWorkspace();
  const workspace = new WorkspaceService({ accounts: service, queue,
    connection: new GoogleConnection(config, clientSecret), google,
    vault: new RefreshTokenVault(new KeyManagementServiceClient(), config.kmsKey) });
  const employees = new EmployeeService({ accounts: service, sheets: new EmployeeSheets(workspace, google) });
  const business = new BusinessService({ accounts: service, sheets: new BusinessSheets(workspace, google) });
  const documents = new DocumentService({ accounts: service, business, employees, workspace, google,
    drive: new DocumentDrive(google), sheets: new DocumentSheets(workspace, google) });
  let sendPush;
  if (config.pushPublicKey || config.pushSecretVersion || config.pushSubject) {
    if (!config.pushPublicKey || !config.pushSecretVersion || !config.pushSubject) throw new Error('Incomplete push configuration');
    const [version] = await secrets.accessSecretVersion({name: config.pushSecretVersion});
    const bytes = bytesFromProto(version.payload.data);
    verifyCrc(bytes, version.payload.dataCrc32c);
    const {privateKey} = JSON.parse(bytes.toString('utf8'));
    webPush.setVapidDetails(config.pushSubject, config.pushPublicKey, privateKey);
    sendPush = (subscription, payload) => webPush.sendNotification(subscription, JSON.stringify(payload),
      {TTL: 3600, timeout: 15000, topic: payload.id.slice(0, 32)});
  }
  const notifications = new NotificationService({accounts: service, employees, business, config, sendPush, queue});
  const server = createApi(service, config, { workspace, queue, employees, business, documents, notifications });
  server.listen(config.port, '0.0.0.0', () => console.log(JSON.stringify({ event: 'listening', port: config.port, phase: 4 })));
  process.on('SIGTERM', () => { server.close(); setTimeout(() => process.exit(0), 9_000).unref(); });
}
main().catch(() => {
  console.error('API startup failed. Check operator configuration, credentials and control storage.');
  process.exitCode = 1;
});
