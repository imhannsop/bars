import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: window
    required property var modelData
    property bool opened: false
    property bool barExpanded: false
    property real barHitWidth: 0
    property real barHitHeight: 0
    property real notchCenterY: 0
    signal requestClose()
    signal requestToggle()
    signal requestBarClose()

    screen: modelData
    visible: opened || barExpanded || launcherContent.opacity > 0
    color: "transparent"
    exclusiveZone: 0
    mask: Region {
        Region {
            item: (window.opened || window.barExpanded) ? backdrop : launcherContent
        }
        Region {
            x: (window.width - window.barHitWidth) / 2
            y: 0
            width: window.barExpanded && !window.opened ? window.barHitWidth : 0
            height: window.barExpanded && !window.opened ? window.barHitHeight : 0
            intersection: Intersection.Subtract
        }
    }

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-app-search"

    Item {
        id: backdrop
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (window.opened) window.requestClose()
                else if (window.barExpanded) window.requestBarClose()
            }
        }
    }

    Item {
        id: launcherContent
        width: search.width
        height: search.height
        x: (parent.width - width) / 2
        y: window.notchCenterY - search.barHeight / 2
        opacity: window.opened ? 1 : 0
        scale: window.opened ? 1 : 0.86
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation {
                duration: window.opened ? 250 : 170
                easing.type: window.opened ? Easing.OutCubic : Easing.InCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: window.opened ? 420 : 220
                easing.type: window.opened ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.12
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        AppSearch {
            id: search
            width: window.barHitWidth
            fontAwesomeFont: Theme.fontAwesomeFont
            onRequestClose: window.requestClose()
            onRequestToggle: window.requestToggle()
        }
    }

    onOpenedChanged: {
        if (opened) Qt.callLater(() => search.focusSearch())
    }

    onVisibleChanged: {
        if (!visible) search.reset()
    }
}
