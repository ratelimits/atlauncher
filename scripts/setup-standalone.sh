#!/bin/sh
# Run as root on the TV after installing the IPK, when keeping LG Home as default.
# Copy the app-list and icon helpers without enabling the Home takeover.
set -eu
APP=/media/developer/apps/usr/palm/applications/com.ratelimits.atlauncher
DATA=/var/lib/atlauncher
HOOK=/var/lib/webosbrew/init.d/61-atlauncher-apps
mkdir -p "$DATA/custom/icons" "$DATA/custom/art" /var/lib/webosbrew/init.d
cp "$APP/tools/apps-watch.sh" "$DATA/apps-watch.sh"
cp "$APP/tools/storeicons.py" "$DATA/storeicons.py"
cat > "$HOOK" <<'EOF'
#!/bin/sh
systemd-run --unit=atlauncher-apps --no-block /bin/sh /var/lib/atlauncher/apps-watch.sh
EOF
chmod +x "$HOOK"
if ! systemctl is-active --quiet atlauncher-apps.service; then
    sh "$HOOK"
fi
