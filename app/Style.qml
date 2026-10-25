pragma Singleton
import QtQuick 2.12

/* ATLauncher's typeface. Inter is bundled (SIL OFL). If you install Apple's SF Pro Display yourself (it is not bundled:
   Apple's license doesn't allow redistributing it), ATLauncher uses it instead: put SF-Pro-Display-Regular, -Medium,
   -Semibold and -Bold (.otf as Apple ships them, or .ttf) in /var/lib/atlauncher/fonts on the TV, or in app/userfonts for
   the desktop preview. Every Text uses Style.font, and with SF Pro the icons are its SF Symbols (Glyph.qml). */
QtObject {
    id: style
    readonly property string userFonts: Qt.platform.os === 'linux' ? 'file:///var/lib/atlauncher/fonts/' : Qt.resolvedUrl('userfonts/')
    // SF Pro is used only when its regular weight loaded (the others are optional).
    readonly property bool sfPro: sfRegularOtf.status === FontLoader.Ready || sfRegularTtf.status === FontLoader.Ready
    readonly property string font: sfPro ? (sfRegularOtf.status === FontLoader.Ready ? sfRegularOtf.name : sfRegularTtf.name) : inter.name

    /* SF Symbols, drawn from the SF Pro font you installed (its private-use characters), in place of the bundled Lucide
       icons. Codepoints of the symbols ATLauncher uses (SF Pro Display 21.x): */
    readonly property var symbols: ({
        'system': 0x10035F,      // gear
        'apps': 0x1001F7,        // square.grid.2x2
        'shelf': 0x1003B2,       // tv
        'menu-edit': 0x1003B2,   // tv
        'look': 0x100003,        // circle.lefthalf.filled
        'tv': 0x100306,          // slider.horizontal.3
        'move': 0x1009D0,        // arrow.up.and.down.and.arrow.left.and.right
        'restart': 0x100148,     // arrow.clockwise
        'info': 0x100174,        // info.circle
        'chevron-up': 0x100190,  // chevron.compact.up
        'menu-quit': 0x100050,   // xmark.circle
        'menu-delete': 0x10004E, // minus.circle
        'airplay': 0x100461,     // airplayvideo
        'user': 0x10026A         // person.fill
    })
    // The character for a symbol name, or '' (then the Lucide picture is used).
    function symbol(name) {
        var cp = sfPro ? symbols[name] : undefined;
        if (!cp) return '';
        cp -= 0x10000;   // UTF-16 surrogate pair
        return String.fromCharCode(0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF));
    }

    property list<QtObject> loaders: [
        FontLoader { id: inter; source: 'fonts/Inter-Regular.ttf' },
        FontLoader { source: 'fonts/Inter-Medium.ttf' },
        FontLoader { source: 'fonts/Inter-SemiBold.ttf' },
        FontLoader { source: 'fonts/Inter-Bold.ttf' },
        FontLoader { id: sfRegularOtf; source: style.userFonts + 'SF-Pro-Display-Regular.otf' },
        FontLoader { id: sfRegularTtf; source: style.userFonts + 'SF-Pro-Display-Regular.ttf' },
        FontLoader { source: style.userFonts + 'SF-Pro-Display-Medium.otf' },
        FontLoader { source: style.userFonts + 'SF-Pro-Display-Medium.ttf' },
        FontLoader { source: style.userFonts + 'SF-Pro-Display-Semibold.otf' },
        FontLoader { source: style.userFonts + 'SF-Pro-Display-Semibold.ttf' },
        FontLoader { source: style.userFonts + 'SF-Pro-Display-Bold.otf' },
        FontLoader { source: style.userFonts + 'SF-Pro-Display-Bold.ttf' }
    ]
}
