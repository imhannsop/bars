import Quickshell

Scope {
    id: root

    Notifications {
        id: notifications
    }

    Bar {
        id: bar
        notifServer: notifications.notifServer
    }

    Launcher {
        id: launcher
    }
}
