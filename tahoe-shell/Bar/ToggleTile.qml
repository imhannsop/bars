import QtQuick

Rectangle {
    id: tile

    property string glyph
    property string label
    property string status
    property bool active: false
    property bool available: true
    property string fontFamily
    property string fontAwesomeFont

    signal clicked()

    readonly property color fg: "#ffffff"
    readonly property color dim: active ? "#d0d0d6" : "#8b8b94"

    radius: 24
    opacity: available ? 1 : 0.5
    scale: mouse.pressed ? 0.97 : 1
    color: active ? (mouse.containsMouse ? "#45454c" : "#38383f")
                  : (mouse.containsMouse ? "#2c2c31" : "#1e1e22")
    border.width: 1
    border.color: active ? "#777780" : "#2d2d34"

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

    Item {
        x: 16
        y: 16
        width: 38
        height: 38

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: tile.active ? "#55555c" : "#303037"
        }

        Text {
            anchors.centerIn: parent
            text: tile.glyph
            font.family: tile.fontAwesomeFont
            font.weight: Font.Black
            font.pixelSize: 16
            color: tile.active ? "#e0e0e0" : "#bbbbbb"

            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.bottomMargin: 16
        width: parent.width - 24
        spacing: 2

        Text {
            width: parent.width
            text: tile.label
            font.family: tile.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 13
            color: tile.fg
            elide: Text.ElideRight

            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            width: parent.width
            text: tile.status
            font.family: tile.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 11
            color: tile.dim
            elide: Text.ElideRight

            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: tile.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (tile.available) tile.clicked()
    }
}
