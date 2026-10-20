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
//   secrets    read at start from the environment or a file the manifest names (and
//              again by reloadSecrets(), Settings' Reload); never saved here and never
//              part of a preset. secretSources says where each one was found, for
//              Settings, which never shows a value.
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
    // { name: "env" | "file" | "" }: where each secret was found; "" = not found.
    property var secretSources: ({})

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

    // Settings' reset: one setting, or all of them, back to the manifest's default.
    function resetSetting(key) {
        if (key in root.plugin.settings)
            root.setSetting(key, root.plugin.settings[key])
    }

    function resetAll() {
        root.settings = PM.mergeSettings(root.plugin.settings, null)
        root.persist()
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

    Component.onCompleted: root.reloadSecrets()

    // The environment is the shell's own, so only a file can change while it runs; this reads
    // the files again (Settings' Reload, after the user has put a token in place).
    function reloadSecrets() {
        const s = {}
        const src = {}
        for (const n in root.plugin.secrets) {
            const d = root.plugin.secrets[n]
            s[n] = d.env !== "" ? (Quickshell.env(d.env) || "") : ""
            src[n] = s[n] !== "" ? "env" : ""
        }
        root.secrets = s
        root.secretSources = src
        if (root.secretReader.running)
            root.secretsAgain = true
        else {
            root.secretIndex = 0
            root.readNextSecret()
        }
    }

    property int secretIndex: 0
    // A reload asked for while the files were still being read: start over when they are done.
    property bool secretsAgain: false

    function readNextSecret() {
        if (root.secretsAgain) {
            root.secretsAgain = false
            root.reloadSecrets()
            return
        }
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
                const v = text.trim()
                const s = Object.assign({}, root.secrets)
                s[root.secretReader.name] = v
                root.secrets = s
                const src = Object.assign({}, root.secretSources)
                src[root.secretReader.name] = v !== "" ? "file" : ""
                root.secretSources = src
                root.secretIndex = root.secretIndex + 1
                root.readNextSecret()
            }
        }
    }
}
