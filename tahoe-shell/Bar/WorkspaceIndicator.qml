import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int dotSize: 14
    property int ringSize: 16
    property int ringBorder: 4
    property int dotSpacing: 9
    property color inactiveColor: "#ffffff"
    property color ringColor: "#ffffff"
    property color bgColor: "#000000"
    property int animDuration: 180

    // Match Niri's easing for workspace indicator motion.
    readonly property var niriCurve: [0.25, 1.0, 0.5, 1.0, 1.0, 1.0]

    property bool standalone: true
    property var workspaces: []
    property int focusedIndex: -1

    implicitWidth: dotsRow.implicitWidth
    implicitHeight: ringSize

    function rebuildFromList(list) {
        var arr = []
        for (var i = 0; i < list.length; i++) {
            arr.push({
                id: list[i].id,
                idx: list[i].idx,
                isFocused: !!list[i].is_focused
            })
        }
        arr.sort(function (a, b) { return a.idx - b.idx })
        workspaces = arr
        updateFocusedIndex()
    }

    function setFocusedById(wsId) {
        var updated = workspaces.slice()
        for (var i = 0; i < updated.length; i++)
            updated[i].isFocused = (updated[i].id === wsId)
        workspaces = updated
        updateFocusedIndex()
    }

    function updateFocusedIndex() {
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i].isFocused) {
                focusedIndex = i
                return
            }
        }
        focusedIndex = -1
    }

    function focusWorkspace(wsIdx) {
        switchProcess.command = ["niri", "msg", "action", "focus-workspace", String(wsIdx)]
        switchProcess.running = true
    }

    Process {
        id: eventStream
        command: ["niri", "msg", "--json", "event-stream"]
        running: root.standalone

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data || data.trim().length === 0) return
                var evt
                try { evt = JSON.parse(data) } catch (e) { return }

                if (evt.WorkspacesChanged) {
                    root.rebuildFromList(evt.WorkspacesChanged.workspaces)
                } else if (evt.WorkspaceActivated) {
                    root.setFocusedById(evt.WorkspaceActivated.id)
                }
            }
        }

        onExited: (exitCode, exitStatus) => { if (root.standalone) restartTimer.start() }
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: eventStream.running = true
    }

    Process { id: switchProcess }

    Row {
        id: dotsRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.dotSpacing

        Repeater {
            model: root.workspaces

            delegate: Item {
                width: root.ringSize
                height: root.ringSize

                Rectangle {
                    anchors.centerIn: parent
                    width: root.dotSize
                    height: root.dotSize
                    radius: width / 2
                    color: root.inactiveColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(modelData.idx)
                }
            }
        }
    }

    Rectangle {
        id: activeRing
        width: root.ringSize
        height: root.ringSize
        radius: width / 2
        color: "transparent"
        border.color: root.ringColor
        border.width: root.ringBorder
        visible: root.focusedIndex >= 0
        y: dotsRow.y + (dotsRow.height - height) / 2

        x: root.focusedIndex >= 0
           ? dotsRow.x + root.focusedIndex * (root.ringSize + root.dotSpacing)
           : 0
    }

    Rectangle {
        id: maskDot
        width: root.ringSize - root.ringBorder * 2
        height: width
        radius: width / 2
        color: root.bgColor
        visible: root.focusedIndex >= 0
        y: dotsRow.y + (dotsRow.height - height) / 2

        x: root.focusedIndex >= 0
           ? dotsRow.x + root.focusedIndex * (root.ringSize + root.dotSpacing) + root.ringBorder
           : root.ringBorder

        Behavior on x {
            NumberAnimation {
                duration: root.animDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.niriCurve
            }
        }
    }
}