import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    // Fullscreen border overlay
    PanelWindow {
        id: screenBorder
        screen: Quickshell.screens[0]

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        mask: Region {}

        property color borderColor: "#000000" // Border color
        property real borderWidth: 5          // Border width
        property real innerRadius: 18         // Corner radius

        Canvas {
            anchors.fill: parent
            antialiasing: true
            smooth: true

            property real bw: screenBorder.borderWidth
            property real r: screenBorder.innerRadius

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var w = width
                var h = height
                var bw = screenBorder.borderWidth
                var r = screenBorder.innerRadius

                ctx.fillStyle = screenBorder.borderColor

                ctx.beginPath()

                // Outer shape - full screen
                ctx.rect(0, 0, w, h)

                // Inner cutout with rounded corners
                ctx.moveTo(bw + r, bw)
                ctx.arcTo(bw, bw, bw, bw + r, r)
                ctx.lineTo(bw, h - bw - r)
                ctx.arcTo(bw, h - bw, bw + r, h - bw, r)
                ctx.lineTo(w - bw - r, h - bw)
                ctx.arcTo(w - bw, h - bw, w - bw, h - bw - r, r)
                ctx.lineTo(w - bw, bw + r)
                ctx.arcTo(w - bw, bw, w - bw - r, bw, r)
                ctx.closePath()

                ctx.fill("evenodd")
            }
        }
    }

    // Top bar
    PanelWindow {
        id: window
        screen: Quickshell.screens[0]

        anchors.top: true
        margins.top: 0

        WlrLayershell.layer: WlrLayer.Overlay

        property real barWidth: 380
        property real barHeight: 35
        property real notchRadius: 20
        property real bottomRadius: 18

        implicitWidth: barWidth + notchRadius * 2
        implicitHeight: barHeight

        color: "transparent"
        exclusiveZone: 30

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

                // Top edge
                ctx.moveTo(ox - nr, 0)
                ctx.lineTo(ox + w + nr, 0)

                // Right curve
                ctx.arcTo(ox + w, 0, ox + w, nr, nr)

                // Right edge
                ctx.lineTo(ox + w, h - r)

                // Bottom-right corner
                ctx.arcTo(ox + w, h, ox + w - r, h, r)

                // Bottom edge
                ctx.lineTo(ox + r, h)

                // Bottom-left corner
                ctx.arcTo(ox, h, ox, h - r, r)

                // Left edge
                ctx.lineTo(ox, nr)

                // Left curve
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
    }
}