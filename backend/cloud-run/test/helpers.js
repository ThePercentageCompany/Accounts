import { Registry, emptyRegistry } from '../src/registry.js';
import { AccountsService } from '../src/service.js';

// Tests only. Production startup has no memory-store/auth bypass flag.
export class MemoryStorage {
  state = emptyRegistry(); generation = 0;
  async read() { return { state: structuredClone(this.state), generation: this.generation }; }
  async compareAndSwap(generation, state) {
    if (generation !== this.generation) return false;
    this.state = structuredClone(state); this.generation++; return true;
  }
}
export function fixture() {
  let time = 1_800_000_000_000;
  const now = () => time;
  const storage = new MemoryStorage();
  const registry = new Registry(storage, { now });
  const config = { appOrigin: 'https://app.test', apiOrigin: 'https://api.test', sessionMs: 3600000, oauthMs: 600000 };
  const identity = {
    authorizationUrl: ({ state }) => `https://accounts.google.com/auth?state=${state}`,
    exchange: async code => ({ sub: code, email: `${code}@example.com`, name: code }),
  };
  const service = new AccountsService(registry, identity, config, { now });
  async function login(sub = 'owner-a') {
    const start = await service.startSignIn();
    const state = new URL(start.authorizationUrl).searchParams.get('state');
    return (await service.finishSignIn(state, start.binding, sub)).token;
  }
  return { storage, registry, config, identity, service, login, advance: ms => { time += ms; } };
}
