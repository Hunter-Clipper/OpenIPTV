// OpenIPTV desktop shell: the Flutter web build in its own window, with the
// browser's CORS / mixed-content limits lifted for this app's own requests.
// See docs/design/desktop.md.
const { app, BrowserWindow, Menu, protocol, screen, session, shell } =
  require('electron');
const fs = require('fs');
const path = require('path');

const WEB_ROOT = path.resolve(
  process.env.OPENIPTV_WEB_ROOT || path.join(__dirname, 'app'));

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.json': 'application/json',
  '.wasm': 'application/wasm', '.css': 'text/css', '.png': 'image/png',
  '.ico': 'image/x-icon', '.svg': 'image/svg+xml', '.ttf': 'font/ttf',
  '.otf': 'font/otf', '.woff2': 'font/woff2', '.txt': 'text/plain',
  '.map': 'application/json',
};

// The private address the app is served from. "standard + secure" gives it
// everything a normal https page has (IndexedDB, workers, WebAssembly).
protocol.registerSchemesAsPrivileged([{
  scheme: 'app',
  privileges: { standard: true, secure: true, supportFetchAPI: true,
                corsEnabled: true, stream: true },
}]);

function serveApp(request) {
  const url = new URL(request.url);
  let rel = decodeURIComponent(url.pathname);
  let file = path.resolve(path.join(WEB_ROOT, rel));
  if (!file.startsWith(WEB_ROOT)) return new Response('Forbidden', { status: 403 });
  // Single-page fallback: unknown paths (/live, /movies/3 ...) get index.html.
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(WEB_ROOT, 'index.html');
  }
  const body = fs.readFileSync(file);
  return new Response(body, {
    headers: { 'content-type': TYPES[path.extname(file)] || 'application/octet-stream',
               'cache-control': 'no-cache' },
  });
}

// Let the page read provider / image / stream responses (CORS) for this app's
// window only. Preflight (OPTIONS) answers are made to succeed too.
function relaxProviderAccess(ses) {
  ses.webRequest.onHeadersReceived((details, callback) => {
    if (details.url.startsWith('app://')) return callback({});
    const headers = {};
    for (const [k, v] of Object.entries(details.responseHeaders || {})) {
      if (!/^access-control-/i.test(k)) headers[k] = v;
    }
    headers['Access-Control-Allow-Origin'] = ['*'];
    headers['Access-Control-Allow-Methods'] = ['GET, HEAD, POST, OPTIONS'];
    headers['Access-Control-Allow-Headers'] = ['*'];
    const out = { responseHeaders: headers };
    if (details.method === 'OPTIONS') out.statusLine = 'HTTP/1.1 200 OK';
    callback(out);
  });
}

// Window size, position and maximized state survive restarts.
const STATE_FILE = () => path.join(app.getPath('userData'), 'window-state.json');

function loadWindowState() {
  const fallback = { width: 1280, height: 800 };
  try {
    const s = JSON.parse(fs.readFileSync(STATE_FILE(), 'utf8'));
    if (!(s.width >= 640 && s.height >= 400)) return fallback;
    // Ignore a saved position that is no longer on any screen (monitor gone).
    const onScreen = Number.isFinite(s.x) && Number.isFinite(s.y) &&
      screen.getAllDisplays().some(({ workArea: a }) =>
        s.x < a.x + a.width - 100 && s.x + s.width > a.x + 100 &&
        s.y < a.y + a.height - 100 && s.y >= a.y - 20);
    return onScreen ? s : { width: s.width, height: s.height, maximized: s.maximized };
  } catch (_) { return fallback; }
}

function trackWindowState(win) {
  let timer;
  const save = () => {
    clearTimeout(timer);
    timer = setTimeout(() => {
      if (win.isDestroyed()) return;
      const state = { ...win.getNormalBounds(), maximized: win.isMaximized() };
      try { fs.writeFileSync(STATE_FILE(), JSON.stringify(state)); } catch (_) {}
    }, 400);
  };
  for (const e of ['resize', 'move', 'maximize', 'unmaximize']) win.on(e, save);
  win.on('close', () => {
    if (win.isDestroyed()) return;
    const state = { ...win.getNormalBounds(), maximized: win.isMaximized() };
    try { fs.writeFileSync(STATE_FILE(), JSON.stringify(state)); } catch (_) {}
  });
}

function createWindow() {
  const saved = loadWindowState();
  const win = new BrowserWindow({
    width: saved.width, height: saved.height, x: saved.x, y: saved.y,
    minWidth: 640, minHeight: 400, autoHideMenuBar: true, backgroundColor: '#0A0A12', title: 'OpenIPTV',
    show: !process.env.OPENIPTV_HEADLESS,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true, nodeIntegration: false,
      // The app page is secure, but providers' streams and pictures are
      // plain http://; allow them (this window only).
      allowRunningInsecureContent: true,
      autoplayPolicy: 'no-user-gesture-required',
    },
  });
  trackWindowState(win);
  if (saved.maximized && !process.env.OPENIPTV_HEADLESS) win.maximize();
  // No menu bar; F11 toggles full screen and Esc leaves it (the page keeps
  // every other key, including Esc when not full screen).
  win.removeMenu();
  win.webContents.on('before-input-event', (e, input) => {
    if (input.type !== 'keyDown') return;
    if (input.key === 'F11') {
      win.setFullScreen(!win.isFullScreen()); e.preventDefault();
    } else if (input.key === 'Escape' && win.isFullScreen()) {
      win.setFullScreen(false); e.preventDefault();
    }
  });
  // Only the app's own address may load here; any other link opens outside.
  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url); return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (e, url) => {
    if (!url.startsWith('app://')) { e.preventDefault(); shell.openExternal(url); }
  });
  win.loadURL(process.env.OPENIPTV_START || 'app://openiptv/');
  return win;
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.whenReady().then(() => {
    Menu.setApplicationMenu(null);
    protocol.handle('app', serveApp);
    relaxProviderAccess(session.defaultSession);
    createWindow();
  });
  app.on('window-all-closed', () => app.quit());
}
