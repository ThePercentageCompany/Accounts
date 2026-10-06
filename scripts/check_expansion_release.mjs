// Usage: node scripts/check_expansion_release.mjs [path-to-Chrome-or-Edge]
// First build tool/expansion_release_probe.dart to build/expansion-probe.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';
import {randomUUID} from 'node:crypto';

const root = path.resolve(process.argv[3] || 'build/expansion-probe');
const server = http.createServer((req, res) => {
  const file = path.resolve(root, '.' + new URL(req.url, 'http://localhost').pathname);
  if (!file.startsWith(root + path.sep) && file !== root) {
    res.writeHead(403).end(); return;
  }
  const target = file === root ? path.join(root, 'index.html') : file;
  const types = {'.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.ttf': 'font/ttf'};
  fs.readFile(target, (error, data) => {
    res.writeHead(error ? 404 : 200, {'Content-Type': types[path.extname(target)] || 'application/octet-stream'});
    res.end(error ? '' : data);
  });
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const port = server.address().port;
const browser = process.argv[2] || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const profile = path.resolve('build', 'probe-profile-' + randomUUID());
const child = spawn(browser, ['--headless=new', '--remote-debugging-port=0',
  `--user-data-dir=${profile}`, '--disable-background-timer-throttling',
  '--window-size=1600,1000', '--no-first-run', 'about:blank'], {windowsHide: true});
let stderr = '';
child.stderr.on('data', data => { stderr += data; });
let socket;
try {
  const portFile = path.join(profile, 'DevToolsActivePort');
  for (let i = 0; i < 300 && !fs.existsSync(portFile) && !stderr.includes('DevTools listening on'); i++) await delay(100);
  const debugPort = fs.existsSync(portFile) ? fs.readFileSync(portFile, 'utf8').split('\n')[0]
    : stderr.match(/DevTools listening on ws:\/\/127\.0\.0\.1:(\d+)/)?.[1];
  if (!debugPort) throw new Error('Browser did not start: ' + stderr);
  const targets = await (await fetch(`http://127.0.0.1:${debugPort}/json`)).json();
  socket = new WebSocket(targets.find(t => t.type === 'page').webSocketDebuggerUrl);
  await new Promise(resolve => socket.addEventListener('open', resolve, {once: true}));
  let id = 0;
  let runtimeErrors = 0;
  const pending = new Map();
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.id) { pending.get(message.id)?.(message); pending.delete(message.id); }
    if (message.method === 'Runtime.consoleAPICalled') {
      console.log(message.params.args.map(a => a.value ?? a.description).join(' '));
    }
    if (message.method === 'Runtime.exceptionThrown') {
      runtimeErrors++;
      console.error(JSON.stringify(message.params));
    }
  });
  const call = (method, params = {}) => new Promise(resolve => {
    pending.set(++id, resolve); socket.send(JSON.stringify({id, method, params}));
  });
  await call('Runtime.enable');
  await call('Page.navigate', {url: `http://127.0.0.1:${port}/`});
  let complete = false;
  for (let i = 0; i < 240; i++) {
    await delay(1000);
    if (i === 30 || i === 60) {
      await call('Emulation.setDeviceMetricsOverride', {
        width: i === 30 ? 900 : 1600, height: i === 30 ? 1600 : 900,
        deviceScaleFactor: 1, mobile: false,
      });
    }
    const response = await call('Runtime.evaluate', {expression: 'document.title', returnByValue: true});
    const title = response.result?.result?.value;
    if (title?.startsWith('PROBE COMPLETE')) {
      complete = true;
      process.exitCode = title === 'PROBE COMPLETE errors=0' && runtimeErrors === 0 ? 0 : 1;
      const shot = await call('Page.captureScreenshot');
      fs.writeFileSync(path.join(root, 'probe-result-' + path.basename(browser) + '.png'), Buffer.from(shot.result.data, 'base64'));
      break;
    }
  }
  if (!complete) throw new Error('Release probe timed out');
} finally {
  socket?.close(); child.kill(); server.close();
}
