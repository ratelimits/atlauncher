#!/bin/sh
# ATLauncher's Home takeover for rooted LG webOS TVs (run as root, e.g. over SSH):
#   sh /media/developer/apps/usr/palm/applications/com.ratelimits.atlauncher/tools/atlauncher.sh enable
#   sh /var/lib/atlauncher/atlauncher.sh status | disable
# enable  - make ATLauncher the TV's Home app: a bind mount over LG Home's folder whose appinfo.json claims LG Home's id
#           and whose files link to ATLauncher's (nothing on the system partition is written; LG Home stays underneath),
#           the remote's Home / Settings / Input keys open ATLauncher (a surface-manager key filter, runtime config only),
#           and Homebrew Channel boot hooks re-apply it all at every boot.
# disable - undo all of that (LG Home is back immediately; open apps close).
# status  - what is active.
# relink  - after updating ATLauncher: link new files into the Home overlay and restart ATLauncher (no SAM restart).
# Internal: early (boot hook, before SAM reads apps), boot (boot hook, long-running helpers).
# Log: /var/lib/atlauncher/boot.log
set -u
ID=com.ratelimits.atlauncher
APP=/media/developer/apps/usr/palm/applications/$ID
DATA=/var/lib/atlauncher
OV=$DATA/home-overlay
T=/usr/palm/applications/com.webos.app.home
HOOKS=/var/lib/webosbrew/init.d
KEYCFG=com.webos.surfacemanager.keyFilters
LOG=$DATA/boot.log

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
L() { timeout 10 luna-send -n 1 "$@" 2>/dev/null; }
mounted() { findmnt "$T" >/dev/null 2>&1; }
installed() { [ -f "$APP/main.qml" ]; }
fg() { L luna://com.webos.applicationManager/getForegroundAppInfo '{}' | sed -n 's/.*"appId": *"\([^"]*\)".*/\1/p'; }

# ---- the Home overlay ----

build() {
  rm -rf "$OV"; mkdir -p "$OV"
  for name in $(ls "$APP"); do
    [ "$name" = appinfo.json ] || ln -s "$APP/$name" "$OV/$name"
  done
  python3 - "$APP/appinfo.json" "$OV/appinfo.json" <<'PY'
import json, sys
a = json.load(open(sys.argv[1]))
a.update({
    "id": "com.webos.app.home", "title": "Home", "visible": False, "class": {"hidden": True},
    "appCategory": ["home"], "lockable": False, "handlesRelaunch": True,
    # LG Home's own permissions (it is a system app, so they are granted).
    "requiredPermissions": ["applications", "applications.launcher", "applications.operation", "applications.internal",
                            "launcher.status", "launcher.control", "settings", "system", "database", "private"],
})
json.dump(a, open(sys.argv[2], "w"), indent=2)
PY
}

# LG Home runs as its own process (flutter-client), which survives a SAM restart: end it by scanning /proc (a pkill
# pattern can match the caller's own shell).
end_lg_home() {
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' 2>/dev/null < "$p/cmdline") || continue
    case "$c" in *flutter-client*com.webos.app.home*) kill "${p#/proc/}" 2>/dev/null ;; esac
  done
}

sam_sees_atlauncher() { L luna://com.webos.applicationManager/getAppInfo '{"id":"com.webos.app.home"}' | grep -q '"type": *"qml"'; }

open_home() {
  i=0; while [ $i -lt 10 ]; do
    L luna://com.webos.applicationManager/launch '{"id":"com.webos.app.home"}' >/dev/null
    sleep 4
    [ "$(fg)" = com.webos.app.home ] && return
    i=$((i + 1))
  done
}

restart_sam_and_home() {
  end_lg_home
  systemctl restart sam.service
  end_lg_home
  i=0; while [ $i -lt 30 ] && ! L luna://com.webos.applicationManager/getForegroundAppInfo '{}' >/dev/null; do i=$((i + 1)); sleep 2; done
  open_home
}

unmount_all() {
  # The mount also appears inside app jails (mount propagation): undo every copy, innermost first.
  for m in $(findmnt -rn -o TARGET | grep "/com.webos.app.home\$" | sort -r); do umount -l "$m" 2>/dev/null; done
}

# ---- remote keys (surface-manager key filter, configd runtime config) ----

keys_on() {
  [ -f "$DATA/keyFilters.original.json" ] || L luna://com.webos.service.config/getConfigs "{\"configNames\":[\"$KEYCFG\"]}" > "$DATA/keyFilters.original.json"
  payload=$(python3 - "$DATA/keyFilters.original.json" "$DATA/homekey.js" "$KEYCFG" <<'PY'
import json, sys
orig = json.load(open(sys.argv[1]))["configs"][sys.argv[3]]
mine = {"handler": "handleATLauncherKey", "file": sys.argv[2]}
filters = [f for f in orig if f.get("file") != sys.argv[2]]
# After the pre-processing filters and the screen-saver wake-up, before LG's own Home handling.
at = next((i + 1 for i, f in enumerate(filters) if f.get("handler") == "handleScreenSaver"), 3)
filters.insert(at, mine)
print(json.dumps({"configs": {sys.argv[3]: filters}}))
PY
)
  L luna://com.webos.service.config/setConfigs "$payload" >/dev/null
}

keys_off() {
  [ -f "$DATA/keyFilters.original.json" ] || return
  payload=$(python3 -c "import json,sys; print(json.dumps({'configs': json.load(open(sys.argv[1]))['configs']}))" "$DATA/keyFilters.original.json")
  L luna://com.webos.service.config/setConfigs "$payload" >/dev/null
}

# ---- long-running helpers ----

# The media server learns the foreground app from a subscription to SAM and doesn't renew it when SAM restarts, so
# every app's video stays black (sound plays) until it is restarted. Restart it if SAM started after it.
media_check() {
  started() { pid=$(systemctl show -p MainPID --value "$1.service"); [ "${pid:-0}" -gt 0 ] && cut -d' ' -f22 "/proc/$pid/stat" 2>/dev/null; }
  s=$(started sam); m=$(started umediaserver)
  if [ -n "$s" ] && [ -n "$m" ] && [ "$s" -gt "$m" ]; then log "media server older than SAM: restarting it"; systemctl restart umediaserver.service; fi
}

helpers() {
  setsid sh "$DATA/apps-watch.sh" </dev/null >/dev/null 2>&1 &
  setsid sh "$DATA/home-redirect.sh" </dev/null >/dev/null 2>&1 &
}

# Each helper runs in its own session (setsid), so its whole process group is stopped: killing only the shell left
# its luna-send subscription running, holding the helper's lock, and a restarted helper exited at once.
helpers_off() {
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' 2>/dev/null < "$p/cmdline") || continue
    case "$c" in "sh $DATA/apps-watch.sh"*|"sh $DATA/home-redirect.sh"*) kill -- "-${p#/proc/}" 2>/dev/null; kill "${p#/proc/}" 2>/dev/null ;; esac
  done
  sleep 1
}

copy_tools() {
  mkdir -p "$DATA/custom/icons" "$DATA/custom/art" "$DATA/fonts"
  for f in atlauncher.sh homekey.js apps-watch.sh home-redirect.sh storeicons.py; do cp "$APP/tools/$f" "$DATA/$f"; done
}

hooks_on() {
  mkdir -p "$HOOKS"
  printf '#!/bin/sh\n# ATLauncher: mount the Home overlay before SAM starts (remove with: sh %s/atlauncher.sh disable)\nsh %s/atlauncher.sh early >/dev/null 2>&1\nexit 0\n' "$DATA" "$DATA" > "$HOOKS/40-atlauncher-home"
  printf '#!/bin/sh\n# ATLauncher: Home keys, app list, LG Home escape (remove with: sh %s/atlauncher.sh disable)\nsystemd-run --unit=atlauncher --no-block sh %s/atlauncher.sh boot >/dev/null 2>&1 || (setsid sh %s/atlauncher.sh boot </dev/null >/dev/null 2>&1 &)\nexit 0\n' "$DATA" "$DATA" "$DATA" > "$HOOKS/60-atlauncher"
  chmod +x "$HOOKS/40-atlauncher-home" "$HOOKS/60-atlauncher"
}

hooks_off() { rm -f "$HOOKS/40-atlauncher-home" "$HOOKS/60-atlauncher"; }

case "${1:-status}" in
  enable)
    installed || { echo "ATLauncher is not installed ($APP)" >&2; exit 1; }
    mkdir -p "$DATA"
    copy_tools
    hooks_on
    keys_on
    helpers_off; helpers
    rm -f "$DATA/lg-home-next-boot" /tmp/atlauncher-lg-home
    L luna://com.webos.applicationManager/closeByAppId '{"id":"com.webos.app.home"}' >/dev/null; sleep 2
    unmount_all; build; end_lg_home
    mount --bind "$OV" "$T" || { echo "mount failed" >&2; exit 1; }
    echo "Restarting SAM (open apps close)..."
    restart_sam_and_home
    media_check
    log "enabled"
    echo "ATLauncher is the Home app. Undo: sh $DATA/atlauncher.sh disable"
    ;;
  disable)
    hooks_off
    keys_off
    helpers_off
    L luna://com.webos.applicationManager/closeByAppId '{"id":"com.webos.app.home"}' >/dev/null; sleep 2
    unmount_all
    systemctl restart sam.service
    sleep 3; media_check
    log "disabled"
    echo "LG Home restored. ATLauncher stays installed as a normal app; its data is in $DATA."
    ;;
  relink)
    mounted || { echo "ATLauncher is not the Home app"; exit 0; }
    copy_tools
    helpers_off; helpers
    for name in $(ls "$APP"); do
      [ "$name" = appinfo.json ] || [ -e "$OV/$name" ] || ln -s "$APP/$name" "$OV/$name"
    done
    for p in /proc/[0-9]*; do
      c=$(tr '\0' ' ' 2>/dev/null < "$p/cmdline") || continue
      case "$c" in /usr/bin/qml-runner*com.webos.app.home*) kill "${p#/proc/}" 2>/dev/null ;; esac
    done
    sleep 2; open_home
    log "relinked"; echo "ATLauncher updated."
    ;;
  status)
    mounted && echo "Home: ATLauncher" || echo "Home: LG Home"
    [ -f "$HOOKS/60-atlauncher" ] && echo "Boot hooks: on" || echo "Boot hooks: off"
    L luna://com.webos.service.config/getConfigs "{\"configNames\":[\"$KEYCFG\"]}" | grep -q handleATLauncherKey && echo "Remote keys: ATLauncher" || echo "Remote keys: LG"
    ;;
  early)
    # Boot hook 40: mount only, before SAM starts (SAM then reads ATLauncher's appinfo on its own). A request for the real
    # LG Home (Settings > System > Restart into LG Home) skips one boot.
    if [ -f "$DATA/lg-home-next-boot" ]; then rm -f "$DATA/lg-home-next-boot"; touch /tmp/atlauncher-lg-home; log "LG Home this boot (requested)"; exit 0; fi
    installed || { log "not installed: skipping"; exit 0; }
    mounted && exit 0
    build && mount --bind "$OV" "$T" && log "mounted early"
    ;;
  boot)
    # Boot hook 60 (as its own systemd unit): helpers, keys once configd answers, and Home in front.
    [ -f /tmp/atlauncher-lg-home ] && exit 0
    helpers
    i=0; while [ $i -lt 90 ]; do
      L luna://com.webos.service.config/getConfigs "{\"configNames\":[\"$KEYCFG\"]}" | grep -q handleScreenSaver && break
      i=$((i + 1)); sleep 2
    done
    keys_on; log "keys on"
    if mounted && ! sam_sees_atlauncher; then log "SAM has LG Home's appinfo: restarting SAM"; restart_sam_and_home; fi
    sleep 20; media_check
    sleep 100; media_check
    ;;
  *) echo "usage: atlauncher.sh enable|disable|status|relink" >&2; exit 2 ;;
esac
