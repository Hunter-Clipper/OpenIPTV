// OpenIPTV anonymous crash-report receiver (#150).
//
// POST /report  with the JSON defined in docs/design/anonymous-stats.md.
//  - Only POST /report, only application/json, body size capped.
//  - The body must pass validate() exactly, or it is rejected and not stored.
//  - Accepted reports go to the R2 bucket as reports/YYYY-MM-DD/<random>.json.
//  - The sender's IP is used for a simple in-memory rate limit only. It is
//    never written to R2 or logged by this code.
// Old reports are deleted by the bucket's 90-day lifecycle rule (README).

import { validate, MAX_BODY_BYTES } from './validate.js';

// Best-effort limit per isolate: 30 reports per IP per hour.
const WINDOW_MS = 60 * 60 * 1000;
const MAX_PER_WINDOW = 30;
const hits = new Map();

function limited(ip, now = Date.now()) {
  const recent = (hits.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  recent.push(now);
  hits.set(ip, recent);
  if (hits.size > 5000) hits.clear(); // bound memory
  return recent.length > MAX_PER_WINDOW;
}

const reply = (status, text = null) => new Response(text, { status });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== '/report') return reply(404);
    if (request.method !== 'POST') return reply(405);
    if (!(request.headers.get('content-type') ?? '').includes('application/json')) {
      return reply(415);
    }
    const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
    if (limited(ip)) return reply(429);

    const text = await request.text();
    if (text.length > MAX_BODY_BYTES) return reply(413);
    let report;
    try {
      report = JSON.parse(text);
    } catch {
      return reply(400, 'not json');
    }
    const problem = validate(report);
    if (problem) return reply(400, problem);

    const id = crypto.randomUUID();
    // Re-serialised from the validated object, so nothing extra can ride along.
    await env.REPORTS.put(`reports/${report.day}/${id}.json`, JSON.stringify(report), {
      httpMetadata: { contentType: 'application/json' },
    });
    return reply(204);
  },
};

export { limited };
