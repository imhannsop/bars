import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "."

Item {
    id: root

    property int gap: 12

    property bool wifiOn: false
    property bool bluetoothOn: false
    property bool hotspotOn: false
    property bool dndActive: false
    property bool darkMode: true
    property real brightness: 0.5
    property real volume: 0.5

    property bool mediaAvailable: false
    property bool mediaPlaying: false
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaArt: ""

    signal wifiClicked()
    signal bluetoothClicked()
    signal hotspotClicked()
    signal dndClicked()
    signal darkModeClicked()
    signal brightnessMoved(real value)
    signal volumeMoved(real value)
    signal mediaPrevious()
    signal mediaToggle()
    signal mediaNext()
    signal actionRequested(string name)

    // TopBar fades the whole panel in and out, so its own opacity is the open signal
    property bool open: root.opacity > 0.02

    // one reveal value per block so they settle one after another
    property real r0: open ? 1 : 0
    property real r1: open ? 1 : 0
    property real r2: open ? 1 : 0
    property real r3: open ? 1 : 0
    property real r4: open ? 1 : 0
    Behavior on r0 { Rise { delay: 0; opening: root.open } }
    Behavior on r1 { Rise { delay: 35; opening: root.open } }
    Behavior on r2 { Rise { delay: 70; opening: root.open } }
    Behavior on r3 { Rise { delay: 105; opening: root.open } }
    Behavior on r4 { Rise { delay: 140; opening: root.open } }

    readonly property int topHeight: 192
    readonly property real half: (width - gap) / 2
    readonly property real tileHeight: (topHeight - gap) / 2
    readonly property real small: (half - gap) / 2

    implicitWidth: 428
    implicitHeight: col.implicitHeight

    // inline components can't see root's ids, so they only touch Theme and their own props
    component Ease: NumberAnimation {
        duration: 220
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    }

    component Tint: ColorAnimation {
        duration: 220
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    }

    // overshoots a little then settles, so releases and entrances feel springy without a hard bounce
    component Pop: NumberAnimation {
        duration: 320
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.34, 1.35, 0.64, 1.0, 1.0, 1.0]
    }

    component Rise: SequentialAnimation {
        property int delay: 0
        property bool opening: false

        PauseAnimation { duration: opening ? delay : 0 }
        NumberAnimation {
            duration: opening ? 440 : 160
            easing.type: opening ? Easing.BezierSpline : Easing.OutCubic
            easing.bezierCurve: [0.34, 1.35, 0.64, 1.0, 1.0, 1.0]
        }
    }

    component Option: Item {
        id: opt

        property string glyph
        property string label
        property string status
        property bool active: false

        signal clicked()

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: mouse.containsMouse ? "#2a2a30" : "transparent"
            Behavior on color { Tint {} }
        }

        Rectangle {
            id: badge
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 20
            color: opt.active ? "#2f6db5" : "#303037"
            Behavior on color { Tint {} }

            Text {
                anchors.centerIn: parent
                text: opt.glyph
                font.family: Theme.fontAwesomeFont
                font.weight: Font.Black
                font.pixelSize: 16
                color: opt.active ? "#ffffff" : "#bbbbbb"
                Behavior on color { Tint {} }
            }
        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: opt.label
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: 14
                color: "#ffffff"
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: opt.status
                font.family: Theme.fontFamily
                font.weight: Font.Medium
                font.pixelSize: 12
                color: "#8b8b94"
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: opt.clicked()
        }
    }

    // layoutMode: "row" icon + text side by side, "stack" icon over label, "icon" glyph only
    component Tile: Rectangle {
        id: tile

        property string glyph
        property string label
        property string status
        property bool active: false
        property string layoutMode: "row"

        signal clicked()

        scale: mouse.pressed ? 0.97 : 1
        color: active ? (mouse.containsMouse ? "#29384b" : "#222f40")
                      : (mouse.containsMouse ? "#2c2c31" : "#1e1e22")
        border.width: 1
        border.color: active ? "#405a77" : "#2d2d34"

        Behavior on color { Tint {} }
        Behavior on scale { Pop {} }

        Rectangle {
            id: badge
            visible: tile.layoutMode !== "icon"
            width: 40
            height: 40
            radius: 20
            x: tile.layoutMode === "row" ? 16 : (tile.width - width) / 2
            y: tile.layoutMode === "row" ? (tile.height - height) / 2 : 14
            color: tile.active ? "#2f6db5" : "#303037"
            Behavior on color { Tint {} }
        }

        Text {
            anchors.centerIn: tile.layoutMode === "icon" ? tile : badge
            text: tile.glyph
            font.family: Theme.fontAwesomeFont
            font.weight: Font.Black
            font.pixelSize: tile.layoutMode === "icon" ? 20 : 16
            color: tile.active ? "#ffffff" : "#d0d0d6"
            Behavior on color { Tint {} }
        }

        Column {
            visible: tile.layoutMode === "row"
            anchors.left: badge.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: tile.label
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: 14
                color: "#ffffff"
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.status
                font.family: Theme.fontFamily
                font.weight: Font.Medium
                font.pixelSize: 12
                color: tile.active ? "#a4bddc" : "#8b8b94"
                elide: Text.ElideRight
            }
        }

        Text {
            visible: tile.layoutMode === "stack"
            anchors.horizontalCenter: parent.horizontalCenter
            y: 14 + 40 + 8
            width: parent.width - 12
            horizontalAlignment: Text.AlignHCenter
            text: tile.label
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 12
            color: "#ffffff"
            elide: Text.ElideRight
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    component MacSlider: Rectangle {
        id: slider

        property string title
        property string glyph
        property real value: 0
        property real wheelStep: 0.05
        // local value while dragging, the backend takes a moment to echo it back
        property real dragValue: 0
        readonly property real shown: area.pressed ? dragValue : Math.min(1, Math.max(0, value))
        readonly property int thumbSize: 28

        signal moved(real ratio)

        radius: 24
        color: "#1e1e22"
        border.width: 1
        border.color: "#2d2d34"

        Text {
            x: 16
            y: 10
            text: slider.title
            font.family: Theme.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 12
            color: "#ffffff"
        }

        Item {
            id: track
            x: 12
            width: parent.width - 24
            height: slider.thumbSize
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#2d2d34"
            }

            Rectangle {
                width: thumb.x + slider.thumbSize
                height: parent.height
                radius: height / 2
                color: "#d9dce3"
            }

            Rectangle {
                id: thumb
                width: slider.thumbSize
                height: slider.thumbSize
                radius: width / 2
                color: "#ffffff"
                scale: area.pressed ? 1.08 : 1
                x: (track.width - width) * slider.shown

                Behavior on scale { Pop {} }
                Behavior on x {
                    enabled: !area.pressed
                    Ease {}
                }

                Text {
                    anchors.centerIn: parent
                    text: slider.glyph
                    font.family: Theme.fontAwesomeFont
                    font.weight: Font.Black
                    font.pixelSize: 13
                    color: "#1b1b1f"
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton

                function drag(x) {
                    const r = slider.thumbSize / 2
                    slider.dragValue = Math.min(1, Math.max(0, (x - r) / (width - 2 * r)))
                    slider.moved(slider.dragValue)
                }

                onPressed: mouse => drag(mouse.x)
                onPositionChanged: mouse => { if (pressed) drag(mouse.x) }
                onWheel: wheel => slider.moved(Math.min(1, Math.max(0,
                    slider.shown + (wheel.angleDelta.y > 0 ? slider.wheelStep : -slider.wheelStep))))
            }
        }
    }

    component TransportButton: Item {
        id: btn

        property string glyph
        property int size: 15

        signal clicked()

        width: 36
        height: 40
        scale: tap.pressed ? 0.88 : 1

        Behavior on scale { Pop {} }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            font.family: Theme.fontAwesomeFont
            font.weight: Font.Black
            font.pixelSize: btn.size
            color: "#ffffff"
        }

        MouseArea {
            id: tap
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component NowPlaying: Rectangle {
        id: card

        property bool available: false
        property bool playing: false
        property string title
        property string artist
        property string art

        signal previous()
        signal toggle()
        signal next()

        radius: 24
        color: "#1e1e22"
        border.width: 1
        border.color: "#2d2d34"

        ClippingRectangle {
            id: cover
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            height: 52
            radius: 12
            color: "#303037"

            Image {
                anchors.fill: parent
                visible: card.art !== ""
                source: card.art
                sourceSize: Qt.size(104, 104)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Text {
                anchors.centerIn: parent
                visible: card.art === ""
                text: "\uf025"
                font.family: Theme.fontAwesomeFont
                font.weight: Font.Black
                font.pixelSize: 18
                color: "#8b8b94"
            }
        }

        Column {
            anchors.left: cover.right
            anchors.leftMargin: 12
            anchors.right: controls.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: card.available && card.title !== "" ? card.title : "Not Playing"
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                font.pixelSize: 14
                color: "#ffffff"
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: card.available ? card.artist : ""
                font.family: Theme.fontFamily
                font.weight: Font.Medium
                font.pixelSize: 12
                color: "#8b8b94"
                elide: Text.ElideRight
            }
        }

        Row {
            id: controls
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            enabled: card.available
            opacity: card.available ? 1 : 0.4

            TransportButton { glyph: "\uf048"; onClicked: card.previous() }
            TransportButton { glyph: card.playing ? "\uf04c" : "\uf04b"; size: 19; onClicked: card.toggle() }
            TransportButton { glyph: "\uf051"; onClicked: card.next() }
        }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: root.gap

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.topHeight
            opacity: root.r0
            scale: 0.92 + 0.08 * root.r0

            Rectangle {
                width: root.half
                height: parent.height
                radius: 28
                color: "#1e1e22"
                border.width: 1
                border.color: "#2d2d34"

                Column {
                    x: 8
                    y: 8
                    width: parent.width - 16
                    spacing: 4

                    Option {
                        width: parent.width
                        height: 56
                        glyph: "\uf1eb"
                        label: "Wi-Fi"
                        status: root.wifiOn ? "On" : "Off"
                        active: root.wifiOn
                        onClicked: root.wifiClicked()
                    }

                    Option {
                        width: parent.width
                        height: 56
                        glyph: "\uf293"
                        label: "Bluetooth"
                        status: root.bluetoothOn ? "On" : "Off"
                        active: root.bluetoothOn
                        onClicked: root.bluetoothClicked()
                    }

                    Option {
                        width: parent.width
                        height: 56
                        glyph: "\uf012"
                        label: "Hotspot"
                        status: root.hotspotOn ? "On" : "Off"
                        active: root.hotspotOn
                        onClicked: root.hotspotClicked()
                    }
                }
            }

            Tile {
                x: root.half + root.gap
                width: root.half
                height: root.tileHeight
                radius: 28
                glyph: "\uf186"
                label: "Focus"
                status: root.dndActive ? "On" : "Off"
                active: root.dndActive
                onClicked: root.dndClicked()
            }

            Tile {
                x: root.half + root.gap
                y: root.tileHeight + root.gap
                width: root.small
                height: root.tileHeight
                radius: 24
                layoutMode: "stack"
                glyph: "\uf042"
                label: "Dark Mode"
                active: root.darkMode
                onClicked: root.darkModeClicked()
            }

            Tile {
                x: root.half + root.gap + root.small + root.gap
                y: root.tileHeight + root.gap
                width: root.small
                height: root.tileHeight
                radius: 24
                layoutMode: "stack"
                glyph: "\uf2d2"
                label: "Overview"
                onClicked: root.actionRequested("overview")
            }
        }

        MacSlider {
            Layout.fillWidth: true
            Layout.preferredHeight: 74
            title: "Display"
            opacity: root.r1
            scale: 0.92 + 0.08 * root.r1
            glyph: "\uf185"
            value: root.brightness
            onMoved: ratio => root.brightnessMoved(ratio)
        }

        MacSlider {
            Layout.fillWidth: true
            Layout.preferredHeight: 74
            title: "Sound"
            opacity: root.r2
            scale: 0.92 + 0.08 * root.r2
            glyph: root.volume <= 0.001 ? "\uf026" : root.volume < 0.5 ? "\uf027" : "\uf028"
            value: root.volume
            onMoved: ratio => root.volumeMoved(ratio)
        }

        NowPlaying {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            opacity: root.r3
            scale: 0.92 + 0.08 * root.r3
            available: root.mediaAvailable
            playing: root.mediaPlaying
            title: root.mediaTitle
            artist: root.mediaArtist
            art: root.mediaArt
            onPrevious: root.mediaPrevious()
            onToggle: root.mediaToggle()
            onNext: root.mediaNext()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.gap
            uniformCellSizes: true
            opacity: root.r4
            scale: 0.92 + 0.08 * root.r4

            Tile {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 28
                layoutMode: "icon"
                glyph: "\uf009"
                onClicked: root.actionRequested("launcher")
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 28
                layoutMode: "icon"
                glyph: "\uf1ec"
                onClicked: root.actionRequested("calculator")
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 28
                layoutMode: "icon"
                glyph: "\uf2f2"
                onClicked: root.actionRequested("timer")
            }

            Tile {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 28
                layoutMode: "icon"
                glyph: "\uf030"
                onClicked: root.actionRequested("screenshot")
            }
        }
    }
}
