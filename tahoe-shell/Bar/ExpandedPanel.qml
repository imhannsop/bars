import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "."

Item {
    id: root

    property string fontFamily: Theme.fontFamily
    property string fontAwesomeFont: Theme.fontAwesomeFont
    property real notchRadius: 30
    property int padding: 20
    property int horizontalPadding: 16
    property int outerPadding: 16

    property int gap: 12
    property int topRowHeight: 200
    property int bottomPadding: padding

    // handed in by TopBar
    property var notifications: null
    property bool autoDismissNotifications: false
    property int notificationLifetime: 8000
    // TopBar paints the date + clock and the workspace dots/battery over the left
    // column, so the column only reserves their space and gives the rest to the
    // notification tile. Both values come from the same metrics TopBar draws with.
    property real clockBlockHeight: 117
    property real sliderHeight: 55

    signal notificationDismissed(int index)
    signal notificationsCleared()
    signal notificationActivated(int index)
    readonly property int innerRadius: 16
    readonly property int columnWidth: 464

    readonly property bool isExpanded: root.Window?.window?.expanded ?? false
    readonly property real animationProgress: root.Window?.window?.expandedContentOpacity ?? 0.0
    readonly property MprisPlayer activePlayer: Mpris.players.values[0] ?? null
    readonly property bool playing: root.activePlayer?.playbackState === MprisPlaybackState.Playing

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink
    // Audio values are writable only after the node is tracked.
    readonly property bool audioReady: Pipewire.ready && !!root.defaultSink?.audio && !!root.defaultSink?.ready
    readonly property real volumeVal: root.audioReady
        ? Math.min(1.0, Math.max(0.0, root.defaultSink.audio.volume))
        : 0.0
    readonly property bool isMuted: root.audioReady ? root.defaultSink.audio.muted : false

    PwObjectTracker {
        objects: root.defaultSink ? [root.defaultSink] : []
    }

    function updateAudioVolume(ratio) {
        if (!root.audioReady) return
        root.defaultSink.audio.volume = Math.min(1.0, Math.max(0.0, ratio))
    }

    function toggleMute() {
        if (!root.audioReady) return
        root.defaultSink.audio.muted = !root.defaultSink.audio.muted
    }

    function volumeGlyph() {
        if (root.isMuted) return ""
        if (root.volumeVal <= 0) return ""
        if (root.volumeVal < 0.5) return ""
        return ""
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

    function formatTime(seconds) {
        const s = isFinite(seconds) && seconds > 0 ? seconds : 0
        const sec = Math.floor(s % 60)
        return Math.floor(s / 60) + ":" + (sec < 10 ? "0" : "") + sec
    }

    function refresh() {
        wifiReadProc.running = true
        wifiSsidProc.running = true
        btReadProc.running = true
        btDeviceProc.running = true
        nightReadProc.running = true
        if (maxBrightnessProc.maxVal > 0) brightnessReadProc.running = true
    }

    property bool wifiActive: false
    property string wifiSsid: ""
    Process {
        id: wifiReadProc
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser {
            onRead: data => root.wifiActive = (data.trim() === "enabled")
        }
    }
    Process {
        id: wifiSsidProc
        command: ["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n").find(l => l.startsWith("yes:"))
                root.wifiSsid = line ? line.slice(4).replace(/\\:/g, ":") : ""
            }
        }
    }
    Process {
        id: wifiToggleProc
        command: ["nmcli", "radio", "wifi", root.wifiActive ? "off" : "on"]
        onExited: root.refresh()
    }

    property bool bluetoothActive: false
    property string btDevice: ""
    Process {
        id: btReadProc
        command: ["bluetoothctl", "show"]
        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("Powered: yes") !== -1) root.bluetoothActive = true
                else if (data.indexOf("Powered: no") !== -1) root.bluetoothActive = false
            }
        }
    }
    Process {
        id: btDeviceProc
        command: ["sh", "-c", "bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3-"]
        stdout: StdioCollector {
            onStreamFinished: root.btDevice = text.trim()
        }
    }
    Process {
        id: btToggleProc
        command: ["bluetoothctl", "power", root.bluetoothActive ? "off" : "on"]
        onExited: root.refresh()
    }

    // Focus belongs to the bar now: TopBar owns the flag and uses it to mute the notch pop-up,
    // so there is no mako/dunst to query. The tile just reports clicks.
    property bool dndActive: false
    signal dndToggleRequested()

    property bool nightActive: false
    property bool nightAvailable: true
    Process {
        id: nightReadProc
        command: ["sh", "-c", "command -v gammastep >/dev/null || { echo missing; exit; }; pgrep -x gammastep >/dev/null && echo on || echo off"]
        stdout: StdioCollector {
            onStreamFinished: {
                const state = text.trim()
                root.nightAvailable = state !== "missing"
                root.nightActive = state === "on"
            }
        }
    }
    Process {
        id: nightToggleProc
        command: ["sh", "-c", root.nightActive ? "pkill -x gammastep" : "setsid -f gammastep -O 4000 >/dev/null 2>&1"]
        onExited: nightReadProc.running = true
    }

    property real brightnessPercent: 1.0
    property int brightnessTarget: 100
    Process {
        id: brightnessReadProc
        command: ["brightnessctl", "g"]
        stdout: SplitParser {
            onRead: data => {
                const current = parseFloat(data)
                if (isNaN(current) || maxBrightnessProc.maxVal <= 0 || brightnessSlider.dragging) return
                root.brightnessPercent = Math.min(1.0, Math.max(0.0, current / maxBrightnessProc.maxVal))
            }
        }
    }
    Process {
        id: maxBrightnessProc
        property real maxVal: 1.0
        command: ["brightnessctl", "m"]
        stdout: SplitParser {
            onRead: data => {
                const m = parseFloat(data)
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
        property int applied: -1
        command: ["brightnessctl", "set", root.brightnessTarget + "%"]
        // a drag can outrun the process, so rerun once if the target moved meanwhile
        onExited: {
            if (applied !== root.brightnessTarget) {
                applied = root.brightnessTarget
                running = true
            }
        }
    }

    function updateBrightness(ratio) {
        // 0% blacks the panel out on most laptops
        root.brightnessPercent = Math.min(1.0, Math.max(0.01, ratio))
        root.brightnessTarget = Math.round(root.brightnessPercent * 100)
        if (!setBrightnessProc.running) {
            setBrightnessProc.applied = root.brightnessTarget
            setBrightnessProc.running = true
        }
    }

    Timer {
        interval: 2000
        running: root.isExpanded
        repeat: true
        onTriggered: root.refresh()
    }

    // MPRIS position doesn't tick on its own
    Timer {
        interval: 1000
        running: root.isExpanded && root.playing
        repeat: true
        onTriggered: root.activePlayer.positionChanged()
    }

    Connections {
        target: root
        function onIsExpandedChanged() {
            if (root.isExpanded) root.refresh()
        }
    }

    Component.onCompleted: root.refresh()

    RowLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.topMargin: root.padding + root.outerPadding
        anchors.bottomMargin: root.bottomPadding + root.outerPadding
        anchors.leftMargin: root.notchRadius + root.padding + root.horizontalPadding + root.outerPadding
        anchors.rightMargin: root.notchRadius + root.padding + root.horizontalPadding + root.outerPadding
        spacing: 0

        // LEFT COLUMN
        // The date + clock (top) and the workspace dots + battery (bottom) are painted
        // by TopBar so they can morph with the collapsed bar. This column just keeps
        // their space free, which makes the notification tile run exactly from the
        // clock's baseline gap down to the bottom edge of the volume slider.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.rightMargin: root.gap
                spacing: root.gap

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.clockBlockHeight
                }

                NotificationCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fontFamily: root.fontFamily
                    fontAwesomeFont: root.fontAwesomeFont
                    model: root.notifications
                    autoDismiss: root.autoDismissNotifications
                    lifetime: root.notificationLifetime
                    onDismissRequested: index => root.notificationDismissed(index)
                    onClearRequested: root.notificationsCleared()
                    onActivated: index => root.notificationActivated(index)
                }

            }
        }

        // RIGHT COLUMN: Toggle Tiles, Media Player, Sliders
        Item {
            Layout.preferredWidth: root.columnWidth
            Layout.maximumWidth: root.columnWidth
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignRight

            ColumnLayout {
                anchors.fill: parent
                spacing: root.gap

                // Toggle Tiles Grid
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.topRowHeight
                    Layout.maximumHeight: root.topRowHeight
                    spacing: root.gap

                    GridLayout {
                        Layout.preferredWidth: 236
                        Layout.maximumWidth: 236
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: root.gap
                        columnSpacing: root.gap

                        // Import and use ToggleTile component
                        ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            fontFamily: root.fontFamily
                            fontAwesomeFont: root.fontAwesomeFont
                            glyph: ""
                            label: "Wi-Fi"
                            status: root.wifiActive ? (root.wifiSsid || "On") : "Off"
                            active: root.wifiActive
                            onClicked: wifiToggleProc.running = true
                        }

                        ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            fontFamily: root.fontFamily
                            fontAwesomeFont: root.fontAwesomeFont
                            glyph: ""
                            label: "Bluetooth"
                            status: root.bluetoothActive ? (root.btDevice || "On") : "Off"
                            active: root.bluetoothActive
                            onClicked: btToggleProc.running = true
                        }

                        ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            fontFamily: root.fontFamily
                            fontAwesomeFont: root.fontAwesomeFont
                            glyph: ""
                            label: "Focus"
                            status: root.dndActive ? "On" : "Off"
                            active: root.dndActive
                            onClicked: root.dndToggleRequested()
                        }

                        ToggleTile {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            fontFamily: root.fontFamily
                            fontAwesomeFont: root.fontAwesomeFont
                            glyph: ""
                            label: "Night Light"
                            status: !root.nightAvailable ? "Not installed" : root.nightActive ? "On" : "Off"
                            active: root.nightActive
                            available: root.nightAvailable
                            onClicked: nightToggleProc.running = true
                        }
                    }

                    MediaTile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        fontFamily: root.fontFamily
                        fontAwesomeFont: root.fontAwesomeFont
                        innerRadius: root.innerRadius

                        hasPlayer: root.activePlayer !== null
                        playing: root.playing
                        title: root.activePlayer?.trackTitle || "Not Playing"
                        artist: root.activePlayer ? root.getArtistString(root.activePlayer) : ""
                        artUrl: root.activePlayer?.trackArtUrl ?? ""
                        position: root.activePlayer?.positionSupported ? root.activePlayer.position : 0
                        length: root.activePlayer?.lengthSupported ? root.activePlayer.length : 0
                        canPrevious: root.activePlayer?.canGoPrevious ?? false
                        canNext: root.activePlayer?.canGoNext ?? false
                        canTogglePlaying: root.activePlayer?.canTogglePlaying ?? false
                        canSeek: (root.activePlayer?.canSeek ?? false) && (root.activePlayer?.positionSupported ?? false)

                        onPreviousClicked: root.activePlayer.previous()
                        onNextClicked: root.activePlayer.next()
                        onPlayPauseClicked: root.activePlayer.togglePlaying()
                        onSeekRequested: ratio => {
                            if (root.activePlayer && root.activePlayer.lengthSupported)
                                root.activePlayer.position = ratio * root.activePlayer.length
                        }
                    }
                }

                // Volume Slider
                PanelSlider {
                    id: soundSlider
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: root.sliderHeight
                    fontFamily: root.fontFamily
                    fontAwesomeFont: root.fontAwesomeFont
                    glyph: root.volumeGlyph()
                    glyphClickable: true
                    dim: root.isMuted
                    value: root.volumeVal
                    onMoved: ratio => root.updateAudioVolume(ratio)
                    onGlyphClicked: root.toggleMute()
                }

                // Brightness Slider
                PanelSlider {
                    id: brightnessSlider
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: root.sliderHeight
                    fontFamily: root.fontFamily
                    fontAwesomeFont: root.fontAwesomeFont
                    glyph: ""
                    value: root.brightnessPercent
                    onMoved: ratio => root.updateBrightness(ratio)
                }
            }
        }
    }
}
