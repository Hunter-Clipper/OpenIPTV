# OpenIPTV anonymous crash-report receiver

The tiny Cloudflare Worker behind **Settings → Advanced → Anonymous Reports**
(issue #150). The app only sends anything if the user turned reports on. See
`docs/design/anonymous-stats.md` for the promise it keeps.

What it does, in full (`src/index.js`, about 60 lines):

1. Accepts only `POST /report` with a JSON body under 16 KB.
2. Checks the body against the exact report shape (`src/validate.js`); any
   extra field, URL, IP address, e-mail or non-code stack line is rejected.
3. Writes the report to the R2 bucket as `reports/YYYY-MM-DD/<random>.json`.
4. Uses the sender's IP only for an in-memory rate limit (30 per hour). It is
   never written to R2 or logged by this code.

Limit worth knowing: Cloudflare itself sees each connection, as any web host
does. The stored reports contain no IP.

## Deploy (once, with your Cloudflare account)

```sh
cd tools/stats-worker
npx wrangler login
npx wrangler r2 bucket create openiptv-reports
# Delete reports after 90 days:
npx wrangler r2 bucket lifecycle add openiptv-reports delete-90d reports/ --expire-days 90
npx wrangler deploy
```

`wrangler deploy` prints the address, like
`https://openiptv-stats.<your-account>.workers.dev`. Put
`https://…workers.dev/report` into `statsEndpoint` in
`lib/telemetry/sender.dart` (one constant). The project's own deployment is already set.

The bucket stays private: only you can read it (R2 dashboard or `wrangler r2
object get`).

## Tests

```sh
npm test
```
