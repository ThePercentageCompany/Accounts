import {readdir, readFile, writeFile} from 'node:fs/promises';
import {join, resolve} from 'node:path';
import {createHash} from 'node:crypto';
const root = resolve(process.argv[2] || 'build/web');
async function files(dir, prefix = '') {
  const result = [];
  for (const entry of await readdir(dir, {withFileTypes:true})) {
    const path = prefix + entry.name;
    if (entry.isDirectory()) result.push(...await files(join(dir, entry.name), path + '/'));
    else if (!path.endsWith('.map') && !['tpc-sw.js', 'flutter_service_worker.js', 'version.json'].includes(path)) result.push(path);
  }
  return result.sort();
}
const resources = await files(root);
const hash = createHash('sha256');
for (const path of resources) hash.update(path).update(await readFile(join(root, path)));
const version = hash.digest('hex').slice(0, 20);
const template = await readFile('web/tpc-sw.js', 'utf8');
await writeFile(join(root, 'tpc-sw.js'), template
  .replace("const VERSION = 'development';", `const VERSION = '${version}';`)
  .replace(/const RESOURCES = \[[^;]+;/, `const RESOURCES = ${JSON.stringify(resources)};`));
console.log(`PWA shell ${version}: ${resources.length} local resources`);
