#!/bin/sh
# Keeps ATLauncher's app list current: follows SAM's listApps subscription and writes a compact copy to
# /var/lib/atlauncher/apps.json whenever an app is installed, removed or updated. Each visible app's own icon and splash
# (LG's system apps included, and the hidden inputs and AirPlay that ATLauncher shows) are copied into appicons/; your own art in custom/icons and custom/art
# (<app id>.png|jpg) is listed too and used first, and App Store icons fetched by storeicons.py (storeicons/) are
# added as storeTile / storeIcon. Started by atlauncher.sh (root).
DATA=/var/lib/atlauncher
OUT=$DATA/apps.json

write() {
  luna-send -n 1 luna://com.webos.applicationManager/listApps '{}' 2>/dev/null | python3 -c '
import json, os, shutil, sys, time
data = sys.argv[1]
icons = os.path.join(data, "appicons")
os.makedirs(icons, exist_ok=True)
apps = json.load(sys.stdin).get("apps", [])
keys = ("id", "title", "iconColor", "folderPath", "visible", "systemApp")

def copy(app, fields, name):
    """Copy the first existing image among `fields` to appicons/<name>.<ext>; return its path relative to data."""
    for field in fields:
        src = app.get(field)
        if not isinstance(src, str) or not src.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
            continue
        if not src.startswith("/"):
            src = os.path.join(app.get("folderPath", ""), src)
        if not os.path.isfile(src):
            continue
        dst = os.path.join(icons, name + os.path.splitext(src)[1].lower())
        if not os.path.isfile(dst) or os.path.getsize(dst) != os.path.getsize(src):
            shutil.copyfile(src, dst + ".tmp")
            os.replace(dst + ".tmp", dst)
        return os.path.relpath(dst, data)
    return None

def custom(kind, app_id):
    for ext in (".png", ".jpg", ".jpeg"):
        p = os.path.join("custom", kind, app_id + ext)
        if os.path.isfile(os.path.join(data, p)):
            return p
    return None

try:
    store = json.load(open(os.path.join(data, "storeicons", "index.json")))
except Exception:
    store = {}

# Hidden LG apps ATLauncher still shows as tiles, with the TV own icons.
shown_hidden = {"com.webos.app.hdmi1", "com.webos.app.hdmi2", "com.webos.app.hdmi3", "com.webos.app.hdmi4", "airplay"}

out, keep = [], set()
for a in apps:
    entry = {k: a.get(k) for k in keys}
    if a.get("visible") or a["id"] in shown_hidden:
        entry["tileIcon"] = copy(a, ("extraLargeIcon", "largeIcon", "mediumLargeIcon", "icon"), a["id"])
        entry["tileBg"] = copy(a, ("splashBackground", "bgImage"), a["id"] + "-bg")
        keep.update(os.path.basename(p) for p in (entry["tileIcon"], entry["tileBg"]) if p)
    entry["customIcon"] = custom("icons", a["id"])
    entry["customArt"] = custom("art", a["id"])
    s = store.get(a["id"]) or {}
    for k, field in (("tile", "storeTile"), ("icon", "storeIcon")):
        if s.get(k) and os.path.isfile(os.path.join(data, s[k])):
            entry[field] = s[k]
    out.append(entry)
for f in os.listdir(icons):  # uninstalled apps
    if f not in keep:
        os.remove(os.path.join(icons, f))
print(json.dumps({"ts": int(time.time() * 1000), "apps": out}, separators=(",", ":")))
' "$DATA" > "$OUT.tmp" 2>/dev/null && [ -s "$OUT.tmp" ] && mv -f "$OUT.tmp" "$OUT"
}

# App Store icons in the background (one run at a time); new icons rewrite the list.
store() {
  [ -f "$DATA/storeicons.py" ] || return
  ( flock -n 8 || exit 0; python3 "$DATA/storeicons.py"; [ $? -eq 3 ] && write ) 8>/tmp/atlauncher-store.lock &
}

# Refetch requests from Settings > Apps > <app> > App Store Icon: ATLauncher stores "<app id>:<time>" in its settings
# (settingsservice, category atlauncher); each new one downloads that app's icon again. The last one handled is kept
# in refetch.done, so renewing the subscription (which repeats the current value) doesn't refetch again.
refetch_watch() {
  while :; do
    timeout 300 luna-send -i luna://com.webos.settingsservice/getSystemSettings \
      '{"app_id":"com.ratelimits.atlauncher","category":"atlauncher","keys":["refetch"],"subscribe":true}' 2>/dev/null |
    while read -r line; do
      req=$(echo "$line" | sed -n 's/.*"refetch": *"\([^"]*\)".*/\1/p')
      [ -n "$req" ] || continue
      [ "$req" = "$(cat "$DATA/refetch.done" 2>/dev/null)" ] && continue
      echo "$req" > "$DATA/refetch.done"
      ( flock 8; python3 "$DATA/storeicons.py" --refetch "${req%%:*}"; [ $? -eq 3 ] && write ) 8>/tmp/atlauncher-store.lock
    done
    sleep 1
  done
}

exec 9>/tmp/atlauncher-apps-watch.lock
flock -n 9 || exit 0
refetch_watch &
while :; do
  write
  store
  # One line per change after the initial list; re-write on each, and every 5 minutes (custom art changes too).
  timeout 300 luna-send -i luna://com.webos.applicationManager/listApps '{"subscribe":true}' 2>/dev/null |
  while read -r line; do
    case "$line" in *'"change"'*) write; store ;; esac
  done
done
