pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "../modules/common/functions/PluginManifest.js" as PM

// Desktop widget plugins: widgets that live in their own folder (their own repo) and plug
// into the shell. docs/PLUGINS.md is the interface; this is where the shell finds them.
//
//   ${XDG_CONFIG_HOME:-~/.config}/sekaipop/plugins/<id>/plugin.json + Widget.qml
//
// At start-up every folder there is read (scripts/state/plugin-state.sh scan) and its
// manifest checked (PluginManifest.js). A good one gets a PluginState (its spot, on / off,
// settings, secrets) and from there on is a desktop widget like the others:
//   - Edit Desktop's shelf lists it after the built-in widgets (EditMode.shelfList),
//     and adds, removes, moves and copies it to other monitors the same way;
//   - shell.qml builds its window (PluginWidgetHost.qml) from `plugins`;
//   - a desktop preset holds it on / off and its spot (PresetWidgets.all), never its
//     settings or secrets.
// A plugin whose manifest is wrong, or that was written for a plugin api this shell does
// not speak, is skipped with ONE notification saying why, never loaded half-broken.
//
// The widget itself is the plugin's Widget.qml, drawn inside the shell's frame and handed
// a `host` object (PluginWidgetHost.qml). It cannot import the shell's own modules
// (`qs.*` only resolves inside the shell's folder), which is on purpose: `host` and the
// manifest are the whole promise, so the shell can change everything else.
//
// Trust: a plugin's QML runs with the shell's full rights (it can run processes). Install
// only what you would run as a script of your own.
//
//   qs -c sekaipop ipc call plugins list               every plugin, and why one was skipped
//   qs -c sekaipop ipc call plugins reload             look in the folder again
//   qs -c sekaipop ipc call plugins toggle <id>        (also show / hide)
//   qs -c sekaipop ipc call plugins set <id> <key> <value>
//   qs -c sekaipop ipc call plugins resetPosition <id>
Singleton {
    id: root

    readonly property string script: Directories.script("state/plugin-state.sh")

    // Where plugins are looked for. The same rule as plugin-state.sh.
    readonly property string pluginsDir: {
        const own = Quickshell.env("SEKAIPOP_PLUGINS_DIR") || ""
        if (own !== "")
            return own
        const cfg = Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")
        return cfg + "/sekaipop/plugins"
    }

    readonly property int apiVersion: PM.API_VERSION

    // False until the folder has been read once.
    property bool scanned: false
    // [{ plugin, dir }] for every plugin that loads, sorted by id.
    property var found: []
    // [{ id, error, code, field }] for every folder that does not (PluginManifest.parse).
    property var skipped: []
    // { pluginId: PluginState }, filled as the states are made.
    property var states: ({})

    // The plugin ids shell.qml builds windows for. A new array only when a plugin comes or
    // goes, so a rescan that finds the same plugins does not rebuild their windows.
    property var ids: []

    // What Edit Desktop's shelf shows after the built-in widgets (EditMode.shelfList).
    readonly property var shelfEntries: root.found.map(f => ({
        id: "plugin:" + f.plugin.id,
        title: f.plugin.name,
        icon: f.plugin.icon
    }))

    // What a desktop preset holds of each plugin (PresetWidgets.all): its spot and on / off,
    // never its settings. Only plugins whose state has been read, so a preset saved in the
    // first moment after start can't record a plugin as off that is really on.
    readonly property var presetEntries: {
        const out = []
        for (const f of root.found) {
            const st = root.states[f.plugin.id]
            if (st && st.loaded)
                out.push({ id: st.widgetId, service: st, skip: ["settings"] })
        }
        return out
    }

    function isPluginId(id) {
        return typeof id === "string" && id.indexOf("plugin:") === 0
    }

    // The PluginState for "plugin:<id>" or "<id>", or null.
    function stateFor(id) {
        if (typeof id !== "string")
            return null
        const key = root.isPluginId(id) ? id.slice(7) : id
        return root.states[key] ?? null
    }

    function pluginOf(id) {
        const st = root.stateFor(id)
        return st ? st.plugin : null
    }

    function dirOf(id) {
        const st = root.stateFor(id)
        return st ? st.dir : ""
    }

    // The monitors a plugin is on: where its main copy is, then its copies (WidgetClones),
    // plugged in or not. [] when it is off.
    function monitorsOf(id) {
        const st = root.stateFor(id)
        if (!st || !st.shown)
            return []
        const out = st.screenName !== "" ? [st.screenName] : []
        for (const n of WidgetClones.namesOf(st.widgetId)) {
            if (out.indexOf(n) < 0)
                out.push(n)
        }
        return out
    }

    // The plugins folder (made if it is missing, so there is somewhere to clone into), or
    // one plugin's folder, in the file manager.
    function openFolder(id) {
        const dir = typeof id === "string" && id !== "" ? root.pluginsDir + "/" + id : root.pluginsDir
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "sh", dir])
    }

    // ===== Settings from Edit Desktop =====
    // A selected plugin widget's Settings key (EditChrome.qml) asks for its settings: Edit
    // Desktop closes, the Quick Panel opens Settings > Desktop on that monitor (it listens
    // for settingsWanted), and the Plugins card opens `settingsTarget` and scrolls to it,
    // then clears it.
    property string settingsTarget: ""

    signal settingsWanted(string screen)

    function askSettings(id, screen) {
        const st = root.stateFor(id)
        if (!st)
            return
        root.settingsTarget = st.pluginId
        root.settingsWanted(typeof screen === "string" ? screen : "")
    }

    // ===== finding them =====
    function rescan() {
        if (!scanner.running)
            scanner.running = true
    }

    Process {
        id: scanner
        running: true
        command: ["sh", root.script, "scan"]
        stdout: StdioCollector {
            onStreamFinished: root.take(PM.scan(text))
        }
    }

    function take(result) {
        const next = result.plugins.map(p => ({ plugin: p, dir: root.pluginsDir + "/" + p.id }))
        const nextIds = next.map(f => f.plugin.id)
        // A plugin whose manifest changed gets a new state (its settings may be different);
        // one that did not keeps the one it has, and its window.
        if (JSON.stringify(next) !== JSON.stringify(root.found))
            root.found = next
        if (JSON.stringify(nextIds) !== JSON.stringify(root.ids))
            root.ids = nextIds
        root.skipped = result.skipped
        root.scanned = true
        root.tell(result.skipped)
    }

    // One notification per problem, not one per reload: a folder that stays broken is
    // reported again only when what is wrong with it changes.
    property var told: ({})

    function tell(skipped) {
        const now = {}
        const fresh = []
        for (const s of skipped) {
            const key = s.id + "|" + s.error
            now[key] = true
            if (!root.told[key])
                fresh.push(s)
        }
        root.told = now
        if (fresh.length === 0)
            return
        const body = fresh.map(s => s.id + ": " + s.error).join("\n")
        Quickshell.execDetached(["notify-send", "-a", "Shell", "-i", "material:extension_off",
            fresh.length === 1 ? "A plugin was not loaded" : fresh.length + " plugins were not loaded", body])
        for (const s of fresh)
            console.warn("PluginService: skipped plugin \"" + s.id + "\": " + s.error)
    }

    Instantiator {
        model: root.found

        delegate: PluginState {
            required property var modelData
            plugin: modelData.plugin
            dir: modelData.dir
        }

        onObjectAdded: (index, object) => {
            const s = Object.assign({}, root.states)
            s[object.pluginId] = object
            root.states = s
        }

        onObjectRemoved: (index, object) => {
            const s = Object.assign({}, root.states)
            if (s[object.pluginId] === object)
                delete s[object.pluginId]
            root.states = s
        }
    }

    // ===== ipc =====
    IpcHandler {
        target: "plugins"

        function list(): string {
            const lines = []
            for (const f of root.found) {
                const st = root.states[f.plugin.id]
                lines.push(f.plugin.id + "  " + f.plugin.version + "  " + (st && st.shown ? "on" : "off") + "  " + f.plugin.name)
            }
            for (const s of root.skipped)
                lines.push(s.id + "  skipped: " + s.error)
            if (lines.length === 0)
                lines.push("no plugins in " + root.pluginsDir)
            return lines.join("\n")
        }

        function reload(): void {
            root.rescan()
        }

        function toggle(id: string): void {
            const st = root.stateFor(id)
            if (st)
                st.setShown(!st.shown)
        }

        function show(id: string): void {
            const st = root.stateFor(id)
            if (st)
                st.setShown(true)
        }

        function hide(id: string): void {
            const st = root.stateFor(id)
            if (st)
                st.setShown(false)
        }

        function set(id: string, key: string, value: string): string {
            const st = root.stateFor(id)
            if (!st)
                return "no plugin " + id
            return st.setSetting(key, value) ? key + " = " + JSON.stringify(st.settings[key])
                : id + " has no setting " + key + " that takes " + JSON.stringify(value)
        }

        function resetPosition(id: string): void {
            const st = root.stateFor(id)
            if (!st)
                return
            st.setPosition(-1, -1, st.screenName, 0)
            WidgetClones.clearAll(st.widgetId)
        }
    }
}
