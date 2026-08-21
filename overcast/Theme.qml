pragma Singleton
import QtQuick

QtObject {
    readonly property color cBg: "#f2f2f2"
    readonly property color cBgHover: "#e5e5e5"
    readonly property color cFg: "#1a1a1a"
    readonly property color cFgMuted: "#686868"
    readonly property color cAccent: "#262626"
    readonly property color cCardBg: "#f8f8f8"
    readonly property color cCardBorder: "#d8d8d8"
    readonly property color cCardActive: "#e6e6e6"
    readonly property color cUrgent: "#d20f39"

    // NOTE: 3-point cubic bezier (6 values) — sharp acceleration, long ease-out.
    // Tuned for Behavior/NumberAnimation `easing.bezierCurve`, not a QML built-in curve.
    readonly property var bezierFastSlow: [0.05, 0.9, 0.1, 1.0, 1.0, 1.0]
}
