import Quickshell
import QtQuick

// The system side of the App Launcher — every installed .desktop
// application, via Quickshell's own DesktopEntries index (no shelling
// out, unlike QuickSource.qml's nmcli/bluetoothctl/wpctl calls: this
// one's a real Quickshell API). The Apps screen (LauncherFace.qml) stays
// pure UI; it hands this file a query string and reads back an ordered
// list of matches to draw as tiles.
//
// Built to be cheap to ask, because the Apps screen asks on every key:
//
//   - `entries`: ONE plain object per app, built once (and again only when
//     apps are installed / removed), name-sorted, carrying the lower-cased
//     search fields. Typing never touches the DesktopEntry objects again
//     (each read of one is a trip into C++), it just compares strings.
//   - the objects are STABLE: the same app is the same object every time, so
//     a ScriptModel can tell which tiles stay and which come and go (see
//     LauncherFace.qml) instead of tearing down and rebuilding the whole grid
//     per letter.
//   - `iconFor()` remembers every icon path it has looked up.
Scope {
    id: root

    property string query: ""

    // Plain-JS scratch that must NOT be a reactive property: the ranking and
    // icon caches are written while a binding is being evaluated, and writing
    // a property from inside a binding that read it is a binding loop. Changing
    // the *fields* of this one object notifies nobody.
    readonly property var _cache: ({
        rankKey: "", rankVal: [],
        iconSrc: null, icons: ({})
    })

    // Every non-hidden, non-NoDisplay application on the system
    // (DesktopEntries.applications already filters those out), name-sorted
    // so there's a stable base order to rank from. `.values` views the
    // ObjectModel as a real reactive JS list, so this keeps itself in sync if
    // apps are installed/removed while the shell is running.
    readonly property var entries: root.buildEntries(DesktopEntries.applications.values)

    // The same apps as plain DesktopEntry objects (what this file used to
    // hand out); kept for anything that still wants them.
    readonly property var allApps: root.entries.map(e => e.app)

    // Matches for the current query, best match first. Empty query ->
    // empty list on purpose: the results card only shows up once
    // you've actually typed something.
    readonly property var results: root.query.length === 0 ? [] : root.rank(root.query)

    function buildEntries(list) {
        const apps = list.slice()
        apps.sort((a, b) => a.name.localeCompare(b.name))
        const seen = ({})
        const out = new Array(apps.length)
        for (let i = 0; i < apps.length; i++) {
            const a = apps[i]
            let kw = ""
            const kws = a.keywords || []
            for (const k of kws)
                kw += k + "\n"
            const name = a.name || ""
            const generic = a.genericName || ""
            // A key the grid can tell apps apart by. Desktop ids are unique; the
            // counter is only there so a odd duplicate can never collide.
            let key = a.id || (name + "\u0001" + (a.icon || ""))
            if (seen[key] !== undefined)
                key = key + "#" + (++seen[key])
            else
                seen[key] = 0
            out[i] = {
                key: key,
                idx: i,
                app: a,
                name: name,
                icon: a.icon || "",
                generic: generic,
                nameL: name.toLowerCase(),
                genericL: generic.toLowerCase(),
                keywordsL: kw.toLowerCase(),
                commentL: (a.comment || "").toLowerCase()
            }
        }
        return out
    }

    // Matches (as the entries above), best first. The result for the last query
    // is remembered, so asking twice for the same text costs nothing.
    function rankEntries(q) {
        const needle = (q || "").toLowerCase().trim()
        if (needle === "")
            return []
        const list = root.entries
        const c = root._cache
        if (c.rankSrc === list && c.rankKey === needle)
            return c.rankVal
        const scored = []
        for (let i = 0; i < list.length; i++) {
            const s = root.scoreEntry(list[i], needle)
            if (s > 0)
                scored.push({ e: list[i], s: s })
        }
        // Ties keep the name order (idx), the same order the apps are sorted in.
        scored.sort((a, b) => b.s - a.s || a.e.idx - b.e.idx)
        const out = scored.map(x => x.e)
        c.rankSrc = list
        c.rankKey = needle
        c.rankVal = out
        return out
    }

    // Same answer rankEntries() gives, as DesktopEntry objects.
    function rank(q) {
        return root.rankEntries(q).map(e => e.app)
    }

    // Higher is better; 0 means "doesn't match". Cheapest/most-likely
    // field checked first — an app whose *name* starts with what you
    // typed is almost always the one you meant, so that outranks a
    // hit buried in another app's long description. `needle` is already
    // lower-cased and trimmed.
    function scoreEntry(e, needle) {
        const name = e.nameL
        if (name === needle)
            return 100
        if (name.startsWith(needle))
            return 80
        if (name.includes(needle))
            return 60

        const generic = e.genericL
        if (generic.startsWith(needle))
            return 45
        if (generic.includes(needle))
            return 35

        if (e.keywordsL.includes(needle))
            return 25

        if (e.commentL.includes(needle))
            return 10

        return 0
    }

    // The icon file for an icon name, looked up once. Every tile asks for it, and
    // asking the icon theme costs a trip through its directories each time.
    // Forgotten whenever the list of apps is rebuilt.
    function iconFor(name) {
        if (!name)
            return ""
        const c = root._cache
        const src = root.entries
        // Forgotten after an icon theme change and whenever new icon files were looked up.
        const rev = IconCursorService.revision
        const res = IconCursorService.resolved
        if (c.iconSrc !== src || c.iconRev !== rev || c.iconRes !== res) {
            c.iconSrc = src
            c.iconRev = rev
            c.iconRes = res
            c.icons = ({})
        }
        let p = c.icons[name]
        if (p === undefined) {
            p = IconCursorService.path(name, true)
            c.icons[name] = p
        }
        return p
    }

    // Runs the app. Quickshell resolves the desktop entry's Exec line
    // (terminal wrapper, working directory, field codes) itself — see
    // DesktopEntry.execute() — so there's nothing to shell out to here.
    function launch(app) {
        if (app)
            app.execute()
    }
}
