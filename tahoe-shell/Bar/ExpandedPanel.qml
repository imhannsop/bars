import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

Item {
    id: root

    property string fontFamily: "SF Pro Display"
    property string fontAwesomeFont: "Font Awesome 6 Free"
    property real notchRadius: 30

    readonly property bool isExpanded: root.Window?.window?.expanded ?? false
    readonly property real animationProgress: root.Window?.window?.expandedContentOpacity ?? 0.0
    readonly property bool selectorExpanded: outputSelector.expanded
    readonly property MprisPlayer activePlayer: Mpris.players.values[0] ?? null

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink
    // audio is present as soon as the node is known to be an audio node, but
    // its volume/muted values are invalid (and writes are dropped) until the
    // node is actually bound via PwObjectTracker below — hence the `ready` check.
    readonly property bool audioReady: Pipewire.ready && !!root.defaultSink?.audio && !!root.defaultSink?.ready
    readonly property real volumeVal: root.audioReady
        ? Math.min(1.0, Math.max(0.0, root.defaultSink.audio.volume))
        : 0.0
    readonly property bool isMuted: root.audioReady ? root.defaultSink.audio.muted : false

    // Every physical/virtual sink, not application streams. Deliberately NOT
    // filtered on n.audio here: a node's .audio object only gets populated
    // once it's bound via PwObjectTracker below, and PwObjectTracker only
    // binds nodes it's given. Filtering on n.audio up front would make that
    // a chicken-and-egg — a freshly connected device (e.g. Bluetooth
    // headphones just paired) would never get bound, so .audio would never
    // populate, so it would never pass the filter. Track everything so any
    // active sink is bound (and thus shows up) as soon as PipeWire reports it.
    readonly property var allSinkNodes: {
        let list = []
        for (const n of Pipewire.nodes.values) {
            if (n.isSink && !n.isStream) list.push(n)
        }
        return list
    }

    // What the selector actually lists. Includes devices whose .audio hasn't
    // finished binding yet (e.g. the instant a Bluetooth device connects) so
    // they appear immediately rather than popping in a moment later.
    readonly property var outputDevices: root.allSinkNodes

    PwObjectTracker {
        // Track every sink (so newly-appearing devices get bound and their
        // .audio populates) plus the current default sink explicitly, since
        // it can briefly be a node not yet present in allSinkNodes while
        // devices switch — that gap is what caused the volume slider/mute
        // toggle to stop reaching pipewire before.
        objects: root.defaultSink && !root.allSinkNodes.includes(root.defaultSink)
            ? [...root.allSinkNodes, root.defaultSink]
            : root.allSinkNodes
    }

    function updateAudioVolume(ratio) {
        if (!root.audioReady) return
        const clamped = Math.min(1.0, Math.max(0.0, ratio))
        root.defaultSink.audio.volume = clamped
    }

    function toggleMute() {
        if (!root.audioReady) return
        root.defaultSink.audio.muted = !root.defaultSink.audio.muted
    }

    function setOutputDevice(node) {
        // PipeWire may keep the old sink briefly while the switch completes.
        Pipewire.preferredDefaultAudioSink = node
    }

    function rawDeviceLabel(node) {
        if (!node) return "Unknown"
        if (node.nickname && node.nickname.length > 0) return node.nickname
        if (node.description && node.description.length > 0) return node.description
        return node.name ?? "Unknown Device"
    }

    // How many currently-listed devices share each raw label, so
    // deviceLabel() below can tell duplicates apart.
    readonly property var deviceLabelCounts: {
        let counts = {}
        for (const n of root.outputDevices) {
            const label = root.rawDeviceLabel(n)
            counts[label] = (counts[label] || 0) + 1
        }
        return counts
    }

    function deviceLabel(node) {
        if (!node) return "Unknown"
        const label = root.rawDeviceLabel(node)
        // node.name is the underlying PipeWire object name, always unique -
        // use it to disambiguate when two devices render the same label.
        if ((root.deviceLabelCounts[label] || 0) > 1 && node.name) {
            return `${label} (${node.name})`
        }
        return label
    }

    function getArtistString(player) {
        if (!player) return "Media System"
        let artists = player.trackArtists
        if (typeof artists === "string" && artists.length > 0) return artists
        if (Array.isArray(artists) && artists.length > 0) return artists.join(", ")
        if (artists && artists.length > 0) return String(artists)
        if (player.trackArtist) return String(player.trackArtist)
        return "Unknown Artist"
    }

    // Wi-Fi
    property bool wifiActive: false
    Process {
        id: wifiReadProc
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser {
            onRead: data => root.wifiActive = (data.trim() === "enabled")
        }
        Component.onCompleted: running = true
    }
    Process {
        id: wifiToggleProc
        command: ["nmcli", "radio", "wifi", root.wifiActive ? "off" : "on"]
        onExited: wifiReadProc.running = true
    }

    // Bluetooth
    property bool bluetoothActive: false
    Process {
        id: btReadProc
        command: ["bluetoothctl", "show"]
        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("Powered: yes") !== -1) root.bluetoothActive = true
                else if (data.indexOf("Powered: no") !== -1) root.bluetoothActive = false
            }
        }
        Component.onCompleted: running = true
    }
    Process {
        id: btToggleProc
        command: ["bluetoothctl", "power", root.bluetoothActive ? "off" : "on"]
        onExited: btReadProc.running = true
    }

    // Do not disturb
    property bool dndActive: false
    Process {
        id: dndReadProc
        command: ["sh", "-c", "if command -v makoctl >/dev/null 2>&1; then exec makoctl mode; elif command -v dunstctl >/dev/null 2>&1; then exec dunstctl is-paused; fi"]
        stdout: SplitParser {
            onRead: data => root.dndActive = data.indexOf("do-not-disturb") !== -1 || data.trim() === "true"
        }
        Component.onCompleted: running = true
    }
    Process {
        id: dndToggleProc
        command: ["sh", "-c", "if command -v makoctl >/dev/null 2>&1; then exec makoctl mode -t do-not-disturb; elif command -v dunstctl >/dev/null 2>&1; then exec dunstctl set-paused toggle; fi"]
        onExited: dndReadProc.running = true
    }

    // Brightness
    property real brightnessPercent: 1.0
    Process {
        id: brightnessReadProc
        command: ["brightnessctl", "g"]
        stdout: SplitParser {
            onRead: data => {
                let current = parseFloat(data)
                if (!isNaN(current) && maxBrightnessProc.maxVal > 0) {
                    root.brightnessPercent = Math.min(1.0, Math.max(0.0, current / maxBrightnessProc.maxVal))
                }
            }
        }
    }
    Process {
        id: maxBrightnessProc
        property real maxVal: 1.0
        command: ["brightnessctl", "m"]
        stdout: SplitParser {
            onRead: data => {
                let m = parseFloat(data)
                if (!isNaN(m) && m > 0) {
                    maxBrightnessProc.maxVal = m
                    brightnessReadProc.running = true
                }
            }
        }
        Component.onCompleted: running = true
    }
    Process {
        id: setBrightnessProc
        property string targetValue: "100%"
        command: ["brightnessctl", "set", targetValue]
    }

    function updateBrightness(ratio) {
        root.brightnessPercent = Math.min(1.0, Math.max(0.0, ratio))
        let pct = Math.round(root.brightnessPercent * 100)
        setBrightnessProc.targetValue = pct + "%"
        setBrightnessProc.running = true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            wifiReadProc.running = true
            btReadProc.running = true
            dndReadProc.running = true
            if (maxBrightnessProc.maxVal > 0) brightnessReadProc.running = true
        }
    }

    transform: Translate {
        y: (1.0 - root.animationProgress) * -12

        Behavior on y {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
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
            Layout.preferredWidth: 400
            Layout.maximumWidth: 400
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignRight
            clip: false

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Toggles and media controls
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 122
                    Layout.maximumHeight: 122
                    spacing: 10

                    ColumnLayout {
                        Layout.preferredWidth: 165
                        Layout.maximumWidth: 165
                        Layout.fillHeight: true
                        spacing: 10

                        // Wi-Fi toggle
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            radius: 15
                            
                            // Background: Solid white when active, dark grey (#222222) when inactive
                            color: root.wifiActive ? "#ffffff" : "#222222"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 22
                                spacing: 12

                                Text {
                                    text: "\uf1eb"
                                    font.family: root.fontAwesomeFont
                                    font.pixelSize: 22
                                    // Swaps to black (#000000) when active
                                    color: root.wifiActive ? "#000000" : "#888888"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: "Wi-Fi"
                                    font.family: root.fontFamily
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                    // Swaps to black (#000000) when active
                                    color: root.wifiActive ? "#000000" : "#888888"
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wifiToggleProc.running = true
                            }
                        }

                       // Bluetooth and do-not-disturb toggles
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            spacing: 10

                            // Bluetooth Toggle
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                radius: 15
                                color: root.bluetoothActive ? "#ffffff" : "#222222"

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf294"
                                    font.family: root.fontAwesomeFont
                                    font.pixelSize: 22
                                    color: root.bluetoothActive ? "#000000" : "#888888"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: btToggleProc.running = true
                                }
                            }

                            // Do Not Disturb Toggle
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                radius: 15
                                color: root.dndActive ? "#ffffff" : "#222222"

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf186"
                                    font.family: root.fontAwesomeFont
                                    font.pixelSize: 22
                                    color: root.dndActive ? "#000000" : "#888888"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: dndToggleProc.running = true
                                }
                            }
                        }
                    }

                    // Media player
                    Rectangle {
                        id: mediaCard
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 15
                        color: "#222222"
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 14

                                // Square album art, sized to fill the
                                // card's height (matches the reference:
                                // the art dominates the left side).
                                Rectangle {
                                    id: albumArtBg
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: albumArtBg.height
                                    radius: 14
                                    color: "#3a3a3a"
                                    clip: true

                                    Image {
                                        id: albumArt
                                        anchors.fill: parent
                                        
                                        // Convert local file paths or URLs provided by MPRIS to valid QML Image sources
                                        source: {
                                            let url = root.activePlayer?.artUrl ?? ""
                                            if (!url) return ""
                                            // Handle local paths without file:// protocol prefix
                                            if (url.startsWith("/")) return "file://" + url
                                            return url
                                        }
                                        
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true  // Prevents UI stutters when downloading album art
                                        cache: false         // Forces refresh when playing a new track with the same filename/URL
                                        visible: status === Image.Ready && source != ""
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf001"
                                        font.family: root.fontAwesomeFont
                                        font.pixelSize: 22
                                        color: "#666666"
                                        visible: !albumArt.visible
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 8
                                        text: root.activePlayer?.trackTitle || "Not Playing"
                                        font.family: root.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: "#ffffff"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.getArtistString(root.activePlayer)
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                        color: "#aaaaaa"
                                        elide: Text.ElideRight
                                    }

                                    Item { Layout.fillHeight: true }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignLeft
                                        spacing: 16

                                        Text {
                                            text: "\uf048"
                                            font.family: root.fontAwesomeFont
                                            font.pixelSize: 13
                                            color: root.activePlayer?.canGoPrevious ? "#ffffff" : "#555555"

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: root.activePlayer?.canGoPrevious ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous()
                                            }
                                        }

                                        Text {
                                            text: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) ? "\uf04c" : "\uf04b"
                                            font.family: root.fontAwesomeFont
                                            font.pixelSize: 16
                                            color: root.activePlayer ? "#ffffff" : "#555555"

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: if (root.activePlayer) root.activePlayer.togglePlaying()
                                            }
                                        }

                                        Text {
                                            text: "\uf051"
                                            font.family: root.fontAwesomeFont
                                            font.pixelSize: 13
                                            color: root.activePlayer?.canGoNext ? "#ffffff" : "#555555"

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: root.activePlayer?.canGoNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next()
                                            }
                                        }
                                    }
                                }
                            }

                            // Progress bar spans the full card width,
                            // under both the art and the text/controls —
                            // matching the reference layout.
                            Item {
                                id: progressContainer
                                Layout.fillWidth: true
                                Layout.preferredHeight: 10

                                readonly property real progressRatio: {
                                    if (!root.activePlayer || root.activePlayer.length <= 0) return 0.0
                                    return Math.min(1.0, Math.max(0.0, root.activePlayer.position / root.activePlayer.length))
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 4
                                    radius: 2
                                    color: "#333333"

                                    Rectangle {
                                        width: parent.width * progressContainer.progressRatio
                                        height: parent.height
                                        radius: parent.radius
                                        color: "#ffffff"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (root.activePlayer && root.activePlayer.length > 0) {
                                            root.activePlayer.position = (mouse.x / width) * root.activePlayer.length
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Output device selector state. The visible trigger is now
                // a small circular chevron button embedded at the end of
                // the volume pill below (id: outputDeviceButton) — this
                // Item just owns the expand/collapse state and keeps the
                // floating popup wired up regardless of where its trigger
                // lives in the layout.
                Item {
                    id: outputSelector
                    visible: false
                    Layout.preferredWidth: 0
                    Layout.preferredHeight: 0

                    property bool expanded: false
                    readonly property bool hasChoices: root.outputDevices.length > 1

                    // Collapse automatically whenever the panel itself
                    // collapses, so it never reopens already-expanded.
                    Connections {
                        target: root
                        function onIsExpandedChanged() {
                            if (!root.isExpanded) outputSelector.expanded = false
                        }
                    }

                    // Open/close the floating popup window in step with
                    // `expanded`. The popup is a real top-level surface now
                    // (see OutputDevicePopup.qml) — no layout here can clip
                    // or squeeze it regardless of how it's driven.
                    onExpandedChanged: {
                        if (expanded) outputDevicePopup.open()
                        else outputDevicePopup.close()
                    }

                    // The device list is a fully separate top-level popup
                    // surface — see OutputDevicePopup.qml. It renders
                    // outside this Item, this ColumnLayout, and this panel
                    // entirely, so no ancestor layout can ever clip or
                    // squeeze it again.
                    OutputDevicePopup {
                        id: outputDevicePopup

                        // --- pass-through: parent -> popup ---
                        anchorItem: outputDeviceButton
                        parentWindow: root.Window?.window ?? null
                        devices: root.outputDevices
                        currentSink: root.defaultSink
                        labelForNode: root.deviceLabel
                        fontFamily: root.fontFamily
                        fontAwesomeFont: root.fontAwesomeFont

                        // --- pass-through: popup -> parent ---
                        onDeviceChosen: (node) => {
                            root.setOutputDevice(node)
                            outputSelector.expanded = false
                        }
                        onDismissed: outputSelector.expanded = false
                    }
                }

                // Volume
                Rectangle {
                    id: soundPill
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: 15
                    color: "#1e1e22"
                    clip: true

                    function volumeIconGlyph() {
                        if (root.isMuted || root.volumeVal <= 0) return "\uf026"
                        if (root.volumeVal < 0.5) return "\uf027"
                        return "\uf028"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 14
                        spacing: 16

                        Text {
                            text: soundPill.volumeIconGlyph()
                            font.family: root.fontAwesomeFont
                            font.pixelSize: 22
                            color: root.isMuted ? "#55555a" : "#ffffff"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Track + thumb
                        Item {
                            id: soundSliderTrack
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 4
                                radius: 2
                                color: "#3a3a40"
                            }

                            Rectangle {
                                id: soundThumb
                                width: 22; height: 22; radius: 11
                                color: "#ffffff"
                                y: (soundSliderTrack.height - height) / 2
                                x: Math.max(0, Math.min(soundSliderTrack.width - width,
                                    soundSliderTrack.width * root.volumeVal - width / 2))

                                Behavior on x {
                                    enabled: !soundDragArea.pressed
                                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea {
                                id: soundDragArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton
                                function setVolume(mouseX) {
                                    root.updateAudioVolume(mouseX / width)
                                }
                                onPressed: (mouse) => setVolume(mouse.x)
                                onPositionChanged: (mouse) => {
                                    if (pressed) setVolume(mouse.x)
                                }
                                onClicked: (mouse) => setVolume(mouse.x)
                                onWheel: (wheel) => {
                                    if (!root.audioReady) return
                                    const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                    root.updateAudioVolume(root.volumeVal + step)
                                }
                            }
                        }

                        // Decorative "loud" reference icon
                        Text {
                            text: "\uf028"
                            font.family: root.fontAwesomeFont
                            font.pixelSize: 20
                            color: "#ffffff"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Output device dropdown trigger
                        Rectangle {
                            id: outputDeviceButton
                            visible: root.outputDevices.length > 0
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            Layout.alignment: Qt.AlignVCenter
                            radius: 100
                            color: outputDeviceButtonArea.containsMouse ? "#E6E6E6" : "#ffffff"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf0d7" // FontAwesome icon for angle-right (>)
                                font.family: root.fontAwesomeFont
                                font.pixelSize: 11
                                color: "#000000"
                                
                                // Rotates 90 degrees when expanded so it points downward 
                                rotation: outputSelector.expanded ? -90 : 0
                                transformOrigin: Item.Center

                                Behavior on rotation {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea {
                                id: outputDeviceButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: outputSelector.hasChoices ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: outputSelector.hasChoices
                                onClicked: outputSelector.expanded = !outputSelector.expanded
                            }
                        }
                    }
                }


                // Brightness
                Rectangle {
                    id: brightnessTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: 15
                    color: "#1e1e22"
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 16

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 15
                            color: "transparent"
                            border.color: "#ffffff"
                            border.width: 3
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            id: brightnessSliderTrack
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 4
                                radius: 2
                                color: "#3a3a40"
                            }

                            Rectangle {
                                id: brightnessThumb
                                width: 22; height: 22; radius: 11
                                color: "#ffffff"
                                y: (brightnessSliderTrack.height - height) / 2
                                x: Math.max(0, Math.min(brightnessSliderTrack.width - width,
                                    brightnessSliderTrack.width * root.brightnessPercent - width / 2))

                                Behavior on x {
                                    enabled: !brightnessDragArea.pressed
                                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea {
                                id: brightnessDragArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: (mouse) => root.updateBrightness(mouse.x / width)
                                onClicked: (mouse) => root.updateBrightness(mouse.x / width)
                            }
                        }

                        Text {
                            text: "\uf042"
                            font.family: root.fontAwesomeFont
                            font.pixelSize: 22
                            color: "#ffffff"
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}