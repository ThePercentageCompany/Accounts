import {createServer} from 'node:http';
import {readFile, mkdir, mkdtemp} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {resolve, extname, sep} from 'node:path';
import {pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';
const {chromium} = await import(pathToFileURL(process.argv[2]).href);
const root = resolve('build/web');
const mime = {'.html':'text/html','.js':'application/javascript','.json':'application/json',
  '.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf'};
let version = '';
const server = createServer(async (request,response) => {
  const name = decodeURIComponent(new URL(request.url,'http://localhost').pathname);
  const path = resolve(root, '.' + (name === '/' ? '/index.html' : name));
  if (path !== root && !path.startsWith(root + sep)) {response.writeHead(403);response.end();return;}
  try {
    let bytes = await readFile(path);
    if (name === '/tpc-sw.js' && version) bytes = Buffer.from(bytes.toString().replace(/const VERSION = '[^']+';/, `const VERSION = '${version}';`));
    response.writeHead(200,{'Content-Type':mime[extname(path)]||'application/octet-stream',
      'Cache-Control':'no-cache', 'Service-Worker-Allowed':'/'}); response.end(bytes);
  } catch (_) {response.writeHead(404);response.end();}
});
await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
const profile = await mkdtemp(resolve(tmpdir(), 'tpc-pwa-browser-'));
const context = await chromium.launchPersistentContext(profile,{executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,viewport:{width:390,height:844}});
const errors = [];
try {
  let offline = false;
  const owner = {ownerId:'o'.repeat(43),name:'Test owner'};
  const company = {companyId:'c'.repeat(43),name:'Test company',stage:'READY'};
  await context.route('https://accounts.thepercentagecompany.com/v1/**', async route => {
    if (offline) {await route.abort('internetdisconnected');return;}
    const path = new URL(route.request().url()).pathname;
    const value = path === '/v1/me' ? {owner} : path === '/v1/companies' ? {companies:[company]}
      : path.endsWith('/setup') ? {company} : path.endsWith('/notifications')
        ? {notifications:[],unread:0,pushAvailable:false}
        : {records:[],accounts:[],journalCount:0};
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(value),
      headers:{'Access-Control-Allow-Origin':origin,'Access-Control-Allow-Credentials':'true'}});
  });
  const page = await context.newPage();
  page.on('pageerror',error=>errors.push(error.message));
  await page.goto(origin,{waitUntil:'domcontentloaded',timeout:90000});
  await page.waitForSelector('flt-glass-pane',{state:'attached',timeout:90000});
  await page.waitForFunction(() => !document.getElementById('launch'),{timeout:90000});
  await page.evaluate(async () => {await navigator.serviceWorker.ready;});
  await page.waitForFunction(() => !!navigator.serviceWorker.controller,{timeout:90000});
  await page.waitForTimeout(10000); // Allow Flutter's first painted frame on CI.
  const cdp = await context.newCDPSession(page);
  const install = await cdp.send('Page.getInstallabilityErrors');
  assert.deepEqual(install.installabilityErrors,[],'Release manifest must be installable');
  const cachesBefore = await page.evaluate(async () => {
    const names = await caches.keys(); const cache = await caches.open(names.find(n=>n.startsWith('tpc-shell-')));
    return (await cache.keys()).map(r=>new URL(r.url).pathname);
  });
  assert(cachesBefore.includes('/main.dart.js'));
  assert(!cachesBefore.some(p=>p.startsWith('/v1/')));
  await mkdir('build/pwa-verification',{recursive:true});
  await page.screenshot({path:'build/pwa-verification/mobile-online.png',fullPage:true});
  offline = true; await context.setOffline(true);
  await page.reload({waitUntil:'domcontentloaded'});
  await page.waitForSelector('flt-glass-pane',{state:'attached',timeout:90000});
  await page.waitForFunction(() => !document.getElementById('launch'),{timeout:90000});
  assert.equal(await page.evaluate(()=>window.tpcPwa.status()).then(JSON.parse).then(s=>s.online),false);
  await page.waitForTimeout(10000);
  // Headless CanvasKit can defer repaint after a same-size offline navigation.
  await page.setViewportSize({width:391,height:844});
  await page.setViewportSize({width:390,height:844});
  await page.waitForTimeout(1000);
  await page.screenshot({path:'build/pwa-verification/mobile-offline.png',fullPage:true});
  offline = false; await context.setOffline(false);
  await page.setViewportSize({width:1366,height:900});
  await page.waitForTimeout(1000);
  await page.screenshot({path:'build/pwa-verification/desktop.png',fullPage:true});
  version = 'verification-update';
  await page.evaluate(async ()=>{await window.tpcPwa.checkUpdate();});
  await page.waitForFunction(()=>JSON.parse(window.tpcPwa.status()).updateAvailable,{timeout:90000});
  await page.evaluate(async ()=> {
    const db = await new Promise((resolve,reject)=>{const r=indexedDB.open('tpc_offline_v1');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
    await new Promise((resolve,reject)=>{
      const tx=db.transaction('partitions','readwrite');
      tx.objectStore('partitions').put({schema:2,operations:[{operationId:'pending-verification'}]},'verification');
      tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);
    });db.close();
  });
  assert.equal(await page.evaluate(()=>window.tpcPwa.pendingWork()),true);
  const blocked = await page.evaluate(async()=>{try {await window.tpcPwa.update();return false;} catch {return true;}});
  assert.equal(blocked,true,'Update must not reload while persisted changes exist');
  assert.deepEqual(errors,[],'Release application has no uncaught browser errors');
  console.log(JSON.stringify({installable:true,offlineShell:true,apiNotCached:true,
    controlledUpdate:true,pendingUpdateBlocked:true,screenshots:'build/pwa-verification',browserErrors:errors}));
} finally {
  await context.close(); await new Promise(resolve=>server.close(resolve));
}
