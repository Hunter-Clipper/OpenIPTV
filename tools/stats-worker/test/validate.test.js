import test from 'node:test';
import assert from 'node:assert/strict';
import { validate } from '../src/validate.js';
import worker, { limited } from '../src/index.js';

const good = () => ({
  v: 1, app: '0.14.51+17', platform: 'android-tv', os: 34,
  device: 'Google Chromecast', day: '2026-11-03', kind: 'crash',
  error: 'StateError',
  stack: ['#0 Foo.bar (package:open_iptv/a.dart:1:1)', 'at com.openiptv.app.X.y(X.kt:1)'],
});

test('a correct report passes', () => assert.equal(validate(good()), null));

test('extra or missing fields are rejected', () => {
  assert.ok(validate({ ...good(), extra: 1 }));
  const r = good(); delete r.os; assert.ok(validate(r));
  assert.ok(validate([]) && validate(null) && validate('x'));
});

test('private looking content is rejected', () => {
  assert.ok(validate({ ...good(), app: 'http://x' }));
  assert.ok(validate({ ...good(), device: '10.0.0.1' }));
  assert.ok(validate({ ...good(), error: 'Bad: message' }));
  assert.ok(validate({ ...good(), stack: ['package:a/b.dart 192.168.0.4'] }));
  assert.ok(validate({ ...good(), stack: ['just some text about a channel'] }));
  assert.ok(validate({ ...good(), stack: ['package:a (https://x.y/z)'] }));
  assert.ok(validate({ ...good(), stack: ['package:a hunter@example.com'] }));
});

test('bad values are rejected', () => {
  assert.ok(validate({ ...good(), v: 2 }));
  assert.ok(validate({ ...good(), kind: 'playback-error' }));
  assert.ok(validate({ ...good(), platform: 'ios' }));
  assert.ok(validate({ ...good(), day: '2026-11-03T10:00:00Z' }));
  assert.ok(validate({ ...good(), os: '34' }));
  assert.ok(validate({ ...good(), stack: new Array(31).fill('package:a/b.dart') }));
});

class FakeBucket {
  constructor() { this.puts = []; }
  async put(key, body) { this.puts.push([key, body]); }
}
const post = (body, opts = {}) => new Request('https://x.workers.dev/report', {
  method: 'POST', headers: { 'content-type': 'application/json', 'cf-connecting-ip': opts.ip ?? '1.1.1.1' },
  body: typeof body === 'string' ? body : JSON.stringify(body),
});

test('worker stores a valid report without the sender IP', async () => {
  const env = { REPORTS: new FakeBucket() };
  const res = await worker.fetch(post({ ...good() }, { ip: '9.9.9.9' }), env);
  assert.equal(res.status, 204);
  const [key, body] = env.REPORTS.puts[0];
  assert.match(key, /^reports\/2026-11-03\/[0-9a-f-]+\.json$/);
  assert.equal(body.includes('9.9.9.9'), false);
});

test('worker rejects bad requests and stores nothing', async () => {
  const env = { REPORTS: new FakeBucket() };
  assert.equal((await worker.fetch(new Request('https://x/report'), env)).status, 405);
  assert.equal((await worker.fetch(new Request('https://x/other', { method: 'POST' }), env)).status, 404);
  assert.equal((await worker.fetch(post('not json', { ip: '2.2.2.2' }), env)).status, 400);
  assert.equal((await worker.fetch(post({ ...good(), extra: 1 }, { ip: '2.2.2.3' }), env)).status, 400);
  assert.equal((await worker.fetch(post('x'.repeat(20000), { ip: '2.2.2.4' }), env)).status, 413);
  assert.equal(env.REPORTS.puts.length, 0);
});

test('rate limit kicks in', () => {
  let blocked = false;
  for (let i = 0; i < 40; i++) blocked = limited('3.3.3.3') || blocked;
  assert.equal(blocked, true);
});
