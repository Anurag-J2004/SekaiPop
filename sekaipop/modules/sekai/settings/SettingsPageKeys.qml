import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/KeyBinds.js" as KB

// Keys: which key each SekaiPop action is on, and changing it. Click a row and press
// the new keys; it is saved and works straight away. KeybindService does the work
// (reading Hyprland's binds, writing the override file, pausing shortcuts while a
// combination is recorded); KeyBinds.js has the rules.
//
// Only the shell's own actions are here (the binds that call `qs -c sekaipop ipc
// call ...`). Window and workspace keys are Hyprland's, and volume / brightness keys
// stay as they are.
SettingsPage {
    id: page

    property string editingId: ""
    property string editingMode: ""
    property string query: ""
    property bool confirmReset: false

    readonly property bool anyEditing: editingId !== ""
    readonly property var shown: KeybindService.rows.filter(r => KB.matches(r, page.query))
    readonly property bool appsShown: KB.matches({ name: "Apps super tap", combos: [] }, page.query)

    function rowsOf(group) {
        return page.shown.filter(r => r.group === group)
    }

    // The mode first: setting the id is what opens the editor, and it reads the
    // mode as it opens.
    function startEdit(id, mode) {
        page.confirmReset = false
        page.editingMode = mode
        page.editingId = id
    }

    function stopEdit() {
        page.editingId = ""
        page.editingMode = ""
    }

    // Read again whenever the page comes up: a hand edit, or the setup line just
    // added, shows without reopening anything. Leaving the page drops any edit
    // (and so gives the shortcuts back).
    onVisibleChanged: {
        if (visible) {
            KeybindService.refresh()
        } else {
            page.stopEdit()
            page.confirmReset = false
            KeybindService.resume()
        }
    }

    // ===== not available: niri, or the override file isn't loaded yet =====
    SectionCard {
        id: setupCard
        visible: !KeybindService.available
        title: KeybindService.niri ? "Keys" : "One-time setup"
        inset: 34

        readonly property string line: KeybindService.mode === "lua"
            ? "pcall(require, \"sekaipop_overrides\")"
            : "source = ~/.config/hypr/sekaipop_overrides.conf"

        Column {
            width: page.fullWidth
            spacing: 20

            Text {
                width: Math.min(parent.width, 820)
                wrapMode: Text.WordWrap
                text: KeybindService.niri ? "Keys are niri's here" : "One line in your Hyprland config, and keys are yours to change"
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 28
                font.weight: Font.Black
            }
            Text {
                width: Math.min(parent.width, 820)
                wrapMode: Text.WordWrap
                lineHeight: 1.25
                text: KeybindService.niri
                    ? "This page changes Hyprland's binds, and the shell is running on niri. Set your keys in niri's own config, as `spawn \"qs\" \"-c\" \"sekaipop\" \"ipc\" \"call\" ...` binds."
                    : "Changes made here are saved in a file of SekaiPop's, and your config doesn't load that file yet. Until it does, a new key would never reach Hyprland, so there's nothing to change here."
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 17
                font.weight: Font.Bold
            }
            Text {
                visible: !KeybindService.niri
                width: Math.min(parent.width, 820)
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                text: "Add this line to <b>" + (KeybindService.mode === "lua" ? "hyprland.lua" : "hyprland.conf") + "</b> once:"
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 17
                font.weight: Font.Bold
            }
            Rectangle {
                visible: !KeybindService.niri
                width: codeText.implicitWidth + 36
                height: 40
                radius: 20
                color: mt.pSurfaceDivider
                Text {
                    id: codeText
                    anchors.centerIn: parent
                    text: setupCard.line
                    color: mt.pInk
                    font.family: "monospace"
                    font.pixelSize: 16
                }
            }
            Text {
                visible: !KeybindService.niri
                width: Math.min(parent.width, 820)
                wrapMode: Text.WordWrap
                // The Lua line is the Hyprland page's own setup line; hyprland.conf has
                // no such setup there, so its line is this page's alone.
                text: KeybindService.mode === "lua"
                    ? "This page switches on by itself as soon as the line is there. Same line as the Hyprland page's setup, so you only add it once."
                    : "This page switches on by itself as soon as the line is there. Put it last, so your keys here win over the ones above it."
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 17
                font.weight: Font.Bold
            }
            Row {
                visible: !KeybindService.niri
                topPadding: 8
                spacing: 20
                SettingAction {
                    tileWidth: 310
                    icon: "content_copy"
                    label: "Copy the line"
                    detail: "Uses wl-copy"
                    onActivated: Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", setupCard.line])
                }
                SettingAction {
                    visible: KeybindService.mode === "lua" && page.host !== null && page.host.go !== undefined
                    tileWidth: 310
                    icon: "grid_view"
                    label: "Open the setup"
                    detail: "On the Hyprland page"
                    onActivated: page.host.go(page.host.pages.findIndex(p => p.id === "hyprland"))
                }
            }
            // Only when the cheat sheet has a key to name.
            Row {
                readonly property var cheat: KeybindService.row("cheatsheet")
                visible: !KeybindService.niri && cheat !== null && cheat.combos.length > 0
                topPadding: 6
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Until then,"
                    color: mt.pInkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
                KeyCaps {
                    anchors.verticalCenter: parent.verticalCenter
                    combos: parent.cheat ? parent.cheat.combos.slice(0, 1) : []
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "still shows every key on the cheat sheet."
                    color: mt.pInkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
            }
        }
    }

    // ===== Keys: what this is, reset all, find =====
    SectionCard {
        visible: KeybindService.available
        title: "Keys"
        icon: "keyboard"

        Item {
            width: page.fullWidth
            height: introRow.height + 22 + searchBox.height

            Row {
                id: introRow
                width: parent.width
                spacing: 28

                // what this page is / the reset-all question
                Column {
                    width: parent.width - resetTile.width - 28
                    spacing: page.confirmReset ? 18 : 8
                    anchors.verticalCenter: page.confirmReset ? undefined : parent.verticalCenter

                    Text {
                        visible: !page.confirmReset
                        width: parent.width
                        wrapMode: Text.WordWrap
                        lineHeight: 1.2
                        text: "Every shortcut that opens or does something in SekaiPop. Click one, press the new keys, and it works straight away."
                        color: mt.pInk
                        font.family: mt.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.Bold
                    }
                    Text {
                        visible: !page.confirmReset
                        width: parent.width
                        wrapMode: Text.WordWrap
                        lineHeight: 1.2
                        text: "Window and workspace keys belong to Hyprland and stay in "
                              + (KeybindService.mode === "lua" ? "keybinds.lua" : "your Hyprland config")
                              + ". Volume and brightness keys aren't listed."
                        color: mt.pInkSub
                        font.family: mt.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    Text {
                        visible: page.confirmReset
                        text: "Put all " + KeybindService.changedCount + " changed keys back?"
                        color: mt.pInk
                        font.family: mt.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.Black
                    }
                    Column {
                        visible: page.confirmReset
                        spacing: 12
                        Repeater {
                            model: page.confirmReset ? KeybindService.rows.filter(r => r.changed) : []
                            delegate: Row {
                                required property var modelData
                                spacing: 16
                                Text {
                                    width: 240
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    text: modelData.name
                                    color: mt.pInk
                                    font.family: mt.fontFamily
                                    font.pixelSize: 16
                                    font.weight: Font.ExtraBold
                                }
                                KeyCaps {
                                    anchors.verticalCenter: parent.verticalCenter
                                    combos: modelData.combos
                                }
                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "arrow_forward"
                                    size: 22
                                    color: mt.pInkSub
                                }
                                KeyCaps {
                                    anchors.verticalCenter: parent.verticalCenter
                                    combos: modelData.before
                                }
                            }
                        }
                    }
                    Row {
                        visible: page.confirmReset
                        spacing: 14
                        SettingChip {
                            anchors.verticalCenter: parent.verticalCenter
                            capH: 36
                            fontSize: 15
                            label: "Keep them"
                            onClicked: page.confirmReset = false
                        }
                        SettingChip {
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Reset all " + KeybindService.changedCount
                            selected: true
                            onClicked: {
                                KeybindService.resetAll()
                                page.confirmReset = false
                            }
                        }
                    }
                }

                SettingAction {
                    id: resetTile
                    anchors.verticalCenter: page.confirmReset ? undefined : parent.verticalCenter
                    tileWidth: 300
                    icon: "restart_alt"
                    label: "Reset all"
                    detail: KeybindService.changedCount === 0 ? "Nothing changed"
                          : KeybindService.changedCount + " changed"
                    busy: page.confirmReset
                    enabled: KeybindService.changedCount > 0 && !page.anyEditing
                    opacity: enabled || page.confirmReset ? 1 : 0.5
                    onActivated: page.confirmReset = !page.confirmReset
                }
            }

            // find an action or a key
            Item {
                id: searchBox
                y: introRow.height + 22
                width: parent.width
                height: 56
                opacity: page.anyEditing ? 0.36 : 1
                enabled: !page.anyEditing

                Rectangle {
                    y: 4
                    width: parent.width
                    height: 52
                    radius: 16
                    color: mt.pLineShadow
                }
                Rectangle {
                    width: parent.width
                    height: 52
                    radius: 16
                    color: mt.pSurface
                    border.width: 3
                    border.color: mt.pLine

                    MaterialIcon {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: 20
                        color: mt.pInkSub
                    }
                    TextInput {
                        id: findField
                        x: 48
                        width: parent.width - 64
                        anchors.verticalCenter: parent.verticalCenter
                        color: mt.pInk
                        font.family: mt.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        clip: true
                        onTextEdited: page.query = text
                        Keys.onEscapePressed: {
                            text = ""
                            page.query = ""
                        }

                        Text {
                            visible: findField.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Find an action or a key, like “super v”"
                            color: mt.pInkSub
                            font: findField.font
                        }
                    }
                }
            }
        }
    }

    // ===== the groups =====
    Repeater {
        model: KeybindService.available ? KB.GROUPS : []

        delegate: SectionCard {
            id: card
            required property string modelData
            readonly property var groupRows: page.rowsOf(modelData)
            readonly property bool apps: modelData === "Shell" && page.appsShown
            visible: groupRows.length > 0 || apps
            title: modelData

            KeyGroup {
                width: page.fullWidth
                rows: card.groupRows
                showApps: card.apps
                onEdit: (id, mode) => page.startEdit(id, mode)
                onResetRequested: id => KeybindService.reset(id)
            }
        }
    }

    // ===== the editor: a modal over the page =====
    // Over the cards rather than among them, so it is always where you are looking
    // and nothing scrolls away under it while the shortcuts are paused. A click on
    // the scrim cancels, like the phone's other dialogs (NightLightDialog.qml).
    overlay: [
        Item {
            anchors.fill: parent
            visible: opacity > 0
            opacity: page.anyEditing ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: page.anyEditing ? 140 : 200 }
            }

            Rectangle {
                anchors.fill: parent
                radius: 30
                color: mt.scrim
                opacity: 0.55
                MouseArea {
                    anchors.fill: parent
                    enabled: page.anyEditing
                    onClicked: page.cancelEdit()
                    onWheel: wheel => wheel.accepted = true
                }
            }

            Loader {
                active: page.anyEditing
                width: Math.min(parent.width - 80, 1000)
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(20, (parent.height - height) / 2)
                sourceComponent: KeyEditor {
                    row: KeybindService.row(page.editingId)
                    onClosed: page.stopEdit()
                    Component.onCompleted: open(page.editingMode)
                }
            }
        }
    ]

    function cancelEdit() {
        KeybindService.resume()
        page.stopEdit()
    }

    // nothing matched the search
    SectionCard {
        visible: KeybindService.available && page.query.trim() !== "" && page.shown.length === 0 && !page.appsShown
        title: "Nothing found"
        icon: "search_off"
        Text {
            width: page.fullWidth
            text: "No action or key matches “" + page.query.trim() + "”."
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 17
            font.weight: Font.Bold
        }
    }
}
