import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

PopupWindow {
    id: controlCenterPopup

    required property var anchorWindow
    property real pillBarWidth: 0
    property real pillBarBottomY: 0
    property var notifServer

    property bool isOpen: false

    function clearAllNotifications() {
        if (!controlCenterPopup.notifServer) return

        var list = controlCenterPopup.notifServer.trackedNotifications
        if (!list) return

        // trackedNotifications is a Quickshell ObjectModel backed by a real
        // QAbstractItemModel (rowCount()/data()/index() all take QModelIndex
        // args, not plain row numbers — that's what caused the "Could not
        // convert argument 0 from 0 to QModelIndex" warning). The JS-usable
        // array of the underlying Notification objects is exposed through
        // the `values` property instead.
        var source = list.values
        if (!source) return

        // Snapshot into a static array first — untracking/dismissing items
        // while iterating the live model can shift indices and skip
        // entries as the array shrinks underneath the loop.
        var items = []
        for (var i = 0; i < source.length; i++) {
            items.push(source[i])
        }

        for (var j = 0; j < items.length; j++) {
            var item = items[j]
            // dismiss() closes the notification and untracks it in one
            // step. Setting `tracked = false` first (as a prior version of
            // this function did) causes Quickshell to destroy the
            // underlying object immediately, so a following dismiss() call
            // then operates on a dangling pointer — that's the source of
            // the "Cannot close destroyed notification" error. Only call
            // dismiss(); don't touch `tracked` separately.
            if (item && typeof item.dismiss === "function") {
                item.dismiss()
            }
        }
    }

    anchor.window: anchorWindow
    // `| 0`, not Math.round(): anchor.rect.x/y are int, but the pixel math
    // below is real (Window.width and pillBarWidth/pillBarBottomY are all
    // qreal). Math.round() still returns a value QML's static type system
    // treats as `real`, so it still trips "Unable to assign double to int"
    // even though the runtime value is already whole. `| 0` is a bitwise
    // op, which QML types as `int`, so this actually satisfies the
    // property's declared type instead of just rounding the value.
    anchor.rect.x: (anchorWindow.width - pillBarWidth - 12) | 0
    // 12px below the pill's actual rendered bottom edge (pillBarBottomY,
    // passed in from Bar.qml) — same spacing Launcher.qml uses between its
    // search pill and its own app-list dropdown (cardColumn.spacing: 12).
    // Deliberately NOT anchorWindow.height: barWindow is taller than the
    // pill itself, and using the window's height instead of the pill's
    // real edge silently added an extra 4px, making this gap 16px instead
    // of 12px.
    anchor.rect.y: (pillBarBottomY + 12) | 0

    implicitWidth: pillBarWidth
    implicitHeight: 430
    color: "transparent"

    // HACK(wayland): grabFocus sets visible=false directly, killing close anims.
    // Re-show, animate close, then hide after delay.
    grabFocus: isOpen

    property bool _closing: false

    visible: false

    onIsOpenChanged: {
        if (controlCenterPopup.isOpen) {
            controlCenterPopup._closing = false
            controlCenterPopup.visible = true
        } else if (!controlCenterPopup._closing) {
            controlCenterPopup._closing = true
            closeTimer.start()
        }
    }

    onVisibleChanged: {
        if (!controlCenterPopup.visible && controlCenterPopup.isOpen && !controlCenterPopup._closing) {
            controlCenterPopup._closing = true
            controlCenterPopup.isOpen = false
            controlCenterPopup.visible = true
            closeTimer.start()
        }
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: {
            controlCenterPopup._closing = false
            controlCenterPopup.visible = false
        }
    }

    Rectangle {
        id: menuContainer
        width: parent.width
        height: controlCenterPopup.isOpen ? 430 : 0
        opacity: controlCenterPopup.isOpen ? 1 : 0
        scale: controlCenterPopup.isOpen ? 1 : 0.95
        transformOrigin: Item.Top
        clip: true
        radius: 18
        color: Theme.cBg
        border.color: Theme.cCardBorder
        border.width: 1

        // NOTE: deliberately no translateY/slide transform here. menuContainer
        // lives inside a real PopupWindow — a fixed-size native surface, not
        // a DOM element with overflow. Sliding it up to a negative y (the
        // classic "slide down from -20 to 0" trick) pushes part of it above
        // the window's own y:0 boundary, and a window surface simply cannot
        // render anything past its own edge — that's what was cutting off
        // the top of the panel during the open animation. height animating
        // 0 → 430 with transformOrigin: Item.Top already gives the "growing
        // down from the top" read on its own, and can never exceed the
        // window's bounds, so it's the safer way to get that effect.

        // Height and opacity use SmoothedAnimation rather than SpringAnimation.
        // SmoothedAnimation tracks a *moving* target (it's built for exactly
        // that — see Qt's docs, it's designed for values that may keep
        // changing mid-animation) so if the panel's content grows/shrinks
        // while it's still unfolding, it smoothly retargets instead of
        // jumping or restarting the curve. It also never overshoots, which
        // matters here: height briefly overshooting past its target would
        // mean momentarily rendering negative height (warnings/clipping
        // glitches) or peeking past the intended max size.
        Behavior on height {
            SmoothedAnimation { duration: 320; velocity: -1 }
        }
        Behavior on opacity {
            SmoothedAnimation { duration: 220; velocity: -1 }
        }

        // Scale is where the "unfold" reads as spring-driven rather than
        // eased — a real SpringAnimation, lightly underdamped so it settles
        // with a small, soft overshoot (like Niri's window-open animation)
        // instead of snapping to rest. Same spring config drives both open
        // and close, so the motion feels identical in both directions —
        // just running toward a different target. Overshoot here is safe
        // (unlike on the old translateY): scale is anchored at
        // transformOrigin: Item.Top, so any overshoot past 1.0 grows the
        // box by a couple of px around that fixed top edge rather than
        // pushing it off past the window's boundary.
        Behavior on scale {
            SpringAnimation { spring: 2.4; damping: 0.45; mass: 0.9; epsilon: 0.001 }
        }

        ColumnLayout {
            anchors.fill: parent
            // Top padding is 12 to match the shell's standard spacing unit
            // (Theme.barEdgeMargin, same value Bar.qml/Launcher.qml use).
            // Left/right/bottom stay at the original 14 — only the top was
            // requested to change.
            anchors.topMargin: 12
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.bottomMargin: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: Theme.cAccent
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.fill: parent
                        source: SystemState.avatarPath
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: status === Image.Ready
                        onStatusChanged: { if (status === Image.Error) fallbackText.visible = true }
                    }
                    Text {
                        id: fallbackText
                        anchors.centerIn: parent
                        text: "󰣇"
                        color: "#ffffff"
                        font.pixelSize: 20
                        visible: false
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    Text {
                        text: SystemState.userAtHost
                        color: Theme.cFg
                        font.family: "Hermit"; font.pixelSize: 13; font.bold: true
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        text: Qt.formatDateTime(new Date(), "MMM dd yyyy") + " • Battery " + SystemState.batteryCapacity + "%"
                        color: Theme.cFgMuted
                        font.family: "Hermit"; font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.cCardBorder }

            RowLayout {
                Layout.fillWidth: true; spacing: 8

                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 46; radius: 10
                    color: SystemState.wifiConnected ? Theme.cCardActive : Theme.cCardBg
                    border.color: SystemState.wifiConnected ? Theme.cAccent : Theme.cCardBorder; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Text {
                            text: SystemState.getNetworkIcon(SystemState.ethernetConnected, SystemState.wifiConnected, SystemState.wifiSignal)
                            color: SystemState.wifiConnected ? Theme.cAccent : Theme.cFgMuted
                            font.family: "Hermit"; font.pixelSize: 18; Layout.alignment: Qt.AlignVCenter
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 1
                            Text { text: "Wi-Fi"; color: Theme.cFg; font.family: "Hermit"; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: SystemState.wifiName; color: Theme.cFgMuted; font.family: "Hermit"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 46; radius: 10
                    color: SystemState.bluetoothOn ? Theme.cCardActive : Theme.cCardBg
                    border.color: SystemState.bluetoothOn ? Theme.cAccent : Theme.cCardBorder; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Text {
                            text: SystemState.bluetoothOn ? "󰂯" : "󰂲"
                            color: SystemState.bluetoothOn ? Theme.cAccent : Theme.cFgMuted
                            font.family: "Hermit"; font.pixelSize: 18; Layout.alignment: Qt.AlignVCenter
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 1
                            Text { text: "Bluetooth"; color: Theme.cFg; font.family: "Hermit"; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: SystemState.bluetoothDevice; color: Theme.cFgMuted; font.family: "Hermit"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }
                }
            }

            Rectangle {
                id: mediaCard
                Layout.fillWidth: true
                implicitHeight: 64
                radius: 10
                color: Theme.cCardBg
                border.color: Theme.cCardBorder
                border.width: 1

                // HACK(perf): Quickshell MPRIS cache goes stale (Firefox, etc.);
                // playerctl metadata --follow for real-time updates.
                property string trackTitle: ""
                property string trackArtist: ""
                property string trackArtUrl: ""
                property string sourceKind: "none"
                property bool isPlaying: false
                property string latchedArt: ""

                property string _cachedTitle: ""
                property string _cachedArtist: ""
                property string _cachedArtUrl: ""
                property bool _cachedPlaying: false

                property string _fetchedArtUrl: ""
                property string _lastFetchKey: ""

                function _fetchKey() {
                    return (mediaCard.trackArtist + "||" + mediaCard.trackTitle).toLowerCase().trim()
                }

                function _maybeFetchArt() {
                    if (mediaCard.latchedArt !== "") return
                    let title = mediaCard.trackTitle
                    let artist = mediaCard.trackArtist
                    if (title === "" || artist === "") return
                    let key = mediaCard._fetchKey()
                    if (key === mediaCard._lastFetchKey) return
                    mediaCard._lastFetchKey = key
                    if (mediaCard._fetchedArtUrl !== "") {
                        mediaCard.latchedArt = mediaCard._fetchedArtUrl
                        return
                    }
                    let query = encodeURIComponent(artist + " " + title)
                    let safeArtist = artist.replace(/'/g, "'\\''")
                    let pyScript = "import sys, json\n" +
                        "data = json.load(sys.stdin)\n" +
                        "results = data.get('results', [])\n" +
                        "artist_target = sys.argv[1].lower() if len(sys.argv) > 1 else ''\n" +
                        "for r in results:\n" +
                        "    if r.get('artistName', '').lower() == artist_target:\n" +
                        "        print(r.get('artworkUrl100', '').replace('100x100bb', '300x300bb'))\n" +
                        "        sys.exit(0)\n" +
                        "if results:\n" +
                        "    print(results[0].get('artworkUrl100', '').replace('100x100bb', '300x300bb'))\n" +
                        "else:\n" +
                        "    print('')\n"
                    artFetchProc.command = [
                        "sh", "-c",
                        "curl -s 'https://itunes.apple.com/search?term=" + query +
                        "&limit=3&entity=song' 2>/dev/null | " +
                        "python3 -c \"" + pyScript + "\" '" + safeArtist + "'"
                    ]
                    artFetchProc.running = true
                }

                Process {
                    id: artFetchProc
                    running: false
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let url = this.text.trim()
                            if (url !== "") {
                                mediaCard._fetchedArtUrl = url
                                mediaCard.latchedArt = url
                            }
                        }
                    }
                }

                function _detectSourceKind(identity) {
                    let id = (identity || "").toLowerCase()
                    if (id.indexOf("spotify") !== -1) return "spotify"
                    if (id.indexOf("firefox") !== -1 || id.indexOf("chrom") !== -1 ||
                        id.indexOf("brave") !== -1 || id.indexOf("edge") !== -1 ||
                        id.indexOf("browser") !== -1) return "browser"
                    return "generic"
                }

                function fallbackIcon(kind) {
                    switch (kind) {
                        case "spotify": return "󰓇"
                        case "browser": return "󰗃"
                        default: return "󰎈"
                    }
                }

                Process {
                    id: metaFollowProc
                    running: true
                    command: ["sh", "-c",
                        "playerctl metadata --follow --format " +
                        "'{{playerName}}|{{title}}|{{artist}}|{{mpris:artUrl}}|{{status}}' " +
                        "2>/dev/null || while true; do echo '|||'; sleep 1; done"
                    ]
                    stdout: SplitParser {
                        onRead: data => {
                            let line = String(data).trim()
                            if (line === "") return
                            let parts = line.split("|")
                            let identity = parts[0] || ""
                            let newTitle = parts[1] || ""
                            let newArtist = parts[2] || ""
                            let newArtUrl = parts[3] || ""
                            let newStatus = parts[4] || ""

                            let newSource = mediaCard._detectSourceKind(identity)
                            if (newSource !== mediaCard.sourceKind) mediaCard.sourceKind = newSource

                            let newPlaying = (newStatus === "Playing")
                            if (newPlaying !== mediaCard._cachedPlaying) {
                                mediaCard._cachedPlaying = newPlaying
                                mediaCard.isPlaying = newPlaying
                            }

                            if (newTitle !== mediaCard._cachedTitle) {
                                mediaCard._cachedTitle = newTitle
                                mediaCard.trackTitle = newTitle
                            }

                            if (newArtist !== mediaCard._cachedArtist) {
                                mediaCard._cachedArtist = newArtist
                                mediaCard.trackArtist = newArtist
                            }

                            if (newArtUrl !== mediaCard._cachedArtUrl) {
                                mediaCard._cachedArtUrl = newArtUrl
                                mediaCard.trackArtUrl = newArtUrl
                                if (newArtUrl !== "") mediaCard.latchedArt = newArtUrl
                            }

                            if (mediaCard.latchedArt === "" && newTitle !== "" && newArtist !== "") {
                                mediaCard._maybeFetchArt()
                            }
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Rectangle {
                        id: artContainer
                        implicitWidth: 42; implicitHeight: 42; radius: 8
                        color: Theme.cCardBorder
                        border.color: Theme.cCardBorder
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter

                        layer.enabled: true
                        layer.effect: DropShadow {
                            transparentBorder: true
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 6
                            samples: 13
                            color: "#40000000"
                        }

                        // NOTE: clip:true ignores Rectangle.radius — leaves square artifacts.
                        // OpacityMask with a separate mask shape gives proper anti-aliased rounded corners.
                        Image {
                            id: artImage
                            anchors.fill: parent
                            source: mediaCard.latchedArt !== "" ? mediaCard.latchedArt : mediaCard.trackArtUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: false
                        }

                        Rectangle {
                            id: artMaskShape
                            anchors.fill: parent
                            radius: 8
                            color: "black"
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: artImage
                            source: artImage
                            maskSource: artMaskShape
                            visible: artImage.status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: mediaCard.fallbackIcon(mediaCard.sourceKind)
                            color: Theme.cFgMuted; font.pixelSize: 20
                            visible: artImage.status !== Image.Ready
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 2
                        Text {
                            text: mediaCard.trackTitle !== "" ? mediaCard.trackTitle : "No Media Playing"
                            color: Theme.cFg; font.family: "Hermit"; font.pixelSize: 12; font.bold: true
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: mediaCard.trackArtist !== "" ? mediaCard.trackArtist : "Media Player"
                            color: Theme.cFgMuted; font.family: "Hermit"; font.pixelSize: 10
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        spacing: 8; Layout.alignment: Qt.AlignVCenter

                        Process { id: transportProc; running: false }

                        Text {
                            text: "󰒮"; color: Theme.cFg; font.pixelSize: 18; Layout.alignment: Qt.AlignVCenter
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { transportProc.command = ["playerctl", "previous"]; transportProc.running = true }
                            }
                        }

                        Text {
                            text: mediaCard.isPlaying ? "󰏤" : "󰐊"
                            color: Theme.cAccent; font.pixelSize: 22; Layout.alignment: Qt.AlignVCenter
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { transportProc.command = ["playerctl", "play-pause"]; transportProc.running = true }
                            }
                        }

                        Text {
                            text: "󰒡"; color: Theme.cFg; font.pixelSize: 18; Layout.alignment: Qt.AlignVCenter
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { transportProc.command = ["playerctl", "next"]; transportProc.running = true }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Notifications"; color: Theme.cFgMuted; font.family: "Hermit"; font.pixelSize: 12; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: notifListView.count > 0 ? notifListView.count.toString() : ""
                        color: Theme.cAccent; font.family: "Hermit"; font.pixelSize: 11; font.bold: true
                    }
                    Rectangle {
                        implicitWidth: clearLabel.implicitWidth + 16
                        implicitHeight: 20
                        radius: 8
                        color: Theme.cCardBg
                        border.color: Theme.cCardBorder; border.width: 1
                        visible: notifListView.count > 0
                        Layout.leftMargin: 8
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Clear"
                            color: Theme.cFgMuted; font.family: "Hermit"; font.pixelSize: 11; font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: controlCenterPopup.clearAllNotifications()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 10
                    color: Theme.cCardBg; border.color: Theme.cCardBorder; border.width: 1; clip: true

                    ListView {
                        id: notifListView
                        anchors.fill: parent; anchors.margins: 6; spacing: 6; clip: true
                        model: controlCenterPopup.notifServer ? controlCenterPopup.notifServer.trackedNotifications : null

                        // Slide the removed item out to the right while fading it,
                        // and smoothly slide remaining items up to fill the gap.
                        remove: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
                                NumberAnimation { property: "x"; to: notifListView.width; duration: 200; easing.type: Easing.InCubic }
                            }
                        }
                        displaced: Transition {
                            NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
                        }

                        delegate: Rectangle {
                            width: notifListView.width
                            implicitHeight: notifMainRow.implicitHeight + 12; radius: 8
                            color: modelData && modelData.urgency === 2 ? "#fff5f5" : "#ffffff"
                            border.color: modelData && modelData.urgency === 2 ? Theme.cUrgent : Theme.cCardBorder; border.width: 1

                            RowLayout {
                                id: notifMainRow
                                anchors.fill: parent; anchors.margins: 8; spacing: 8

                                Rectangle {
                                    implicitWidth: 28; implicitHeight: 28; radius: 6
                                    color: modelData && modelData.urgency === 2 ? Theme.cUrgent : Theme.cCardActive
                                    Layout.alignment: Qt.AlignTop; Layout.topMargin: 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData && modelData.urgency === 2 ? "󰵅" : "󰂚"
                                        color: modelData && modelData.urgency === 2 ? "#ffffff" : Theme.cAccent
                                        font.pixelSize: 15
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2

                                    Text {
                                        text: (modelData && modelData.appName) ? modelData.appName : "System"
                                        color: modelData && modelData.urgency === 2 ? Theme.cUrgent : Theme.cFgMuted
                                        font.family: "Hermit"; font.pixelSize: 10; font.bold: true
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                    Text {
                                        text: (modelData && modelData.summary) ? modelData.summary : "Notification"
                                        color: Theme.cFg; font.family: "Hermit"; font.pixelSize: 11; font.bold: true
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                    Text {
                                        text: (modelData && modelData.body) ? modelData.body : ""
                                        color: Theme.cFgMuted; font.family: "Hermit"; font.pixelSize: 10
                                        elide: Text.ElideRight; maximumLineCount: 3; wrapMode: Text.Wrap
                                        visible: text !== ""; Layout.fillWidth: true
                                    }
                                }

                                Text {
                                    text: "󰅖"; color: Theme.cFgMuted; font.pixelSize: 14; Layout.alignment: Qt.AlignTop
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData && typeof modelData.dismiss === "function") {
                                                modelData.dismiss()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No Notifications"; color: Theme.cFgMuted
                            font.family: "Hermit"; font.pixelSize: 11
                            visible: notifListView.count === 0
                        }
                    }
                }
            }

            Item { Layout.fillHeight: false; height: 2 }

            RowLayout {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter

                Process { id: powerFooterProc; running: false }

                Text {
                    text: "󰌾 Lock"; color: Theme.cFg; font.family: "Hermit"; font.pixelSize: 12; font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            controlCenterPopup.isOpen = false
                            powerFooterProc.command = ["sh", "-c", "swaylock || loginctl lock-session"]
                            powerFooterProc.running = true
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "󰤆 Power Off"; color: Theme.cUrgent; font.family: "Hermit"; font.pixelSize: 12; font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            controlCenterPopup.isOpen = false
                            powerFooterProc.command = ["systemctl", "poweroff"]
                            powerFooterProc.running = true
                        }
                    }
                }
            }
        }
    }
}
