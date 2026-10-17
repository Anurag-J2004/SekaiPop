pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// What version this shell is, whether a newer one exists, and what changed.
// The work is scripts/system/update-check.sh (git upstream first, then an optional
// URL to a VERSION file; see its header). The changelog is CHANGELOG.md next
// to shell.qml.
//
//   status   "idle"      never asked yet
//            "checking"  asking
//            "current"   up to date
//            "behind"    a newer version exists (`behind` commits, or `latest`)
//            "nosource"  nothing to compare with (not a git clone, no URL)
//            "error"     couldn't ask (`reason` says why)
Singleton {
    id: root

    property string version: ""
    property bool isGit: false
    property string branch: ""
    property string commit: ""
    property string remote: ""

    property string status: "idle"
    property int behind: 0
    property string latest: ""
    property string reason: ""
    property double checkedAt: 0
    // Commits an update would bring: [{ hash, subject, age }]
    property var pending: []
    // CHANGELOG.md as [{ title, items: [text] }], newest first.
    property var changelog: []

    property bool updating: false
    property string updateMessage: ""

    readonly property string script: Directories.script("system/update-check.sh")

    function parseKv(text) {
        const out = {}
        for (const line of text.split("\n")) {
            const i = line.indexOf("=")
            if (i > 0)
                out[line.slice(0, i)] = line.slice(i + 1).trim()
        }
        return out
    }

    function check() {
        if (checker.running)
            return
        root.status = "checking"
        root.reason = ""
        checker.running = true
    }

    function update() {
        if (updater.running)
            return
        root.updating = true
        root.updateMessage = ""
        updater.running = true
    }

    // Cheap and local; runs once at startup.
    Process {
        running: true
        command: ["sh", root.script, "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = root.parseKv(text)
                root.version = kv.version || ""
                root.isGit = kv.git === "yes"
                root.branch = kv.branch || ""
                root.commit = kv.commit || ""
                root.remote = kv.remote || ""
            }
        }
    }

    // Talks to the network (git fetch / curl), only when asked.
    Process {
        id: checker
        command: ["sh", root.script, "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = root.parseKv(text)
                root.behind = Number(kv.behind || 0)
                root.latest = kv.latest || ""
                root.reason = kv.reason || ""
                root.status = kv.status || "error"
                root.checkedAt = Date.now()
                if (root.status === "behind" && root.isGit)
                    logger.running = true
                else
                    root.pending = []
            }
        }
        onExited: code => {
            if (code !== 0 && root.status === "checking") {
                root.status = "error"
                root.reason = "the update check failed"
            }
        }
    }

    Process {
        id: logger
        command: ["sh", root.script, "log"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const line of text.split("\n")) {
                    const p = line.split("|")
                    if (p.length >= 3)
                        list.push({ hash: p[0], subject: p.slice(1, -1).join("|"), age: p[p.length - 1] })
                }
                root.pending = list
            }
        }
    }

    Process {
        id: updater
        command: ["sh", root.script, "apply"]
        stdout: StdioCollector {
            onStreamFinished: root.updateMessage = text.trim().split("\n").slice(-1)[0] || ""
        }
        onExited: code => {
            root.updating = false
            if (code === 0)
                // The new files are on disk: rebuild the shell from them.
                Quickshell.reload(true)
            else
                root.updateMessage = root.updateMessage || "the update didn't apply"
        }
    }

    // ===== changelog =====
    function parseChangelog(text) {
        const out = []
        let cur = null
        for (const raw of text.split("\n")) {
            const line = raw.trim()
            if (line.startsWith("## ")) {
                cur = { title: line.slice(3), items: [] }
                out.push(cur)
            } else if (cur && line.startsWith("- ")) {
                cur.items.push(line.slice(2).replace(/`/g, ""))
            }
        }
        return out
    }

    FileView {
        path: Quickshell.shellDir + "/CHANGELOG.md"
        onLoaded: root.changelog = root.parseChangelog(text())
        onLoadFailed: root.changelog = []
    }
}
