pragma Singleton

import QtQuick
import Quickshell

QtObject {
    property FontLoader sfProBold: FontLoader {
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/SFPro/SF-Pro-Display-Bold.otf"
    }

    // Load every weight the UI asks for so Regular/Medium/Bold all come from the same
    // SF Pro Display family instead of falling back to a different face.
    property FontLoader sfProMedium: FontLoader {
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/SFPro/SF-Pro-Display-Medium.otf"
    }
    property FontLoader sfProRegular: FontLoader {
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/SFPro/SF-Pro-Display-Regular.otf"
    }

    readonly property string fontFamily: sfProBold.name
    readonly property string fontAwesomeFont: "Font Awesome 6 Free"

    readonly property var title: ({
        family: fontFamily,
        weight: Font.Bold,
        pixelSize: 16
    })
    readonly property var body: ({
        family: fontFamily,
        weight: Font.Bold,
        pixelSize: 14
    })
    readonly property var secondary: ({
        family: fontFamily,
        weight: Font.Medium,
        pixelSize: 12
    })
    readonly property var caption: ({
        family: fontFamily,
        weight: Font.Medium,
        pixelSize: 11
    })
}
