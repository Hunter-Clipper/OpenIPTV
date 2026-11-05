// The whole bridge between the page and the shell (kept tiny on purpose).
const { contextBridge } = require('electron');
contextBridge.exposeInMainWorld('openiptvDesktop', {
  platform: process.platform,
  versions: { electron: process.versions.electron, chromium: process.versions.chrome },
});
