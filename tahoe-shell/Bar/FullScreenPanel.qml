import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    screen: Quickshell.screens[0]

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    property bool shown: false

    // Match Niri's easing for the overlay transition.
    readonly property var niriCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    property int slideDuration: 220

    Item {
        id: content
        anchors.fill: parent

        transform: Translate {
            id: slide
            y: root.shown ? 0 : root.height

            Behavior on y {
                NumberAnimation {
                    duration: root.slideDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.niriCurve
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#0d0d0d"
        }

        TopBar {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Component.onCompleted: shown = true
}
