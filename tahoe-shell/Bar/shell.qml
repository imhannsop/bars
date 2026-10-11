import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "."

ShellRoot {
    id: shell
    property var appLauncherOpenByScreen: ({})

    function screenKey(screenName: string): string {
        return screenName ? String(screenName) : ""
    }

    function isAppLauncherOpen(screenName: string): bool {
        var key = screenKey(screenName)
        return !!key && !!appLauncherOpenByScreen[key]
    }

    function toggleAppLauncher(screenName: string): void {
        var key = screenKey(screenName)
        if (!key) return

        var states = Object.assign({}, appLauncherOpenByScreen)
        states[key] = !states[key]
        appLauncherOpenByScreen = states
    }

    function closeAppLauncher(screenName: string): void {
        var key = screenKey(screenName)
        if (!key) return

        var states = Object.assign({}, appLauncherOpenByScreen)
        states[key] = false
        appLauncherOpenByScreen = states
    }

    IpcHandler {
        target: "app-search"

        function toggle(screenName: string): void {
            shell.toggleAppLauncher(screenName)
        }
    }

    ScreenBorder {}

    Variants {
        model: Quickshell.screens
        delegate: Item {
            id: screenContainer
            required property var modelData

            TopBar {
                id: topBar
                modelData: screenContainer.modelData
                appSearchOpen: shell.isAppLauncherOpen(screenContainer.modelData.name)
                onAppSearchCloseRequested: shell.closeAppLauncher(screenContainer.modelData.name)
                onAppSearchToggleRequested: shell.toggleAppLauncher(screenContainer.modelData.name)
            }
        }
    }
}
