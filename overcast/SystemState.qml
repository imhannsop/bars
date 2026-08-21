pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Singleton via qmldir — accessible shell-wide as `SystemState.foo`, no import
// needed. Single source of truth for non-visual/non-notification state;
// Bar.qml and ControlCenter.qml both bind directly to these properties.
Scope {
    id: systemState

    property string avatarPath: "file://" + Quickshell.env("HOME") + "/.config/quickshell/avatar.png"
    property string userName: Quickshell.env("USER") || "user"
    property string hostName: Quickshell.env("HOSTNAME") || Quickshell.env("HOST") || "yoi"
    property string userAtHost: userName + "@" + systemState.hostName

    // Bar.qml's pillBar reports its live width here so other windows
    // (Launcher.qml) can size themselves to match without needing a direct
    // cross-file property wire-up through shell.qml.
    property real barPillWidth: 320

    // ----------------------------------------------------
    // NIRI WORKSPACE STATE
    // ----------------------------------------------------
    property int currentWorkspace: 1
    property int totalWorkspaces: 9

    function setWorkspace(wsNumber) {
        let target = parseInt(wsNumber)
        if (!isNaN(target)) {
            systemState.currentWorkspace = Math.max(1, Math.min(target, systemState.totalWorkspaces))
        }
    }

    function switchToWorkspace(wsNumber) {
        let target = Math.max(1, Math.min(parseInt(wsNumber), systemState.totalWorkspaces))
        systemState.setWorkspace(target)

        // WARN: wmctrl fallback assumes workspace indices line up 1:1 with Niri's
        // (target - 1), which only holds if no dynamic/named workspaces are in play.
        wsProc.command = ["sh", "-c",
            "niri msg action focus-workspace " + target + " 2>/dev/null || " +
            "wmctrl -s " + (target - 1)
        ]
        wsProc.running = true
    }

    Process {
        id: wsProc
        running: false
    }

    // Long-lived `event-stream` subscription — Niri pushes on every workspace/
    // window change instead of us having to poll. Kept running: true permanently.
    Process {
        id: niriEventProc
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    let event = JSON.parse(data)
                    if (event && (event.WorkspaceActivated || event.WorkspacesChanged || event.WindowFocused)) {
                        // HACK(wayland): toggling running off/on is how you force a
                        // one-shot Process to re-execute; there's no restart() method.
                        // Rapid-fire events (e.g. window focus churn) will spawn a new
                        // `niri msg workspaces` process per event — no debounce.
                        niriPollProc.running = false
                        niriPollProc.running = true
                    }
                } catch (e) {}
                // NOTE: malformed/partial JSON on a line is silently dropped; a
                // truncated stdout chunk here just means one missed sync, not a crash.
            }
        }
    }

    // One-shot snapshot poll, re-triggered by niriEventProc above rather than
    // trusting the event payload itself (event-stream deltas don't carry full
    // workspace state, so we always re-fetch ground truth).
    Process {
        id: niriPollProc
        command: ["niri", "msg", "--json", "workspaces"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let list = JSON.parse(this.text.trim())
                    if (Array.isArray(list)) {
                        for (let i = 0; i < list.length; i++) {
                            if (list[i].is_focused || list[i].is_active) {
                                let wsNum = (list[i].idx !== undefined) ? list[i].idx : (i + 1)
                                systemState.setWorkspace(wsNum)
                                break
                            }
                        }
                    }
                } catch (e) {}
            }
        }
    }

    // NOTE: This shell targets Niri. Quickshell.Hyprland is intentionally NOT
    // imported, so the `Hyprland` singleton does not exist in this scope.
    // Any future Hyprland integration must be guarded like so to avoid a
    // runtime ReferenceError:
    //
    //     if (typeof Hyprland !== "undefined" && Hyprland) { ... }
    //
    // The previously empty Component.onCompleted / Connections { target: Hyprland }
    // block has been removed entirely, which is the cleanest way to ensure no
    // ReferenceError is thrown under Niri.

    // ----------------------------------------------------
    // BATTERY STATE
    // ----------------------------------------------------
    property int fallbackCapacity: 100
    property string fallbackStatus: "Discharging"

    // UPower is the primary source; sysfs polling below only backstops
    // environments where upowerd isn't running (e.g. minimal/headless installs).
    readonly property bool isUPowerReady: UPower.displayDevice && UPower.displayDevice.ready
    readonly property int batteryCapacity: isUPowerReady ? Math.round(UPower.displayDevice.percentage * 100) : fallbackCapacity
    readonly property bool isCharging: isUPowerReady
        ? (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)
        : (fallbackStatus === "Charging" || fallbackStatus === "Full")

    // WARN: `BAT*` glob grabs the first match only — multi-battery laptops
    // (dual internal batteries) will silently report just one.
    Process {
        id: sysfsBatteryProc
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -d \"$b\" ] && cat \"$b/capacity\" \"$b/status\" && break; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                if (lines.length >= 1 && !isNaN(parseInt(lines[0]))) systemState.fallbackCapacity = parseInt(lines[0])
                if (lines.length >= 2) systemState.fallbackStatus = lines[1].trim()
            }
        }
    }

    // ----------------------------------------------------
    // WI-FI & BLUETOOTH STATE
    // ----------------------------------------------------
    property bool wifiConnected: false
    property bool ethernetConnected: false
    property int wifiSignal: 0
    property string wifiName: "Disconnected"
    property bool bluetoothOn: false
    property string bluetoothDevice: "No Device"

    // TODO(perf): nmcli is spawned once per second via the Timer below even
    // when nothing has changed — fine for a bar, but consider switching to
    // NetworkManager's D-Bus signals if this ever shows up in profiling.
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION dev; echo '---'; nmcli -t -f IN-USE,SSID,SIGNAL dev wifi | grep '^\*:'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("---")
                let devInfo = parts[0] ? parts[0].trim().split("\n") : []
                let wifiInfo = parts[1] ? parts[1].trim() : ""

                let isEth = false
                let isWifi = false
                let connName = ""

                // NOTE: last matching device line wins if multiple ethernet/wifi
                // devices are connected simultaneously — no explicit priority.
                for (let line of devInfo) {
                    if (line.includes("ethernet:connected")) { isEth = true; connName = line.split(":")[2] || "Ethernet"; }
                    if (line.includes("wifi:connected")) { isWifi = true; }
                }

                systemState.ethernetConnected = isEth
                systemState.wifiConnected = isWifi

                if (isWifi && wifiInfo.length > 0) {
                    let fields = wifiInfo.split(":")
                    if (fields.length >= 3) {
                        systemState.wifiName = fields[1] || "Connected"
                        let sig = parseInt(fields[2])
                        if (!isNaN(sig)) systemState.wifiSignal = sig
                    }
                } else if (isEth) {
                    systemState.wifiName = connName
                } else {
                    systemState.wifiName = "Disconnected"
                    systemState.wifiSignal = 0
                }
            }
        }
    }

    // WARN: bluetoothctl's output format is not a stable, versioned API —
    // this text scraping can break across bluez releases.
    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl show | grep 'Powered: yes'; echo '---'; bluetoothctl info | grep 'Name:'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("---")
                systemState.bluetoothOn = parts[0] && parts[0].includes("Powered: yes")
                if (parts[1] && parts[1].includes("Name:")) {
                    systemState.bluetoothDevice = parts[1].replace("Name:", "").trim()
                } else {
                    systemState.bluetoothDevice = systemState.bluetoothOn ? "On" : "Off"
                }
            }
        }
    }

    // One-shot: overrides the env-derived hostName/userAtHost once `uname -n`
    // resolves, since $HOSTNAME isn't reliably exported in all login shells.
    Process {
        command: ["uname", "-n"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "") {
                    systemState.hostName = this.text.trim()
                    systemState.userAtHost = systemState.userName + "@" + systemState.hostName
                }
            }
        }
    }

    property string currentTime: ""
    // NOTE: this Timer doubles as the polling heartbeat for net/bt/sysfs-battery
    // and as a watchdog that restarts niriEventProc if the event-stream process
    // ever dies. The `running === false` guards prevent overlapping spawns if a
    // prior invocation hasn't finished within the 1s interval, but a process
    // that legitimately takes >1s (e.g. bluetoothctl under load) will just be
    // skipped that tick rather than queued.
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            systemState.currentTime = new Date().toLocaleTimeString(Qt.locale(), "h:mm AP")
            if (!systemState.isUPowerReady && sysfsBatteryProc.running === false) sysfsBatteryProc.running = true
            if (netProc.running === false) netProc.running = true
            if (btProc.running === false) btProc.running = true
            if (niriEventProc.running === false) niriEventProc.running = true
        }
    }

    // ----------------------------------------------------
    // ICON MAPPERS
    // ----------------------------------------------------
    function getStandingBatteryIcon(cap, charging) {
        if (charging) {
            if (cap >= 95) return "󰂅"
            if (cap >= 85) return "󰂋"
            if (cap >= 75) return "󰂊"
            if (cap >= 65) return "󰢞"
            if (cap >= 55) return "󰂉"
            if (cap >= 45) return "󰢝"
            if (cap >= 35) return "󰂈"
            if (cap >= 25) return "󰂇"
            if (cap >= 15) return "󰂆"
            if (cap >= 5)  return "󰢜"
            return "󰂄"
        } else {
            if (cap >= 95) return "󰁹"
            if (cap >= 85) return "󰂂"
            if (cap >= 75) return "󰂁"
            if (cap >= 65) return "󰂀"
            if (cap >= 55) return "󰁿"
            if (cap >= 45) return "󰁾"
            if (cap >= 35) return "󰁽"
            if (cap >= 25) return "󰁼"
            if (cap >= 15) return "󰁻"
            if (cap >= 5)  return "󰁺"
            return "󰂎"
        }
    }

    function getNetworkIcon(eth, connected, signal) {
        if (eth) return "󰈀"
        if (!connected) return "󰤮"
        if (signal >= 80) return "󰤨"
        if (signal >= 60) return "󰤥"
        if (signal >= 40) return "󰤢"
        if (signal >= 20) return "󰤟"
        return "󰤯"
    }
}
