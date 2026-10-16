import QtQuick
import QtQuick.Effects
import "."

Item {
    id: root

    property real gap: 4
    property int tileSize: 26
    property real circleScale: 0.68

    property int iconSize: Math.round(cell * 0.30)
    property int titleSize: Math.round(cell * 0.14)
    property int subtitleSize: Math.round(cell * 0.23)
    property int focusStatusSize: Math.round(cell * 0.17)

    property bool airplaneOn: false
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

    signal airplaneClicked()
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

    property bool open: root.opacity > 0.02

    property real r0: open ? 1 : 0
    property real r1: open ? 1 : 0
    property real r2: open ? 1 : 0
    property real r3: open ? 1 : 0
    Behavior on r0 { Rise { delay: 0; opening: root.open } }
    Behavior on r1 { Rise { delay: 40; opening: root.open } }
    Behavior on r2 { Rise { delay: 80; opening: root.open } }
    Behavior on r3 { Rise { delay: 120; opening: root.open } }

    readonly property real cell: ((width > 0 ? width : tileSize * 4 + gap * 3) - 3 * gap) / 4
    readonly property real step: cell + gap
    readonly property real wide: cell * 2 + gap

    readonly property real corner: Math.round(cell * 0.30)
    readonly property real pad: Math.max(3, Math.round(cell * 0.16))
    readonly property real knob: Math.round(cell * 0.64)

    implicitWidth: tileSize * 4 + gap * 3
    implicitHeight: cell * 4 + gap * 3

    QtObject {
        id: pal
        readonly property color card: "#1c1c1e"
        readonly property color hover: "#2a2a2e"
        readonly property color fill: "#e6e6ea"
        readonly property color ink: "#17171a"
        readonly property color muted: "#8b8b94"
        readonly property color accent: "#0a84ff"
    }

    component Ease: NumberAnimation {
        duration: 220
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    }

    component Tint: ColorAnimation {
        duration: 160
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    }

    component Pop: NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
    }

    component Rise: SequentialAnimation {
        property int delay: 0
        property bool opening: false

        PauseAnimation { duration: opening ? delay : 0 }
        NumberAnimation {
            duration: opening ? 220 : 150
            easing.type: Easing.OutCubic
        }
    }

    component Bump: SequentialAnimation {
        property Item item

        NumberAnimation {
            target: item
            property: "scale"
            to: 0.8
            duration: 70
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: item
            property: "scale"
            to: 1
            duration: 300
            easing.type: Easing.OutBack
            easing.overshoot: 2.2
        }
    }

    component Cell: Item {
        property real reveal: 1

        opacity: reveal
        scale: 0.92 + 0.08 * reveal
    }

    component Disc: Rectangle {
        id: disc

        property var colors
        property string glyph
        property int iconSize: 11
        property bool active: false
        property bool interactive: true
        property bool hovered: discArea.containsMouse
        readonly property color iconColor: active ? "#ffffff" : colors.fill

        signal clicked()

        radius: width / 2
        scale: discArea.pressed ? 0.92 : 1
        color: Qt.rgba(1, 1, 1, hovered ? 0.18 : 0.12)

        Behavior on color { Tint {} }
        Behavior on scale { Pop {} }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: disc.hovered ? Qt.lighter(disc.colors.accent, 1.1) : disc.colors.accent
            opacity: disc.active ? 1 : 0
            scale: disc.active ? 1 : 0.6

            Behavior on opacity { Ease {} }
            Behavior on scale { Ease {} }
            Behavior on color { Tint {} }
        }

        Text {
            id: discIcon
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: disc.glyph
            font.family: Theme.fontAwesomeFont
            font.weight: Font.Black
            font.italic: false
            font.pixelSize: disc.iconSize
            color: disc.iconColor
            Behavior on color { Tint {} }
        }

        Bump { id: discBump; item: discIcon }
        onActiveChanged: discBump.restart()

        MouseArea {
            id: discArea
            anchors.fill: parent
            enabled: disc.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: disc.clicked()
        }
    }

    component IconTile: Rectangle {
        id: iconTile

        property var colors
        property string glyph
        property int iconSize: 11
        property bool active: false
        property color activeIcon: colors.accent
        property real corner: 8

        signal clicked()

        radius: corner
        scale: tileArea.pressed ? 0.94 : 1
        color: tileArea.containsMouse ? colors.hover : colors.card

        Behavior on color { Tint {} }
        Behavior on scale { Pop {} }

        Rectangle {
            anchors.fill: parent
            radius: iconTile.radius
            color: iconTile.colors.fill
            opacity: iconTile.active ? 1 : 0
            scale: iconTile.active ? 1 : 0.85

            Behavior on opacity { Ease {} }
            Behavior on scale { Ease {} }
        }

        Text {
            id: tileIcon
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: iconTile.glyph
            font.family: Theme.fontAwesomeFont
            font.weight: Font.Black
            font.italic: false
            font.pixelSize: iconTile.iconSize
            color: iconTile.active ? iconTile.activeIcon : iconTile.colors.fill
            Behavior on color { Tint {} }
        }

        Bump { id: tileBump; item: tileIcon }
        onActiveChanged: tileBump.restart()

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconTile.clicked()
        }
    }

    component FocusTile: Rectangle {
        id: focusTile

        property var colors
        property bool active: false
        property string label
        property string status
        property real badge: 16
        property int iconSize: 11
        property int titleSize: 8
        property int subtitleSize: 6
        property real pad: 4
        property real corner: 8

        signal clicked()

        radius: corner
        scale: focusHit.pressed ? 0.96 : 1
        color: focusHit.containsMouse ? colors.hover : colors.card

        Behavior on color { Tint {} }
        Behavior on scale { Pop {} }

        Disc {
            id: focusBadge
            x: (focusTile.height - focusTile.badge) / 2
            y: x
            width: focusTile.badge
            height: width
            colors: focusTile.colors
            glyph: "\uf186"
            iconSize: focusTile.iconSize
            active: focusTile.active
            interactive: false
            hovered: focusHit.containsMouse
        }

        Column {
            anchors.left: focusBadge.right
            anchors.leftMargin: focusTile.pad
            anchors.right: parent.right
            anchors.rightMargin: focusTile.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: focusTile.label
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
                font.italic: false
                font.pixelSize: focusTile.titleSize
                color: "#ffffff"
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: focusTile.status
                font.family: Theme.fontFamily
                font.weight: Font.Normal
                font.italic: false
                font.pixelSize: focusTile.subtitleSize
                color: focusTile.active ? focusTile.colors.accent : focusTile.colors.muted
                elide: Text.ElideRight
                Behavior on color { Tint {} }
            }
        }

        MouseArea {
            id: focusHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: focusTile.clicked()
        }
    }

    component VSlider: Rectangle {
        id: slider

        property var colors
        property string glyph
        property int iconSize: 11
        property int labelSize: 6
        property real corner: 8
        property real value: 0
        property real wheelStep: 0.05
        property real dragValue: 0
        property real minimumFillHeight: 8
        readonly property real shown: sliderArea.pressed ? dragValue : Math.min(1, Math.max(0, value))
        readonly property real fillHeight: shown <= 0 ? 0
            : Math.min(height, Math.max(minimumFillHeight, height * shown))
        readonly property bool covered: sliderFill.fillAmount > width * 0.5

        signal moved(real ratio)

        radius: corner
        clip: true
        scale: sliderArea.pressed ? 0.98 : 1
        color: sliderArea.containsMouse ? colors.hover : colors.card

        Behavior on color { Tint {} }
        Behavior on scale { Pop {} }

        Canvas {
            id: sliderFill
            anchors.fill: parent
            antialiasing: true
            property real fillAmount: slider.fillHeight

            onFillAmountChanged: requestPaint()
            Component.onCompleted: requestPaint()

            Behavior on fillAmount {
                enabled: !sliderArea.pressed
                Ease {}
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var radius = Math.min(slider.corner, width / 2, height / 2)
                ctx.beginPath()
                ctx.moveTo(radius, 0)
                ctx.lineTo(width - radius, 0)
                ctx.quadraticCurveTo(width, 0, width, radius)
                ctx.lineTo(width, height - radius)
                ctx.quadraticCurveTo(width, height, width - radius, height)
                ctx.lineTo(radius, height)
                ctx.quadraticCurveTo(0, height, 0, height - radius)
                ctx.lineTo(0, radius)
                ctx.quadraticCurveTo(0, 0, radius, 0)
                ctx.closePath()
                ctx.clip()

                ctx.fillStyle = slider.colors.fill
                ctx.fillRect(0, height - fillAmount, width, fillAmount)
            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: sliderFill.y + Math.round(slider.width * 0.18)
            text: Math.round(slider.shown * 100) + "%"
            font.family: Theme.fontFamily
            font.weight: Font.DemiBold
            font.italic: false
            font.pixelSize: slider.labelSize
            color: slider.colors.ink
            opacity: sliderArea.pressed && sliderFill.height > slider.width * 1.7 ? 0.8 : 0
            Behavior on opacity { Ease {} }
        }

        Text {
            x: 0
            y: slider.height - slider.width
            width: slider.width
            height: slider.width
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: slider.glyph
            font.family: Theme.fontAwesomeFont
            font.weight: Font.Black
            font.italic: false
            font.pixelSize: slider.iconSize
            color: slider.covered ? slider.colors.ink : slider.colors.muted
            Behavior on color { Tint {} }
        }

        MouseArea {
            id: sliderArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton

            function setFromY(y) {
                slider.dragValue = Math.min(1, Math.max(0, (slider.height - y) / Math.max(1, slider.height)))
                slider.moved(slider.dragValue)
            }

            onPressed: mouse => setFromY(mouse.y)
            onPositionChanged: mouse => { if (pressed) setFromY(mouse.y) }
            onWheel: wheel => slider.moved(Math.min(1, Math.max(0,
                slider.shown + (wheel.angleDelta.y > 0 ? slider.wheelStep : -slider.wheelStep))))
        }
    }

    component TransportButton: Item {
        id: btn

        property var colors
        property string glyph
        property int box: 24
        property int size: 10
        property bool filled: false

        signal clicked()

        width: box
        height: box
        scale: tap.pressed ? 0.9 : 1

        Behavior on scale { Pop {} }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: btn.filled ? btn.colors.fill : "transparent"
        }

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: btn.glyph
            font.family: Theme.fontAwesomeFont
            font.weight: Font.Black
            font.italic: false
            font.pixelSize: btn.size
            color: btn.filled ? btn.colors.ink : "#ffffff"
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

        property var colors
        property bool available: false
        property bool playing: false
        property string title
        property string artist
        property string art: ""
        property real big: 16
        property int iconSize: 10
        property int titleSize: 8
        property int subtitleSize: 6
        property real pad: 4
        property real corner: 8

        readonly property int side: Math.round(big * 0.78)
        readonly property real artSize: Math.min(width * 0.34, height * 0.34)

        signal previous()
        signal toggle()
        signal next()

        radius: corner
        color: colors.card

        Rectangle {
            id: artworkFrame
            x: card.pad
            y: card.pad
            width: card.artSize
            height: card.artSize
            radius: Math.max(3, card.corner * 0.55)
            color: Qt.rgba(1, 1, 1, 0.1)
            clip: true

            Image {
                id: artworkImage
                anchors.fill: parent
                source: card.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: artworkMask
                    maskThresholdMin: 0.5
                }
            }

            Item {
                id: artworkMask
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    radius: artworkFrame.radius
                    color: "#000000"
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !card.available || artworkImage.status !== Image.Ready
                text: "\uf001"
                font.family: Theme.fontAwesomeFont
                font.weight: Font.Black
                font.pixelSize: card.iconSize
                color: card.colors.muted
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: card.pad
            anchors.top: parent.top
            anchors.topMargin: card.pad
            width: card.iconSize + 6
            height: width
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "\uf108"
            font.family: Theme.fontAwesomeFont
            font.weight: Font.Black
            font.pixelSize: card.iconSize
            color: card.colors.muted
        }

        Column {
            anchors.top: parent.top
            anchors.topMargin: artworkFrame.y + artworkFrame.height + 4
            anchors.left: parent.left
            anchors.leftMargin: card.pad
            anchors.right: parent.right
            anchors.rightMargin: card.pad
            spacing: 1

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignLeft
                text: card.available && card.title !== "" ? card.title : "Not Playing"
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
                font.italic: false
                font.pixelSize: card.titleSize
                color: "#ffffff"
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignLeft
                visible: text !== ""
                text: card.available ? card.artist : ""
                font.family: Theme.fontFamily
                font.weight: Font.Normal
                font.italic: false
                font.pixelSize: card.subtitleSize
                color: card.colors.muted
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: card.pad
            anchors.rightMargin: card.pad
            anchors.bottomMargin: card.pad
            spacing: Math.max(0, (width - card.side * 2 - card.big) / 2)
            enabled: card.available
            opacity: card.available ? 1 : 0.4

            Behavior on opacity { Ease {} }

            TransportButton {
                anchors.verticalCenter: parent.verticalCenter
                colors: card.colors
                glyph: "\uf048"
                box: card.side
                size: Math.round(card.iconSize * 0.9)
                onClicked: card.previous()
            }
            TransportButton {
                colors: card.colors
                glyph: card.playing ? "\uf04c" : "\uf04b"
                box: Math.round(card.big)
                size: card.iconSize
                filled: true
                onClicked: card.toggle()
            }
            TransportButton {
                anchors.verticalCenter: parent.verticalCenter
                colors: card.colors
                glyph: "\uf051"
                box: card.side
                size: Math.round(card.iconSize * 0.9)
                onClicked: card.next()
            }
        }
    }


    Cell {
        x: 0
        y: 0
        width: root.wide
        height: root.wide
        reveal: root.r0

        Rectangle {
            id: connect
            anchors.fill: parent
            radius: root.corner
            color: pal.card

            readonly property real d: Math.round(root.wide / 2 * root.circleScale)
            readonly property real m: Math.round((root.wide - 2 * d) / 3)
            readonly property real far: root.wide - m - d

            Disc {
                x: connect.m
                y: connect.m
                width: connect.d
                height: width
                colors: pal
                glyph: "\uf072"
                iconSize: root.iconSize
                active: root.airplaneOn
                onClicked: root.airplaneClicked()
            }

            Disc {
                x: connect.far
                y: connect.m
                width: connect.d
                height: width
                colors: pal
                glyph: "\uf293"
                iconSize: root.iconSize
                active: root.bluetoothOn
                onClicked: root.bluetoothClicked()
            }

            Disc {
                x: connect.m
                y: connect.far
                width: connect.d
                height: width
                colors: pal
                glyph: ""
                iconSize: root.iconSize
                active: root.hotspotOn
                onClicked: root.hotspotClicked()

                Canvas {
                    anchors.centerIn: parent
                    width: parent.iconSize * 1.2
                    height: width
                    z: 1
                    antialiasing: true
                    property color iconColor: parent.iconColor

                    Behavior on iconColor { Tint {} }
                    onIconColorChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = iconColor
                        ctx.fillStyle = iconColor
                        ctx.lineWidth = Math.max(1.5, width * 0.12)
                        ctx.lineCap = "round"

                        var centerX = width / 2
                        var centerY = height * 0.6
                        for (var index = 0; index < 3; index++) {
                            ctx.beginPath()
                            ctx.arc(centerX, centerY, width * (0.16 + index * 0.13), Math.PI * 0.75, Math.PI * 2.25)
                            ctx.stroke()
                        }

                    }
                }
            }

            Disc {
                x: connect.far
                y: connect.far
                width: connect.d
                height: width
                colors: pal
                glyph: "\uf1eb"
                iconSize: root.iconSize
                active: root.wifiOn
                onClicked: root.wifiClicked()
            }
        }
    }

    Cell {
        x: 2 * root.step
        y: 0
        width: root.wide
        height: root.wide
        reveal: root.r0

        NowPlaying {
            anchors.fill: parent
            colors: pal
            corner: root.corner
            big: root.knob
            iconSize: root.iconSize
            titleSize: Math.round(root.cell * 0.16)
            subtitleSize: Math.round(root.cell * 0.15)
            pad: root.pad
            available: root.mediaAvailable
            playing: root.mediaPlaying
            title: root.mediaTitle
            artist: root.mediaArtist
            art: root.mediaArt
            onPrevious: root.mediaPrevious()
            onToggle: root.mediaToggle()
            onNext: root.mediaNext()
        }
    }

    Cell {
        x: 0
        y: 2 * root.step
        width: root.cell
        height: root.cell
        reveal: root.r1

        IconTile {
            anchors.fill: parent
            colors: pal
            corner: root.corner
            glyph: "\uf042"
            iconSize: root.iconSize
            active: root.darkMode
            onClicked: root.darkModeClicked()
        }
    }

    Cell {
        x: root.step
        y: 2 * root.step
        width: root.cell
        height: root.cell
        reveal: root.r1

        IconTile {
            anchors.fill: parent
            colors: pal
            corner: root.corner
            glyph: "\uf2d2"
            iconSize: root.iconSize
            onClicked: root.actionRequested("overview")
        }
    }

    Cell {
        x: 2 * root.step
        y: 2 * root.step
        width: root.cell
        height: root.wide
        reveal: root.r2

        VSlider {
            anchors.fill: parent
            colors: pal
            corner: root.corner
            glyph: "\uf185"
            iconSize: root.iconSize
            labelSize: root.subtitleSize
            value: root.brightness
            onMoved: ratio => root.brightnessMoved(ratio)
        }
    }

    Cell {
        x: 3 * root.step
        y: 2 * root.step
        width: root.cell
        height: root.wide
        reveal: root.r2

        VSlider {
            anchors.fill: parent
            colors: pal
            corner: root.corner
            glyph: root.volume <= 0.001 ? "\uf026" : root.volume < 0.5 ? "\uf027" : "\uf028"
            iconSize: root.iconSize
            labelSize: root.subtitleSize
            value: root.volume
            onMoved: ratio => root.volumeMoved(ratio)
        }
    }

    Cell {
        x: 0
        y: 3 * root.step
        width: root.wide
        height: root.cell
        reveal: root.r3

        FocusTile {
            anchors.fill: parent
            colors: pal
            corner: root.corner
            label: "Focus"
            status: root.dndActive ? "On" : "Off"
            badge: root.knob
            iconSize: root.iconSize
            titleSize: root.titleSize
            subtitleSize: root.focusStatusSize
            pad: root.pad
            active: root.dndActive
            onClicked: root.dndClicked()
        }
    }
}
