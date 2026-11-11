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

exec 9>/tmp/atlauncher-redirect.lock
flock -n 9 || exit 0

# Whether Settings > Restart into LG Home was pressed in the last 20 s (its time, in ms, is newer than any handled).
requested() {
  at=$(timeout 10 luna-send -n 1 luna://com.webos.settingsservice/getSystemSettings \
    '{"app_id":"com.ratelimits.atlauncher","category":"atlauncher","keys":["lgHome"]}' 2>/dev/null |
    sed -n 's/.*"lgHome": *"\{0,1\}\([0-9]*\).*/\1/p')
  [ -n "$at" ] || return 1
  [ "$at" = "$(cat /tmp/atlauncher-redirect.done 2>/dev/null)" ] && return 1
  # Seconds, cut as text (no 13-digit arithmetic in the shell).
  age=$(($(date +%s) - ${at%???}))
  [ "$age" -ge -5 ] && [ "$age" -le 20 ] || return 1
  echo "$at" > /tmp/atlauncher-redirect.done
}

PREV=/tmp/atlauncher-redirect.prev
: > $PREV
while :; do
  # Renewed every 30 s: a subscription made before SAM restarts goes silent without ending.
  timeout 30 luna-send -i luna://com.webos.applicationManager/getForegroundAppInfo '{"subscribe":true}' 2>/dev/null |
  while read -r line; do
    app=$(echo "$line" | sed -n 's/.*"appId": *"\([^"]*\)".*/\1/p')
    [ -n "$app" ] || continue
    previous=$(cat $PREV)
    [ "$app" = "$previous" ] && continue
    if findmnt /usr/palm/applications/com.webos.app.home >/dev/null 2>&1 && [ "$app" = "$ID" ] && [ "$previous" = com.webos.app.home ] && requested; then
      echo "$(date '+%F %T') LG Home requested: restarting" >> $DATA/boot.log
      touch $DATA/lg-home-next-boot
      sync
      sleep 2   # let the "Restarting into LG Home" message show
      timeout 15 luna-send -n 1 luna://com.webos.service.tvpower/power/reboot '{"reason":"reset"}' >/dev/null 2>&1 || reboot
    fi
    echo "$app" > $PREV
  done
  sleep 1
done
