#!/bin/sh
# Settings > System > Restart into LG Home: while ATLauncher is the Home app, its button launches ATLauncher's own app id,
# which nothing else launches then. Seeing that come to the front straight after Home means "give me the real LG
# Home": mark the next boot to skip the overlay and restart the TV (swapping LG Home back in while running can leave
# a black screen). The boot after that brings ATLauncher back. Started by atlauncher.sh (root).
ID=com.ratelimits.atlauncher
DATA=/var/lib/atlauncher

exec 9>/tmp/atlauncher-redirect.lock
flock -n 9 || exit 0

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
    if findmnt /usr/palm/applications/com.webos.app.home >/dev/null 2>&1 && [ "$app" = "$ID" ] && [ "$previous" = com.webos.app.home ]; then
      touch $DATA/lg-home-next-boot
      sync
      sleep 2   # let the "Restarting into LG Home" message show
      timeout 15 luna-send -n 1 luna://com.webos.service.tvpower/power/reboot '{"reason":"reset"}' >/dev/null 2>&1 || reboot
    fi
    echo "$app" > $PREV
  done
  sleep 1
done
