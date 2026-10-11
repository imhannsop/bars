import QtQuick
import QtQuick.Layouts

// Notification tile for the expanded panel.
//
// Same language as the other tiles (radius 22, #1e1e22, no border, no shadow),
// with a tinted type chip per notification, relative timestamps, a hover-only
// dismiss button and a fade at the bottom edge when the list can scroll.
//
// Feed it a ListModel with the roles: title, message, type, accent, timestamp.
Rectangle {
    id: root

    property var model
    property string fontFamily
    property string fontAwesomeFont: "Font Awesome 6 Free"
    property bool autoDismiss: false
    property int lifetime: 8000

    signal dismissRequested(int index)
    signal clearRequested()
    signal activated(int index)

    readonly property int count: model ? model.count : 0

    readonly property color panelColor: "#1e1e22"
    readonly property color cellColor: "#1e1e22"   // same fill as every other tile
    readonly property color cellHover: "#26262b"
    readonly property color buttonColor: "#27272c"  // small buttons / empty-state badge
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#a4a4ad"
    readonly property color textMuted: "#707079"

    // ticks so the relative timestamps stay fresh while the panel is open
    property double now: Date.now()

    function ago(ts) {
        var t = ts instanceof Date ? ts.getTime() : new Date(ts).getTime()
        if (isNaN(t)) return ""
        var m = Math.floor((root.now - t) / 60000)
        if (m < 1) return "now"
        if (m < 60) return m + "m"
        var h = Math.floor(m / 60)
        if (h < 24) return h + "h"
        return Math.floor(h / 24) + "d"
    }

    function typeGlyph(type) {
        if (type === "error") return "\uf06a"
        if (type === "warning") return "\uf071"
        if (type === "success") return "\uf058"
        return "\uf05a"
    }

    radius: 24
    color: "#1e1e22"
    border.width: 1
    border.color: "#2d2d34"
    clip: true

    onCountChanged: if (count > 0) pop.restart()

    Timer {
        interval: 30000
        running: root.visible && root.count > 0
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // swallow clicks on the tile itself so they don't fall through and collapse the panel
    MouseArea { anchors.fill: parent }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.bottomMargin: 12
        spacing: 12

        // ---- header -------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.preferredHeight: 28
            spacing: 12

            Text {
                text: "Notifications"
                font.family: root.fontFamily
                font.weight: Font.Bold
                font.pixelSize: 13
                color: root.textPrimary
            }

            // count pill: inverted like an "on" toggle tile
            Rectangle {
                id: countPill
                visible: root.count > 0
                Layout.preferredHeight: 22
                Layout.preferredWidth: Math.max(22, countLabel.implicitWidth + 14)
                radius: 11
                color: "#414147"

                Text {
                    id: countLabel
                    anchors.centerIn: parent
                    text: root.count
                    font.family: root.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 11
                    font.features: { "tnum": 1 }
                    color: "#e0e0e0"
                }

                SequentialAnimation {
                    id: pop
                    NumberAnimation { target: countPill; property: "scale"; to: 1.18; duration: 90; easing.type: Easing.OutCubic }
                    NumberAnimation { target: countPill; property: "scale"; to: 1.0; duration: 180; easing.type: Easing.OutBack }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: clearButton
                visible: root.count > 0
                Layout.preferredHeight: 24
                Layout.preferredWidth: Math.ceil(clearLabel.implicitWidth) + 32
                Layout.minimumWidth: Math.ceil(clearLabel.implicitWidth) + 32
                radius: 12
                color: clearMouse.pressed ? "#3a3a42"
                     : clearMouse.containsMouse ? "#303037"
                     : root.buttonColor
                scale: clearMouse.pressed ? 0.96 : 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

                Text {
                    id: clearLabel
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    clip: false
                    text: "Clear"
                    font.family: root.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 11
                    color: clearMouse.containsMouse ? root.textPrimary : root.textSecondary
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearRequested()
                }
            }
        }

        // ---- body ---------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors.fill: parent
                anchors.bottomMargin: 6
                clip: true
                spacing: 12
                bottomMargin: 8
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                model: root.model

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                        NumberAnimation { property: "x"; from: 28; to: 0; duration: 240; easing.type: Easing.OutCubic }
                    }
                }
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: 140 }
                        NumberAnimation { property: "x"; to: -28; duration: 160; easing.type: Easing.InCubic }
                    }
                }
                displaced: Transition {
                    NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: row

                    required property int index
                    required property string title
                    required property string message
                    required property string type
                    required property color accent
                    required property var timestamp

                    readonly property bool hovered: cardMouse.containsMouse || closeMouse.containsMouse
                    property real life: 1

                    width: ListView.view.width
                    height: card.height

                    Rectangle {
                        id: card
                        x: 12
                        width: parent.width - 24
                        height: Math.max(56, body.implicitHeight + 20)
                        radius: 16
                        color: cardMouse.pressed ? "#2b2b30" : row.hovered ? root.cellHover : root.cellColor

                        Behavior on color { ColorAnimation { duration: 120 } }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activated(row.index)
                        }

                        // type chip: soft tint of the accent, glyph in the accent colour
                        Rectangle {
                            id: chip
                            x: 10
                            y: 10
                            width: 26
                            height: 26
                            radius: 13
                            color: Qt.rgba(row.accent.r, row.accent.g, row.accent.b, 0.16)

                            Text {
                                anchors.centerIn: parent
                                text: root.typeGlyph(row.type)
                                font.family: root.fontAwesomeFont
                                font.weight: Font.Black
                                font.pixelSize: 12
                                color: row.accent
                            }
                        }

                        ColumnLayout {
                            id: body
                            anchors.left: chip.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    text: row.title
                                    font.family: root.fontFamily
                                    font.weight: Font.Bold
                                    font.pixelSize: 12
                                    color: root.textPrimary
                                    elide: Text.ElideRight
                                }

                                // timestamp, swapped for a dismiss button on hover
                                Item {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 18

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.ago(row.timestamp)
                                        font.family: root.fontFamily
                                        font.weight: Font.Bold
                                        font.pixelSize: 10
                                        color: root.textMuted
                                        opacity: row.hovered ? 0 : 1
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                    }

                                    Rectangle {
                                        id: closeButton
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: closeMouse.pressed ? "#4a4a53"
                                             : closeMouse.containsMouse ? "#40404a"
                                             : "#34343b"
                                        opacity: row.hovered ? 1 : 0
                                        scale: row.hovered ? 1 : 0.7

                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf00d"
                                            font.family: root.fontAwesomeFont
                                            font.weight: Font.Black
                                            font.pixelSize: 9
                                            color: root.textPrimary
                                        }

                                        MouseArea {
                                            id: closeMouse
                                            anchors.fill: parent
                                            enabled: row.hovered
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.dismissRequested(row.index)
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: row.message
                                font.family: root.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: 11
                                color: root.textSecondary
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }

                        // optional auto-dismiss countdown (autoDismiss is off by default)
                        Rectangle {
                            visible: root.autoDismiss
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            width: (parent.width - 24) * row.life
                            height: 2
                            radius: 1
                            color: row.accent
                            opacity: 0.7
                        }
                    }

                    NumberAnimation on life {
                        running: root.autoDismiss
                        paused: row.hovered
                        from: 1
                        to: 0
                        duration: root.lifetime
                        onFinished: root.dismissRequested(row.index)
                    }
                }
            }

            // soft fade where the list continues below the tile edge
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.bottom: list.bottom
                height: 26
                opacity: list.atYEnd ? 0 : 1
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 150 } }

                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#001e1e22" }
                    GradientStop { position: 1.0; color: root.panelColor }
                }
            }

            // empty state
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                opacity: root.count === 0 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity { NumberAnimation { duration: 180 } }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: root.buttonColor

                    Text {
                        anchors.centerIn: parent
                        text: "\uf1f6"
                        font.family: root.fontAwesomeFont
                        font.weight: Font.Black
                        font.pixelSize: 14
                        color: root.textMuted
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "All caught up"
                    font.family: root.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 12
                    color: "#d4d4da"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No new notifications"
                    font.family: root.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 11
                    color: root.textMuted
                }
            }
        }
    }
}
