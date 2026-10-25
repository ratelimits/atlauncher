#!/bin/sh
# Trim the Aerial Screensaver add-on (org.aabytt.webos.custom-screensaver-aerial, from Homebrew Channel) to ATLauncher's
# picks in picks.json, played as 4K HEVC SDR. Run as root on the TV, with picks.json next to this script:
#   sh apply-picks.sh          apply (the add-on's own files are backed up first, once)
#   sh apply-picks.sh restore  put the add-on's files back
# An update of the add-on resets its list: run this again afterwards.
set -eu
A=/media/developer/apps/usr/palm/applications/org.aabytt.webos.custom-screensaver-aerial/assets
B=/var/lib/atlauncher/aerial-backup
HERE=$(cd "$(dirname "$0")" && pwd)
[ -f "$A/videos.json" ] || { echo "Aerial Screensaver is not installed (Homebrew Channel: Aerial Screensaver)" >&2; exit 1; }

if [ "${1:-apply}" = restore ]; then
  [ -f "$B/videos.json" ] || { echo "no backup in $B" >&2; exit 1; }
  cp -p "$B/videos.json" "$A/videos.json"; cp -p "$B/settings.json" "$A/settings.json"
  echo "Aerial Screensaver restored to its own list and settings."
  exit 0
fi

mkdir -p "$B"
[ -f "$B/videos.json" ] || cp -p "$A/videos.json" "$B/videos.json"
[ -f "$B/settings.json" ] || cp -p "$A/settings.json" "$B/settings.json"
python3 - "$B/videos.json" "$A/videos.json" "$A/settings.json" "$HERE/picks.json" <<'PY'
import json, sys
backup, videos_out, settings_path, picks_path = sys.argv[1:]
picks = json.load(open(picks_path))
wanted = [p["id"] for p in picks["picks"]]
videos = json.load(open(backup))
by_id = {a.get("id"): a for a in videos["assets"]}
kept = [by_id[i] for i in wanted if i in by_id]
missing = [p["name"] for p in picks["picks"] if p["id"] not in by_id]
videos["assets"] = kept
json.dump(videos, open(videos_out, "w"))
settings = json.load(open(settings_path))
# The add-on's own "Source video type" list, in its order (sourceTypeIndex is the position here).
types = ["url-1080-SDR", "url-1080-H264", "url-1080-HDR", "url-4K-SDR", "url-4K-HDR", "url-4K-SDR-240FPS"]
settings["sourceType"] = picks.get("sourceType", "url-4K-SDR")
if settings["sourceType"] in types:
    settings["sourceTypeIndex"] = types.index(settings["sourceType"])
json.dump(settings, open(settings_path, "w"))
print(f"Aerial Screensaver: {len(kept)} of {len(wanted)} picks, {settings['sourceType']}." + (f" Not in this version: {', '.join(missing)}" if missing else ""))
PY
