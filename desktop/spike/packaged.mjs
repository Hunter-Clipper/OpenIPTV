// Starts the PACKAGED app (not the dev shell) and checks it serves the web
// build and exposes the shell flag.   node spike/packaged.mjs <executable>
import { _electron } from 'playwright-core';
const app = await _electron.launch({
  executablePath: process.argv[2],
  args: ['--no-sandbox', `--user-data-dir=${process.env.OPENIPTV_DATA || '/tmp/openiptv-packaged-data'}`],
  env: { ...process.env, OPENIPTV_HEADLESS: '1' },
});
try {
  const win = await app.firstWindow();
  await win.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
  await win.waitForTimeout(5000);
  console.log('title:', await win.title(), '| url:', win.url());
  console.log('shell flag:', await win.evaluate(() => JSON.stringify(window.openiptvDesktop)));
  console.log('packaged:', await app.evaluate(({ app }) => app.isPackaged));
} finally { await app.close(); }
