import { emptyRegistry } from './registry.js';

export class GoogleControlStorage {
  constructor(storage, bucket, object) { this.bucket = storage.bucket(bucket); this.object = object; }
  async read() {
    // Pin download to the generation inspected; never pair stale metadata with new bytes.
    for (let attempt = 0; attempt < 5; attempt++) {
      let metadata;
      try { [metadata] = await this.bucket.file(this.object).getMetadata(); }
      catch (error) {
        if (Number(error.code) === 404) return { generation: 0, state: emptyRegistry() };
        throw error;
      }
      try {
        const [bytes] = await this.bucket.file(this.object, { generation: metadata.generation }).download();
        return { generation: metadata.generation, state: JSON.parse(bytes.toString('utf8')) };
      } catch (error) {
        if (Number(error.code) !== 404) throw error;
      }
    }
    throw new Error('Control registry changed repeatedly during read');
  }
  async compareAndSwap(generation, state) {
    try {
      await this.bucket.file(this.object).save(JSON.stringify(state), {
        resumable: false, validation: 'crc32c',
        preconditionOpts: { ifGenerationMatch: generation },
        metadata: { contentType: 'application/json', cacheControl: 'no-store' },
      });
      return true;
    } catch (error) {
      if (Number(error.code) === 412) return false;
      // Do not reinterpret unavailable/forbidden/ambiguous writes as an empty registry.
      throw error;
    }
  }
}
