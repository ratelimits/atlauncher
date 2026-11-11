# Changelog

## 1.0.4

- Fix: on some TVs (an LG C2 on webOS 26) the TV restarted into LG Home on its own shortly after ATLauncher took
  over at startup. Settings → System → Restart into LG Home now records the press, and only that restarts the TV.
- Fix: the app list helper and the Restart into LG Home helper stopped about two minutes after each boot (systemd
  ended them with the boot hook's unit), so new apps, App Store icon downloads and Restart into LG Home only worked
  again after a relink. Each now runs as its own unit.
- Startup: where LG Home was already loaded when the boot hooks ran (late hooks, or a cold start with Quick Start+
  off), the TV's app manager now rereads Home instead of being restarted, which left the picture black for a while;
  the restart is only a fallback. LG Home on screen at that point is closed straight away. With ATLauncher
  uninstalled, its boot hooks no longer change anything (the remote keys stayed with it).
- Streaming Region: about 40 countries, India among them, and the TV's 3-letter country codes are understood.
  Suggestion Language: more languages (Hindi, English (India), Japanese, Korean, Portuguese (Brazil) and others).
- Top Shelf shows for JioHotstar, ZEE5 and SonyLIV, and Prime Video's shows outside the US.
- App Store Icons: apps are looked up in the TV's country's App Store first, then the US one; every icon is
  fetched again once.

## 1.0.3

- Top Shelf: each show's TMDB logo appears with its picture instead of its name in large type first, and flipping
  quickly through the carousel no longer cuts dissolves short or lags (logos and neighbouring backdrops load ahead).
- Settings → Apps → Edit Apps: pick up, move and place several apps in a row (#7, thanks @gamma).
- Settings → Top Shelf: streaming region and suggestion language, automatic from the TV or chosen by hand; Settings →
  Appearance: 12/24-hour clock and a switch for the avatar (#8, thanks @gamma).
- Failed webOS calls are reported instead of silently doing nothing (#6), and `scripts/setup-qml-permissions.py`
  repairs a missing QML app registration on some developer installs (#9, thanks @gamma).
- `scripts/setup-standalone.sh` starts the app list and icon helpers without replacing LG Home (#10, thanks @gamma).
- Loads on Qt 5.9 (webOS 5) as well (#5, thanks @calozpom).
- The LG B4 (webOS 25, 10.3.2) is on the compatibility list (#12).

## 1.0.1

- Fix: Liquid Glass (the Dock, app menu and clock pill) did not draw on the LG C5 (webOS 25, 10.3.1): the glass
  shader's `mix` uniform shadowed GLSL's built-in `mix()`, and it is now `fade` (#3, thanks @n4bcb).
- The LG C5 (`OLEDC5??AUA`, webOS 25) is on the compatibility list.

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
