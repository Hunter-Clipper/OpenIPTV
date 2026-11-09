// Phase 0, check 1-3: can this shell read a plain-http, no-CORS provider and
// which audio/video formats play? Run under xvfb. Usage:
//   node spike/formats.mjs <media-dir>
import { _electron } from 'playwright-core';
import { createRequire } from 'module';
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';
const here = path.dirname(fileURLToPath(import.meta.url));
const electronPath = createRequire(import.meta.url)('electron');
import fs from 'fs';
const media = path.resolve(process.argv[2]);
// The page loads hls.js / mpegts.js from the web build's own copies.
fs.cpSync(path.join(here, '..', '..', 'web', 'lib'), path.join(here, 'root', 'lib'), { recursive: true });
const server = spawn('python3', ['-m', 'http.server', '8096', '--bind', '127.0.0.1'], { cwd: media, stdio: 'ignore' });
await new Promise(r => setTimeout(r, 800));
const app = await _electron.launch({
  executablePath: electronPath,
  args: [path.join(here, '..', 'main.js'), '--no-sandbox'],
  env: { ...process.env, OPENIPTV_WEB_ROOT: path.join(here, 'root'),
         OPENIPTV_START: 'app://openiptv/formats.html', OPENIPTV_HEADLESS: '1' },
});
try {
  const win = await app.firstWindow();
  await win.waitForLoadState('load');
  const versions = await win.evaluate(() => window.openiptvDesktop && window.openiptvDesktop.versions);
  console.log('shell:', JSON.stringify(versions), '| platform', process.platform);
  const r = await win.evaluate(() => window.runAll());
  console.log('\nMediaSource.isTypeSupported:');
  for (const [k, v] of Object.entries(r.mse)) console.log(' ', v ? 'yes' : 'NO ', k);
  console.log('\nPlayback over plain http without CORS headers (3.5 s each):');
  console.log('  (V = picture decoded, A = sound decoded)');
  for (const m of r.media) {
    const v = m.videoBytes > 0 && m.frames > 0, a = m.audioBytes > 0;
    const note = m.engineError || m.error || m.thrown || '';
    console.log(' ', `V:${v ? 'yes' : 'NO '} A:${a ? 'yes' : 'NO '}`, m.name.padEnd(22), `t=${m.time}s`, note.slice(0, 110));
  }
} finally { await app.close(); server.kill(); }
