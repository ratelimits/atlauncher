# ATLauncher

A native Home Screen for rooted LG webOS TVs, inspired by Apple TV.

ATLauncher is a QML app run by the TV's own Qt (no runtime to install), drawn on the GPU at a steady ~58 fps on a
budget webOS 25 set. It can take over the Home button, so it *is* the TV's Home screen.

- **Dock and app grid**: a Liquid Glass Dock whose rounded edge bends the picture behind it, a 6-column grid,
  rim-lit icons, and tilt-toward-the-move focus.
- **Top Shelf**: each app's own splash; rest on Netflix, Prime Video, Disney+, Hulu or Apple TV for 5 seconds
  and its popular shows appear from [TMDB](https://www.themoviedb.org) (full-screen carousel or a "Top Shows" row).
- **App menu**: hold OK on an app for Quit App (while it runs), Edit Home Screen and Delete App.
- **Settings**: per app, show or hide it, choose its App Store icon, quit or delete it; rearrange; Top Shelf and Dock
  options; LG's quick settings; and a way back to LG Home.
- **Remote**: Home returns to the app you were on (press again for the first app); the Settings and Input keys open
  ATLauncher's Settings and inputs row; Back works throughout.

No third-party artwork is bundled: tiles and splashes come from the apps installed on your TV, and you can add your
own (see [Custom art](#custom-art)).

## Compatibility

| TV | Model identifier | webOS | Takeover |
| -- | ---------------- | ----- | -------- |
| LG (2025 lineup, Realtek RTD2875N) | _to be filled in_ | 25 (10.3.1) | ✅ |

ATLauncher needs a **rooted** TV with [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel) (elevated)
and LG's `qml-runner` (present on webOS 25; other versions are untested). Reports for other models are welcome.

## Installation

### Homebrew Channel

Add this repository in Homebrew Channel's settings:

```text
https://github.com/ratelimits/atlauncher/releases/latest/download/repo.json
```

### SSH

On your computer, replace `TV_IP`:

```sh
scp -O com.ratelimits.atlauncher_1.0.0_all.ipk root@TV_IP:/tmp/atlauncher.ipk
ssh root@TV_IP
```

In the TV's root shell:

```sh
luna-send -i luna://com.webos.appInstallService/dev/install \
  '{"id":"com.ratelimits.atlauncher","ipkUrl":"/tmp/atlauncher.ipk","subscribe":true}'
```

Open **ATLauncher** from the app list to try it as a normal app.

## Replacing LG Home

> [!WARNING]
> This changes how your TV starts. It writes nothing to the system partition and can be undone, but disable it
> before uninstalling ATLauncher. Use at your own risk.

In the TV's root shell:

```sh
sh /media/developer/apps/usr/palm/applications/com.ratelimits.atlauncher/tools/atlauncher.sh enable
```

This mounts ATLauncher over LG Home's folder (LG's files stay untouched underneath), maps the Home, Settings and Input
keys to ATLauncher, and installs Homebrew Channel boot hooks that re-apply it at every boot. The app manager restarts
once, so open apps close.

```sh
sh /var/lib/atlauncher/atlauncher.sh status
sh /var/lib/atlauncher/atlauncher.sh disable     # LG Home back immediately
sh /var/lib/atlauncher/atlauncher.sh relink      # after installing an update
```

To use LG Home once without disabling anything: **Settings → System → Restart into LG Home**; the restart after that
brings ATLauncher back. Boot log: `/var/lib/atlauncher/boot.log`.

<details>
<summary>How it works</summary>

- `/var/lib/atlauncher/home-overlay` holds an `appinfo.json` that claims LG Home's id (`com.webos.app.home`, type `qml`)
  and symlinks to ATLauncher's files; it is bind-mounted over `/usr/palm/applications/com.webos.app.home` before the app
  manager (SAM) starts, so SAM launches ATLauncher as Home.
- The remote keys go through a surface-manager key filter (`homekey.js`) added to the runtime config
  `com.webos.surfacemanager.keyFilters`; the original list is saved and restored by `disable`.
- The window declares `_WEBOS_ACCESS_POLICY_KEYS_BACK`, so Back stays inside ATLauncher instead of offering to exit.
- If the app manager ever restarts after the media server, the media server loses track of which app is in front
  and every app's video stays black (sound plays). ATLauncher's boot step checks for this and restarts the media server.

</details>

## TMDB (popular shows)

Popular shows need your own free API key: create one at
[themoviedb.org/settings/api](https://www.themoviedb.org/settings/api), then:

```sh
echo YOUR_API_KEY | ssh root@TV_IP 'mkdir -p /var/lib/atlauncher && cat > /var/lib/atlauncher/tmdb.key'
```

Reopen ATLauncher. Without a key, each app's own splash is shown. You can also turn it off in **Settings → Top Shelf**.

This product uses the TMDB API but is not endorsed or certified by TMDB.

## App Store icons

With **Settings → Appearance → App Store Icons** on (the default), the TV looks each app up on Apple's App Store and
uses its Apple TV icon as the tile. They're downloaded once by the TV into `/var/lib/atlauncher/storeicons/` (none
are bundled); apps without an Apple TV version keep their own LG icon, scaled by **Icon Size** (Medium by default).
Each app's own page in **Settings → Apps** can turn its App Store icon off. Popular apps
use exact App Store ids; others are matched by name, accepting only a close match.

To fix a wrong match, or keep an app's LG icon, add it to `/var/lib/atlauncher/store-ids.json` (the App Store id is
the number in its `apps.apple.com` link):

```json
{ "io.strem.tv": null, "some.app.id": 123456789 }
```

## Custom art

Put your own pictures on the TV, named by app id:

| Folder | Size | Used for |
| ------ | ---- | -------- |
| `/var/lib/atlauncher/custom/icons/<app id>.png` | 500×300 | the app's tile |
| `/var/lib/atlauncher/custom/art/<app id>.png` (or `.jpg`) | 1920×1080 | the app's Top Shelf splash |

App ids are listed in `/var/lib/atlauncher/apps.json`. Changes appear within about five minutes, or after a restart.

## Recommended screensaver

ATLauncher pairs well with [Aerial Screensaver](https://repo.webosbrew.org/apps/org.aabytt.webos.custom-screensaver-aerial)
by aabytt ([source](https://github.com/aabytt/custom-screensaver-aerial)), which replaces LG's screensaver with
Apple TV-style aerial footage. Install it from Homebrew Channel, open it once and choose **Apply**.

ATLauncher's picks keep just 12 of its videos, played in 4K HEVC: San Francisco Evening; Sonoma Horizon, Evening,
Clouds and from Above; Sequoia Sunrise, Morning and Night; Tahoe Day, Morning, Evening and Night. They are in
`atlauncher-aerial-picks.tar.gz` with each release (and [extras/aerial](extras/aerial) here). On the TV:

```sh
cd /tmp && tar xzf atlauncher-aerial-picks.tar.gz && sh aerial/apply-picks.sh
sh /tmp/aerial/apply-picks.sh restore     # back to the add-on's full list
```

The add-on's own files are backed up to `/var/lib/atlauncher/aerial-backup` first. Updating the add-on resets its list;
run `apply-picks.sh` again afterwards. No video is included with ATLauncher: the add-on streams them.

## Using SF Pro (optional)

ATLauncher ships with [Inter](https://rsms.me/inter/). If you'd rather use Apple's SF Pro, download it yourself from
[developer.apple.com/fonts](https://developer.apple.com/fonts/) (it is not included: Apple's license doesn't allow
redistributing it, and limits it to Apple platforms, so check it covers your use). Copy these four files from the
installer to the TV, then reopen ATLauncher:

```sh
ssh root@TV_IP mkdir -p /var/lib/atlauncher/fonts
scp -O SF-Pro-Display-Regular.otf SF-Pro-Display-Medium.otf SF-Pro-Display-Semibold.otf \
  SF-Pro-Display-Bold.otf root@TV_IP:/var/lib/atlauncher/fonts/
```

ATLauncher uses SF Pro whenever the regular weight is there (`.otf` or `.ttf`), and Inter otherwise. With SF Pro, ATLauncher's icons
(Settings, the app menu, the chevron) are its SF Symbols too, drawn from the font you installed; with Inter they are
Lucide icons. Delete the folder
to go back. For the desktop preview, put the files in `app/userfonts/` (ignored by git and never packaged).

## Moving your arrangement

To bring an app order over from another launcher, put `/var/lib/atlauncher/import.json` on the TV, then reopen
ATLauncher. It is applied once per `id` (change the `id` to apply it again):

```json
{ "id": "my-layout-1", "order": ["netflix", "youtube.leanback.v4", "hulu"], "hidden": ["some.app.id"] }
```

## Development

The desktop preview needs Qt 5 (`brew install qt@5`):

```sh
QML_XHR_ALLOW_FILE_READ=1 /opt/homebrew/opt/qt@5/bin/qmlscene app/preview.qml
```

Arrows move, Return is OK (hold for the app menu), Esc is Back. For TMDB in the preview, put your key in
`app/tmdb.key` (ignored by git). Scripted runs: `--steps="keys:Right,Up wait:800 shot:/tmp/a.png"`.

Build a release (needs Node for LG's `ares-package`, fetched with `npx`):

```sh
scripts/build.sh            # dist/: IPK, sha256sums, repo.json, description.html, app-icon-large.png
scripts/render-assets.py    # re-render glyphs, built-in tiles and the app icon (needs Google Chrome)
```

ATLauncher targets the TV's Qt 5.12: no `required` properties, `?.` or `??`.

## Privacy

ATLauncher talks to the TV's own services; with your TMDB key, to `api.themoviedb.org` and `image.tmdb.org`; and with
App Store Icons on, to `itunes.apple.com`, `apps.apple.com` and Apple's image server (`*.mzstatic.com`) to fetch each
app's icon once. There is no telemetry. Settings, the TMDB cache and the icons stay on the TV.

## License

MIT, see [LICENSE](LICENSE). Bundled fonts and icons are under their own licenses, see [NOTICE.md](NOTICE.md).

ATLauncher is not affiliated with LG, Apple, TMDB or any app or brand shown in its UI. Apple TV is a trademark of
Apple Inc.; webOS is a trademark of LG Electronics.
