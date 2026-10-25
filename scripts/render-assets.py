#!/usr/bin/env python3
"""Render ATLauncher's bundled images with headless Chrome: Lucide icons (ISC, assets/lucide) recoloured to PNG glyphs,
the Settings tile, AirPlay's splash, and the app icon (other tiles use the apps' own icons from the TV or the App
Store). Usage: scripts/render-assets.py"""
import os, subprocess, tempfile, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP, LUCIDE = ROOT / 'app', ROOT / 'assets' / 'lucide'
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
FONT = (APP / 'fonts' / 'Inter-SemiBold.ttf').as_uri()
TMP = pathlib.Path(tempfile.mkdtemp())

def shot(html, w, h, out):
    page = TMP / 'p.html'
    page.write_text(html)
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                    '--default-background-color=00000000', f'--window-size={w},{h}', f'--screenshot={out}', page.as_uri()],
                   check=True, stderr=subprocess.DEVNULL)

def icon_svg(name, color, stroke=2):
    svg = (LUCIDE / f'{name}.svg').read_text()
    svg = svg.replace('currentColor', color)
    svg = re.sub(r'stroke-width="[^"]*"', f'stroke-width="{stroke}"', svg)
    svg = re.sub(r'\s(width|height)="[^"]*"', '', svg, count=2)
    return re.sub(r'<svg', '<svg style="width:100%;height:100%;display:block"', svg, count=1)

def glyph(name, out, size, color, frac=0.82, stroke=2):
    pad = size * (1 - frac) / 2
    shot(f'<html><body style="margin:0;background:transparent"><div style="position:absolute;left:{pad}px;top:{pad}px;'
         f'width:{size - 2 * pad}px;height:{size - 2 * pad}px">{icon_svg(name, color, stroke)}</div></body></html>', size, size, out)

def tile(out, bg, icon=None, label=None, icon_color='#ffffff', w=500, h=300):
    icon_html = f'<div style="width:{120 if label else 150}px;height:{120 if label else 150}px">{icon_svg(icon, icon_color, 1.75)}</div>' if icon else ''
    label_html = f'<div style="font:600 46px/1 L;color:#fff;margin-top:14px;letter-spacing:.01em">{label}</div>' if label else ''
    shot(f'<html><head><style>@font-face{{font-family:L;src:url({FONT})}}</style></head>'
         f'<body style="margin:0;width:{w}px;height:{h}px;background:{bg};display:flex;flex-direction:column;'
         f'align-items:center;justify-content:center">{icon_html}{label_html}</body></html>', w, h, out)

dark, red = '#2c2c30', '#ff453a'
# Settings pictures (shown 300 px on a light glass square) and the app menu.
for f, n in [('apps', 'layout-grid'), ('shelf', 'tv'), ('look', 'contrast'), ('tv', 'sliders-horizontal'),
             ('system', 'settings'), ('move', 'move'), ('restart', 'rotate-cw'), ('info', 'info')]:
    glyph(n, APP / 'glyphs' / f'{f}.png', 420, dark, 0.72, 1.6)
for f, n, c in [('menu-quit', 'circle-x', '#ffffff'), ('menu-quit-focus', 'circle-x', '#1c1c1e'),
                ('menu-edit', 'tv', '#ffffff'), ('menu-edit-focus', 'tv', '#1c1c1e'),
                ('menu-delete', 'circle-minus', red), ('menu-delete-focus', 'circle-minus', red)]:
    glyph(n, APP / 'glyphs' / f'{f}.png', 96, c, 0.86, 2)
glyph('chevron-up', APP / 'glyphs' / 'chevron-up.png', 92, '#ffffff', 0.9, 2.4)
glyph('user', APP / 'glyphs' / 'user.png', 64, '#ffffff', 0.7, 2)

# ATLauncher's own tiles.
tile(APP / 'icons' / 'atlauncher.settings.png', 'linear-gradient(160deg,#8e8e93 0%,#3a3a3e 100%)', 'settings')
# AirPlay's Top Shelf splash (LG's AirPlay page grey), from the same Lucide icon.
shot(f'<html><body style="margin:0;width:1920px;height:1080px;background:#252525;display:flex;align-items:center;justify-content:center">'
     f'<div style="width:300px;height:300px">{icon_svg("airplay", "#ffffff", 1.5)}</div></body></html>', 1920, 1080, APP / 'art' / 'airplay.png')

# App icon: a frosted Dock holding three tiles, on a deep blue-to-black ground (square, as webOS draws it).
def app_icon(out, size):
    s = size / 400
    shot(f'''<html><body style="margin:0;width:{size}px;height:{size}px;background:radial-gradient(circle at 30% 20%,#3b4a7a 0%,#141a33 55%,#05060c 100%);position:relative;overflow:hidden">
<div style="position:absolute;left:{40*s}px;top:{150*s}px;width:{320*s}px;height:{110*s}px;border-radius:{40*s}px;
 background:linear-gradient(180deg,rgba(255,255,255,.22),rgba(255,255,255,.08));box-shadow:inset {2*s}px {2*s}px 0 rgba(255,255,255,.45),0 {12*s}px {30*s}px rgba(0,0,0,.45)"></div>
{''.join(f'<div style="position:absolute;left:{(62 + i*98)*s}px;top:{170*s}px;width:{82*s}px;height:{70*s}px;border-radius:{16*s}px;background:{c}"></div>' for i, c in enumerate(['#f2f2f7','#6e8bff','#2f2f36']))}
</body></html>''', size, size, out)
app_icon(APP / 'icon-large.png', 130)
app_icon(APP / 'icon.png', 80)
app_icon(ROOT / 'docs' / 'app-icon-large.png', 400)
print('rendered into', APP)
