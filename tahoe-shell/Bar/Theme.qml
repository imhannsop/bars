pragma Singleton

import QtQuick
import Quickshell

QtObject {
    readonly property string fontFamily: "Hurmit Nerd Font"
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
        weight: Font.Bold,
        pixelSize: 12
    })
    readonly property var caption: ({
        family: fontFamily,
        weight: Font.Bold,
        pixelSize: 11
    })
}
