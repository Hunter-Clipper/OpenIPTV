#!/usr/bin/env python3
"""Summarise the anonymous crash reports in the R2 bucket (#150).

Reads the Cloudflare token + account id from ~/.openiptv-cloudflare/env
(never printed). Groups reports by error and top frames so a bug that fired
ten times reads as one line. Usage: tools/summarize-reports.py [--since YYYY-MM-DD]
"""
import json, os, re, sys, urllib.parse, urllib.request, collections

env = {}
for line in open(os.path.expanduser('~/.openiptv-cloudflare/env')):
    m = re.match(r'export (\w+)=(.*)', line.strip())
    if m:
        env[m.group(1)] = m.group(2).strip('"\'')
H = {'Authorization': 'Bearer ' + env['CLOUDFLARE_API_TOKEN']}
base = ('https://api.cloudflare.com/client/v4/accounts/%s/r2/buckets/'
        'openiptv-reports/objects' % env['CLOUDFLARE_ACCOUNT_ID'])

def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=H)).read()

since = sys.argv[sys.argv.index('--since') + 1] if '--since' in sys.argv else ''
keys = [o['key'] for o in json.loads(get(base + '?per_page=1000'))['result']]
groups = collections.defaultdict(list)
for k in keys:
    if k.split('/')[1] < since:
        continue
    r = json.loads(get(base + '/' + urllib.parse.quote(k, safe='/')))
    stack = r.get('stack') or []
    # First frame in our own code, else the first frame at all.
    top = next((l for l in stack if 'open_iptv' in l or 'com.openiptv' in l),
               stack[0] if stack else '(no stack)')
    groups[(r['kind'], r['error'], re.sub(r'^#\d+\s+', '', top))].append(r)

for (kind, err, top), rs in sorted(groups.items(), key=lambda g: -len(g[1])):
    apps = sorted({r['app'] for r in rs})
    devs = sorted({r['device'] for r in rs})
    days = sorted({r['day'] for r in rs})
    print('%3d x %s %s\n      %s\n      builds %s | %s | %s..%s\n' % (
        len(rs), kind, err, top[:140], ', '.join(apps), ', '.join(devs),
        days[0], days[-1]))
