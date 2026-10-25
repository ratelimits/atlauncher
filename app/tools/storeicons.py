#!/usr/bin/env python3
"""App Store icons for ATLauncher (Settings > Appearance > App Store Icons). For each app on the TV, find its App Store
app and download its Apple TV tile (the flat render of its tvOS icon, 500x300), or its iPhone icon when it has no
Apple TV version, into /var/lib/atlauncher/storeicons. Nothing is bundled: this runs on the TV (started by
apps-watch.sh) and only talks to itunes.apple.com, apps.apple.com and Apple's image server.

Which App Store app: /var/lib/atlauncher/store-ids.json first ({"<webOS app id>": <App Store id>, or null to leave
that app's LG icon}), then a built-in list for popular apps, then a search by the app's name that only accepts a
close match. Hits are refreshed monthly; misses are retried after a week."""
import hashlib, json, os, re, sys, time, urllib.parse, urllib.request

DATA = '/var/lib/atlauncher'
OUT = os.path.join(DATA, 'storeicons')
INDEX = os.path.join(OUT, 'index.json')
UA = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) '
                    'Version/17.0 Safari/605.1.15'}
HIT_DAYS, MISS_DAYS = 30, 7
# Bump when the way icons are found changes: an index from an older version is discarded and every app refetched.
INDEX_VERSION = 3

# webOS app id -> App Store id, for apps whose LG names don't search well or have look-alikes.
BUILTIN = {
    'netflix': 363590051, 'amazon': 545519333, 'com.disney.disneyplus-prod': 1446075923, 'hulu': 376510438,
    'com.apple.appletv': 1174078549, 'youtube.leanback.v4': 544007664, 'com.wbd.stream': 1666653815,
    'com.peacock.tv': 1508186374, 'com.apple.applemusic': 1108187390, 'com.microsoft.xbox': 736179781,
}
# LG system apps with no App Store counterpart: never searched.
SKIP = re.compile(r'^(com\.webos\.|com\.palm\.|com\.lge\.|airplay$|org\.webosbrew\.|com\.ratelimits\.atlauncher$)')


def get(url, binary=False):
    data = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=20).read()
    return data if binary else data.decode('utf-8', 'replace')


def norm(s):
    return re.sub(r'[^a-z0-9]', '', (s or '').lower())


def search(title):
    """The App Store id for an app name, only if a result's name starts with it (or is it)."""
    want = norm(title)
    if len(want) < 3:
        return None
    q = urllib.parse.urlencode({'term': title, 'entity': 'software', 'country': 'us', 'limit': 8})
    for r in json.loads(get('https://itunes.apple.com/search?' + q)).get('results', []):
        name = norm(r.get('trackName'))
        if name == want or name.startswith(want):
            return r['trackId']
    return None


ICON = re.compile(r'"icon":\{"\$kind":"Artwork","crop":"[^"]*","template":"([^"]+?\.lsr)/\{w\}x\{h\}\{c\}\.\{f\}",'
                  r'"width":(\d+),"height":(\d+)')


def own_tv_icon(page, store_id):
    """The app's own Apple TV icon (a 5:3 .lsr template) from the page's embedded data: the icon inside the entry that
    carries its adamId, searching only up to the next app's entry (the page also lists other apps' icons)."""
    for m in re.finditer(r'"adamId":"%s"' % store_id, page):
        nxt = re.compile(r'"adamId":"(?!%s")' % store_id).search(page, m.end())
        t = ICON.search(page[m.end():nxt.start() if nxt else m.end() + 6000])
        if t and abs(int(t.group(2)) / int(t.group(3)) - 5 / 3) < 0.02:
            return t.group(1)
    return None


def fetch(store_id, app_id):
    """Download the Apple TV tile, else the iPhone icon. Returns {'tile': path} or {'icon': path} or {}."""
    tv = own_tv_icon(get(f'https://apps.apple.com/us/app/id{store_id}?platform=tv'), store_id)
    if tv:
        return {'tile': save(tv + '/500x300bb.png', app_id, 'tile')}
    look = json.loads(get(f'https://itunes.apple.com/lookup?id={store_id}&country=us')).get('results', [])
    art = look[0].get('artworkUrl512') if look else None
    if art:
        return {'icon': save(re.sub(r'/\d+x\d+bb\.\w+$', '/512x512bb.png', art), app_id, 'icon')}
    return {}


def save(url, app_id, kind):
    """Save as <app id>-<kind>-<content hash>.png, removing that app's older picture of this kind: a changed picture
    gets a new name (ATLauncher caches images by name, so reusing it would keep showing the old one)."""
    data = get(url, binary=True)
    if not data.startswith(b'\x89PNG'):
        raise ValueError('not a PNG')
    name = f'{app_id}-{kind}-{hashlib.sha1(data).hexdigest()[:10]}.png'
    for old in os.listdir(OUT):
        if old.startswith(f'{app_id}-{kind}') and old != name and re.fullmatch(r'%s-%s(-[0-9a-f]{10})?\.png' % (re.escape(app_id), kind), old):
            os.remove(os.path.join(OUT, old))
    path = os.path.join(OUT, name)
    with open(path + '.tmp', 'wb') as f:
        f.write(data)
    os.replace(path + '.tmp', path)
    return os.path.relpath(path, DATA)


def main():
    os.makedirs(OUT, exist_ok=True)
    try:
        apps = json.load(open(os.path.join(DATA, 'apps.json')))['apps']
    except Exception:
        return
    try:
        overrides = json.load(open(os.path.join(DATA, 'store-ids.json')))
    except Exception:
        overrides = {}
    try:
        index = json.load(open(INDEX))
    except Exception:
        index = {}
    if index.get('_version') != INDEX_VERSION:
        index = {'_version': INDEX_VERSION}
    now, changed = time.time(), False
    for a in apps:
        app_id = a.get('id', '')
        if not a.get('visible') or a.get('systemApp') or SKIP.match(app_id):
            continue
        if app_id in overrides and overrides[app_id] is None:
            if index.pop(app_id, None) is not None:
                changed = True
            continue
        wanted = overrides.get(app_id) or BUILTIN.get(app_id)
        old = index.get(app_id) or {}
        age_days = (now - old.get('ts', 0)) / 86400
        if old and (wanted is None or old.get('storeId') == wanted) and \
                age_days < (HIT_DAYS if (old.get('tile') or old.get('icon')) else MISS_DAYS):
            continue
        entry = {'ts': now, 'storeId': None}
        try:
            store_id = wanted or search(a.get('title') or app_id)
            entry['storeId'] = store_id
            if store_id:
                entry.update(fetch(store_id, app_id))
        except Exception as e:
            entry['error'] = str(e)[:120]
        index[app_id] = entry
        changed = True
        time.sleep(1)
    # Pictures no app refers to any more (a replaced or dropped icon).
    used = {os.path.basename(e.get('tile') or e.get('icon') or '') for e in index.values() if isinstance(e, dict)}
    for f in os.listdir(OUT):
        if f.endswith('.png') and f not in used:
            os.remove(os.path.join(OUT, f))
    if changed:
        with open(INDEX + '.tmp', 'w') as f:
            json.dump(index, f, indent=1)
        os.replace(INDEX + '.tmp', INDEX)
    sys.exit(3 if changed else 0)   # 3: apps.json should be rewritten to carry the new icons


if __name__ == '__main__':
    main()
