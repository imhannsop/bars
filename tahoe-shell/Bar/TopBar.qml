import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower

PanelWindow {
    id: window
    screen: Quickshell.screens[0]

    readonly property bool fullscreenActive: ToplevelManager.activeToplevel !== null
                                             && ToplevelManager.activeToplevel.fullscreen

    property bool debouncedFullscreen: false

    Timer {
        id: fullscreenDebounce
        interval: 60
        onTriggered: window.debouncedFullscreen = window.fullscreenActive
    }

    onFullscreenActiveChanged: fullscreenDebounce.restart()

    anchors.top: true
    margins.top: 0

    WlrLayershell.layer: WlrLayer.Overlay

    property real barWidth: 460
    property real barHeight: 35
    property real notchRadius: 20
    property real bottomRadius: 18

    implicitWidth: barWidth + notchRadius * 2
    implicitHeight: barHeight

    color: "transparent"
    exclusiveZone: 30

    readonly property var niriCurve: [0.05, 0.9, 0.1, 1.05, 1, 1]
    property int entranceStagger: 80

    FontLoader {
        id: ubuntuBold
        source: "file:///usr/share/fonts/ubuntu/UbuntuMono-B.ttf"
    }

    Item {
        id: barContent
        anchors.fill: parent
        opacity: 0

        transform: [
            Translate {
                id: entranceSlide
                y: -30
            },
            Translate {
                id: fullscreenSlide
                y: 0
            }
        ]

        enabled: !window.fullscreenActive
        state: window.debouncedFullscreen ? "hidden" : "shown"

        states: [
            State {
                name: "shown"
                PropertyChanges { target: fullscreenSlide; y: 0 }
            },
            State {
                name: "hidden"
                PropertyChanges { target: fullscreenSlide; y: -(barContent.height + window.notchRadius) }
            }
        ]

        transitions: [
            Transition {
                to: "shown"
                NumberAnimation {
                    target: fullscreenSlide
                    property: "y"
                    duration: 150
                    easing.type: Easing.OutExpo
                }
            },
            Transition {
                to: "hidden"
                NumberAnimation {
                    target: fullscreenSlide
                    property: "y"
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
        ]

        SequentialAnimation {
            id: entranceAnim
            running: false

            PauseAnimation { duration: window.entranceStagger }

            ParallelAnimation {
                NumberAnimation {
                    target: entranceSlide
                    property: "y"
                    to: 0
                    duration: 350
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: window.niriCurve
                }
                NumberAnimation {
                    target: barContent
                    property: "opacity"
                    to: 1.0
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }

        Component.onCompleted: entranceAnim.start()

        Canvas {
            id: barCanvas
            anchors.fill: parent
            antialiasing: true
            smooth: true

            property real w: window.barWidth
            property real h: window.barHeight
            property real nr: window.notchRadius
            property real r: window.bottomRadius

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var ox = nr

                ctx.beginPath()
                ctx.moveTo(ox - nr, 0)
                ctx.lineTo(ox + w + nr, 0)
                ctx.arcTo(ox + w, 0, ox + w, nr, nr)
                ctx.lineTo(ox + w, h - r)
                ctx.arcTo(ox + w, h, ox + w - r, h, r)
                ctx.lineTo(ox + r, h)
                ctx.arcTo(ox, h, ox, h - r, r)
                ctx.lineTo(ox, nr)
                ctx.arcTo(ox, 0, ox - nr, 0, nr)
                ctx.closePath()

                ctx.fillStyle = "#000000"
                ctx.fill()
            }
        }

        WorkspaceIndicator {
            anchors.left: parent.left
            anchors.leftMargin: window.notchRadius + 20
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: window.notchRadius + 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Timer {
                id: clockTimer
                property var now: new Date()
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: now = new Date()
            }

            Text {
                id: wifiIcon
                anchors.verticalCenter: parent.verticalCenter
                color: "#ffffff"
                font.pixelSize: 13
                font.family: ubuntuBold.name
                font.weight: Font.Bold
                text: ""
            }

            Text {
                id: batteryIcon
                anchors.verticalCenter: parent.verticalCenter
                color: "#ffffff"
                font.pixelSize: 18
                font.family: ubuntuBold.name
                font.weight: Font.Bold
                text: ""

                HoverHandler { id: batteryHover }
                ToolTip.visible: batteryHover.hovered
                ToolTip.text: (UPower.displayDevice.state === UPowerDeviceState.Charging ? "Charging – " : "")
                              + Math.round(UPower.displayDevice.percentage * 100) + "%"

                // Nested under the icon rather than laid out in the Row, so fading it
                // in/out never touches the row's implicit width/height.
                Text {
                    anchors.top: parent.bottom
                    anchors.topMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#ffffff"
                    font.pixelSize: 9
                    font.family: ubuntuBold.name
                    font.features: { "tnum": 1 }
                    text: Math.round(UPower.displayDevice.percentage * 100) + "%"

                    opacity: batteryHover.hovered ? 0.7 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 12
                color: "#ffffff"
                opacity: 0.2            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: "#ffffff"
                font.pixelSize: 15
                font.family: ubuntuBold.name
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                text: Qt.formatDateTime(clockTimer.now, "hh:mm AP")
            }
        }
    }
}