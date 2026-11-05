// Shell check: window size/position are remembered, F11 toggles full screen.
//   node spike/window.mjs <web-build-dir>   (needs a display, e.g. xvfb-run)
import { _electron } from 'playwright-core';
import { createRequire } from 'module';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { fileURLToPath } from 'url';
const here = path.dirname(fileURLToPath(import.meta.url));
const electronPath = createRequire(import.meta.url)('electron');
const data = fs.mkdtempSync(path.join(os.tmpdir(), 'openiptv-win-'));
const launch = () => _electron.launch({
  executablePath: electronPath,
  args: [path.join(here, '..', 'main.js'), '--no-sandbox', `--user-data-dir=${data}`],
  env: { ...process.env, OPENIPTV_WEB_ROOT: path.resolve(process.argv[2]) },
});
const bounds = (app) => app.evaluate(({ BrowserWindow }) => BrowserWindow.getAllWindows()[0].getBounds());
import { execSync } from 'child_process';
const sh = async (c) => execSync(c, { stdio: 'ignore' });
let ok = true;
const check = (name, pass, info) => { ok &&= pass; console.log(pass ? 'PASS' : 'FAIL', name, info ?? ''); };

let app = await launch(); let win = await app.firstWindow();
await win.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60000 });
await app.evaluate(({ BrowserWindow }) => BrowserWindow.getAllWindows()[0].setBounds({ x: 120, y: 90, width: 900, height: 620 }));
// A bare virtual display has no window manager, so record the calls instead.
await app.evaluate(({ BrowserWindow }) => {
  const w = BrowserWindow.getAllWindows()[0]; globalThis.fsCalls = [];
  w.isFullScreen = () => globalThis.fsCalls.at(-1) === true;
  w.setFullScreen = (v) => globalThis.fsCalls.push(v);
});
await sh('xdotool key F11'); await win.waitForTimeout(300);
check('F11 enters full screen', await app.evaluate(() => JSON.stringify(globalThis.fsCalls)) === '[true]');
await sh('xdotool key Escape'); await win.waitForTimeout(300);
check('Esc leaves full screen', await app.evaluate(() => JSON.stringify(globalThis.fsCalls)) === '[true,false]');
await win.waitForTimeout(600);
await app.close();
app = await launch(); await app.firstWindow();
const b = await bounds(app);
check('size remembered', b.width === 900 && b.height === 620, JSON.stringify(b));
check('position remembered', b.x === 120 && b.y === 90, JSON.stringify(b));
await app.close();
fs.writeFileSync(path.join(data, 'window-state.json'), JSON.stringify({ x: 9000, y: 9000, width: 800, height: 500 }));
app = await launch(); await app.firstWindow();
const c = await bounds(app);
check('off-screen position ignored', c.x < 3000 && c.width === 800, JSON.stringify(c));
await app.close();
fs.rmSync(data, { recursive: true, force: true });
process.exit(ok ? 0 : 1);
