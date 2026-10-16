import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root

    signal requestClose()
    signal requestToggle()
    signal launchRequested()

    property string fontFamily: Theme.fontFamily
    property string fontAwesomeFont: Theme.fontAwesomeFont
    property bool expanded: false
    property string keycapText: "ESC"
    property real compactWidth: 460
    property real expandedWidth: 560
    property var results: []
    property var shownResults: []
    property var counts: ({})
    property string query: ""
    property int modeIndex: 0
    property int currentIndex: -1
    property bool snapping: false
    property bool busy: false
    property bool filesDirty: false
    property bool clipMissing: false
    property bool clipLoaded: false
    property var clipItems: []

    readonly property int rowHeight: 44
    readonly property int barHeight: 56
    readonly property int rowGap: 4
    readonly property int rowPadding: 12
    readonly property int maxRows: 8
    readonly property string countsPath: Quickshell.env("HOME") + "/.local/state/quickshell/app-launch-counts.json"
    readonly property color primaryColor: "#ffffff"
    readonly property color secondaryColor: "#a4a4ad"
    readonly property color mutedColor: "#707079"
    readonly property color accentColor: "#d0d0d6"
    readonly property color selectedRowColor: "#17171b"
    readonly property color iconBackgroundColor: "#000000"

    readonly property var modes: [
        { name: "Applications", glyph: "\uf009", placeholder: "Search apps" },
        { name: "Files", glyph: "\uf07b", placeholder: "Search files" },
        { name: "Actions", glyph: "\uf0e7", placeholder: "Run an action" },
        { name: "Clipboard", glyph: "\uf328", placeholder: "Search clipboard" }
    ]
    readonly property string fileScript:
        'printf "%s\\n" "$1"; ' +
        '{ if command -v fd >/dev/null; then fd -F -i -t f -t d --max-results 60 -- "$1" "$HOME"; ' +
        'else find "$HOME" -maxdepth 6 -iname "*$1*" -not -path "*/.*" 2>/dev/null | head -60; fi; } | ' +
        'while IFS= read -r p; do if [ -d "$p" ]; then printf "d\\t%s\\n" "$p"; else printf "f\\t%s\\n" "$p"; fi; done'
    readonly property var actions: [
        { name: "Lock", genericName: "Lock the session", glyph: "\uf023", command: ["loginctl", "lock-session"] },
        { name: "Suspend", genericName: "Sleep until woken", glyph: "\uf186", command: ["systemctl", "suspend"] },
        { name: "Log Out", genericName: "Quit niri", glyph: "\uf2f5", command: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
        { name: "Restart", genericName: "Reboot the machine", glyph: "\uf2f9", command: ["systemctl", "reboot"] },
        { name: "Shut Down", genericName: "Power off", glyph: "\uf011", command: ["systemctl", "poweroff"] }
    ]

    readonly property string emptyText: {
        if (busy) return ""
        if (modeIndex === 3 && clipMissing) return "Install cliphist and wl-clipboard to use this"
        if (results.length > 0) return ""
        if (query.trim().length > 0) return "No results for \u201C" + query.trim() + "\u201D"
        return modeIndex === 3 && clipLoaded ? "Clipboard history is empty" : ""
    }
    readonly property bool showEmpty: results.length === 0 && emptyText.length > 0
    readonly property int resultsHeight: {
        if (results.length > 0) {
            const pad = rowPadding * 2
            const rows = Math.min(results.length, maxRows)
            return rows * rowHeight + (rows - 1) * rowGap + pad
        }
        return showEmpty ? rowHeight + rowPadding * 2 : 0
    }

    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    width: expanded ? expandedWidth : compactWidth
    height: barHeight + (resultsSurface.height > 0 ? 8 + resultsSurface.height : 0)

    Behavior on width {
        NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0] }
    }
    Behavior on height {
        NumberAnimation { duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0] }
    }

    function isSubsequence(q, s) {
        let i = 0
        for (let c of s) {
            if (c === q[i]) i++
            if (i === q.length) return true
        }
        return false
    }

    function score(item, q) {
        const name = item.name.toLowerCase()
        const words = name.split(/[\s\-_.]+/)
        let s = 0
        if (name === q) s = 1000
        else if (name.startsWith(q)) s = 800
        else if (words.some(w => w.startsWith(q))) s = 600
        else if (words.map(w => w[0]).join("").startsWith(q)) s = 500
        else if (name.includes(q)) s = 400
        else if (q.length > 1 && isSubsequence(q, name)) s = 200
        else if ((item.genericName || "").toLowerCase().includes(q)) s = 150
        else if (Array.from(item.keywords || []).some(k => k.toLowerCase().includes(q))) s = 100
        return s ? s + Math.min(counts[item.id] || 0, 30) * 5 : 0
    }

    function rank(items, q) {
        return Array.from(items)
            .filter(item => !item.noDisplay)
            .map(item => ({ item, s: score(item, q) }))
            .filter(r => r.s > 0)
            .sort((a, b) => b.s - a.s
                || a.item.name.length - b.item.name.length
                || a.item.name.localeCompare(b.item.name))
            .slice(0, 20)
            .map(r => r.item)
    }

    function show(found) {
        scrollAnim.stop()
        if (found.length > 0) shownResults = found
        snapping = true
        results = found
        currentIndex = found.length > 0 ? 0 : -1
        snapping = false
        appList.positionViewAtBeginning()
    }

    function search() {
        const q = query.trim().toLowerCase()
        if (modeIndex === 0) {
            show(q ? rank(DesktopEntries.applications.values, q) : [])
        } else if (modeIndex === 1) {
            if (q) {
                busy = true
                fileTimer.restart()
            } else {
                fileTimer.stop()
                busy = false
                show([])
            }
        } else if (modeIndex === 2) {
            show(q ? rank(actions, q) : actions)
        } else {
            show(clipItems.filter(c => c.name.toLowerCase().includes(q)).slice(0, 20))
        }
    }

    function runFiles() {
        if (fileProc.running) {
            filesDirty = true
            return
        }
        fileProc.command = ["sh", "-c", fileScript, "sh", query.trim()]
        fileProc.running = true
    }

    function applyFiles(text) {
        const lines = text.split("\n")
        const q = lines[0]
        if (q !== query.trim()) return
        const home = Quickshell.env("HOME")
        const lowered = q.toLowerCase()
        const items = lines.slice(1).filter(l => l.length > 2).map(l => {
            const path = l.slice(2).replace(/\/$/, "")
            const dir = path.slice(0, path.lastIndexOf("/"))
            return {
                name: path.slice(path.lastIndexOf("/") + 1),
                genericName: dir.startsWith(home) ? "~" + dir.slice(home.length) : dir,
                glyph: l[0] === "d" ? "\uf07b" : "\uf15b",
                command: ["setsid", "-f", "xdg-open", path]
            }
        })
        const rk = item => item.name.toLowerCase().startsWith(lowered) ? 0 : 1
        items.sort((a, b) => rk(a) - rk(b) || a.name.length - b.name.length)
        busy = false
        show(items.slice(0, 30))
    }

    function loadClipboard() {
        if (clipProc.running) return
        busy = true
        clipLoaded = false
        clipProc.running = true
    }

    function applyClip(text) {
        const lines = text.split("\n").filter(l => l.length > 0)
        busy = false
        clipLoaded = true
        clipMissing = lines[0] === "__missing__"
        clipItems = clipMissing ? [] : lines.map(l => {
            const tab = l.indexOf("\t")
            const preview = l.slice(tab + 1).trim()
            const image = preview.startsWith("[[ binary data")
            return {
                name: image ? "Image" : preview.slice(0, 200),
                genericName: image ? preview.replace(/^\[\[ binary data (.*) \]\]$/, "$1") : "",
                glyph: image ? "\uf03e" : "\uf0ea",
                command: ["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", l.slice(0, tab)]
            }
        })
        if (modeIndex === 3) search()
    }

    function bump(id) {
        if (!id) return
        counts[id] = (counts[id] || 0) + 1
        saver.command = ["sh", "-c", 'mkdir -p "${1%/*}" && printf %s "$2" > "$1"', "sh", countsPath, JSON.stringify(counts)]
        saver.running = true
    }

    function launch(item) {
        if (!item) return
        if (typeof item.execute === "function") {
            item.execute()
            bump(item.id)
        } else if (item.command) {
            runner.command = item.command
            runner.running = true
        } else {
            return
        }
        root.launchRequested()
        root.requestClose()
    }

    function ensureVisible(i) {
        const top = i * (rowHeight + rowGap)
        const bottom = top + rowHeight
        let target = appList.contentY
        if (top < target) target = top
        else if (bottom > target + appList.height) target = bottom - appList.height
        if (target === appList.contentY) return
        scrollAnim.to = target
        scrollAnim.restart()
    }

    function moveSelection(step, clamp) {
        const n = results.length
        if (n === 0) return
        currentIndex = clamp
            ? Math.max(0, Math.min(n - 1, currentIndex + step))
            : (currentIndex + step + n) % n
        ensureVisible(currentIndex)
    }

    function setMode(index) {
        modeIndex = (index + modes.length) % modes.length
        busy = false
        fileTimer.stop()
        show([])
        if (modeIndex === 3) loadClipboard()
        search()
        focusSearch()
    }

    function cycleMode(step) {
        setMode(modeIndex + step)
    }

    function reset() {
        searchField.clear()
        modeIndex = 0
        busy = false
        fileTimer.stop()
        search()
    }

    function prepareClose() {
        show([])
    }

    function focusSearch() {
        searchField.forceActiveFocus()
    }

    NumberAnimation {
        id: scrollAnim
        target: appList
        property: "contentY"
        duration: 120
        easing.type: Easing.OutCubic
    }

    Process {
        command: ["cat", root.countsPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.counts = JSON.parse(text) } catch (e) {}
            }
        }
    }

    Timer {
        id: fileTimer
        interval: 150
        onTriggered: root.runFiles()
    }

    Process {
        id: fileProc
        stdout: StdioCollector {
            onStreamFinished: root.applyFiles(text)
        }
        onExited: {
            if (root.filesDirty) {
                root.filesDirty = false
                root.runFiles()
            }
        }
    }

    Process {
        id: clipProc
        command: ["sh", "-c", "command -v cliphist >/dev/null || { echo __missing__; exit; }; cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: root.applyClip(text)
        }
    }

    Process { id: saver }
    Process { id: runner }

    RowLayout {
        id: mainLayout
        z: 2
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: root.barHeight
        spacing: 8

        Rectangle {
            id: searchSurface
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: height / 2
            color: "#000000"
            clip: true
            border.width: 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 16
                spacing: 14

                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20

                    Rectangle {
                        x: 2
                        y: 2
                        width: 11
                        height: 11
                        radius: 6
                        color: "transparent"
                        border.width: 2
                        border.color: root.primaryColor
                    }

                    Rectangle {
                        x: 12
                        y: 13
                        width: 7
                        height: 2
                        radius: 1
                        color: root.primaryColor
                        rotation: 45
                        transformOrigin: Item.Left
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TextField {
                        id: searchField
                        anchors.left: parent.left
                        anchors.right: keycap.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        clip: true
                        color: root.primaryColor
                        placeholderTextColor: root.mutedColor
                        selectionColor: Qt.rgba(1, 1, 1, 0.3)
                        selectedTextColor: root.primaryColor
                        placeholderText: root.modes[root.modeIndex].placeholder
                        font.family: root.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: 15
                        background: null
                        selectByMouse: true
                        activeFocusOnTab: false

                        onTextChanged: {
                            root.query = text
                            root.search()
                        }

                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier
                            const alt = event.modifiers & Qt.AltModifier
                            event.accepted = true

                            switch (event.key) {
                            case Qt.Key_Down: root.moveSelection(1, false); return
                            case Qt.Key_Up: root.moveSelection(-1, false); return
                            case Qt.Key_PageDown: root.moveSelection(5, true); return
                            case Qt.Key_PageUp: root.moveSelection(-5, true); return
                            case Qt.Key_Tab: root.cycleMode(1); return
                            case Qt.Key_Backtab: root.cycleMode(-1); return
                            case Qt.Key_Return:
                            case Qt.Key_Enter: root.launch(root.results[root.currentIndex]); return
                            case Qt.Key_Escape: root.requestClose(); return
                            }

                            if (ctrl) {
                                switch (event.key) {
                                case Qt.Key_N:
                                case Qt.Key_J: root.moveSelection(1, false); return
                                case Qt.Key_P:
                                case Qt.Key_K: root.moveSelection(-1, false); return
                                case Qt.Key_U: searchField.clear(); return
                                }
                            }

                            if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                                root.setMode(event.key - Qt.Key_1)
                                return
                            }

                            if (event.key === Qt.Key_D && (event.modifiers & Qt.MetaModifier)) {
                                root.requestToggle()
                                return
                            }

                            event.accepted = false
                        }
                    }

                    Rectangle {
                        id: keycap
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 26
                        radius: 13
                        color: "#111114"
                        border.width: 1
                        border.color: "#303036"

                        Text {
                            anchors.centerIn: parent
                            text: root.keycapText.toLowerCase()
                            color: root.secondaryColor
                            font.family: root.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 10
                            font.letterSpacing: 0.3
                        }
                    }
                }
            }
        }

    }

    DarkSurface {
        id: resultsSurface
        z: 1
        anchors.top: parent.top
        anchors.topMargin: root.barHeight + 8
        width: parent.width
        height: root.resultsHeight
        cornerRadius: root.barHeight / 2
        border.width: 0
        opacity: height > 0 ? 1 : 0
        visible: opacity > 0

        Behavior on height {
            NumberAnimation {
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Text {
            anchors.centerIn: parent
            visible: root.showEmpty
            z: 1
            text: root.emptyText
            color: root.mutedColor
            font.family: root.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 12
        }

        Rectangle {
            z: 1
            visible: root.currentIndex >= 0 && !root.showEmpty
            x: root.rowPadding
            y: root.rowPadding + highlightIndex * (root.rowHeight + root.rowGap) - appList.contentY
            width: parent.width - root.rowPadding * 2
            height: root.rowHeight
            radius: root.rowHeight / 2
            color: root.selectedRowColor
            property real highlightIndex: root.currentIndex

            Behavior on highlightIndex {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
        }

        ListView {
            id: appList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.rowPadding
            anchors.rightMargin: root.rowPadding
            anchors.topMargin: root.rowPadding
            anchors.bottomMargin: root.rowPadding
            z: 2
            visible: !root.showEmpty
            clip: true
            spacing: root.rowGap
            model: root.shownResults
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            onMovementStarted: scrollAnim.stop()

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: appList.width
                height: root.rowHeight

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28

                        Image {
                            id: icon
                            anchors.fill: parent
                            source: row.modelData.glyph ? "" : Quickshell.iconPath(row.modelData.icon || "application-x-executable", true)
                            sourceSize: Qt.size(28, 28)
                            fillMode: Image.PreserveAspectFit
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !!row.modelData.glyph || icon.status === Image.Error
                            radius: 8
                            color: root.iconBackgroundColor

                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.glyph || row.modelData.name.charAt(0).toUpperCase()
                                color: row.modelData.glyph ? root.accentColor : root.primaryColor
                                font.family: row.modelData.glyph ? root.fontAwesomeFont : root.fontFamily
                                font.pixelSize: row.modelData.glyph ? 13 : 14
                                font.weight: row.modelData.glyph ? Font.Black : Font.Bold
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40
                        spacing: 2

                        Text {
                            width: parent.width
                            text: row.modelData.name
                            color: root.primaryColor
                            font.family: root.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: row.modelData.genericName || row.modelData.comment || ""
                            color: root.secondaryColor
                            font.family: root.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: root.currentIndex = row.index
                    onClicked: root.launch(row.modelData)
                }
            }
        }
    }
}
