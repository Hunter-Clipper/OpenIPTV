// Phase 0, check 1: the real web build inside the shell, against a provider
// and image hosts that send no CORS headers (a plain browser can't do this).
//   node spike/app.mjs <web-build-dir> <provider-url> <shots-dir>
import { _electron } from 'playwright-core';
import { createRequire } from 'module';
import path from 'path';
import { fileURLToPath } from 'url';
const here = path.dirname(fileURLToPath(import.meta.url));
const electronPath = createRequire(import.meta.url)('electron');
const [, , webRoot, provider, shots] = process.argv;
const app = await _electron.launch({
  executablePath: electronPath,
  args: [path.join(here, '..', 'main.js'), '--no-sandbox', `--user-data-dir=${process.env.OPENIPTV_DATA || '/tmp/openiptv-spike-data'}`],
  env: { ...process.env, OPENIPTV_WEB_ROOT: path.resolve(webRoot), OPENIPTV_HEADLESS: '1' },
});
const t0 = Date.now(); const T = () => ((Date.now() - t0) / 1000).toFixed(1) + 's';
try {
  const win = await app.firstWindow();
  const logs = []; win.on('console', m => logs.push(m.text()));
  win.on('pageerror', e => logs.push('PAGEERROR ' + e.message));
  await win.setViewportSize({ width: 1280, height: 800 });
  await win.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
  await win.waitForTimeout(7000);
  console.log(T(), 'app up; shell flag:', await win.evaluate(() => JSON.stringify(window.openiptvDesktop)), '| url', win.url());
  await win.mouse.click(640, 700); await win.waitForTimeout(4500);
  await win.keyboard.type('Tester', { delay: 30 });
  await win.mouse.click(640, 752); await win.waitForTimeout(3500); await win.mouse.click(640, 768); await win.waitForTimeout(3500);
  await win.mouse.click(640, 255); await win.waitForTimeout(3500);
  await win.keyboard.type('desk', { delay: 20 });
  await win.mouse.click(640, 294); await win.keyboard.type(provider, { delay: 5 });
  await win.mouse.click(640, 382); await win.keyboard.type('t'); await win.mouse.click(640, 470); await win.keyboard.type('t');
  await win.mouse.click(640, 550);
  for (let i = 0; i < 60 && !/\/live/.test(win.url()); i++) await new Promise(r => setTimeout(r, 3000));
  if (!/\/live/.test(win.url())) { console.log(T(), 'NOT on /live, url =', win.url()); console.log(logs.filter(l => !/OPENDB|GL Driver|WebGL/.test(l)).slice(-12).join('\n').slice(0, 1500)); throw new Error('did not land on /live'); }
  console.log(T(), 'playlist added, landed on', win.url());
  await win.waitForTimeout(1500);
  await win.mouse.click(384, 760); await win.waitForTimeout(6000);
  const b64 = await app.evaluate(async ({ BrowserWindow }) =>
    (await BrowserWindow.getAllWindows()[0].webContents.capturePage()).toPNG().toString('base64'));
  (await import('fs')).writeFileSync(path.join(shots, 'desk_movies.png'), Buffer.from(b64, 'base64'));
  const cors = logs.filter(l => /CORS policy/.test(l)).length;
  const bad = logs.filter(l => /ERR_|PAGEERROR|Unsupported|ServiceWorker/i.test(l) && !/CORS policy/.test(l));
  console.log(T(), `CORS console errors: ${cors}; other errors: ${bad.length}`);
  for (const l of [...new Set(bad)].slice(0, 6)) console.log('   ', l.slice(0, 160));
  // persistence: restart the page, the playlist must still be there
  await win.reload(); await win.waitForSelector('flt-glass-pane', { state: 'attached' }); await win.waitForTimeout(9000);
  console.log(T(), 'after reload url:', win.url());
} finally { await app.close(); }
