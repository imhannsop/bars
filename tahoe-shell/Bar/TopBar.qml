import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower

PanelWindow {
    id: window
    screen: Quickshell.screens[0]

    mask: Region {
        item: barArea
    }

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

    property bool expanded: false

    property int expandDuration: 260
    property int collapseDuration: 200

    property real collapsedWidth: 460
    property real collapsedHeight: 35
    property real collapsedNotchRadius: 20
    property real collapsedBottomRadius: 18

    property real expandedWidth: 720
    property real expandedHeight: 350
    property real expandedNotchRadius: 30
    property real expandedBottomRadius: 32

    property real collapsedClockSize: 15
    property real expandedClockSize: 110

    property real collapsedClockWidth: 64
    property real collapsedClockHeight: 17
    property real expandedClockHeight: 136

    property real collapsedClockXScale: 1.0
    property real expandedClockXScale: 0.70

    property real collapsedClockYScale: 1.0
    property real expandedClockYScale: 1.6

    property real barWidth: collapsedWidth
    property real barHeight: collapsedHeight
    property real notchRadius: collapsedNotchRadius
    property real bottomRadius: collapsedBottomRadius
    property real clockFontSize: collapsedClockSize
    property real clockXScale: collapsedClockXScale
    property real clockYScale: collapsedClockYScale

    property real expandedContentOpacity: 0.0

    readonly property real maxNotchRadius: Math.max(collapsedNotchRadius, expandedNotchRadius)

    implicitWidth: expandedWidth + maxNotchRadius * 2
    implicitHeight: expandedHeight

    color: "transparent"
    exclusiveZone: 30

    FontLoader {
        id: sfProBold
        source: "file:///home/ekoubu/.local/share/fonts/SFPro/SF-Pro-Display-Bold.otf"
    }

    Item {
        id: barContent
        anchors.fill: parent
        opacity: 0

        transform: [
            Translate { id: entranceSlide; y: -30 },
            Translate { id: fullscreenSlide; y: 0 }
        ]

        enabled: !window.fullscreenActive
        state: window.debouncedFullscreen ? "hidden" : "shown"

        states: [
            State { name: "shown"; PropertyChanges { target: fullscreenSlide; y: 0 } },
            State { name: "hidden"; PropertyChanges { target: fullscreenSlide; y: -(window.barHeight + window.notchRadius) } }
        ]

        transitions: [
            Transition {
                to: "shown"
                NumberAnimation { target: fullscreenSlide; property: "y"; duration: 160; easing.type: Easing.OutExpo }
            },
            Transition {
                to: "hidden"
                NumberAnimation { target: fullscreenSlide; property: "y"; duration: 160; easing.type: Easing.OutQuad }
            }
        ]

        SequentialAnimation {
            id: entranceAnim
            running: false
            PauseAnimation { duration: 20 }
            ParallelAnimation {
                NumberAnimation { target: entranceSlide; property: "y"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                OpacityAnimator { target: barContent; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
            }
        }

        Component.onCompleted: entranceAnim.start()

        Item {
            id: barArea
            x: (barContent.width - width) / 2
            y: 0
            width: window.barWidth + window.notchRadius * 2
            height: window.barHeight

            state: window.expanded ? "expanded" : "collapsed"

            // Keep geometry and child positions in one state transition.
            states: [
                State {
                    name: "collapsed"
                    PropertyChanges { target: window; barWidth: window.collapsedWidth; barHeight: window.collapsedHeight; notchRadius: window.collapsedNotchRadius; bottomRadius: window.collapsedBottomRadius; clockFontSize: window.collapsedClockSize; clockXScale: window.collapsedClockXScale; clockYScale: window.collapsedClockYScale; expandedContentOpacity: 0.0 }
                    PropertyChanges { target: wsIndicator; x: window.collapsedNotchRadius + 20; y: (window.collapsedHeight - wsIndicator.implicitHeight) / 2 }
                    PropertyChanges { target: clockDisplay; x: window.collapsedWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth; y: (window.collapsedHeight - window.collapsedClockHeight) / 2 }
                    PropertyChanges { target: statusCluster; x: window.collapsedWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth - 12 - 50; y: (window.collapsedHeight - statusCluster.height) / 2 }
                },
                State {
                    name: "expanded"
                    PropertyChanges { target: window; barWidth: window.expandedWidth; barHeight: window.expandedHeight; notchRadius: window.expandedNotchRadius; bottomRadius: window.expandedBottomRadius; clockFontSize: window.expandedClockSize; clockXScale: window.expandedClockXScale; clockYScale: window.expandedClockYScale; expandedContentOpacity: 1.0 }
                    PropertyChanges { target: wsIndicator; x: window.expandedNotchRadius + 34; y: window.expandedHeight - 24 - wsIndicator.implicitHeight }
                    PropertyChanges { target: clockDisplay; x: window.expandedNotchRadius + 26; y: 110 }
                    PropertyChanges { target: statusCluster; x: (window.expandedNotchRadius + 34) + wsIndicator.width + 14; y: (window.expandedHeight - 24 - wsIndicator.implicitHeight) + (wsIndicator.height - statusCluster.height) / 2 }
                }
            ]

            transitions: [
                Transition {
                    from: "collapsed"; to: "expanded"
                    ParallelAnimation {
                        NumberAnimation {
                            targets: [window, wsIndicator, clockDisplay, statusCluster]
                            properties: "barWidth,barHeight,notchRadius,bottomRadius,clockFontSize,clockXScale,clockYScale,x,y"
                            duration: window.expandDuration
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.08
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: 30 }
                            NumberAnimation {
                                target: window
                                property: "expandedContentOpacity"
                                duration: window.expandDuration - 30
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                },
                Transition {
                    from: "expanded"; to: "collapsed"
                    ParallelAnimation {
                        NumberAnimation {
                            targets: [window, wsIndicator, clockDisplay, statusCluster]
                            properties: "barWidth,barHeight,notchRadius,bottomRadius,clockFontSize,clockXScale,clockYScale,x,y"
                            duration: window.collapseDuration
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: window
                            property: "expandedContentOpacity"
                            duration: window.collapseDuration - 20
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            ]

            Canvas {
                id: barCanvas
                anchors.fill: parent
                antialiasing: true
                smooth: true

                layer.enabled: true
                layer.smooth: true

                property real w: window.barWidth
                property real h: window.barHeight
                property real nr: window.notchRadius
                property real r: window.bottomRadius

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
                opacity: 1.0 - window.expandedContentOpacity
                visible: opacity > 0.01
                layer.enabled: true
            }

            ExpandedPanel {
                id: expandedPanel
                anchors.fill: parent
                fontFamily: sfProBold.name
                notchRadius: window.notchRadius

                opacity: window.expandedContentOpacity
                visible: opacity > 0.01
                layer.enabled: true
            }

            WorkspaceIndicator {
                id: wsIndicator
                dotSize: 14
                ringSize: 16
                ringBorder: 4
                dotSpacing: 9
            }

            Row {
                id: clockDisplay
                spacing: 1

                transform: Scale {
                    origin.x: 0
                    origin.y: clockDisplay.height / 2
                    xScale: window.clockXScale
                    yScale: window.clockYScale
                }

                Text {
                    id: clockHours
                    color: "#ffffff"
                    font.pixelSize: window.clockFontSize
                    font.family: sfProBold.name
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    text: Qt.formatDateTime(clockTimer.now, "hh")
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    id: customColon
                    // Added moderate padding (+8) so the dots have clean, balanced breathing room
                    implicitWidth: dotWidth + (30 * window.expandedContentOpacity)
                    height: clockHours.height
                    anchors.verticalCenter: parent.verticalCenter

                    property real dotWidth: window.clockFontSize * 0.12
                    property real dotHeight: dotWidth
                    property real dotRadius: dotWidth / 2
                    
                    property real dotSpacing: (height * 0.20) * window.expandedContentOpacity + (1.8 * (1.0 - window.expandedContentOpacity))

                    // Top Dot
                    Rectangle {
                        id: topDot
                        width: customColon.dotWidth
                        height: customColon.dotHeight
                        radius: customColon.dotRadius
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -customColon.dotSpacing

                        transform: Scale {
                            origin.x: topDot.width / 2
                            origin.y: topDot.height / 2
                            xScale: 1.0 / Math.max(0.01, window.clockXScale)
                            yScale: 1.0 / Math.max(0.01, window.clockYScale)
                        }
                    }

                    // Bottom Dot
                    Rectangle {
                        id: bottomDot
                        width: customColon.dotWidth
                        height: customColon.dotHeight
                        radius: customColon.dotRadius
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: customColon.dotSpacing

                        transform: Scale {
                            origin.x: bottomDot.width / 2
                            origin.y: bottomDot.height / 2
                            xScale: 1.0 / Math.max(0.01, window.clockXScale)
                            yScale: 1.0 / Math.max(0.01, window.clockYScale)
                        }
                    }
                }

                Text {
                    id: clockMinutes
                    color: "#ffffff"
                    font.pixelSize: window.clockFontSize
                    font.family: sfProBold.name
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    text: Qt.formatDateTime(clockTimer.now, "mm")
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    id: clockMeridiem
                    anchors.bottom: parent.bottom
                    color: "#ffffff"
                    font.pixelSize: window.clockFontSize
                    font.family: sfProBold.name
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    text: Qt.formatDateTime(clockTimer.now, "AP")
                    
                    // The expanded clock replaces the meridiem label.
                    opacity: Math.max(0.0, 1.0 - (window.expandedContentOpacity * 2.0))
                    visible: opacity > 0.01
                }
            }

            Text {
                id: clockDate
                x: window.expandedNotchRadius + 34
                y: window.expandedNotchRadius + 40
                color: "#ffffff"
                font.family: "SF Pro Display"
                font.weight: Font.Bold
                font.pixelSize: 18
                font.capitalization: Font.AllUppercase
                text: Qt.formatDateTime(clockTimer.now, "ddd, MMM d")

                opacity: window.expandedContentOpacity
                visible: opacity > 0.01
            }

            Item {
                id: statusCluster
                width: statusRow.implicitWidth
                height: statusRow.implicitHeight

                Row {
                    id: statusRow
                    spacing: 10

                    Text {
                        id: wifiIcon
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.family: "Font Awesome 6 Free"
                        font.weight: Font.Black
                        text: "\uf1eb"
                    }

                    Text {
                        id: batteryIcon
                        anchors.verticalCenter: parent.verticalCenter
                        color: UPower.displayDevice.percentage <= 0.15 && UPower.displayDevice.state !== UPowerDeviceState.Charging ? "#ff5555" : "#ffffff"
                        font.pixelSize: 18
                        font.family: sfProBold.name
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
                        font.family: "SF Pro Text"
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                        text: Math.round(UPower.displayDevice.percentage * 100) + "%"

                        opacity: window.expandedContentOpacity
                        visible: opacity > 0.01
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 12
                        color: "#ffffff"
                        opacity: (1.0 - window.expandedContentOpacity) * 0.4
                        visible: opacity > 0.01
                    }
                }
            }
        }
    }
}