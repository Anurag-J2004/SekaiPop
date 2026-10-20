# Plugin settings in Settings

Settings > Desktop > **Plugins** lists every desktop widget plugin that is installed and edits its
settings with the shell's own controls. Before it, a plugin's settings could only be changed by
the widget's own buttons or by `ipc call plugins set`, so someone who installed a plugin had no
way to see what it could be set to (issue #30, after the plugins themselves in #56). How plugins
work, and the manifest fields this reads, are in [PLUGINS.md](PLUGINS.md).

## Using it

- **The list.** Each plugin shows its icon, name, version and id, its description, and where it
  is: "On the desktop" with a chip per monitor, or "Not on the desktop". A missing secret shows as
  a yellow warning ("token not found"). On the right, how many settings and secrets it has, and
  **Settings** (**Details** for a plugin with neither).
- **A plugin's settings.** **Settings** opens the plugin in its row's place, one at a time. It
  shows its folder, its monitors, **Place it in Edit Desktop**, its settings under their group
  headings, and its secrets. Every change is saved at once and the widget redraws. A setting that
  differs from its default has a diamond beside its name, its default under it, and a reset button.
  **Reset all N changed** puts them all back.
- **Secrets.** Each one is **Found** (in the environment, as `VAR`, or in the file `path`) or
  **Not found**. For one that is missing, the card says exactly where to put it, with a copy
  button for the variable's name and the file's path. The value is never shown. **Reload** reads
  the files again, so a token put in place while the shell runs is picked up.
- **Folders that did not load.** They appear after the plugins, dashed and marked SKIPPED. Each
  one says what is wrong in plain words, who has to fix it, and the shell's own message (for a bug
  report), with one button: **Check for updates** when the plugin is for a newer SekaiPop,
  **Open its folder** otherwise.
- **No plugins.** The card says where plugins go (`~/.config/sekaipop/plugins/`) and offers
  **Reload**, **Open the folder** (made if missing) and a link to PLUGINS.md.
- **From Edit Desktop.** A selected plugin widget with settings or secrets has a **Settings** key
  beside its EDITING tag. It closes Edit Desktop and opens Settings > Desktop on that monitor,
  scrolled to Plugins, with the plugin open.
- The card says once, at its foot, that a plugin runs with the shell's full rights.

## How it works

| File | What it does |
| --- | --- |
| `modules/common/functions/PluginManifest.js` | Reads `settingsInfo` and `groups` (leniently; a wrong field is dropped, never a reason to skip a plugin). Every refusal carries a `code` (`json`, `api-new`, `field` + `field`, ...) beside its message. |
| `modules/common/functions/PluginForm.js` | Everything the card works out: the form (`form`, `row`: control kind, label, changed, the default as text), `changedKeys`, `countText`, `hasForm`, `warnText`, `secretInfo`, and `skipInfo` (a code in plain words). Pure functions, tested in node. |
| `services/PluginState.qml` | `secretSources` (`env` / `file` / "" per secret, never a value), `reloadSecrets()`, `resetSetting()`, `resetAll()`. |
| `services/PluginService.qml` | `monitorsOf()`, `openFolder()`, and `settingsTarget` + `settingsWanted` for the Edit Desktop key. |
| `modules/sekai/settings/SettingsPluginsCard.qml` | The card, on the Desktop page after Widgets. One `PluginRow` per plugin, swapped for a `PluginEditor` while it is open; one `PluginRow` per skipped folder. |
| `PluginEditor.qml`, `PluginSettingRow.qml`, `PluginSecretRow.qml`, `PluginSectionHead.qml`, `PluginBadge.qml`, `PluginDiamond.qml` | The open plugin and its pieces. A setting's control is the shell's own: `SettingText`, `SettingChoice`, `SettingSlider`, `SettingStepper`, `SettingToggle`. |
| `modules/sekai/editMode/EditChrome.qml` | The Settings key beside EDITING. |
| `modules/sekai/quickPanel/QuickPanel.qml` | Answers `settingsWanted`: closes Edit Desktop, then opens Settings on the Desktop page of that monitor. |

The open plugin's rows are made from the manifest alone (which keys, in which group), and each
row reads its own value. Built from the values, a slider would be rebuilt under the pointer on
every step of a drag.

## Where it departs from the handoff

The design is in `docs/handoffs/plugin-settings/` (Claude Design, pulled 2026-10-20). Where it and
the repository disagreed, the repository won:

- **The slider** is the shell's own `SettingSlider`, with its value badge above the track as on
  every other slider in Settings, not the mock's inline `min | track | max | badge`. A value
  outside `min` / `max` shows as it is in the badge, while the knob stops at the end of the track.
- **The stepper** has no bounds of its own (a number with no `min` / `max` has none in the
  manifest either).
- **Reload for secrets** only reads the files again. An environment variable is the shell's own,
  fixed when it starts, which the card already says ("set before the shell starts").
- **Check for updates** on a "made for a newer SekaiPop" row runs the update check that was
  already there (`UpdateService.check`), not a new one.
- **The skip messages** come from a `code` on each refusal, not from matching the message text, so
  the shell's wording can change without breaking them. A folder whose plugin.json is missing a
  field names the field ("version", "settings.refreshMinutes").
- **Measurements** come from the handoff's stylesheet as written (the 300px label column, the
  20px gaps, 74px rows, the 520px field and 600px slider caps, the 46px icon diamond). The
  design-tools conformance test drives a browser page and cannot run against QML, so nothing pins
  them yet.

## What it doesn't do yet

- No way to type a value for a stepper; it moves by `step`.
- Nothing pins the measurements in a test (see above).
- A `settingsInfo` mistake is dropped silently. A plugin author learns of it only by seeing the
  plainer control.
- The list does not sort or search; plugins are in id order, as on the shelf.

## Tests

```sh
node sekaipop/tests/plugin-test/manifest_unit.js   # settingsInfo / groups parsing, skip codes
node sekaipop/tests/plugin-test/form_unit.js       # the form, labels, fallbacks, skip reasons
```
