import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Application launcher overlay. Toggled via IPC (see the `IpcHandler` below)
// so a compositor keybind (e.g. Niri's Super+D) can pop it open without
// Quickshell needing to own the global shortcut itself.
Scope {
    id: launcherRoot

    property bool isOpen: false
    property int selectedIndex: 0
    property string query: ""

    // NOTE: DesktopEntries/DesktopEntry are core Quickshell types (part of
    // the base `Quickshell` module, not a separate services import) — the
    // ObjectModel's `.values` property is the confirmed way to get an
    // indexable/filterable JS array out of it.
    property var allApps: DesktopEntries.applications ? DesktopEntries.applications.values : []

    // Plain functional binding — QML re-evaluates it whenever `query` or
    // `allApps` changes, no manual re-filter call needed.
    property var filteredApps: {
        if (!query.length) return allApps
        const q = query.toLowerCase()
        return allApps.filter(a => a && a.name && a.name.toLowerCase().indexOf(q) !== -1)
    }

    function open() {
        isOpen = true
    }

    function close() {
        isOpen = false
    }

    function toggle() {
        isOpen = !isOpen
    }

    function moveSelection(delta) {
        if (!filteredApps.length) return
        let next = selectedIndex + delta
        if (next < 0) next = 0
        if (next > filteredApps.length - 1) next = filteredApps.length - 1
        selectedIndex = next
        resultsListView.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    // entry.execute() runs the parsed Exec command from the .desktop file.
    function launchSelected() {
        const entry = filteredApps[selectedIndex]
        if (entry && typeof entry.execute === "function") {
            entry.execute()
        }
        close()
    }

    onIsOpenChanged: {
        if (isOpen) {
            searchField.text = ""
            selectedIndex = 0
            // Deferred a beat so it fires after the surface's mask/focus
            // change actually takes effect — grabbing focus in the same
            // tick as the visibility/mask flip is unreliable on some
            // wlr-layer-shell compositors.
            Qt.callLater(() => searchField.forceActiveFocus())
        }
    }

    // NOTE: bind a compositor keypress to `qs ipc call launcher toggle`
    // (see the Niri config.kdl snippet at the bottom of this file's
    // accompanying explanation) rather than Quickshell owning a global
    // shortcut directly — keeps the keybind itself under compositor config,
    // consistent with how this shell already lets Niri drive workspace
    // switching (see SystemState.qml's niriEventProc).
    IpcHandler {
        target: "launcher"
        function toggle(): void { launcherRoot.toggle() }
        function open(): void { launcherRoot.open() }
        function close(): void { launcherRoot.close() }
    }

    // NOTE: single-screen by design (Quickshell.screens[0]), matching
    // Notifications.qml's toast window rather than Bar.qml's per-monitor
    // Variants — a launcher overlay is a single, screen-agnostic surface,
    // and per-screen instancing would also break the id-scoping this file
    // relies on (searchField/resultsListView referenced directly from
    // root-level functions above).
    PanelWindow {
        id: launcherWindow
        screen: Quickshell.screens[0]

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: launcherRoot.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Bar.qml auto-reserves its own height as an exclusion zone (it has
        // 3 anchors, which triggers ExclusionMode.Auto). Without this,
        // niri slides Launcher's top-anchored window down below that
        // reserved strut before its content is even positioned. Ignoring
        // exclusion zones here means Launcher's window sits flush at the
        // screen's top-left corner, same as Bar's own window does — with
        // cardColumn's margins (below) providing the 12px inset, mirroring
        // Bar's RowLayout margins exactly rather than adding a second,
        // window-level offset on top of it.
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
        }

        // Matches the top bar's pill width live via SystemState (set by
        // Bar.qml's pillBar) — same as ControlCenter.qml's own
        // implicitWidth: pillBarWidth, with no fallback/minimum, so the
        // two pills are always exactly the same width.
        implicitWidth: SystemState.barPillWidth
        implicitHeight: 480
        color: "transparent"

        // NOTE: this surface stays permanently mapped (visible: true)
        // rather than toggling `visible` with isOpen. That's what lets the
        // fade+scale transition on launcherCard below actually play on
        // close — if the surface itself unmapped instantly there'd be
        // nothing left on screen to animate. `mask` is what makes the
        // surface click-through and non-interactive while logically
        // closed — same Region hack Bar.qml uses for outsideClickCatcher,
        // needed because niri has no xdg_popup grab to lean on instead.
        visible: true
        mask: launcherRoot.isOpen ? cardRegion : nothingRegion
        Item { id: nothingItem; width: 0; height: 0 }
        Region { id: nothingRegion; item: nothingItem }
        Region { id: cardRegion; item: launcherCard }

        Item {
            id: launcherCard
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            // Sizes to whatever's actually showing — just the search pill
            // when there's no query, plus the results panel once one
            // appears — rather than always rendering a full-height card.
            // The outer window keeps its fixed implicitHeight (see above)
            // so the wlr-layer-shell surface itself never resizes; only
            // this ordinary Item resizes, which is cheap and animatable.
            implicitHeight: cardColumn.implicitHeight + 24

            // Plain Item, not Rectangle — there's no color/border to set
            // here at all. This is purely a sizing/animation wrapper
            // around the layout below; the search pill and results panel
            // each already draw their own rounded background (matching
            // Bar.qml's pill style), so giving this wrapper a background
            // too doubled up into a "card inside a card" look.

            opacity: launcherRoot.isOpen ? 1 : 0
            scale: launcherRoot.isOpen ? 1 : 0.95
            transformOrigin: Item.Top

            // NOTE: no translateY/slide transform (previously animated
            // -12 -> 0 via a Translate). Same issue as ControlCenter.qml's
            // menuContainer: launcherWindow is a fixed-size real
            // wlr-layer-shell surface (implicitHeight: 480), not a DOM
            // element with overflow, so translating this card to a
            // negative y pushed part of it above the surface's own y:0
            // edge — invisible, not just clipped-looking. scale (anchored
            // at transformOrigin: Item.Top) already reads as an "unfold
            // from the top" on its own without that risk.

            // implicitHeight and opacity use SmoothedAnimation rather than
            // NumberAnimation, matching ControlCenter.qml's menuContainer.
            // SmoothedAnimation tracks a *moving* target smoothly instead of
            // restarting/jumping — relevant here because implicitHeight
            // isn't just an open/close value, it also changes live as
            // filteredApps/resultsPanel grows or shrinks while typing, so
            // the target can shift mid-animation.
            Behavior on implicitHeight {
                SmoothedAnimation { duration: 320; velocity: -1 }
            }
            Behavior on opacity {
                SmoothedAnimation { duration: 220; velocity: -1 }
            }
            // scale uses the same lightly-underdamped SpringAnimation as
            // ControlCenter.qml, for the same soft-overshoot "premium"
            // unfold feel, driving both open and close identically.
            Behavior on scale {
                SpringAnimation { spring: 2.4; damping: 0.45; mass: 0.9; epsilon: 0.001 }
            }

            // Swallows clicks inside the card so they don't fall through
            // to outsideClickCatcher below and close the launcher.
            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: cardColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    // All three margins are 12 to mirror Bar.qml's own
                    // RowLayout margins exactly, so this search pill sits
                    // on the same top line, and the same inset from its
                    // screen edge, as Bar's pill does from its edge — a
                    // true left/right mirror. (Not related to
                    // ControlCenter.qml's anchor.rect.y — that's a dropdown
                    // gap below the bar, a different relationship.)
                    topMargin: 12
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 12

                // --- Search pill --------------------------------------
                // Sized and colored to match Bar.qml's pillBar exactly
                // (implicitHeight: 36, radius: 18, color: Theme.cBg) so
                // this reads as the same pill, not a separate style.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 18
                    color: Theme.cBg
                    border.color: Theme.cCardBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 8

                        Text {
                            text: "\uf002" // nf-fa-search
                            font.family: "Hermit"
                            font.pixelSize: 14
                            color: Theme.cFgMuted
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            implicitHeight: searchField.implicitHeight

                            Text {
                                text: "Search apps..."
                                color: Theme.cFgMuted
                                font: searchField.font
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !searchField.text.length
                            }

                            TextInput {
                                id: searchField
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.cFg
                                font.family: "Hermit"
                                font.pixelSize: 12
                                clip: true
                                selectByMouse: true

                                onTextChanged: {
                                    launcherRoot.query = text
                                    launcherRoot.selectedIndex = 0
                                }

                                Keys.onEscapePressed: launcherRoot.close()
                                Keys.onUpPressed: launcherRoot.moveSelection(-1)
                                Keys.onDownPressed: launcherRoot.moveSelection(1)
                                Keys.onReturnPressed: launcherRoot.launchSelected()
                                Keys.onEnterPressed: launcherRoot.launchSelected()
                            }
                        }
                    }
                }

                // --- Results panel -------------------------------------
                Rectangle {
                    id: resultsPanel
                    Layout.fillWidth: true
                    // NOTE: capped, content-driven height — this Rectangle
                    // resizing is a cheap ordinary Item resize, not a
                    // wlr-layer-shell surface resize (the outer
                    // launcherWindow above is fixed at implicitHeight: 480
                    // for exactly that reason — see Notifications.qml for
                    // the flicker this distinction fixes). An empty query
                    // means "no filter" in filteredApps, not "no results",
                    // so filteredApps.length alone can't be used to decide
                    // whether this panel should be showing.
                    readonly property int maxVisibleRows: 6
                    readonly property int rowHeight: 52
                    readonly property int rowSpacing: 4
                    readonly property bool shouldShow: launcherRoot.query.length > 0 && launcherRoot.filteredApps.length > 0

                    // Target collapses to 0 rather than toggling `visible`.
                    // Qt Quick Layouts drops invisible children out of the
                    // layout entirely, so a `visible` flip has no height to
                    // animate from/to — it would just pop. Animating the
                    // height itself down to 0 (still `visible: true`, see
                    // below) is what lets this grow/shrink with the same
                    // SmoothedAnimation the rest of the launcher/control
                    // center uses, whether the change is the panel
                    // appearing/disappearing or just the result count
                    // changing while typing.
                    Layout.preferredHeight: shouldShow
                        ? Math.min(launcherRoot.filteredApps.length, maxVisibleRows) * (rowHeight + rowSpacing) + 16
                        : 0
                    opacity: shouldShow ? 1 : 0
                    clip: true
                    radius: 14
                    color: Theme.cCardBg
                    border.color: Theme.cCardBorder
                    border.width: 1

                    // Same motion as launcherCard's implicitHeight/opacity
                    // and ControlCenter.qml's menuContainer — SmoothedAnimation
                    // so a target that keeps shifting (result count changing
                    // on every keystroke) retargets smoothly instead of
                    // restarting the curve each time.
                    Behavior on Layout.preferredHeight {
                        SmoothedAnimation { duration: 320; velocity: -1 }
                    }
                    Behavior on opacity {
                        SmoothedAnimation { duration: 220; velocity: -1 }
                    }

                    ListView {
                        id: resultsListView
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: resultsPanel.rowSpacing
                        clip: true
                        model: launcherRoot.filteredApps
                        currentIndex: launcherRoot.selectedIndex
                        interactive: contentHeight > height

                        delegate: Rectangle {
                            width: resultsListView.width
                            implicitHeight: resultsPanel.rowHeight
                            radius: 10
                            color: index === launcherRoot.selectedIndex ? Theme.cCardActive : "transparent"

                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                // Quickshell registers an image provider for
                                // themed icon lookups at image://icon/<name>.
                                Image {
                                    source: modelData && modelData.icon
                                        ? "image://icon/" + modelData.icon
                                        : ""
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    Layout.alignment: Qt.AlignVCenter
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: modelData ? modelData.name : ""
                                        color: Theme.cFg
                                        font.family: "Hermit"
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData ? (modelData.comment || modelData.genericName || "") : ""
                                        color: Theme.cFgMuted
                                        font.family: "Hermit"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: launcherRoot.selectedIndex = index
                                onClicked: launcherRoot.launchSelected()
                            }
                        }
                    }
                }
            }
        }
    }

    // HACK(wayland): same outside-click-dismiss pattern as Bar.qml's
    // outsideClickCatcher — niri has no xdg_popup grab, so a fullscreen
    // transparent surface with a toggled input mask is how "click outside
    // to close" gets implemented here.
    PanelWindow {
        id: outsideClickCatcher
        screen: Quickshell.screens[0]

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        color: "transparent"
        mask: launcherRoot.isOpen ? null : catcherNothingRegion

        Item { id: catcherNothingItem; width: 0; height: 0 }
        Region { id: catcherNothingRegion; item: catcherNothingItem }

        MouseArea {
            anchors.fill: parent
            enabled: launcherRoot.isOpen
            onClicked: launcherRoot.close()
        }
    }
}
