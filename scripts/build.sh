#!/bin/sh
# Build a ATLauncher release into dist/: the IPK (LG's ares-package via npx), sha256sums, the Homebrew Channel repo.json,
# description.html and the store icon. Usage: scripts/build.sh   (REPO=owner/name to change the download URLs)
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REPO=${REPO:-ratelimits/atlauncher}
ID=$(python3 -c "import json; print(json.load(open('$ROOT/app/appinfo.json'))['id'])")
VERSION=$(python3 -c "import json; print(json.load(open('$ROOT/app/appinfo.json'))['version'])")
DIST=$ROOT/dist
STAGE=$DIST/source
rm -rf "$DIST"; mkdir -p "$STAGE"

# Everything in app/ except the desktop preview, a local TMDB key, and fonts you installed for the preview (SF Pro
# must never be redistributed).
cp -R "$ROOT/app/." "$STAGE/"
rm -f "$STAGE/preview.qml" "$STAGE/tmdb.key"
rm -rf "$STAGE/userfonts"
find "$STAGE" -name __pycache__ -type d -prune -exec rm -r {} +
chmod +x "$STAGE"/tools/*.sh

npx --yes -p @webos-tools/cli ares-package --no-minify "$STAGE" -o "$DIST" >/dev/null
IPK=$(cd "$DIST" && ls *.ipk)
rm -rf "$STAGE"
(cd "$DIST" && shasum -a 256 "$IPK" > sha256sums)
cp "$ROOT/docs/app-icon-large.png" "$DIST/app-icon-large.png"
(cd "$ROOT/extras" && tar czf "$DIST/atlauncher-aerial-picks.tar.gz" aerial)

URL=https://github.com/$REPO/releases/download/v$VERSION
python3 - "$DIST" "$IPK" "$ID" "$VERSION" "$URL" "$REPO" <<'PY'
import hashlib, json, os, sys
dist, ipk, app_id, version, url, repo = sys.argv[1:]
data = open(os.path.join(dist, ipk), 'rb').read()
desc = 'A native Home Screen for rooted LG webOS TVs, inspired by Apple TV.'
manifest = {"id": app_id, "version": version, "type": "qml", "title": "ATLauncher", "appDescription": desc,
            "iconUri": f"{url}/app-icon-large.png", "sourceUrl": f"https://github.com/{repo}", "rootRequired": True,
            "ipkUrl": f"{url}/{ipk}", "ipkHash": {"sha256": hashlib.sha256(data).hexdigest()}, "ipkSize": len(data)}
repo_json = {"paging": {"page": 1, "count": 1, "maxPage": 1, "itemsTotal": 1},
             "packages": [{"id": app_id, "title": "ATLauncher", "shortDescription": desc,
                           "fullDescriptionUrl": f"{url}/description.html", "iconUri": manifest["iconUri"], "manifest": manifest}]}
json.dump(repo_json, open(os.path.join(dist, 'repo.json'), 'w'), indent=2)
open(os.path.join(dist, 'description.html'), 'w').write(f"""<h1>ATLauncher {version}</h1>
<p>{desc} Dock, app grid, Liquid Glass, a Top Shelf with each app's splash or popular shows from TMDB (your own API
key), Settings, and Home-button takeover. Requires root (Homebrew Channel).</p>
<p>After installing, run <code>sh /media/developer/apps/usr/palm/applications/{app_id}/tools/atlauncher.sh enable</code>
as root to make ATLauncher the Home app. See <a href="https://github.com/{repo}">github.com/{repo}</a>.</p>
<p>This product uses the TMDB API but is not endorsed or certified by TMDB. Not affiliated with LG or Apple.</p>
""")
PY
echo "built: $(ls "$DIST")"
