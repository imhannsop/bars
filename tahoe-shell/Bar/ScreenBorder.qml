import QtQuick
import Quickshell
import Quickshell.Wayland

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

    property color borderColor: "#000000"
    property real borderWidth: 5
    property real innerRadius: 18

    Canvas {
        id: borderCanvas
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

            ctx.rect(0, 0, w, h)

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
