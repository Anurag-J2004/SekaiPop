pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property var queue: []
    readonly property var definitions: [
        { id: "wallpaper", key: "hooks.wallpaper", hookName: "onWallpaperChanged", label: "Desktop wallpaper changed", args: "HOOK: onWallpaperChanged | PATH: new wallpaper's absolute path | MONITOR: monitor name, empty when applied to all monitors", example: "/path/to/script onWallpaperChanged PATH MONITOR" },
        { id: "lockWallpaper", key: "hooks.lockWallpaper", hookName: "onLockWallpaperChanged", label: "Lockscreen wallpaper changed", args: "HOOK: onLockWallpaperChanged | PATH: new wallpaper's absolute path | MONITOR: monitor name, empty when applied to all monitors", example: "/path/to/script onLockWallpaperChanged PATH MONITOR" },
        { id: "theme", key: "hooks.theme", hookName: "onThemeChanged", label: "Theme palette changed", args: "HOOK: onThemeChanged | OLD_THEME: previous theme ID | NEW_THEME: new theme ID", example: "/path/to/script onThemeChanged OLD_THEME NEW_THEME" },
        { id: "lock", key: "hooks.lock", hookName: "onSessionLockChanged", label: "Session lock changed", args: "HOOK: onSessionLockChanged | STATE: locked or unlocked", example: "/path/to/script onSessionLockChanged STATE" }
    ]

    function emit(id, args) {
        const def = root.definitions.find(h => h.id === id);
        if (!def) return;
        const executable = String(SettingsService.get(def.key) || "").trim();
        if (!executable) return;
        const next = root.queue.slice();
        next.push([executable, def.hookName].concat(args.map(v => String(v === undefined || v === null ? "" : v))));
        root.queue = next;
        root.startNext();
    }

    function startNext() {
        if (runner.running || root.queue.length === 0) return;
        const next = root.queue[0];
        root.queue = root.queue.slice(1);
        runner.exec(next);
    }

    Process {
        id: runner
        onExited: root.startNext()
    }

    Connections {
        target: LockState
        function onPhaseChanged() {
            if (LockState.phase === "locked") root.emit("lock", ["locked"]);
            else if (LockState.phase === "unlocking") root.emit("lock", ["unlocked"]);
        }
    }
}
