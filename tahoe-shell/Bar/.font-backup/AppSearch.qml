import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root

    signal requestClose()
    signal requestToggle()

    property string fontFamily: Theme.fontFamily
    property string fontAwesomeFont: Theme.fontAwesomeFont
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

    readonly property int rowHeight: 52
    readonly property int barHeight: 44
    readonly property int rowGap: 4
    readonly property int rowPadding: 8
    readonly property int maxRows: 8
    readonly property string countsPath: Quickshell.env("HOME") + "/.local/state/quickshell/app-launch-counts.json"

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
        const pad = rowPadding * 2
        if (results.length > 0) {
            const rows = Math.min(results.length, maxRows)
            return rows * rowHeight + (rows - 1) * rowGap + pad
        }
        return showEmpty ? rowHeight + pad : 0
    }

    width: 700
    height: barHeight + (resultsSurface.height > 0 ? 8 + resultsSurface.height : 0)

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
        // boost stays under the 200 gap between tiers so frequency only reorders within a tier
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
        // keep the old rows while the panel collapses so it doesn't flash empty
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
        // output carries its own query so a slow earlier run can't overwrite newer results
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
        if (item.command) {
            runner.command = item.command
            runner.running = true
        } else {
            item.execute()
            bump(item.id)
        }
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

    DarkSurface {
        id: searchSurface
        anchors.bottom: parent.bottom
        width: parent.width - modeRow.width - 8
        height: root.barHeight
        cornerRadius: root.barHeight / 2

        Item {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20

            Rectangle {
                x: 2
                y: 2
                width: 11
                height: 11
                radius: 6
                color: "transparent"
                border.width: 2
                border.color: "#ffffff"
            }

            Rectangle {
                x: 12
                y: 13
                width: 7
                height: 2
                radius: 1
                color: "#ffffff"
                rotation: 45
                transformOrigin: Item.Left
            }
        }

        TextField {
            id: searchField
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 42
            anchors.rightMargin: 12
            height: parent.height
            placeholderText: root.modes[root.modeIndex].placeholder
            color: "#ffffff"
            placeholderTextColor: "#666666"
            font.family: root.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 16
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
    }

    Row {
        id: modeRow
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 6

        Repeater {
            model: root.modes

            delegate: DarkSurface {
                required property var modelData
                required property int index
                width: root.barHeight
                height: root.barHeight
                cornerRadius: root.barHeight / 2
                active: index === root.modeIndex
                hovered: modeMouse.containsMouse
                scale: modeMouse.pressed ? 0.94 : 1

                Behavior on scale {
                    NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.glyph
                    color: index === root.modeIndex ? "#000000" : "#ffffff"
                    font.pixelSize: 15
                    font.family: root.fontAwesomeFont
                    font.weight: Font.Black
                }

                MouseArea {
                    id: modeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.setMode(index)
                }
            }
        }
    }

    DarkSurface {
        id: resultsSurface
        anchors.bottom: searchSurface.top
        anchors.bottomMargin: 8
        width: parent.width
        height: root.resultsHeight
        cornerRadius: 24
        opacity: height > 0 ? 1 : 0
        visible: opacity > 0

        Behavior on height {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Text {
            anchors.centerIn: parent
            visible: root.showEmpty
            text: root.emptyText
            color: "#888888"
            font.family: root.fontFamily
            font.weight: Font.Bold
            font.pixelSize: 14
        }

        ListView {
            id: appList
            anchors.fill: parent
            anchors.margins: root.rowPadding
            visible: !root.showEmpty
            clip: true
            spacing: root.rowGap
            model: root.shownResults
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            onMovementStarted: scrollAnim.stop()

            Rectangle {
                z: -1
                visible: root.currentIndex >= 0
                y: root.currentIndex * (root.rowHeight + root.rowGap)
                width: appList.width
                height: root.rowHeight
                radius: 14
                color: "#222222"

                Behavior on y {
                    enabled: !root.snapping
                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                }
            }

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: appList.width
                height: root.rowHeight

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12
                    scale: rowMouse.pressed ? 0.985 : 1

                    Behavior on scale {
                        NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28

                        Image {
                            id: icon
                            anchors.fill: parent
                            source: row.modelData.glyph ? "" : Quickshell.iconPath(row.modelData.icon || "application-x-executable", "application-x-executable")
                            sourceSize: Qt.size(28, 28)
                            fillMode: Image.PreserveAspectFit
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !!row.modelData.glyph || icon.status === Image.Error
                            radius: 8
                            color: "#333333"

                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.glyph || row.modelData.name.charAt(0).toUpperCase()
                                color: "#ffffff"
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
                            color: "#ffffff"
                            font.family: root.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: row.modelData.genericName || row.modelData.comment || ""
                            color: "#888888"
                            font.family: root.fontFamily
                            font.weight: Font.Medium
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
                    // positionChanged, not entered: rows scrolling under a still cursor must not steal the selection
                    onPositionChanged: root.currentIndex = row.index
                    onClicked: root.launch(row.modelData)
                }
            }
        }
    }

    Component.onCompleted: focusSearch()
}
