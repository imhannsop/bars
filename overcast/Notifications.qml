import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

// NOTE: notifServer exposed for Bar.qml → ControlCenter's trackedNotifications
Scope {
    id: notifications

    property alias notifServer: notifServer

    ListModel {
        id: popupModel
    }

    NotificationServer {
        id: notifServer
        persistenceSupported: true
        bodySupported: true

        onNotification: (notification) => {
            if (!notification) return // Defensive: ignore malformed/empty DBus calls

            notification.tracked = true

            popupModel.append({
                "appName": notification.appName || "System",
                "summary": notification.summary || "Notification",
                "body": notification.body || "",
                "urgency": notification.urgency !== undefined ? notification.urgency : 1
            })
        }
    }

    PanelWindow {
        id: toastWindow
        screen: Quickshell.screens[0]

        WlrLayershell.layer: WlrLayer.Overlay

        // NOTE: Anchored bottom-right instead of top-left. Height grows upward
        // from the fixed bottom edge as toasts stack, keeping the stack pinned
        // to the bottom-right corner.
        anchors {
            bottom: true
            right: true
        }

        // WARN: wlr-layer-shell compositors (Niri included) refuse to remap
        // a surface that was committed at 0x0. Keep 1px height floor;
        // drive show/hide via `visible`, not contentHeight collapsing.
        //
        // NOTE: implicitHeight is intentionally a fixed cap, not
        // `popupListView.contentHeight + 24`. A wlr-layer-shell surface
        // resize is a real compositor commit/remap, not a cheap compositing
        // op — animating it (or even just snapping it) on every toast
        // add/remove is what caused the flicker. Since the window is
        // transparent, reserving more height than currently needed costs
        // nothing visually; only the ListView content inside moves/fades,
        // and the surface itself never resizes.
        visible: popupModel.count > 0
        implicitWidth: 320
        implicitHeight: 640 // room for ~6 stacked toasts; raise if you regularly stack more
        color: "transparent"

        readonly property real defaultSlideDistance: 320

        ListView {
            id: popupListView
            // NOTE: Anchored bottom-right to match the window; rightMargin
            // replaces the old leftMargin so the stack hugs the right edge.
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            width: 300
            height: contentHeight
            spacing: 8
            model: popupModel
            interactive: false
            clip: false

            add: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            populate: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            displaced: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            move: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }

            delegate: Rectangle {
                id: toastCard
                width: popupListView.width
                implicitHeight: toastLayout.implicitHeight + 16
                radius: 12
                color: Theme.cBg
                border.color: model.urgency === 2 ? Theme.cUrgent : Theme.cCardBorder
                border.width: 1

                // NOTE: slideDistance defined locally so it's valid during delegate creation/destruction,
                // before `width` resolves.
                readonly property real slideDistance: width > 0 ? width + 24 : 320

                property real animState: 1
                property bool exiting: false

                // NOTE: Sign flipped (was `-animState * slideDistance`). animState: 1
                // (hidden) now offsets the card to the RIGHT of its resting x, so
                // entry (1 -> 0) slides right-to-left into place, and exit (0 -> 1)
                // continues that same rightward-offset path outward.
                transform: Translate {
                    x: toastCard.animState * toastCard.slideDistance
                }

                opacity: 1 - toastCard.animState

                Behavior on animState {
                    NumberAnimation {
                        duration: 250
                        easing.type: toastCard.exiting ? Easing.InCubic : Easing.OutCubic
                    }
                }

                Component.onCompleted: {
                    slideInTimer.start()
                }

                Timer {
                    id: slideInTimer
                    interval: 0
                    repeat: false
                    onTriggered: {
                        toastCard.exiting = false
                        toastCard.animState = 0
                    }
                }

                Timer {
                    interval: model.urgency === 2 ? 8000 : 4000
                    running: true
                    repeat: false
                    onTriggered: {
                        toastCard.startExit()
                    }
                }

                function startExit() {
                    toastCard.animState = 1
                    exitTimer.restart()
                }

                Timer {
                    id: exitTimer
                    interval: 250
                    repeat: false
                    onTriggered: {
                        if (index >= 0 && index < popupModel.count) {
                            popupModel.remove(index)
                        }
                    }
                }

                RowLayout {
                    id: toastLayout
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 8
                        color: model.urgency === 2 ? Theme.cUrgent : Theme.cCardActive
                        Layout.alignment: Qt.AlignTop

                        Text {
                            anchors.centerIn: parent
                            text: model.urgency === 2 ? "" : ""
                            color: model.urgency === 2 ? "#ffffff" : Theme.cAccent
                            font.pixelSize: 16
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: model.appName
                            color: model.urgency === 2 ? Theme.cUrgent : Theme.cFgMuted
                            font.family: "Hermit"
                            font.pixelSize: 10
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: model.summary
                            color: Theme.cFg
                            font.family: "Hermit"
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: model.body
                            color: Theme.cFgMuted
                            font.family: "Hermit"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            visible: text !== ""
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: ""
                        color: Theme.cFgMuted
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignTop
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                toastCard.startExit()
                            }
                        }
                    }
                }
            }
        }
    }
}