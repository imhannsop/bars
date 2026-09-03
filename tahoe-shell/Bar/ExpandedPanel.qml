import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string fontFamily: "Ubuntu Mono"
    property real notchRadius: 30

    readonly property bool isExpanded: root.Window?.window?.expanded ?? false
    readonly property real animationProgress: root.Window?.window?.expandedContentOpacity ?? 0.0

    transform: Translate {
        y: (1.0 - root.animationProgress) * -12
    }

    RowLayout {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.notchRadius + 8
        anchors.leftMargin: root.notchRadius + 34
        anchors.rightMargin: root.notchRadius + 24
        anchors.bottomMargin: 18
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Item {
            Layout.fillWidth: false
            Layout.preferredWidth: 350
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignRight

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 122
                    spacing: 10

                    ColumnLayout {
                        Layout.preferredWidth: 122
                        Layout.maximumWidth: 122
                        Layout.fillHeight: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 122
                            Layout.fillWidth: false
                            Layout.preferredHeight: 56
                            radius: height / 2
                            color: "#222222"

                            RowLayout {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 16
                                spacing: 8

                                Text {
                                    text: "\uf1eb"
                                    font.family: "Font Awesome 6 Free"
                                    font.pixelSize: 14
                                    color: "#ffffff"
                                }

                                Text {
                                    text: "Wi-Fi"
                                    font.family: root.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                            }
                        }

                        RowLayout {
                            Layout.preferredWidth: 122
                            Layout.preferredHeight: 56
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                radius: 28
                                color: "#222222"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf293"
                                    font.family: "Font Awesome 6 Free"
                                    font.pixelSize: 18
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                radius: 28
                                color: "#222222"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf186"
                                    font.family: "Font Awesome 6 Free"
                                    font.pixelSize: 16
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 32
                        color: "#222222"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "\uf04b"
                                font.family: "Font Awesome 6 Free"
                                font.pixelSize: 18
                                color: "#ffffff"
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "media\nplay"
                                horizontalAlignment: Text.AlignHCenter
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: height / 2
                    color: "#222222"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * 0.96
                        radius: parent.radius
                        color: "#333333"
                    }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18

                        RowLayout {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: "\uf185"
                                font.family: "Font Awesome 6 Free"
                                font.pixelSize: 14
                                color: "#ffffff"
                            }

                            Text {
                                text: "Brightness"
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "96%"
                            font.family: root.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: height / 2
                    color: "#222222"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * 0.69
                        radius: parent.radius
                        color: "#333333"
                    }

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18

                        RowLayout {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: "\uf028"
                                font.family: "Font Awesome 6 Free"
                                font.pixelSize: 14
                                color: "#ffffff"
                            }

                            Text {
                                text: "Sound"
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: "#ffffff"
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "69%"
                            font.family: root.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                    }
                }
            }
        }
    }
}