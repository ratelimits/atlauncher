pragma Singleton
import QtQuick 2.12

/* ATLauncher's typeface. Inter is bundled (SIL OFL). If you install Apple's SF Pro Display yourself (it is not bundled:
   Apple's license doesn't allow redistributing it), ATLauncher uses it instead: put SF-Pro-Display-Regular, -Medium,
   -Semibold and -Bold (.otf as Apple ships them, or .ttf) in /var/lib/atlauncher/fonts on the TV, or in app/userfonts for
   the desktop preview. Every Text uses Style.font. */
QtObject {
    id: style
    readonly property string userFonts: Qt.platform.os === 'linux' ? 'file:///var/lib/atlauncher/fonts/' : Qt.resolvedUrl('userfonts/')
    // SF Pro is used only when its regular weight loaded (the others are optional).
    readonly property bool sfPro: sfRegularOtf.status === FontLoader.Ready || sfRegularTtf.status === FontLoader.Ready
    readonly property string font: sfPro ? (sfRegularOtf.status === FontLoader.Ready ? sfRegularOtf.name : sfRegularTtf.name) : inter.name

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
