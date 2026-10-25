# Changelog

## 1.0.0

First release.

- Native QML Home Screen for LG webOS 25: Liquid Glass Dock, app grid, rim-lit icons, tilt and press physics.
- Top Shelf: bundled splashes for popular apps, otherwise each app's own; popular shows from TMDB (your own API key)
  as a full-screen carousel or a "Top Shows" row, with TMDB attribution.
- App icons: each app's Apple TV icon from the App Store, fetched by the TV (Settings > Appearance > App Store Icons),
  else its own webOS icon scaled onto its tile (Settings > Appearance > Icon Size). The TV's own icons for its inputs,
  Internet, App Store and AirPlay.
- App menu (hold OK): Quit App, Edit Home Screen, Delete App with confirmation.
- Settings: show/hide and rearrange apps, Top Shelf and Dock options, LG quick settings, Restart into LG Home.
- Home takeover (`tools/atlauncher.sh enable|disable|status|relink`): overlay over LG Home, remote key mapping without
  the Magic Remote pointer popping up, boot hooks, and a fix for black video after an app-manager restart.
- Custom tile and splash art from `/var/lib/atlauncher/custom/`; one-time arrangement import from `import.json`.
- Inter by default; uses SF Pro Display instead if you install it yourself in `/var/lib/atlauncher/fonts/` (not bundled).
- Recommended screensaver: picks for the Aerial Screensaver add-on (`atlauncher-aerial-picks.tar.gz`).
