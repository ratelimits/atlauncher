# Changelog

## 1.0.0

First release. Still in testing: tested on one TV (LG UR8000, webOS 25), and there may be bugs; see the README's
Testing status.

- Native QML Home Screen for LG webOS 25: Liquid Glass Dock, app grid, rim-lit icons, tilt and press physics.
- Top Shelf: bundled splashes for popular apps, otherwise each app's own; popular shows from TMDB (your own API key)
  as a full-screen carousel or a "Top Shows" row, with a small TMDB credit.
- App icons: each app's Apple TV icon from the App Store, fetched by the TV (Settings > Appearance > App Store Icons);
  apps without one keep their own webOS icon (Settings > Appearance > Icon Size, Medium by default). The TV's own icons for its inputs,
  Internet, App Store and AirPlay.
- App menu (hold OK): Quit App, Edit Home Screen, Delete App with confirmation.
- Settings: per app (Home Screen shown/hidden, App Store icon on/off with a fresh download when turned back on, Quit,
  Delete), rearrange apps, Top Shelf, Dock and icon options, LG quick settings, Restart into LG Home.
- Optional initial next to the clock, chosen during setup (`atlauncher.sh initial`).
- Home takeover (`tools/atlauncher.sh enable|disable|status|relink`): overlay over LG Home, remote key mapping without
  the Magic Remote pointer popping up, boot hooks, and a fix for black video after an app-manager restart.
- Custom tile and splash art from `/var/lib/atlauncher/custom/`; one-time arrangement import from `import.json`.
- Inter and Lucide icons by default; SF Pro Display and its SF Symbols instead if you install SF Pro yourself in
  `/var/lib/atlauncher/fonts/` (not bundled).
- Recommended screensaver: picks for the Aerial Screensaver add-on (`atlauncher-aerial-picks.tar.gz`).

## Unreleased

- Fix: Liquid Glass (Dock, app menu, clock pill) did not draw on the LG C5 (webOS 25, 10.3.1). The glass shader's `mix` uniform shadowed GLSL's built-in `mix()`; it is now `fade`.
