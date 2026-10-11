import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

PopupWindow {
    id: popup

    required property Item anchorItem          
    property var parentWindow: null             
    property var devices: []                    
    property var currentSink: null               
    property var labelForNode: (node) => ""      
    property string fontFamily: Theme.fontFamily
    property string fontAwesomeFont: Theme.fontAwesomeFont

    readonly property int rowHeight: 32
    readonly property int rowSpacing: 3
    // gap between the bar edge and the popup
    readonly property real edgeGap: 16
    readonly property real slideDistance: 28

    signal deviceChosen(var node)
    signal dismissed()

    // fixed anchor rect, slide is done via Translate below (see content)
    // anchored to root (whole bar), not the button -> rests bottom-right of bar
    anchor.item: anchorItem
    anchor.rect: Qt.rect(
        anchorItem ? anchorItem.width : 0,
        anchorItem ? anchorItem.height : 0,
        edgeGap,
        0)
    anchor.edges: Edges.Right | Edges.Bottom
    anchor.gravity: Edges.Right | Edges.Top

    implicitWidth: 260
    implicitHeight: 16 + devices.length * rowHeight
        + Math.max(0, devices.length - 1) * rowSpacing
    color: "transparent"
    visible: false

    grabFocus: true

    property real revealProgress: 0
    property bool closing: false

    // niri easing, same curve as FullScreenPanel.qml
    readonly property var niriCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property int slideDuration: 220

    function open() {
        closeTimer.stop()
        closing = false
        visible = true
        content.state = "shown"
    }

    function close() {
        if (!visible) return
        closing = true
        content.state = "hidden"
        closeTimer.restart()
    }

    Timer {
        id: closeTimer
        interval: popup.slideDuration
        onTriggered: {
            if (popup.closing) {
                popup.visible = false
                popup.closing = false
            }
        }
    }

    onVisibleChanged: {
        if (!popup.visible) {
            content.state = "hidden"
            if (!popup.closing) popup.dismissed()
        }
    }

    // states live here, not on popup - PopupWindow is a Window, not an Item
    Item {
        id: content
        anchors.fill: parent
        opacity: popup.revealProgress
        scale: 0.95 + (0.05 * popup.revealProgress)
        transformOrigin: Item.Left

        // slide left -> right on open
        transform: Translate {
            x: (1.0 - popup.revealProgress) * -popup.slideDistance
        }

        state: "hidden"
        states: [
            State { name: "hidden"; PropertyChanges { target: popup; revealProgress: 0.0 } },
            State { name: "shown"; PropertyChanges { target: popup; revealProgress: 1.0 } }
        ]
        transitions: [
            Transition {
                to: "shown"
                NumberAnimation {
                    target: popup; property: "revealProgress"
                    duration: popup.slideDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: popup.niriCurve
                }
            },
            Transition {
                to: "hidden"
                NumberAnimation {
                    target: popup; property: "revealProgress"
                    duration: popup.slideDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: popup.niriCurve
                }
            }
        ]

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
                            font.weight: deviceRow.isActive ? Font.Bold : Font.Medium
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
