import QtQuick

Rectangle {
    id: root

    property bool hovered: false
    property bool active: false
    property int cornerRadius: 24
    property color activeColor: "#000000"
    property color activeHoveredColor: "#000000"
    property color activeBorderColor: "#777780"

    radius: cornerRadius
    color: "#000000"
    border.width: 1
    border.color: active ? activeBorderColor : hovered ? "#45454c" : "#242429"

    Behavior on color {
        ColorAnimation { duration: 160 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 160 }
    }
}
