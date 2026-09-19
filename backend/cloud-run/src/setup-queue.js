import { digest } from './crypto.js';
import { ApiError } from './errors.js';

export class SetupQueue {
  constructor(tasks, identity, config) { Object.assign(this, { tasks, identity, config }); }
  async enqueue(companyId, revision, retry = '') {
    const name = `${this.config.taskQueue}/tasks/setup-${digest(`${companyId}:${revision}:${retry}`)}`;
    try {
      await this.tasks.createTask({ parent: this.config.taskQueue, task: {
        name, dispatchDeadline: { seconds: 180 }, httpRequest: {
          httpMethod: 'POST', url: `${this.config.workerOrigin}/internal/setup`,
          headers: { 'Content-Type': 'application/json' },
          body: Buffer.from(JSON.stringify({ companyId })).toString('base64'),
          oidcToken: { serviceAccountEmail: this.config.workerEmail, audience: this.config.workerOrigin },
        },
      } });
    } catch (error) {
      if (Number(error.code) === 6) return; // ALREADY_EXISTS: same durable dispatch.
      throw new ApiError(503, 'SETUP_QUEUE_UNAVAILABLE', 'Setup is saved. Retry to continue when the service is available.');
    }
  }
  async authorize(header) {
    try {
      if (typeof header !== 'string' || !header.startsWith('Bearer ')) throw new Error();
      const ticket = await this.identity.verifyIdToken({ idToken: header.slice(7), audience: this.config.workerOrigin });
      const claims = ticket.getPayload();
      if (claims?.email !== this.config.workerEmail || claims.email_verified !== true ||
        !['https://accounts.google.com', 'accounts.google.com'].includes(claims.iss)) throw new Error();
    } catch { throw new ApiError(401, 'WORKER_UNAUTHORIZED', 'Worker authentication is required.'); }
  }
}
