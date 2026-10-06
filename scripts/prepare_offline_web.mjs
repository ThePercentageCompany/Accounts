// Run after flutter build web. Only deploy-built public app assets are included.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const root = path.resolve(process.argv[2] || 'build/web');
const files = [];
function walk(dir, prefix = '') {
  for (const name of fs.readdirSync(dir)) {
    const relative = prefix + name;
    const file = path.join(dir, name);
    if (fs.statSync(file).isDirectory()) walk(file, relative + '/');
    else if (['index.html', 'flutter_bootstrap.js', 'flutter.js', 'main.dart.js', 'manifest.json', 'favicon.png'].includes(relative) ||
      ['assets/', 'canvaskit/', 'icons/'].some(p => relative.startsWith(p))) files.push(relative);
  }
}
walk(root);
files.sort();
const digest = crypto.createHash('sha256');
for (const file of files) digest.update(file).update(fs.readFileSync(path.join(root, file)));
const version = digest.digest('hex').slice(0, 20);
const worker = fs.readFileSync('web/offline_worker.js', 'utf8')
  .replace('__TPC_SHELL_VERSION__', version)
  .replace('const FILES = [];', 'const FILES = ' + JSON.stringify(files) + ';');
fs.writeFileSync(path.join(root, 'offline_worker.js'), worker);
console.log(`Offline shell ${version}: ${files.length} public assets; API requests excluded.`);
