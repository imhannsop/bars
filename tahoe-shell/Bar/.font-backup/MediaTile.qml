import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "."

// Now-playing tile. Pure view: ExpandedPanel feeds it from the MPRIS player.
Rectangle {
    id: card

    property string fontFamily: Theme.fontFamily
    property string fontAwesomeFont: Theme.fontAwesomeFont
    property int innerRadius: 14

    property bool hasPlayer: false
    property bool playing: false
    property string title: "Not Playing"
    property string artist: ""
    property url artUrl
    property real position: 0     // seconds
    property real length: 0       // seconds
    property bool canPrevious: false
    property bool canNext: false
    property bool canTogglePlaying: false
    property bool canSeek: false

    signal previousClicked()
    signal nextClicked()
    signal playPauseClicked()
    signal seekRequested(real ratio)

    readonly property real progress: length > 0 ? Math.min(1, Math.max(0, position / length)) : 0

    function formatTime(seconds) {
        var s = isFinite(seconds) && seconds > 0 ? seconds : 0
        var sec = Math.floor(s % 60)
        return Math.floor(s / 60) + ":" + (sec < 10 ? "0" : "") + sec
    }

    radius: 24
    color: "#202025"
    border.width: 1
    border.color: "#303038"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                id: artBg
                Layout.preferredWidth: 58
                Layout.preferredHeight: 58
                radius: card.innerRadius
                color: "#2b2b30"

                Text {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: "\uf001"
                    font.family: card.fontAwesomeFont
                    font.weight: Font.Black
                    font.pixelSize: 18
                    color: "#5a5a60"
                }

                Image {
                    id: art
                    anchors.fill: parent
                    source: card.artUrl
                    sourceSize: Qt.size(116, 116)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: art.width
                            height: art.height
                            radius: artBg.radius
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: card.title
                    font.family: card.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 14
                    color: "#ffffff"
                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: card.artist
                    font.family: card.fontFamily
                    font.weight: Font.Medium
                    font.pixelSize: 12
                    color: "#aaaaaa"
                    elide: Text.ElideRight
                }
            }
        }

        Item { Layout.fillHeight: true }

        // transport
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            Item {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                opacity: card.canPrevious ? 1 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: "\uf048"
                    font.family: card.fontAwesomeFont
                    font.weight: Font.Black
                    font.pixelSize: 13
                    color: prevMouse.containsMouse ? "#ffffff" : "#888888"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    enabled: card.canPrevious
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.previousClicked()
                }
            }

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: playMouse.containsMouse ? "#ffffff" : "#e6e6e6"
                opacity: card.canTogglePlaying ? 1 : 0.5
                scale: playMouse.pressed ? 0.94 : 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    // the play triangle looks left-heavy, nudge it to the optical centre
                    anchors.horizontalCenterOffset: card.playing ? 0 : 1
                    text: card.playing ? "\uf04c" : "\uf04b"
                    font.family: card.fontAwesomeFont
                    font.weight: Font.Black
                    font.pixelSize: 14
                    color: "#000000"
                }
                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    enabled: card.canTogglePlaying
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.playPauseClicked()
                }
            }

            Item {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                opacity: card.canNext ? 1 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: "\uf051"
                    font.family: card.fontAwesomeFont
                    font.weight: Font.Black
                    font.pixelSize: 13
                    color: nextMouse.containsMouse ? "#ffffff" : "#888888"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    enabled: card.canNext
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.nextClicked()
                }
            }
        }

        Item { Layout.fillHeight: true }

        // progress
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 14
                Layout.topMargin: 4
                Layout.leftMargin: 8
                Layout.rightMargin: 8

                Row {
                    anchors.fill: parent
                    spacing: 2

                    Repeater {
                        model: 24

                        Rectangle {
                            required property int index
                            width: (parent.width - 23 * parent.spacing) / 24
                            height: parent.height * (0.28 + ((index * 17 + 11) % 13) / 18)
                            radius: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: (index + 1) / 24 <= card.progress ? "#a8d2ff" : "#45454d"
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: card.canSeek && card.length > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => card.seekRequested(Math.min(1, Math.max(0, mouse.x / width)))
                }
            }
        }
    }
}
