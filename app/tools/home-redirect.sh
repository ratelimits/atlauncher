#!/bin/sh
# Settings > System > Restart into LG Home: while ATLauncher is the Home app, its button launches ATLauncher's own app id,
# which nothing else launches then. Seeing that come to the front straight after Home means "give me the real LG
# Home": mark the next boot to skip the overlay and restart the TV (swapping LG Home back in while running can leave
# a black screen). The boot after that brings ATLauncher back. Started by atlauncher.sh (root).
# The button also stores the time it was pressed (settingsservice, category atlauncher, key lgHome), and only a launch
# within 20 s of a press counts: on some TVs (a C2 on webOS 26) the app id showed in front after Home on its own at
# boot, and the TV restarted.
ID=com.ratelimits.atlauncher
DATA=/var/lib/atlauncher
# LG's Home app id as found by atlauncher.sh enable (com.webos.app.fullhome on webOS 5).
HOME_ID=$(cat $DATA/home-id 2>/dev/null)
[ "$HOME_ID" = com.webos.app.fullhome ] || HOME_ID=com.webos.app.home
# GNU and newer BusyBox: timeout SECS CMD. BusyBox before 1.30 (webOS 5): timeout -t SECS CMD.
if timeout 1 true 2>/dev/null; then tmo() { timeout "$@"; }; else tmo() { _s=$1; shift; timeout -t "$_s" "$@"; }; fi

exec 9>/tmp/atlauncher-redirect.lock
flock -n 9 || exit 0

# Whether Settings > Restart into LG Home was just pressed: its time (ms) was stored by the button, is at most 20 s old
# and not handled before. Never in the first 2 minutes after boot: the clock may not be set yet, and a restart while
# Homebrew Channel's startup is still running puts the TV in its failsafe mode. A handled press is cleared and
# remembered across restarts (webOS can reopen the last app, ATLauncher's own id, at boot).
requested() {
  [ "$(cut -d. -f1 /proc/uptime)" -ge 120 ] || return 1
  at=$(tmo 10 luna-send -n 1 luna://com.webos.settingsservice/getSystemSettings \
    '{"app_id":"com.ratelimits.atlauncher","category":"atlauncher","keys":["lgHome"]}' 2>/dev/null |
    sed -n 's/.*"lgHome": *"\{0,1\}\([0-9]*\).*/\1/p')
  [ "${#at}" -ge 13 ] || return 1
  [ "$at" = "$(cat $DATA/redirect.done 2>/dev/null)" ] && return 1
  # Seconds, cut as text (no 13-digit arithmetic in the shell).
  age=$(($(date +%s) - ${at%???}))
  [ "$age" -ge -5 ] && [ "$age" -le 20 ] || return 1
  echo "$at" > $DATA/redirect.done
  tmo 10 luna-send -n 1 luna://com.webos.settingsservice/setSystemSettings \
    '{"app_id":"com.ratelimits.atlauncher","category":"atlauncher","settings":{"lgHome":"0"}}' >/dev/null 2>&1
}

PREV=/tmp/atlauncher-redirect.prev
: > $PREV
while :; do
  # Renewed every 30 s: a subscription made before SAM restarts goes silent without ending.
  tmo 30 luna-send -i luna://com.webos.applicationManager/getForegroundAppInfo '{"subscribe":true}' 2>/dev/null |
  while read -r line; do
    app=$(echo "$line" | sed -n 's/.*"appId": *"\([^"]*\)".*/\1/p')
    [ -n "$app" ] || continue
    previous=$(cat $PREV)
    [ "$app" = "$previous" ] && continue
    if findmnt "/usr/palm/applications/$HOME_ID" >/dev/null 2>&1 && [ "$app" = "$ID" ] && [ "$previous" = "$HOME_ID" ] && requested; then
      echo "$(date '+%F %T') LG Home requested: restarting" >> $DATA/boot.log
      touch $DATA/lg-home-next-boot
      sync
      sleep 2   # let the "Restarting into LG Home" message show
      tmo 15 luna-send -n 1 luna://com.webos.service.tvpower/power/reboot '{"reason":"reset"}' >/dev/null 2>&1 || reboot
    fi
    echo "$app" > $PREV
  done
  sleep 1
done
