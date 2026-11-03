// Strict validation for anonymous OpenIPTV crash reports (#150).
// Mirrors lib/telemetry/report.dart + scrubber.dart. The receiver accepts
// ONLY this exact shape; anything else is rejected and never stored.
// Defense in depth: even a correct app is re-checked here, so a modified or
// fake client can't get extra data stored.

const FIELDS = ['v', 'app', 'platform', 'os', 'device', 'day', 'kind', 'error', 'stack'];
const KINDS = new Set(['crash', 'native-crash']);
const PLATFORMS = new Set(['android', 'android-tv']);

const URL_RE = /[a-zA-Z][a-zA-Z0-9+.-]*:\/\//;
const IPV4_RE = /\b\d{1,3}(?:\.\d{1,3}){3}\b/;
const IPV6_RE = /\b(?:[0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{1,4}\b/;
const EMAIL_RE = /[^\s@]+@[^\s@]+\.[^\s@]+/;
const looksPrivate = (s) => URL_RE.test(s) || IPV4_RE.test(s) || IPV6_RE.test(s) || EMAIL_RE.test(s);

const CODE_FRAME_RE = /package:|dart:|^\s*(?:at\s+)?(?:com\.openiptv\.|androidx\.|android\.|java\.|javax\.|kotlin\.|kotlinx\.|io\.flutter\.|com\.google\.android\.)/;

export const MAX_BODY_BYTES = 16 * 1024;

/** Returns null if the report is acceptable, otherwise a short reason. */
export function validate(r) {
  if (r === null || typeof r !== 'object' || Array.isArray(r)) return 'not an object';
  const keys = Object.keys(r);
  if (keys.length !== FIELDS.length || !FIELDS.every((k) => keys.includes(k))) return 'wrong fields';
  if (r.v !== 1) return 'bad version';
  for (const k of ['app', 'device']) {
    if (typeof r[k] !== 'string' || r[k].length === 0 || r[k].length > 60) return `bad ${k}`;
    if (looksPrivate(r[k])) return `private ${k}`;
  }
  if (!PLATFORMS.has(r.platform)) return 'bad platform';
  if (!Number.isInteger(r.os) || r.os < 0 || r.os > 99) return 'bad os';
  if (typeof r.day !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(r.day)) return 'bad day';
  if (!KINDS.has(r.kind)) return 'bad kind';
  if (typeof r.error !== 'string' || !/^[A-Za-z_][A-Za-z0-9_$.]{0,79}$/.test(r.error)) return 'bad error';
  if (!Array.isArray(r.stack) || r.stack.length > 30) return 'bad stack';
  for (const line of r.stack) {
    if (typeof line !== 'string' || line.length === 0 || line.length > 200) return 'bad stack line';
    if (!CODE_FRAME_RE.test(line) || looksPrivate(line)) return 'stack line is not plain code';
  }
  return null;
}
