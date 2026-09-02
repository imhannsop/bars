import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower

PanelWindow {
    id: window
    screen: Quickshell.screens[0]

    mask: Region { item: barArea }

    readonly property bool fullscreenActive: ToplevelManager.activeToplevel !== null
                                             && ToplevelManager.activeToplevel.fullscreen

    property bool debouncedFullscreen: false

    Timer {
        id: fullscreenDebounce
        interval: 60
        onTriggered: window.debouncedFullscreen = window.fullscreenActive
    }

    onFullscreenActiveChanged: {
        fullscreenDebounce.restart()
        if (window.fullscreenActive)
            window.expanded = false
    }

    anchors.top: true
    margins.top: 0

    WlrLayershell.layer: WlrLayer.Overlay

    // Panel expanded state
    property bool expanded: false

    // Spring curves
    readonly property var iosExpandCurve: [0.32, 0.72, 0.0, 1.0, 1.0, 1.0]
    readonly property var iosCollapseCurve: [0.40, 0.00, 0.2, 1.0, 1.0, 1.0]

    // Curve based on direction
    readonly property var activeCurve: expanded ? iosExpandCurve : iosCollapseCurve

    // Asymmetric timing
    property int morphDuration: expanded ? 380 : 280

    // Collapsed geometry
    property real collapsedWidth: 460
    property real collapsedHeight: 35
    property real collapsedNotchRadius: 20
    property real collapsedBottomRadius: 18

    // Expanded geometry
    property real expandedWidth: 710
    property real expandedHeight: 320
    property real expandedNotchRadius: 30
    property real expandedBottomRadius: 32

    property real collapsedClockSize: 15
    property real expandedClockSize: 150

    property real collapsedClockWidth: 44
    property real collapsedClockHeight: 17
    property real expandedClockHeight: 136

    property real collapsedClockXScale: 1.0
    property real expandedClockXScale: 0.64
    property real clockXScale: collapsedClockXScale

    property real collapsedClockYScale: 1.0
    property real expandedClockYScale: 1.2
    property real clockYScale: collapsedClockYScale

    // Dynamic geometry
    property real barWidth: expanded ? expandedWidth : collapsedWidth
    property real barHeight: expanded ? expandedHeight : collapsedHeight
    property real notchRadius: expanded ? expandedNotchRadius : collapsedNotchRadius
    property real bottomRadius: expanded ? expandedBottomRadius : collapsedBottomRadius
    property real clockFontSize: expanded ? expandedClockSize : collapsedClockSize

    Behavior on barWidth {
        NumberAnimation { duration: window.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: window.activeCurve }
    }
    Behavior on barHeight {
        NumberAnimation { duration: window.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: window.activeCurve }
    }
    Behavior on notchRadius {
        NumberAnimation { duration: window.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: window.activeCurve }
    }
    Behavior on bottomRadius {
        NumberAnimation { duration: window.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: window.activeCurve }
    }
    Behavior on clockFontSize {
        NumberAnimation { duration: window.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: window.activeCurve }
    }
    Behavior on clockXScale {
        NumberAnimation { duration: window.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: window.activeCurve }
    }
    Behavior on clockYScale {
        NumberAnimation { duration: window.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: window.activeCurve }
    }

    onExpandedChanged: {
        clockXScale = expanded ? expandedClockXScale : collapsedClockXScale
        clockYScale = expanded ? expandedClockYScale : collapsedClockYScale
    }

    readonly property real maxNotchRadius: Math.max(collapsedNotchRadius, expandedNotchRadius)

    implicitWidth: expandedWidth + maxNotchRadius * 2
    implicitHeight: expandedHeight

    color: "transparent"
    exclusiveZone: 30

    FontLoader {
        id: ubuntuBold
        source: "file:///usr/share/fonts/ubuntu/UbuntuMono-B.ttf"
    }

    FontLoader {
        id: fontAwesome
        source: "file:///usr/share/fonts/fontawesome/otfs/Font Awesome 6 Free-Solid-900.otf"
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
                PropertyChanges { target: fullscreenSlide; y: -(window.barHeight + window.notchRadius) }
            }
        ]

        transitions: [
            Transition {
                to: "shown"
                NumberAnimation {
                    target: fullscreenSlide
                    property: "y"
                    duration: 180
                    easing.type: Easing.OutExpo
                }
            },
            Transition {
                to: "hidden"
                NumberAnimation {
                    target: fullscreenSlide
                    property: "y"
                    duration: 180
                    easing.type: Easing.OutQuad
                }
            }
        ]

        SequentialAnimation {
            id: entranceAnim
            running: false

            PauseAnimation { duration: 60 }

            ParallelAnimation {
                NumberAnimation {
                    target: entranceSlide
                    property: "y"
                    to: 0
                    duration: 320
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: window.iosExpandCurve
                }
                OpacityAnimator {
                    target: barContent
                    to: 1.0
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        }

        Component.onCompleted: entranceAnim.start()

        Item {
            id: barArea
            x: (barContent.width - width) / 2
            y: 0
            width: window.barWidth + window.notchRadius * 2
            height: window.barHeight

            Canvas {
                id: barCanvas
                anchors.fill: parent
                antialiasing: true
                smooth: true

                // Cache layer for performance
                layer.enabled: true
                layer.smooth: true

                property real w: window.barWidth
                property real h: window.barHeight
                property real nr: window.notchRadius
                property real r: window.bottomRadius

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onWChanged: requestPaint()
                onHChanged: requestPaint()
                onNrChanged: requestPaint()
                onRChanged: requestPaint()
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

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: window.expanded = !window.expanded
            }

            Timer {
                id: clockTimer
                property var now: new Date()
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: now = new Date()
            }

            Item {
                id: collapsedContent
                anchors.fill: parent
                opacity: window.expanded ? 0 : 1
                visible: opacity > 0.01

                layer.enabled: true

                Behavior on opacity {
                    OpacityAnimator {
                        duration: window.morphDuration * 0.4
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: window.notchRadius + 20 + window.collapsedClockWidth + 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 12
                    color: "#ffffff"
                    opacity: 0.3
                }
            }

            ExpandedPanel {
                id: expandedPanel
                anchors.fill: parent
                fontFamily: ubuntuBold.name
                notchRadius: window.notchRadius

                opacity: window.expanded ? 1 : 0
                visible: opacity > 0.01

                layer.enabled: true

                Behavior on opacity {
                    OpacityAnimator {
                        duration: window.morphDuration * 0.5
                        easing.type: Easing.OutCubic
                    }
                }
            }

            WorkspaceIndicator {
                id: wsIndicator
                dotSize: 14
                ringSize: 16
                ringBorder: 4
                dotSpacing: 9

                state: window.expanded ? "expanded" : "collapsed"

                states: [
                    State {
                        name: "collapsed"
                        PropertyChanges {
                            target: wsIndicator
                            x: window.collapsedNotchRadius + 20
                            y: (window.collapsedHeight - wsIndicator.implicitHeight) / 2
                        }
                    },
                    State {
                        name: "expanded"
                        PropertyChanges {
                            target: wsIndicator
                            x: window.expandedNotchRadius + 34
                            y: window.expandedHeight - 24 - wsIndicator.implicitHeight
                        }
                    }
                ]

                transitions: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: window.morphDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: window.activeCurve
                    }
                }
            }

            Row {
                id: clockDisplay
                spacing: 1

                state: window.expanded ? "expanded" : "collapsed"

                states: [
                    State {
                        name: "collapsed"
                        PropertyChanges {
                            target: clockDisplay
                            x: window.collapsedWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth
                            y: (window.collapsedHeight - window.collapsedClockHeight) / 2
                        }
                    },
                    State {
                        name: "expanded"
                        PropertyChanges {
                            target: clockDisplay
                            x: window.expandedNotchRadius + 34
                            y: window.expandedHeight / 2 - 16 - window.expandedClockHeight / 2
                        }
                    }
                ]

                transitions: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: window.morphDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: window.activeCurve
                    }
                }

                transform: Scale {
                    origin.x: 0
                    origin.y: clockDisplay.height / 2
                    xScale: window.clockXScale
                    yScale: window.clockYScale
                }

                Text {
                    id: clockTime
                    anchors.bottom: parent.bottom
                    color: "#ffffff"
                    font.pixelSize: window.clockFontSize
                    font.family: ubuntuBold.name
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    text: Qt.formatDateTime(clockTimer.now, "h:mm")
                }

                Text {
                    id: clockMeridiem
                    anchors.bottom: parent.bottom
                    color: "#ffffff"
                    font.pixelSize: 9
                    font.family: ubuntuBold.name
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    text: Qt.formatDateTime(clockTimer.now, "AP")

                    opacity: window.expanded ? 0 : 1

                    Behavior on opacity {
                        OpacityAnimator {
                            duration: window.morphDuration * 0.4
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Text {
                id: clockDate
                x: window.expandedNotchRadius + 34
                y: (window.expandedHeight / 2 - 16 - window.expandedClockHeight / 2) - height - 10
                color: "#ffffff"
                font.family: ubuntuBold.name
                font.weight: Font.Bold
                font.pixelSize: 18
                font.capitalization: Font.AllUppercase
                text: Qt.formatDateTime(clockTimer.now, "ddd, MMM d")

                opacity: window.expanded ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity {
                    OpacityAnimator {
                        duration: window.morphDuration * 0.5
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                id: statusCluster
                spacing: 10

                state: window.expanded ? "expanded" : "collapsed"

                states: [
                    State {
                        name: "collapsed"
                        PropertyChanges {
                            target: statusCluster
                            x: window.collapsedWidth + window.collapsedNotchRadius - 20 - (window.collapsedClockWidth + 12) - 10
                               - statusCluster.width + statusCluster.spacing + batteryPercent.width
                            y: (window.collapsedHeight - statusCluster.height) / 2
                        }
                    },
                    State {
                        name: "expanded"
                        PropertyChanges {
                            target: statusCluster
                            x: (window.expandedNotchRadius + 34) + wsIndicator.width + 14
                            y: (window.expandedHeight - 24 - wsIndicator.implicitHeight) + (wsIndicator.height - statusCluster.height) / 2
                        }
                    }
                ]

                transitions: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: window.morphDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: window.activeCurve
                    }
                }

                Text {
                    id: wifiIcon
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.family: fontAwesome.name
                    font.weight: Font.Black
                    text: "\uf1eb"
                }

                Text {
                    id: batteryIcon
                    anchors.verticalCenter: parent.verticalCenter
                    color: UPower.displayDevice.percentage <= 0.15 && UPower.displayDevice.state !== UPowerDeviceState.Charging ? "#ff5555" : "#ffffff"
                    font.pixelSize: 18
                    font.family: ubuntuBold.name
                    font.weight: Font.Bold
                    text: {
                        var pct = UPower.displayDevice.percentage
                        if (UPower.displayDevice.state === UPowerDeviceState.Charging) return "\uf0e7"
                        if (pct >= 0.9) return "\uf240"
                        if (pct >= 0.75) return "\uf241"
                        if (pct >= 0.4) return "\uf242"
                        if (pct >= 0.15) return "\uf243"
                        return "\uf244"
                    }

                    HoverHandler { id: batteryHover }
                    ToolTip.visible: batteryHover.hovered && UPower.displayDevice.state === UPowerDeviceState.Charging
                    ToolTip.text: "Charging"
                }

                Text {
                    id: batteryPercent
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.family: ubuntuBold.name
                    font.features: { "tnum": 1 }
                    text: Math.round(UPower.displayDevice.percentage * 100) + "%"

                    opacity: window.expanded ? 1 : 0

                    Behavior on opacity {
                        OpacityAnimator {
                            duration: window.morphDuration * 0.5
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}