# Desktop widget plugins

A plugin is a desktop widget that lives in its own folder, usually its own repository, and plugs
into the shell. It is for a widget that only makes sense for you: one that shows your own
self-hosted app, needs its own API token, or would never belong in SekaiPop itself (issue #30).

The shell does everything about **where** a widget is: placing it, dragging it, which monitor,
copies on other monitors, on / off, Desktop Focus Mode, the shell scale, the pop in and out, its
picture on the Edit Desktop shelf, and desktop presets. The plugin only **draws**.

> **Trust.** A plugin's QML runs with the shell's full rights: it can run programs and read your
> files. Install a plugin only if you would run the same code as a script of your own. The shell
> does not sandbox plugins and never downloads them.

## Installing one

1. Put its folder in `~/.config/sekaipop/plugins/` (or `$XDG_CONFIG_HOME/sekaipop/plugins/`),
   for example with `git clone`. The folder name is the plugin's id.
2. `qs -c sekaipop ipc call plugins reload` (or restart the shell).
3. Right-click the desktop, **Edit Desktop**, and click the plugin's tile on the shelf. It sits
   after the built-in widgets.

To update a plugin, `git pull` in its folder and reload. To remove it, delete the folder. Its saved
state (spot, on / off, settings) stays in `~/.local/state/sekaipop/plugins/<id>.json` until you
delete that too.

A folder that is not a working plugin is skipped, never loaded half-broken. The shell sends one
notification saying why, and `ipc call plugins list` shows it again.

### Commands

```sh
qs -c sekaipop ipc call plugins list                   # every plugin, on / off, and why one was skipped
qs -c sekaipop ipc call plugins reload                 # look in the folder again
qs -c sekaipop ipc call plugins toggle <id>            # also: show <id>, hide <id>
qs -c sekaipop ipc call plugins set <id> <key> <value> # change a setting
qs -c sekaipop ipc call plugins resetPosition <id>     # if it ends up off-screen
qs -c sekaipop ipc call desktopedit movewidget plugin:<id> DP-2
```

## Writing one

The smallest complete plugin is [`examples/plugins/hello-clock/`](../examples/plugins/hello-clock/).
Copy it and change it. A plugin is two files:

```
my-widget/
  plugin.json   what it is, which plugin api it was written for, its settings and secrets
  Widget.qml    what it draws
```

It can have any other files beside those (more QML files, pictures). `Widget.qml` imports a
sibling `Card.qml` as `Card {}`, as QML always does, and `host.path("icon.png")` is the full
path of a file of its own.

### plugin.json

```json
{
    "id": "my-widget",
    "name": "My Widget",
    "version": "1.0.0",
    "api": 1,
    "description": "One line about it.",
    "icon": "dns",
    "frame": true,
    "cloneable": true,
    "settings": { "url": "https://example.org", "refreshMinutes": 5, "compact": false },
    "secrets": { "token": { "env": "MY_WIDGET_TOKEN", "file": "~/.config/my-widget/token" } }
}
```

| Field         | Required | What it is                                                                                                                                                           |
| ------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`          | yes      | The folder's name, repeated: lower case letters, digits and `-`, at most 40. It is a file name and an ipc argument, so it is checked.                                  |
| `name`        | yes      | The title on the shelf.                                                                                                                                              |
| `version`     | yes      | The plugin's own version, as a string. Shown by `plugins list`.                                                                                                       |
| `api`         | yes      | The plugin interface it was written for. This shell speaks `1`. A plugin for an api the shell does not speak is skipped with a message saying which side to update. |
| `description` | no       | One line.                                                                                                                                                             |
| `icon`        | no       | A [Material Symbols](https://fonts.google.com/icons) name for the shelf tile. Default `extension`.                                                                    |
| `frame`       | no       | `true` (default): the shell draws its card around the widget (outline, ring, surface, shadow), like the built-in cards. `false`: the widget draws everything.          |
| `cloneable`   | no       | `true` (default): the widget can be on several monitors at once, each copy with its own spot. `false`: one monitor, and adding it on another moves it there.          |
| `settings`    | no       | `name: default`. A default is a string, a number or `true` / `false`, and its type is the setting's type.                                                            |
| `secrets`     | no       | `name: { env, file }`. Where a secret is read from: the environment variable first, then the file. `~/` is your home; a relative path is inside the plugin's folder. |

### Widget.qml

```qml
import QtQuick
import Quickshell          // and Quickshell.Io etc.: Quickshell's own modules work

Item {
    required property var host

    implicitWidth: 240     // design pixels; the shell scale is applied around it
    implicitHeight: 120

    Text {
        anchors.centerIn: parent
        text: host.settings.url
        color: host.theme.pInk
        font.family: host.theme.fontFamily
    }
}
```

- **Declare `required property var host`.** The shell hands it over as the widget is made, before
  any of the widget's own bindings run.
- **Its size** is `implicitWidth` x `implicitHeight`, in design pixels. It can change; the card
  follows. (The shell keeps it between 24 and 1600 x 1200.)
- **It cannot import the shell's own modules.** `import qs.services` and the like only resolve
  inside the shell's folder, which is on purpose: `host` and the manifest are the whole interface,
  so the shell can change everything else without breaking a plugin. Qt's and Quickshell's modules
  work as usual.
- **Clicks**: anything the widget makes clickable (a `MouseArea`, a button) keeps its clicks. The
  rest of the card is the shell's handle for dragging, on an unlocked desktop and in Edit Desktop.
  In Edit Desktop a click first selects the widget, after which it works as it does on the desktop
  (`host.selected` says when).
- **Do work only while it is wanted.** Run timers and fetches while `host.working` is true. It is
  false while the widget is hidden by Focus Mode or switched off.

### The host object

Everything the widget gets from the shell.

| Name                       | What it is                                                                                                       |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `apiVersion`               | The plugin api the shell speaks (`1`).                                                                           |
| `id`                       | The plugin's id.                                                                                                 |
| `name`                     | Its name, from the manifest.                                                                                     |
| `version`                  | Its version, from the manifest.                                                                                  |
| `dir`                      | Its folder, as a full path.                                                                                      |
| `path(rel)`                | `dir + "/" + rel`. For a picture: `source: "file://" + host.path("logo.png")`.                                   |
| `theme`                    | The theme of the monitor it is on. It changes with the theme; bind to it, don't copy it. The names promised are below. |
| `settings`                 | The settings: the manifest's defaults with the user's values on top. A new object whenever one changes.          |
| `setSetting(key, value)`   | Changes one and saves it. Returns `false` for a key the manifest does not declare or a value of the wrong type.  |
| `secrets`                  | The secrets, by name: a string, empty when not found. A file secret arrives a moment after start.                |
| `screenName`               | The monitor it is on (`DP-1`).                                                                                   |
| `scale`                    | That monitor's shell scale. The widget is drawn in design pixels already; this is for pixel-exact images.        |
| `clone`                    | `true` for a copy on another monitor. Copies share settings; only their spot differs.                            |
| `working`                  | On screen, or about to be. Poll only while it is true.                                                           |
| `editing`                  | Edit Desktop is open on its monitor.                                                                             |
| `selected`                 | It is the widget selected in Edit Desktop.                                                                       |

Theme names that are promised (they are the ones the built-in cards use; others exist but may be
renamed):

<!-- theme-names -->
- Surfaces and ink on the card: `pSurface`, `pSurfaceHover`, `pInk`, `pInkSub`, `pLine`
- Chips and accents: `chipFill`, `chipInk`, `accentCyan`, `accentMint`, `colBorder`
- Light or dark: `dark`
- Type: `fontFamily`, `fontStyleBold`, `iconFont`
- Shape: `borderWidth`, `radiusOuter`
<!-- /theme-names -->

### Settings and secrets

Settings are for things the user may want to change: a URL, an interval, a style. The shell keeps
them, per plugin, in its state file. They change by the widget's own `host.setSetting()` or by
`ipc call plugins set <id> <key> <value>` (the value is turned into the setting's type). A setting
the plugin stops declaring, or whose type changes, falls back to the default.

**Secrets (API tokens, passwords) are never settings.** Declare them under `secrets`. The shell
reads them from the environment or from a file you keep, and never writes them anywhere: they are
not in the state file and not in a desktop preset.

### Presets and copies

A desktop preset holds each plugin's on / off and its spot, like a built-in widget, and never its
settings. As with built-in widgets, a preset saved before a plugin was installed switches it off
when worn.

## How it works

| File                                                         | What it does                                                                                                     |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| `sekaipop/services/PluginService.qml`                        | Finds the plugins at start-up and on `reload`, checks them, makes one `PluginState` each, the `plugins` ipc.     |
| `sekaipop/services/PluginState.qml`                          | One plugin's spot, on / off, settings and secrets, shaped like a widget's service.                               |
| `sekaipop/modules/common/functions/PluginManifest.js`        | The manifest rules (`API_VERSION`, `parse`, settings, saved state). Pure functions, tested in node.             |
| `sekaipop/scripts/state/plugin-state.sh`                     | Lists the plugin folders, saves and loads state, reads secret files.                                             |
| `sekaipop/modules/sekai/desktopWidgets/PluginWidgetHost.qml` | The window: placement, dragging, Edit Desktop, Focus Mode, the frame, and the `host` object.                     |
| `sekaipop/shell.qml`                                         | One `PluginWidgetHost` per plugin, and one per copy on another monitor.                                          |
| `EditMode.qml`, `PresetWidgets.qml`                          | A plugin is `plugin:<id>`: the shelf (`shelfList`), adding, removing and copying, and presets (`PresetWidgets.all`). |

Because each plugin's `PluginState` has the same shape as a built-in widget's service (`loaded`,
`shown`, `posX` / `posY` / `posScale`, `screenName`, `setShown`, `setPosition`, `snapshot` /
`restore`), Edit Desktop, the monitor copies and presets handle it with the code they already
had. Nothing in them is plugin-specific beyond looking the state up.

### Changing the interface

The manifest fields and the `host` object above are a promise to plugins written elsewhere:

- **Adding** a manifest field (with a default) or a `host` property is fine at any time.
- **Renaming, removing or changing the meaning** of one is a new api: raise `API_VERSION` in
  `PluginManifest.js`, keep the old number in `SUPPORTED` for as long as reading old plugins costs
  little, and say what changed here.
- `tests/plugin-test/manifest_unit.js` checks that every `host` name and every promised theme name
  in this file exists in the code, so this document can't silently drift from the code.

### Tests

```sh
node sekaipop/tests/plugin-test/manifest_unit.js      # manifest, settings, state, wiring, the example
sh sekaipop/tests/plugin-test/plugin_state_test.sh     # the state script, against a throwaway folder
node sekaipop/tests/preset-widgets-test/registry_unit.js
```
