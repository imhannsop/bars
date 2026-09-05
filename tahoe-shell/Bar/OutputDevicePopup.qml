import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: popup

    // ---- Pass-through state: parent -> popup -----------------------
    required property Item anchorItem          
    property var parentWindow: null             
    property var devices: []                    
    property var currentSink: null               
    property var labelForNode: (node) => ""      
    property string fontFamily: "SF Pro Display"
    property string fontAwesomeFont: "Font Awesome 6 Free"

    readonly property int rowHeight: 32
    readonly property int rowSpacing: 3
    readonly property real gap: 270

    // ---- Pass-through signal: popup -> parent -----------------------
    signal deviceChosen(var node)
    signal dismissed()

    anchor.item: anchorItem
    // Fixed geometry — the window itself never resizes during the
    // animation. Resizing a real (layer-shell) surface every frame is
    // what caused the previous stutter: each tick meant a synchronous
    // native resize plus a re-layout, which the compositor can't keep
    // at 60fps. Everything that "moves" now happens purely via opacity/
    // scale on the content Item below, which the compositor can animate
    // smoothly on the GPU without ever touching the window's geometry.
    anchor.rect: Qt.rect(
        anchorItem ? anchorItem.width : 0,
        96,
        gap,
        anchorItem ? anchorItem.height : 0)
    anchor.edges: Edges.Right
    anchor.gravity: Edges.Right

    implicitWidth: 260
    implicitHeight: 16 + devices.length * rowHeight
        + Math.max(0, devices.length - 1) * rowSpacing
    color: "transparent"
    visible: false

    grabFocus: true

    property real revealProgress: 0
    property bool closing: false

    // True iOS-style spring for the open (a physical spring settles far
    // more naturally than a hand-tuned OutBack easing curve — no fixed
    // duration, it just relaxes into place). A quick, non-bouncy ease-out
    // is used for the close, mirroring how UIKit dismisses popovers.
    SpringAnimation {
        id: openAnim
        target: popup
        property: "revealProgress"
        spring: 3.2
        damping: 0.42
        mass: 1.0
        epsilon: 0.0015
    }

    NumberAnimation {
        id: closeAnim
        target: popup
        property: "revealProgress"
        duration: 160
        easing.type: Easing.OutQuad
    }

    function open() {
        closeTimer.stop()
        closing = false
        visible = true
        closeAnim.stop()
        openAnim.to = 1.0
        openAnim.start()
    }

    function close() {
        if (!visible) return
        closing = true
        openAnim.stop()
        closeAnim.to = 0.0
        closeAnim.start()
        closeTimer.restart()
    }

    Timer {
        id: closeTimer
        interval: 160
        onTriggered: {
            if (popup.closing) {
                popup.visible = false
                popup.closing = false
            }
        }
    }

    onVisibleChanged: {
        if (!popup.visible) {
            popup.revealProgress = 0
            if (!popup.closing) popup.dismissed()
        }
    }

    // Main Container with Scale + Opacity for authentic iOS pop.
    // Opacity ramps faster than scale (matching UIKit popovers, which
    // are already ~90% opaque before the scale settles) so the reveal
    // reads as a solid shape growing into place rather than a fade.
    Item {
        anchors.fill: parent
        opacity: Math.min(1.0, popup.revealProgress * 1.6)
        scale: 0.88 + (0.12 * popup.revealProgress)
        transformOrigin: Item.Left

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: "#000000"
        }

        Column {
            x: 8
            y: 8
            width: Math.max(0, popup.implicitWidth - 16)
            spacing: popup.rowSpacing

            Repeater {
                model: popup.devices

                Rectangle {
                    id: deviceRow
                    required property var modelData
                    readonly property bool isActive: popup.currentSink
                        && modelData.id === popup.currentSink.id

                    width: parent.width
                    height: popup.rowHeight
                    radius: 8
                    color: isActive ? "#2a2a30" : (deviceMouseArea.containsMouse ? "#232327" : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: popup.labelForNode(deviceRow.modelData)
                            elide: Text.ElideRight
                            font.family: popup.fontFamily
                            font.pixelSize: 11
                            font.weight: deviceRow.isActive ? Font.Bold : Font.Normal
                            color: deviceRow.isActive ? "#ffffff" : "#8a8a90"
                        }

                        Text {
                            visible: deviceRow.isActive
                            text: "\uf00c"
                            font.family: popup.fontAwesomeFont
                            font.pixelSize: 10
                            color: "#d8d8d8"
                        }
                    }

                    MouseArea {
                        id: deviceMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.deviceChosen(deviceRow.modelData)
                    }
                }
            }
        }
    }
}