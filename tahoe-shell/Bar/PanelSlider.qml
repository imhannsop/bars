import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: card

    property real value: 0
    property string glyph
    property bool dim: false
    property bool glyphClickable: false
    property real wheelStep: 0.05
    property int trailingWidth: 0
    property int leftPadding: 16
    property int rightPadding: 16
    property string fontFamily: Theme.fontFamily
    property string fontAwesomeFont: Theme.fontAwesomeFont

    default property alias trailing: trailingSlot.data

    signal moved(real ratio)
    signal glyphClicked()

    readonly property real clamped: Math.min(1, Math.max(0, value))
    // local value while dragging, the backend takes a moment to echo it back
    property real dragValue: 0
    readonly property real shown: area.pressed ? dragValue : clamped
    readonly property bool dragging: area.pressed

    radius: 24
    color: "#1e1e22"
    border.width: 1
    border.color: "#2d2d34"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: card.leftPadding
        anchors.rightMargin: card.rightPadding
        spacing: 16

        Item {
            Layout.preferredWidth: 26
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                text: card.glyph
                font.family: card.fontAwesomeFont
                font.weight: Font.Black
                font.pixelSize: 19
                color: card.dim ? "#55555a" : "#ffffff"

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            MouseArea {
                anchors.fill: parent
                enabled: card.glyphClickable
                cursorShape: card.glyphClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: card.glyphClicked()
            }
        }

        Item {
            id: track
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 5
                radius: 2.5
                color: "#3a3a40"

                Rectangle {
                    width: thumb.x + thumb.width / 2
                    height: parent.height
                    radius: parent.radius
                    color: card.dim ? "#8a8a90" : "#ffffff"
                }
            }

            Rectangle {
                id: thumb
                width: 22
                height: 22
                radius: 11
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                scale: area.pressed ? 1.15 : 1
                x: Math.max(0, Math.min(track.width - width, track.width * card.shown - width / 2))

                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                Behavior on x {
                    enabled: !area.pressed
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton

                function drag(x) {
                    card.dragValue = Math.min(1, Math.max(0, x / width))
                    card.moved(card.dragValue)
                }

                onPressed: mouse => drag(mouse.x)
                onPositionChanged: mouse => { if (pressed) drag(mouse.x) }
                onWheel: wheel => card.moved(Math.min(1, Math.max(0,
                    card.clamped + (wheel.angleDelta.y > 0 ? card.wheelStep : -card.wheelStep))))
            }
        }

        Text {
            Layout.preferredWidth: 42
            horizontalAlignment: Text.AlignRight
            text: Math.round(card.shown * 100) + "%"
            font.family: card.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 13
            font.features: { "tnum": 1 }
            color: card.dim ? "#55555a" : "#aaaaaa"
        }

        Item {
            id: trailingSlot
            visible: card.trailingWidth > 0
            Layout.preferredWidth: card.trailingWidth
            Layout.fillHeight: true
        }
    }
}
