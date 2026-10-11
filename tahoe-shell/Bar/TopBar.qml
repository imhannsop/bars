import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "."

PanelWindow {
    id: window
    required property var modelData
    screen: modelData

    mask: Region {
        Region {
            item: barArea
        }
        Region {
            item: (window.appSearchOpen || window.searchClosing) ? appSearch : null
        }
    }

    Process {
        id: obsStopProcess
        command: [
            "python3",
            decodeURIComponent(Qt.resolvedUrl("ObsRecordingMonitor.py").toString().replace(/^file:\/\//, "")),
            "--stop"
        ]
    }

    readonly property bool fullscreenActive: ToplevelManager.activeToplevel !== null
                                             && ToplevelManager.activeToplevel.fullscreen

    property bool debouncedFullscreen: false

    Timer {
        id: fullscreenDebounce
        interval: 60
        onTriggered: window.debouncedFullscreen = window.fullscreenActive
    }

    onFullscreenActiveChanged: {
        fullscreenDebounce.restart()
        if (window.fullscreenActive) {
            window.expanded = false
            window.peeking = false
            if (window.appSearchOpen) window.appSearchCloseRequested()
        }
    }

    onExpandedChanged: {
        // the panel already lists every notification, so the pop-up gets out of the way
        if (window.expanded) {
            if (window.appSearchOpen) window.appSearchCloseRequested()
            window.peeking = false
            peekTimer.stop()
            Qt.callLater(() => barArea.forceActiveFocus())
        }
    }

    onAppSearchOpenChanged: {
        if (window.appSearchOpen) {
            searchCloseTimer.stop()
            window.searchClosing = false
            window.searchLaunching = false
            window.expanded = false
            window.peeking = false
            peekTimer.stop()
            Qt.callLater(() => appSearch.focusSearch())
        } else {
            window.searchClosing = true
            appSearch.prepareClose()
            searchCloseTimer.restart()
        }
    }

    anchors.top: true
    margins.top: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (expanded || appSearchOpen || (searchClosing && !searchLaunching)) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool expanded: false
    property bool appSearchOpen: false
    property bool searchClosing: false
    property bool searchLaunching: false
    signal appSearchCloseRequested()
    signal appSearchToggleRequested()

    property int expandDuration: 260
    property int collapseDuration: 200

    property real collapsedWidth: 460
    property real collapsedHeight: 35
    property real collapsedNotchRadius: 20
    property real collapsedBottomRadius: 18

    // portrait control-center card: the bar row stays on top, the grid sits underneath
    property real expandedWidth: 560
    property real expandedHeaderHeight: expandedOuterPadding
    property real expandedHeight: expandedHeaderHeight + controlCenter.implicitHeight + expandedFooterHeight
    property real expandedNotchRadius: 30
    property real expandedOuterPadding: 24
    property real expandedFooterHeight: 50
    property real expandedRowInset: 8
    property real expandedGap: 16
    property real expandedBottomRadius: 36

    property real collapsedClockSize: 15
    property real expandedClockSize: 15

    property real collapsedClockWidth: 64
    property real collapsedClockHeight: 17
    property real expandedClockHeight: 17

    property real collapsedClockXScale: 1.0
    property real expandedClockXScale: 1.0

    property real collapsedClockYScale: 1.0
    property real expandedClockYScale: 1.0

    property real barWidth: collapsedWidth
    property real barHeight: collapsedHeight
    Behavior on barHeight {
        enabled: window.appSearchOpen || window.searchClosing
        NumberAnimation {
            duration: 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: window.niriCurve
        }
    }
    property real notchRadius: collapsedNotchRadius
    property real bottomRadius: collapsedBottomRadius
    property real clockFontSize: collapsedClockSize
    property real clockXScale: collapsedClockXScale
    property real clockYScale: collapsedClockYScale

    property real expandedContentOpacity: 0.0
    property real expandedContentScale: 0.92
    readonly property real expansionOvershootMargin: 0.12

    // ---- notch pop-up: the bar grows downward to show a new notification ----------
    property bool peeking: false
    property bool doNotDisturb: false       // driven by the Focus tile
    property int peekDuration: 5000
    property real peekWidth: 520
    property real peekHeight: 92
    property real recordingPeekWidth: 420
    property real recordingPeekHeight: 72
    property real peekBottomRadius: 24
    property int peekOpenDuration: 360
    property int peekCloseDuration: 300
    property real peekContentOpacity: 0.0
    property real peekContentScale: 0.88
    property real peekBorderAlpha: 0.12
    property real peekChipScale: 0.5        // icon chip springs in first
    property real peekTextShift: 16         // text glides in from the right
    property real searchWidth: 560
    property real searchContentOpacity: 0.0
    property real searchContentScale: 0.9
    readonly property var niriCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    // The normal bar row fades out fast as the notch opens and returns softly after it closes.
    property real barRowOpacity: ((window.peeking || window.appSearchOpen || window.searchClosing) && !window.expanded) ? 0.0 : 1.0
    Behavior on barRowOpacity {
        NumberAnimation {
            duration: (window.peeking || window.expanded) ? 120 : 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: window.niriCurve
        }
    }

    Timer {
        id: searchCloseTimer
        interval: 250
        onTriggered: {
            appSearch.reset()
            window.searchClosing = false
            window.searchLaunching = false
        }
    }
    property string peekTitle: ""
    property string peekMessage: ""
    property string peekApp: ""
    property string peekIcon: ""
    property real peekIconRadius: 23        // 23 = full circle, ~12 = rounded square
    property string peekType: "info"
    property color peekAccent: "#d0d0d6"
    property bool obsRecordingActive: false
    property bool obsStopPending: false
    property real obsAudioLevel: 0.0
    property double obsRecordingStartedAt: 0
    property int obsRecordingElapsedSeconds: 0

    readonly property real maxNotchRadius: Math.max(collapsedNotchRadius, expandedNotchRadius)

    // Reserve transparent shell space for the OutBack peak so it doesn't clip.
    implicitWidth: expandedWidth + maxNotchRadius * 2
                  + Math.max(0, expandedWidth - collapsedWidth) * expansionOvershootMargin
                  + 2 * Math.max(0, expandedNotchRadius - collapsedNotchRadius) * expansionOvershootMargin
    implicitHeight: expandedHeight
                   + Math.max(0, expandedHeight - collapsedHeight) * expansionOvershootMargin

    color: "transparent"
    exclusiveZone: 30

    // ---- notifications ---------------------------------------------------------
    // Lives on the window (not on barArea) so window.addNotification() & co. resolve.
    QtObject {
        id: notificationTheme
        readonly property color panel: "#1e1e22"
        readonly property color card: "#29292f"
        readonly property color border: "#35353c"
        readonly property color primary: "#ffffff"
        readonly property color secondary: "#a4a4ad"
        readonly property color muted: "#707079"
        readonly property color accent: "#d0d0d6"
        readonly property color success: "#d0d0d6"
        readonly property color warning: "#d0d0d6"
        readonly property color error: "#d0d0d6"
    }

    ListModel {
        id: notificationModel
    }

    property bool autoDismissNotifications: false
    property int notificationLifetime: 8000

    function notificationType(notification) {
        var declaredType = String(notification?.type ?? "").toLowerCase()
        if (declaredType === "success" || declaredType === "warning"
                || declaredType === "error" || declaredType === "info")
            return declaredType
        var urgency = Number(notification?.urgency ?? 0)
        if (urgency >= 2) return "error"
        if (urgency === 1) return "warning"
        return "info"
    }

    function notificationAccent(type) {
        if (type === "error") return notificationTheme.error
        if (type === "warning") return notificationTheme.warning
        if (type === "success") return notificationTheme.success
        return notificationTheme.accent
    }

    function peekGlyph(type) {
        if (type === "error") return ""
        if (type === "warning") return ""
        if (type === "success") return ""
        return ""
    }

    // Picks the best icon for a notification: the image it carries (Firefox puts the website's
    // icon here), then its app icon, then the icon of its .desktop entry. "" when nothing resolves.
    function resolvePeekIcon(notification) {
        function toSource(v) {
            if (!v) return ""
            v = String(v)
            if (v.length === 0) return ""
            if (v.indexOf("image://") === 0 || v.indexOf("file://") === 0
                    || v.indexOf("http://") === 0 || v.indexOf("https://") === 0
                    || v.indexOf("data:") === 0)
                return v
            if (v.charAt(0) === "/") return "file://" + v
            return Quickshell.iconPath(v, true)
        }

        var src = toSource(notification.image)
        if (src) return src
        src = toSource(notification.appIcon)
        if (src) return src

        var id = notification.desktopEntry || notification.appName
        if (id) {
            var entry = DesktopEntries.heuristicLookup(String(id))
            if (entry && entry.icon) {
                src = toSource(entry.icon)
                if (src) return src
            }
        }
        return ""
    }

    function showPeek(notification) {
        if (window.expanded || window.appSearchOpen || window.fullscreenActive) return
        var type = notificationType(notification)
        // Focus mutes the pop-up, but critical notifications still break through
        if (window.doNotDisturb && type !== "error" && notification.peekType !== "recording") return

        var wasPeeking = window.peeking

        window.peekTitle = notification.summary || notification.appName || "Notification"
        window.peekMessage = notification.body || ""
        window.peekApp = notification.appName || ""
        window.peekIcon = resolvePeekIcon(notification)
        window.peekType = notification.peekType || type
        window.peekAccent = notification.peekAccent || notificationAccent(type)
        window.peeking = true
        if (wasPeeking) swapPop.restart()

        // hovering the notch keeps it open; the countdown starts once the cursor leaves
        if (barHover.hovered) peekTimer.stop()
        else peekTimer.restart()
    }

    function closePeekPopup() {
        peekTimer.stop()
        window.peeking = false
    }

    function showObsRecordingPeek(active) {
        window.showPeek({
            summary: active ? "Screen Recording" : "Recording Stopped",
            body: active ? "OBS Studio is recording" : "OBS Studio stopped recording",
            appName: "OBS Studio",
            appIcon: "obs",
            type: "info",
            peekType: active ? "recording" : "info",
            peekAccent: active ? "#ff453a" : notificationTheme.accent
        })
        if (active) peekTimer.stop()
    }

    function handleObsRecordingEvent(data) {
        let message
        try {
            message = JSON.parse(data)
        } catch (error) {
            console.warn("Invalid OBS recording monitor event:", error)
            return
        }

        if (message.event === "audio") {
            if (window.obsRecordingActive && Number.isFinite(message.level))
                window.obsAudioLevel = Math.max(0, Math.min(1, message.level))
            return
        }

        if (message.event !== "state" && message.event !== "recording") return
        const active = Boolean(message.active)
        if (active === window.obsRecordingActive) return
        window.obsRecordingActive = active
        if (active) {
            window.obsRecordingStartedAt = Date.now()
            window.obsRecordingElapsedSeconds = 0
            window.obsStopPending = false
        } else {
            window.obsAudioLevel = 0
            window.obsStopPending = false
        }
        window.showObsRecordingPeek(active)
    }

    Behavior on obsAudioLevel {
        NumberAnimation { duration: 55; easing.type: Easing.OutCubic }
    }

    // announce is true only for notifications that just arrived, not ones restored at startup
    function addNotification(notification, announce) {
        if (!notification) return
        for (var i = 0; i < notificationModel.count; i++) {
            if (notificationModel.get(i).source === notification) return
        }
        notification.tracked = true
        notificationModel.insert(0, {
            source: notification,
            title: notification.summary || notification.appName || "Notification",
            message: notification.body || "",
            type: notificationType(notification),
            timestamp: new Date(),
            accent: notificationAccent(notificationType(notification))
        })
        if (announce) window.showPeek(notification)
    }

    // a new notification replacing the one on screen: soft re-pop on the same niri-style curves
    ParallelAnimation {
        id: swapPop
        NumberAnimation { target: window; property: "peekContentScale"; from: 0.94; to: 1.0; duration: 460; easing.type: Easing.OutExpo }
        NumberAnimation { target: window; property: "peekContentOpacity"; from: 0.4; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: window; property: "peekTextShift"; from: 12; to: 0; duration: 460; easing.type: Easing.OutExpo }
    }

    Timer {
        id: peekTimer
        interval: window.peekDuration
        onTriggered: window.peeking = false
    }

    Timer {
        interval: 250
        running: window.obsRecordingActive
        repeat: true
        onTriggered: {
            window.obsRecordingElapsedSeconds = Math.floor((Date.now() - window.obsRecordingStartedAt) / 1000)
        }
    }

    NumberAnimation {
        id: recordingWave
        target: recordingWaveState
        property: "phase"
        from: 0
        to: Math.PI * 2
        duration: 1300
        loops: Animation.Infinite
        running: window.obsRecordingActive
    }

    Item {
        id: recordingWaveState
        property real phase: 0
    }

    function recordingTimeText() {
        const seconds = Math.max(0, window.obsRecordingElapsedSeconds)
        const minutes = Math.floor(seconds / 60)
        return (minutes < 10 ? "0" : "") + minutes + ":"
            + (seconds % 60 < 10 ? "0" : "") + (seconds % 60)
    }

    function stopObsRecording() {
        obsStopProcess.running = true
    }

    function requestObsRecordingStop() {
        if (window.obsStopPending) return
        window.obsStopPending = true
        recordingStopAnimation.restart()
    }

    SequentialAnimation {
        id: recordingStopAnimation
        PauseAnimation { duration: 170 }
        onFinished: window.stopObsRecording()
    }

    function dismissNotification(index) {
        if (index < 0 || index >= notificationModel.count) return
        var entry = notificationModel.get(index)
        if (entry.source && entry.source.dismiss)
            entry.source.dismiss()
        notificationModel.remove(index)
    }

    function clearNotifications() {
        while (notificationModel.count > 0)
            dismissNotification(notificationModel.count - 1)
    }

    NotificationServer {
        id: notificationServer
        persistenceSupported: true
        // Firefox checks the server's capabilities before sending web notifications;
        // advertise the common ones so it doesn't treat the server as unusable.
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => window.addNotification(notification, true)
    }

    Process {
        id: obsRecordingMonitor
        command: [
            "python3",
            decodeURIComponent(Qt.resolvedUrl("ObsRecordingMonitor.py").toString().replace(/^file:\/\//, ""))
        ]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => window.handleObsRecordingEvent(data)
        }
    }

    // ---- control center backends ---------------------------------------------------
    property bool wifiOn: true
    property bool bluetoothOn: true
    property bool hotspotOn: false
    property bool darkMode: true
    property real brightness: 0.5

    // keeps the default sink's volume live
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var audioSink: Pipewire.defaultAudioSink

    // prefer whichever player is playing, else the first one
    readonly property var mediaPlayer: {
        var list = Mpris.players.values
        var fallback = null
        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying) return list[i]
            if (!fallback) fallback = list[i]
        }
        return fallback
    }

    // shortcut buttons; edit these to match your setup (empty list = does nothing)
    readonly property var actionCommands: ({
        "launcher": ["fuzzel"],
        "overview": ["niri", "msg", "action", "toggle-overview"],
        "calculator": ["gnome-calculator"],
        "timer": ["gnome-clocks"],
        "screenshot": ["sh", "-c", "grim -g \"$(slurp)\" - | wl-copy"]
    })

    function runAction(name) {
        var cmd = window.actionCommands[name]
        if (cmd && cmd.length > 0) Quickshell.execDetached(cmd)
    }

    Process {
        id: brightnessReader
        command: ["brightnessctl", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var pct = parseInt(text.split(",")[3])
                if (!isNaN(pct)) window.brightness = pct / 100
            }
        }
    }

    Timer {
        id: brightnessTimer
        interval: 60
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(window.brightness * 100) + "%"])
    }

    // re-read the real brightness each time the panel opens
    Connections {
        target: window
        function onExpandedChanged() {
            if (window.expanded) brightnessReader.running = true
        }
    }

    Component.onCompleted: {
        for (var notification of notificationServer.trackedNotifications.values)
            window.addNotification(notification)
    }

    Item {
        id: barContent
        anchors.fill: parent
        opacity: 0

        transform: [
            Translate { id: entranceSlide; y: -30 },
            Translate { id: fullscreenSlide; y: 0 }
        ]

        enabled: !window.fullscreenActive
        state: window.debouncedFullscreen ? "hidden" : "shown"

        states: [
            State { name: "shown"; PropertyChanges { target: fullscreenSlide; y: 0 } },
            State { name: "hidden"; PropertyChanges { target: fullscreenSlide; y: -(window.barHeight + window.notchRadius) } }
        ]

        transitions: [
            Transition {
                to: "shown"
                NumberAnimation { target: fullscreenSlide; property: "y"; duration: 160; easing.type: Easing.OutExpo }
            },
            Transition {
                to: "hidden"
                NumberAnimation { target: fullscreenSlide; property: "y"; duration: 160; easing.type: Easing.OutQuad }
            }
        ]

        SequentialAnimation {
            id: entranceAnim
            running: false
            PauseAnimation { duration: 20 }
            ParallelAnimation {
                NumberAnimation { target: entranceSlide; property: "y"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                OpacityAnimator { target: barContent; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
            }
        }

        Component.onCompleted: entranceAnim.start()

        Item {
            id: barArea
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: window.barWidth + window.notchRadius * 2
            height: window.barHeight

            state: window.expanded ? "expanded"
                 : window.appSearchOpen ? "search"
                 : window.peeking ? "peek" : "collapsed"
            focus: window.expanded || window.appSearchOpen

            Keys.onEscapePressed: event => {
                if (window.appSearchOpen) window.appSearchCloseRequested()
                else window.expanded = false
                event.accepted = true
            }

            // Keep geometry and child positions in sync.
            states: [
                State {
                    name: "collapsed"
                    PropertyChanges { target: window; barWidth: window.collapsedWidth; barHeight: window.collapsedHeight; notchRadius: window.collapsedNotchRadius; bottomRadius: window.collapsedBottomRadius; clockFontSize: window.collapsedClockSize; clockXScale: window.collapsedClockXScale; clockYScale: window.collapsedClockYScale; expandedContentOpacity: 0.0; expandedContentScale: 0.92; peekContentOpacity: 0.0; peekContentScale: 0.88; peekChipScale: 0.5; peekTextShift: 16; searchContentOpacity: 0.0; searchContentScale: 0.9 }
                    PropertyChanges { target: wsIndicator; x: window.collapsedNotchRadius + 20; y: (window.collapsedHeight - wsIndicator.implicitHeight) / 2 }
                    PropertyChanges { target: clockDisplay; x: window.collapsedWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth; y: (window.collapsedHeight - window.collapsedClockHeight) / 2 }
                    PropertyChanges { target: statusCluster; rightEdge: window.collapsedWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth - 12; y: (window.collapsedHeight - statusCluster.height) / 2 }
                },
                State {
                    name: "peek"
                    // same top row as the collapsed bar, just wider and taller
                    PropertyChanges { target: window; barWidth: window.peekType === "recording" ? window.recordingPeekWidth : window.peekWidth; barHeight: window.peekType === "recording" ? window.recordingPeekHeight : window.peekHeight; notchRadius: window.collapsedNotchRadius; bottomRadius: window.peekBottomRadius; clockFontSize: window.collapsedClockSize; clockXScale: window.collapsedClockXScale; clockYScale: window.collapsedClockYScale; expandedContentOpacity: 0.0; peekContentOpacity: 1.0; peekContentScale: 1.0; peekChipScale: 1.0; peekTextShift: 0 }
                    PropertyChanges { target: wsIndicator; x: window.collapsedNotchRadius + 20; y: (window.collapsedHeight - wsIndicator.implicitHeight) / 2 }
                    PropertyChanges { target: clockDisplay; x: window.peekWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth; y: (window.collapsedHeight - window.collapsedClockHeight) / 2 }
                    PropertyChanges { target: statusCluster; rightEdge: window.peekWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth - 12; y: (window.collapsedHeight - statusCluster.height) / 2 }
                },
                State {
                    name: "search"
                    PropertyChanges { target: window; barWidth: window.searchWidth; barHeight: appSearch.barHeight; notchRadius: window.collapsedNotchRadius; bottomRadius: 24; clockFontSize: window.collapsedClockSize; clockXScale: window.collapsedClockXScale; clockYScale: window.collapsedClockYScale; expandedContentOpacity: 0.0; expandedContentScale: 0.92; peekContentOpacity: 0.0; peekContentScale: 0.88; peekChipScale: 0.5; peekTextShift: 16; searchContentOpacity: 1.0; searchContentScale: 1.0 }
                    PropertyChanges { target: wsIndicator; x: window.collapsedNotchRadius + 20; y: (window.collapsedHeight - wsIndicator.implicitHeight) / 2 }
                    PropertyChanges { target: clockDisplay; x: window.searchWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth; y: (window.collapsedHeight - window.collapsedClockHeight) / 2 }
                    PropertyChanges { target: statusCluster; rightEdge: window.searchWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth - 12; y: (window.collapsedHeight - statusCluster.height) / 2 }
                },
                State {
                    name: "expanded"
                    PropertyChanges { target: window; barWidth: window.expandedWidth; barHeight: window.expandedHeight; notchRadius: window.expandedNotchRadius; bottomRadius: window.expandedBottomRadius; clockFontSize: window.expandedClockSize; clockXScale: window.expandedClockXScale; clockYScale: window.expandedClockYScale; expandedContentOpacity: 1.0; expandedContentScale: 1.0; peekContentOpacity: 0.0; peekContentScale: 0.88; peekChipScale: 0.5; peekTextShift: 16; searchContentOpacity: 0.0; searchContentScale: 0.9 }
                    // same top row as the collapsed bar, spread across the wider card
                    PropertyChanges { target: wsIndicator; x: window.expandedNotchRadius + window.expandedOuterPadding + window.expandedRowInset; y: window.expandedHeaderHeight + controlCenter.implicitHeight + window.expandedFooterHeight / 2 - wsIndicator.implicitHeight / 2 }
                    PropertyChanges { target: clockDisplay; x: window.expandedNotchRadius + window.expandedOuterPadding + window.expandedRowInset + wsIndicator.implicitWidth + 14; y: window.expandedHeaderHeight + controlCenter.implicitHeight + window.expandedFooterHeight / 2 - window.collapsedClockHeight / 2 }
                    PropertyChanges { target: statusCluster; rightEdge: window.expandedNotchRadius + window.expandedWidth - window.expandedOuterPadding - window.expandedRowInset; y: window.expandedHeaderHeight + controlCenter.implicitHeight + window.expandedFooterHeight / 2 - statusCluster.height / 2 }
                }
            ]

            transitions: [
                Transition {
                    from: "collapsed,peek,expanded"; to: "search"
                    ParallelAnimation {
                        NumberAnimation {
                            target: window
                            properties: "expandedContentOpacity,expandedContentScale"
                            duration: 180
                            easing.type: Easing.InOutCubic
                        }
                        NumberAnimation {
                            target: window
                            properties: "barWidth,barHeight,notchRadius,bottomRadius"
                            duration: 380
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.08
                        }
                        NumberAnimation {
                            targets: [wsIndicator, clockDisplay, statusCluster]
                            properties: "x,y,rightEdge"
                            duration: 340
                            easing.type: Easing.OutCubic
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: 45 }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: window
                                    property: "searchContentOpacity"
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: window
                                    property: "searchContentScale"
                                    duration: 360
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.1
                                }
                            }
                        }
                    }
                },
                Transition {
                    from: "search"; to: "collapsed,peek"
                    ParallelAnimation {
                        NumberAnimation {
                            target: window
                            properties: "barWidth,barHeight,notchRadius,bottomRadius"
                            duration: 230
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: window.niriCurve
                        }
                        NumberAnimation {
                            targets: [wsIndicator, clockDisplay, statusCluster]
                            properties: "x,y,rightEdge"
                            duration: 230
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: window.niriCurve
                        }
                        NumberAnimation {
                            target: window
                            property: "searchContentOpacity"
                            duration: 170
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: window.niriCurve
                        }
                        NumberAnimation {
                            target: window
                            property: "searchContentScale"
                            duration: 210
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: window.niriCurve
                        }
                    }
                },
                Transition {
                    from: "collapsed,peek"; to: "expanded"
                    ParallelAnimation {
                        NumberAnimation { target: window; properties: "peekContentOpacity,peekContentScale,peekChipScale,peekTextShift,searchContentOpacity,searchContentScale"; duration: 90; easing.type: Easing.OutCubic }
                        NumberAnimation {
                            target: window
                            properties: "barWidth,barHeight,notchRadius,bottomRadius"
                            duration: window.expandDuration
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.35
                        }
                        NumberAnimation {
                            targets: [window, wsIndicator, clockDisplay, statusCluster]
                            properties: "clockFontSize,clockXScale,clockYScale,x,y,rightEdge"
                            duration: window.expandDuration
                            easing.type: Easing.OutCubic
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: 60 }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: window
                                    property: "expandedContentOpacity"
                                    duration: window.expandDuration - 60
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: window
                                    property: "expandedContentScale"
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                },
                // A slower ease-in-out gives the notch a fluid, deliberate morph.
                Transition {
                    to: "peek"
                    ParallelAnimation {
                        NumberAnimation { target: window; property: "barWidth"; duration: window.peekOpenDuration; easing.type: Easing.InOutCubic }
                        NumberAnimation { target: window; property: "barHeight"; duration: window.peekOpenDuration; easing.type: Easing.InOutCubic }
                        NumberAnimation { target: window; properties: "notchRadius,bottomRadius"; duration: window.peekOpenDuration; easing.type: Easing.InOutCubic }
                        NumberAnimation { targets: [wsIndicator, clockDisplay, statusCluster]; properties: "x,y,rightEdge"; duration: window.peekOpenDuration; easing.type: Easing.InOutCubic }

                        // Reveal the content just after the shape starts opening.
                        SequentialAnimation {
                            PauseAnimation { duration: 80 }
                            NumberAnimation { target: window; property: "peekContentOpacity"; duration: 240; easing.type: Easing.OutCubic }
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: 80 }
                            NumberAnimation { target: window; property: "peekContentScale"; duration: 300; easing.type: Easing.OutCubic }
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: 110 }
                            NumberAnimation { target: window; property: "peekChipScale"; duration: 280; easing.type: Easing.OutCubic }
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: 130 }
                            NumberAnimation { target: window; property: "peekTextShift"; duration: 260; easing.type: Easing.OutCubic }
                        }
                    }
                },
                // Keep the content and notch moving together through the close.
                Transition {
                    from: "peek"; to: "collapsed"
                    ParallelAnimation {
                        NumberAnimation {
                            target: window
                            properties: "barWidth,barHeight,notchRadius,bottomRadius"
                            duration: window.peekCloseDuration
                            easing.type: Easing.InOutCubic
                        }
                        NumberAnimation {
                            targets: [wsIndicator, clockDisplay, statusCluster]
                            properties: "x,y,rightEdge"
                            duration: window.peekCloseDuration
                            easing.type: Easing.InOutCubic
                        }
                        NumberAnimation {
                            target: window
                            properties: "peekContentOpacity,peekContentScale,peekChipScale,peekTextShift"
                            duration: window.peekCloseDuration
                            easing.type: Easing.InOutCubic
                        }
                    }
                },
                Transition {
                    from: "expanded"; to: "collapsed"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation {
                                target: window
                                property: "expandedContentOpacity"
                                to: 0.0
                                duration: 80
                                easing.type: Easing.InQuad
                            }
                            NumberAnimation {
                                target: window
                                property: "expandedContentScale"
                                to: 0.92
                                duration: 80
                                easing.type: Easing.InQuad
                            }
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: window
                                properties: "barWidth,barHeight,notchRadius,bottomRadius"
                                duration: window.collapseDuration
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                targets: [window, wsIndicator, clockDisplay, statusCluster]
                                properties: "clockFontSize,clockXScale,clockYScale,x,y,rightEdge"
                                duration: window.collapseDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            ]

            Canvas {
                id: barCanvas
                x: -barArea.x
                y: -barArea.y
                width: window.width
                height: window.height
                antialiasing: true
                smooth: true

                layer.enabled: true
                layer.smooth: true

                property real w: window.barWidth
                property real h: window.barHeight
                property real nr: window.notchRadius
                property real r: window.bottomRadius
                property real ba: window.peekBorderAlpha * window.peekContentOpacity

                onBaChanged: requestPaint()
                onWChanged: requestPaint()
                onHChanged: requestPaint()
                onNrChanged: requestPaint()
                onRChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()

                    var ox = (width - w) / 2

                    ctx.beginPath()
                    ctx.moveTo(ox - nr, 0)
                    ctx.lineTo(ox + w + nr, 0)
                    ctx.arcTo(ox + w, 0, ox + w, nr, nr)
                    ctx.lineTo(ox + w, h - r)
                    ctx.arcTo(ox + w, h, ox + w - r, h, r)
                    ctx.lineTo(ox + r, h)
                    ctx.arcTo(ox, h, ox, h - r, r)
                    ctx.lineTo(ox, nr)
                    ctx.arcTo(ox, 0, ox - nr, 0, nr)
                    ctx.closePath()

                    ctx.fillStyle = "#000000"
                    ctx.fill()

                    // 1px inner highlight (2px stroke clipped to the shape), notification only
                    if (ba > 0.002) {
                        ctx.save()
                        ctx.clip()
                        ctx.beginPath()
                        ctx.moveTo(ox + w, nr)
                        ctx.lineTo(ox + w, h - r)
                        ctx.arcTo(ox + w, h, ox + w - r, h, r)
                        ctx.lineTo(ox + r, h)
                        ctx.arcTo(ox, h, ox, h - r, r)
                        ctx.lineTo(ox, nr)
                        ctx.lineWidth = 2
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, ba)
                        ctx.stroke()
                        ctx.restore()
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (window.appSearchOpen) window.appSearchCloseRequested()
                    else if (!window.expanded || mouse.y < window.expandedHeaderHeight || mouse.y > window.expandedHeaderHeight + controlCenter.implicitHeight)
                        window.expanded = !window.expanded
                }
            }

            Item {
                id: recordingIndicator
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: 62
                height: window.collapsedHeight
                visible: window.obsRecordingActive && !window.peeking
                    && !window.expanded && !window.appSearchOpen && !window.searchClosing
                z: 5

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: width / 2
                        color: "#ff453a"
                        SequentialAnimation on opacity {
                            running: recordingIndicator.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.45; duration: 650; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 650; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "REC"
                        color: "#ff453a"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.showObsRecordingPeek(true)
                }
            }

            HoverHandler {
                id: barHover
                onHoveredChanged: {
                    if (!window.peeking) return
                    if (hovered || window.obsRecordingActive) peekTimer.stop()
                    else peekTimer.restart()
                }
            }

            Timer {
                id: clockTimer
                property var now: new Date()
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: now = new Date()
            }

            Item {
                id: collapsedContent
                anchors.fill: parent
                opacity: 1.0 - window.expandedContentOpacity
                visible: opacity > 0.01
                layer.enabled: true
            }

            ControlCenterPanel {
                id: controlCenter
                anchors.top: parent.top
                anchors.topMargin: window.expandedHeaderHeight
                anchors.horizontalCenter: parent.horizontalCenter
                width: window.expandedWidth - 2 * window.expandedOuterPadding
                gap: window.expandedGap

                wifiOn: window.wifiOn
                bluetoothOn: window.bluetoothOn
                hotspotOn: window.hotspotOn
                dndActive: window.doNotDisturb
                darkMode: window.darkMode
                brightness: window.brightness
                volume: window.audioSink?.audio?.volume ?? 0

                mediaAvailable: window.mediaPlayer !== null
                mediaPlaying: window.mediaPlayer?.isPlaying ?? false
                mediaTitle: window.mediaPlayer?.trackTitle ?? ""
                mediaArtist: window.mediaPlayer?.trackArtist ?? ""
                mediaArt: window.mediaPlayer?.trackArtUrl ?? ""

                onWifiClicked: {
                    window.wifiOn = !window.wifiOn
                    Quickshell.execDetached(["nmcli", "radio", "wifi", window.wifiOn ? "on" : "off"])
                }
                onBluetoothClicked: {
                    window.bluetoothOn = !window.bluetoothOn
                    Quickshell.execDetached(["bluetoothctl", "power", window.bluetoothOn ? "on" : "off"])
                }
                onHotspotClicked: window.hotspotOn = !window.hotspotOn
                onDndClicked: window.doNotDisturb = !window.doNotDisturb
                onDarkModeClicked: {
                    window.darkMode = !window.darkMode
                    Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme",
                                             window.darkMode ? "prefer-dark" : "prefer-light"])
                }
                onBrightnessMoved: value => {
                    window.brightness = value
                    if (!brightnessTimer.running) brightnessTimer.start()
                }
                onVolumeMoved: value => {
                    if (window.audioSink && window.audioSink.audio)
                        window.audioSink.audio.volume = value
                }
                onMediaPrevious: { if (window.mediaPlayer) window.mediaPlayer.previous() }
                onMediaToggle: { if (window.mediaPlayer) window.mediaPlayer.togglePlaying() }
                onMediaNext: { if (window.mediaPlayer) window.mediaPlayer.next() }
                onActionRequested: name => window.runAction(name)

                opacity: window.expandedContentOpacity
                scale: window.expandedContentScale
                transformOrigin: Item.Top
                visible: opacity > 0.01
                layer.enabled: true
            }

            AppSearch {
                id: appSearch
                z: 10
                expanded: window.appSearchOpen || window.searchClosing
                fontAwesomeFont: Theme.fontAwesomeFont
                opacity: window.searchContentOpacity
                scale: window.searchContentScale
                transformOrigin: Item.Top
                visible: window.appSearchOpen || opacity > 0.01
                enabled: window.appSearchOpen
                onRequestClose: window.appSearchCloseRequested()
                onRequestToggle: window.appSearchToggleRequested()
                onLaunchRequested: window.searchLaunching = true
            }

            WorkspaceIndicator {
                id: wsIndicator
                opacity: window.barRowOpacity
                dotSize: 14
                ringSize: 16
                ringBorder: 4
                dotSpacing: 9
            }

            Row {
                id: clockDisplay
                spacing: 1
                opacity: window.barRowOpacity

                transform: Scale {
                    origin.x: 0
                    origin.y: clockDisplay.height / 2
                    xScale: window.clockXScale
                    yScale: window.clockYScale
                }

                Text {
                    id: clockHours
                    color: "#ffffff"
                    font.pixelSize: window.clockFontSize
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    text: Qt.formatDateTime(clockTimer.now, "hh")
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    id: customColon
                    implicitWidth: dotWidth
                    height: clockHours.height
                    anchors.verticalCenter: parent.verticalCenter

                    property real dotWidth: window.clockFontSize * 0.12
                    property real dotHeight: dotWidth
                    property real dotRadius: dotWidth / 2
                    
                    property real dotSpacing: 1.8

                    Rectangle {
                        id: topDot
                        width: customColon.dotWidth
                        height: customColon.dotHeight
                        radius: customColon.dotRadius
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -customColon.dotSpacing

                        transform: Scale {
                            origin.x: topDot.width / 2
                            origin.y: topDot.height / 2
                            xScale: 1.0 / Math.max(0.01, window.clockXScale)
                            yScale: 1.0 / Math.max(0.01, window.clockYScale)
                        }
                    }

                    Rectangle {
                        id: bottomDot
                        width: customColon.dotWidth
                        height: customColon.dotHeight
                        radius: customColon.dotRadius
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: customColon.dotSpacing

                        transform: Scale {
                            origin.x: bottomDot.width / 2
                            origin.y: bottomDot.height / 2
                            xScale: 1.0 / Math.max(0.01, window.clockXScale)
                            yScale: 1.0 / Math.max(0.01, window.clockYScale)
                        }
                    }
                }

                Text {
                    id: clockMinutes
                    color: "#ffffff"
                    font.pixelSize: window.clockFontSize
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    text: Qt.formatDateTime(clockTimer.now, "mm")
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    id: clockMeridiem
                    anchors.bottom: parent.bottom
                    color: "#ffffff"
                    font.pixelSize: window.clockFontSize
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    text: Qt.formatDateTime(clockTimer.now, "AP")
                    
                }
            }

            // notification view: fills the whole card. Fixed at the final size and centred,
            // so it scales (never reflows) while the card morphs open.
            Item {
                id: peekContent
                width: (window.peekType === "recording" ? window.recordingPeekWidth : window.peekWidth) - 40
                height: window.peekType === "recording" ? window.recordingPeekHeight : window.peekHeight
                x: (barArea.width - width) / 2
                y: 0
                opacity: window.peekContentOpacity
                scale: window.peekContentScale
                transformOrigin: Item.Center
                visible: opacity > 0.01

                Row {
                    id: recordingContent
                    anchors.fill: parent
                    visible: window.peekType === "recording"

                    MouseArea {
                        anchors.fill: parent
                        z: 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.closePeekPopup()
                    }

                    Row {
                        id: recordingLayout
                        anchors.fill: parent
                        z: 1
                        spacing: 0

                        Row {
                            id: waveform
                            anchors.verticalCenter: parent.verticalCenter
                            width: 190
                            height: 54
                            spacing: 3

                            Repeater {
                                model: 20
                                delegate: Rectangle {
                                    required property int index
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    property real envelope: 0.18
                                        + 0.82 * Math.abs(Math.sin(index * 0.42 + recordingWaveState.phase * 0.35))
                                    height: 3 + Math.sqrt(window.obsAudioLevel) * (5 + envelope * 42)
                                    radius: 2
                                    color: "#ff453a"
                                    opacity: 0.55 + window.obsAudioLevel * 0.45
                                }
                            }
                        }

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(8, parent.width - waveform.width - recordingTime.width - 20 - 44)
                            height: 1
                        }

                        Text {
                            id: recordingTime
                            anchors.verticalCenter: parent.verticalCenter
                            text: window.recordingTimeText()
                            color: "#ff453a"
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 14
                            font.features: { "tnum": 1 }
                        }

                        Item {
                            width: 16
                            height: 1
                        }

                        Item {
                            id: recordingStopButton
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: 44
                            scale: window.obsStopPending ? 0.65 : 1
                            opacity: window.obsStopPending ? 0.35 : 1

                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.InOutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 150; easing.type: Easing.InOutCubic }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: 3
                                border.color: "#ffffff"
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 17
                                height: 17
                                radius: 4
                                color: "#ff453a"
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: 2
                                enabled: !window.obsStopPending
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.requestObsRecordingStop()
                            }
                        }
                    }
                }

                // app / website icon (falls back to the app's first letter, never an alert glyph)
                Rectangle {
                    id: peekChip
                    scale: window.peekChipScale
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    height: 46
                    radius: window.peekIconRadius
                    color: peekIconImage.status === Image.Ready ? "transparent" : "#26262b"
                    visible: window.peekType !== "recording"

                    Image {
                        id: peekIconImage
                        anchors.fill: parent
                        source: window.peekIcon
                        sourceSize: Qt.size(46, 46)
                        fillMode: Image.PreserveAspectFit
                        horizontalAlignment: Image.AlignHCenter
                        verticalAlignment: Image.AlignVCenter
                        asynchronous: true
                        smooth: false
                        mipmap: false
                        visible: status === Image.Ready

                        // clip the icon to the rounded shape
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: peekIconMask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                    }

                    Item {
                        id: peekIconMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Rectangle {
                            anchors.fill: parent
                            radius: window.peekIconRadius
                            color: "#000000"
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: peekIconImage.status !== Image.Ready
                        text: (window.peekApp || window.peekTitle || "?").charAt(0).toUpperCase()
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: 21
                        color: "#a4a4ad"
                    }

                    Rectangle {
                        visible: window.peekType === "recording"
                        anchors.right: parent.right
                        anchors.top: parent.top
                        width: 13
                        height: 13
                        radius: 7
                        color: "#ff453a"
                        border.width: 2
                        border.color: "#000000"
                    }
                }

                Column {
                    anchors.left: peekChip.right
                    anchors.leftMargin: 16 + window.peekTextShift
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    visible: window.peekType !== "recording"

                    Item {
                        width: parent.width
                        height: peekTitleText.implicitHeight

                        Text {
                            id: peekTitleText
                            anchors.left: parent.left
                            anchors.right: peekAppText.left
                            anchors.rightMargin: 8
                            text: window.peekTitle
                            color: "#ffffff"
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 17
                            elide: Text.ElideRight
                        }

                        Text {
                            id: peekAppText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width * 0.35)
                            horizontalAlignment: Text.AlignRight
                            text: window.peekApp
                            color: "#707079"
                            font.family: Theme.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        width: parent.width
                        visible: text.length > 0
                        text: window.peekMessage
                        color: "#a4a4ad"
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: 1
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    enabled: window.peekType !== "recording"
                    onClicked: window.closePeekPopup()
                }
            }

            Item {
                id: statusCluster
                property real rightEdge: window.collapsedWidth + window.collapsedNotchRadius - 20 - window.collapsedClockWidth - 12
                x: rightEdge - width
                opacity: window.barRowOpacity
                width: statusRow.implicitWidth
                height: statusRow.implicitHeight

                Row {
                    id: statusRow
                    spacing: 0

                    readonly property bool charging: UPower.displayDevice.state === UPowerDeviceState.Charging
                    readonly property color tint: UPower.displayDevice.percentage <= 0.15 && !charging ? "#ff5555" : "#ffffff"

                    // the expanded panel already has a Wi-Fi tile
                    Text {
                        id: wifiIcon
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.family: Theme.fontAwesomeFont
                        font.weight: Font.Black
                        text: "\uf1eb"
                        rightPadding: 10
                        width: implicitWidth * (1.0 - window.expandedContentOpacity)
                        opacity: 1.0 - window.expandedContentOpacity
                        clip: true
                    }

                    Text {
                        id: boltIcon
                        anchors.verticalCenter: parent.verticalCenter
                        visible: statusRow.charging
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.family: Theme.fontAwesomeFont
                        font.weight: Font.Black
                        text: "\uf0e7"
                        rightPadding: 10

                        HoverHandler { id: batteryHover }
                        ToolTip.visible: batteryHover.hovered
                        ToolTip.text: "Charging"
                        ToolTip.toolTip.font.family: Theme.fontFamily
                        ToolTip.toolTip.font.weight: Font.Bold
                    }

                    // while charging the bolt stands in for the battery on the collapsed bar
                    Text {
                        id: batteryIcon
                        anchors.verticalCenter: parent.verticalCenter
                        color: statusRow.tint
                        font.pixelSize: 17
                        font.family: Theme.fontAwesomeFont
                        font.weight: Font.Black
                        text: {
                            var pct = UPower.displayDevice.percentage
                            if (pct >= 0.9) return "\uf240"
                            if (pct >= 0.75) return "\uf241"
                            if (pct >= 0.4) return "\uf242"
                            if (pct >= 0.15) return "\uf243"
                            return "\uf244"
                        }
                        rightPadding: 10
                        width: implicitWidth * (statusRow.charging ? window.expandedContentOpacity : 1.0)
                        opacity: statusRow.charging ? window.expandedContentOpacity : 1.0
                        clip: true
                    }

                    Text {
                        id: batteryPercent
                        anchors.verticalCenter: parent.verticalCenter
                        color: statusRow.tint
                        font.pixelSize: 13
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                        text: Math.round(UPower.displayDevice.percentage * 100) + "%"

                        width: implicitWidth * window.expandedContentOpacity
                        opacity: window.expandedContentOpacity
                        clip: true
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1.0 - window.expandedContentOpacity
                        height: 12
                        color: "#ffffff"
                        opacity: (1.0 - window.expandedContentOpacity) * 0.4
                    }
                }
            }
        }
    }
}
