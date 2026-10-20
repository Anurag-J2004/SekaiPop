import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "../modules/common/functions/PluginManifest.js" as PM

// One desktop widget plugin's state (PluginService.qml makes one per plugin found). It has
// the same shape as a built-in widget's service (UserCardService.qml): loaded, shown,
// posX / posY / posScale, screenName, setShown / setPosition / persist, snapshot / restore.
// That is what lets Edit Desktop (EditMode.svcOf), the copies on other monitors
// (WidgetClones.qml) and the desktop presets (PresetWidgets.all) treat a plugin like any
// other widget without knowing it is one.
//
// What is the plugin's own on top of that:
//   settings   the manifest's defaults with the user's values on top (PM.mergeSettings);
//              changed with setSetting(), by the widget (host.setSetting) or by
//              `qs -c sekaipop ipc call plugins set <id> <key> <value>`
//   secrets    read once at start from the environment or a file the manifest names;
//              never saved here and never part of a preset
QtObject {
    id: root

    // The manifest, as PluginManifest.parse() filled it in.
    required property var plugin
    // The plugin's folder (Widget.qml is in it).
    required property string dir

    readonly property string pluginId: root.plugin.id
    // The id everything else knows it by: Edit Desktop, the copies, presets, Focus Mode.
    readonly property string widgetId: "plugin:" + root.plugin.id

    property bool loaded: false
    property bool shown: false
    property real posX: -1
    property real posY: -1
    property real posScale: 0
    property string screenName: ""
    property var settings: PM.mergeSettings(root.plugin.settings, null)
    property var secrets: ({})

    // A copy on another monitor decides which monitors get a window from where the main
    // copy is (WidgetClones.rebuild), the same as the built-in widgets' Connections there.
    onScreenNameChanged: WidgetClones.rebuild()

    function setPosition(x, y, screen, scale) {
        if (!root.loaded)
            return
        root.posX = x
        root.posY = y
        if (typeof scale === "number" && scale > 0)
            root.posScale = scale
        if (typeof screen === "string" && screen !== "")
            root.screenName = screen
        root.saveTimer.stop()
        root.saver.save(root.snapshot())
    }

    function setShown(value) {
        root.shown = value
        root.persist()
    }

    // false when the plugin does not declare `key` or the value is not of its type.
    function setSetting(key, value) {
        if (!(key in root.plugin.settings))
            return false
        const v = PM.coerce(root.plugin.settings[key], value)
        if (v === undefined)
            return false
        const s = Object.assign({}, root.settings)
        s[key] = v
        root.settings = s
        root.persist()
        return true
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/plugin-state.sh")

    function snapshot() {
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            screen: root.screenName,
            shown: root.shown,
            settings: root.settings
        })
    }

    function restore(text) {
        const s = PM.readState(text, root.plugin.settings)
        root.posX = s.x
        root.posY = s.y
        root.posScale = s.scale
        root.screenName = s.screen
        root.shown = s.shown
        root.settings = s.settings
        root.loaded = true
    }

    function persist() {
        if (root.loaded)
            root.saveTimer.restart()
    }

    property Timer saveTimer: Timer {
        interval: 300
        onTriggered: root.saver.save(root.snapshot())
    }

    property Process loader: Process {
        running: true
        command: ["sh", root.script, "load", root.pluginId]
        stdout: StdioCollector {
            onStreamFinished: root.restore(text)
        }
    }

    // Fire-and-forget save that never drops the last state (same as UserCardService's).
    property Process saver: Process {
        property var pending: null

        function save(json) {
            if (running) {
                pending = json
                return
            }
            pending = null
            exec(["sh", root.script, "save", root.pluginId, json])
        }

        onExited: {
            if (pending !== null) {
                const json = pending
                pending = null
                exec(["sh", root.script, "save", root.pluginId, json])
            }
        }
    }

    // ===== secrets =====
    // The environment first (it is there at once), then the file. A file secret arrives a
    // moment after start; the widget sees host.secrets change, like any other binding.
    readonly property var secretFiles: {
        const out = []
        const names = Object.keys(root.plugin.secrets)
        for (const n of names) {
            const d = root.plugin.secrets[n]
            const env = d.env !== "" ? (Quickshell.env(d.env) || "") : ""
            if (env === "" && d.file !== "")
                out.push({ name: n, path: PM.expandPath(d.file, Quickshell.env("HOME") || "", root.dir) })
        }
        return out
    }

    Component.onCompleted: {
        const s = {}
        for (const n in root.plugin.secrets) {
            const d = root.plugin.secrets[n]
            s[n] = d.env !== "" ? (Quickshell.env(d.env) || "") : ""
        }
        root.secrets = s
        root.readNextSecret()
    }

    property int secretIndex: 0

    function readNextSecret() {
        if (root.secretIndex >= root.secretFiles.length)
            return
        const f = root.secretFiles[root.secretIndex]
        root.secretReader.name = f.name
        root.secretReader.exec(["sh", root.script, "secret", f.path])
    }

    property Process secretReader: Process {
        property string name: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const s = Object.assign({}, root.secrets)
                s[root.secretReader.name] = text.trim()
                root.secrets = s
                root.secretIndex = root.secretIndex + 1
                root.readNextSecret()
            }
        }
    }
}
