pragma Singleton
import QtQuick
import qs.services

// The shell's theme: one ThemeSet (ThemeSet.qml holds every colour, size and font, and
// how they follow the palette and the mode) on the active theme's palette.
//
// ===== one theme per monitor =====
// Settings: `theme.perMonitor`. Off (the default), every monitor wears this one theme and
// Theme.of() just returns it. On, a monitor that has its own theme
// (ThemeService.setScreenTheme) gets its own ThemeSet, made here the first time it is
// asked for and kept. What sits ON a monitor (the bar, the dock, the desktop widgets, the
// Quick Panel) reads its colours from the theme of its window's monitor:
//
//   readonly property var mt: Theme.of(QsWindow.window)    (an Item; needs `import Quickshell`)
//   readonly property var mt: Theme.of(screen)             (a PanelWindow's own file)
//   ... color: mt.surface
//
// (`mt`, "monitor theme": a QML property can't start with a capital.) The window or
// screen is passed in, not looked up: a function can't read another item's attached
// QsWindow. Reading `screen` inside here makes the binding follow a window that moves
// to another monitor.
ThemeSet {
    id: theme

    readonly property bool perMonitor: SettingsService.flag("theme.perMonitor")

    // { monitor name: ThemeSet }, made on demand. Never shrinks: a monitor that comes
    // back finds its theme again, and one ThemeSet is a few hundred bindings.
    property var perScreen: ({})
    property Component maker: Component {
        ThemeSet {}
    }

    // `w`: a window (anything with a `screen`), or a screen itself.
    function of(w) {
        if (!theme.perMonitor || !w)
            return theme
        const scr = w.screen !== undefined ? w.screen : w
        const name = scr ? String(scr.name ?? "") : ""
        if (name === "" || !ThemeService.hasScreenTheme(name))
            return theme
        let t = theme.perScreen[name]
        if (!t) {
            t = theme.maker.createObject(theme, { pal: Qt.binding(() => ThemeService.paletteFor(name)) })
            theme.perScreen[name] = t
        }
        return t
    }
}
