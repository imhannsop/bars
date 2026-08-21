import QtQuick
import QtQuick.Layouts
import Quickshell

// NOTE: notifServer forwarded to ControlCenter's trackedNotifications model
Variants {
    id: bar

    property var notifServer

    property int sectionGap: 20

    model: Quickshell.screens

    // NOTE: Scope bundles both windows into one Variants delegate (Variants expects single delegate per screen)
    Scope {
        id: screenScope
        required property var modelData

    PanelWindow {
        id: barWindow
        screen: screenScope.modelData

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: 52
        color: "transparent"

        RowLayout {
            id: topRow
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.rightMargin: 12
            anchors.leftMargin: 12

            Item { Layout.fillWidth: true }

            Rectangle {
                id: pillBar
                implicitWidth: mainRow.implicitWidth + 32
                implicitHeight: 36
                radius: 18
                color: controlCenterPopup.isOpen ? Theme.cBgHover : Theme.cBg
                border.color: Theme.cCardBorder
                border.width: 1

                // Pinned to the top of the RowLayout rather than left to
                // default-center: the RowLayout is 40px tall (52 window
                // height - 12 topMargin) but this pill is only 36px, so
                // without this it picks up a stray 2px top offset that
                // put it 2px lower than Launcher.qml's search pill, which
                // sits at exactly topMargin (12) with no such gap.
                Layout.alignment: Qt.AlignTop

                onWidthChanged: SystemState.barPillWidth = width
                Component.onCompleted: SystemState.barPillWidth = width

                RowLayout {
                    id: mainRow
                    anchors.centerIn: parent
                    spacing: bar.sectionGap

                    Item {
                        implicitWidth: wsRow.implicitWidth
                        implicitHeight: wsRow.implicitHeight
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            id: activePill
                            width: 16
                            height: 16
                            radius: 8
                            color: Theme.cAccent
                            z: 0

                            // WARN: x binding assumes 18px spacing — breaks if wsRow.spacing changes
                            x: (SystemState.currentWorkspace - 1) * 18 - 4
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on x {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        RowLayout {
                            id: wsRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            z: 1

                            Repeater {
                                id: wsRepeater
                                model: SystemState.totalWorkspaces

                                Item {
                                    implicitWidth: 8
                                    implicitHeight: 8
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        id: wsDot
                                        property int wsIndex: index + 1
                                        anchors.fill: parent
                                        radius: 4
                                        color: SystemState.currentWorkspace === wsIndex ? "#ffffff" : Theme.cFgMuted

                                        Behavior on color {
                                            ColorAnimation { duration: 180 }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: SystemState.switchToWorkspace(wsDot.wsIndex)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        implicitWidth: rightStatusRow.implicitWidth
                        implicitHeight: rightStatusRow.implicitHeight
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            id: rightStatusRow
                            anchors.fill: parent
                            spacing: 10

                            RowLayout {
                                spacing: 8
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: SystemState.getNetworkIcon(SystemState.ethernetConnected, SystemState.wifiConnected, SystemState.wifiSignal)
                                    color: (!SystemState.wifiConnected && !SystemState.ethernetConnected) ? Theme.cFgMuted : Theme.cFg
                                    font.family: "Hermit"
                                    font.pixelSize: 15
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: SystemState.getStandingBatteryIcon(SystemState.batteryCapacity, SystemState.isCharging)
                                    color: SystemState.batteryCapacity <= 15 && !SystemState.isCharging ? Theme.cUrgent : Theme.cFg
                                    font.family: "Hermit"
                                    font.pixelSize: 15
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            Rectangle {
                                width: 1
                                height: 12
                                color: Theme.cCardBorder
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: SystemState.currentTime
                                color: Theme.cFg
                                font.family: "Hermit"
                                font.pixelSize: 11
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlCenterPopup.isOpen = !controlCenterPopup.isOpen
                        }
                    }
                }
            }
        }

        ControlCenter {
            id: controlCenterPopup
            anchorWindow: barWindow
            pillBarWidth: pillBar.width
            // pillBar sits AlignTop inside topRow, flush against topRow's
            // own topMargin (see the comment on pillBar's Layout.alignment
            // above) — so its absolute bottom edge, relative to barWindow,
            // is just topMargin + pillBar's own height. Computed directly
            // like this instead of via mapToItem(), which turned out not
            // to resolve reliably against PanelWindow's contentItem.
            pillBarBottomY: topRow.anchors.topMargin + pillBar.height
            notifServer: bar.notifServer
        }
    }

    // HACK(wayland): niri lacks xdg_popup grab; fullscreen PanelWindow with mask toggle emulates outside-click-dismiss
    PanelWindow {
        id: outsideClickCatcher
        screen: screenScope.modelData

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        color: "transparent"
        mask: controlCenterPopup.isOpen ? null : nothingRegion

        Item { id: nothingItem; width: 0; height: 0 }
        Region { id: nothingRegion; item: nothingItem }

        MouseArea {
            anchors.fill: parent
            enabled: controlCenterPopup.isOpen
            onClicked: controlCenterPopup.isOpen = false
        }
    }
    }
}