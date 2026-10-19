import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/KeyBinds.js" as KB

// The panel a Keys row opens into, full width of its card. Three faces:
//
//   record    "Press the new keys": shortcuts are paused (KeybindService.pause) so
//             SUPER + A reaches this panel; the modifiers held so far light up, and
//             the combination is saved the moment a key lands. Escape cancels: it is
//             the one bind of the paused submap, so it works even without focus.
//   byhand    the same thing built from modifier chips and a key, for when keys
//             don't come through.
//   conflict  the keys are taken (another action, or any other Hyprland bind):
//             take them over, or try other keys.
//
// `closed` is sent when it is done, saved or not.
FocusScope {
    id: root

    property var row: null              // the action's KeyBinds.rows() entry
    property string mode: "record"      // record | byhand | conflict

    // record: modifiers held right now; a refused key flashes a hint
    property int heldMods: 0
    property string refusal: ""
    // conflict: the combination that was asked for, and who has it
    property var wanted: null
    property var taken: null
    // byhand
    property int handMods: KB.SUPER
    property string handKey: ""
    property bool fKeysOpen: false

    signal closed()

    readonly property var handCombo: ({ mods: root.handMods, key: root.handKey })
    readonly property var handTaken: root.handKey === "" ? null : KeybindService.conflict(root.handCombo, root.row ? root.row.id : "")

    readonly property real inner: width - 8

    implicitHeight: shadow.y + box.height

    function open(m) {
        root.mode = m === "" ? "record" : m
        root.heldMods = 0
        root.refusal = ""
        if (m === "record") {
            KeybindService.pause()
            root.forceActiveFocus()
        } else {
            KeybindService.resume()
            if (m === "byhand") {
                const now = root.row && root.row.combos.length > 0 ? root.row.combos[0] : null
                root.handMods = now ? now.mods : KB.SUPER
                root.handKey = ""
                keyField.text = ""
                keyField.forceActiveFocus()
            } else {
                root.forceActiveFocus()
            }
        }
    }

    function close() {
        KeybindService.resume()
        root.closed()
    }

    // A combination from recording or from "Set it by hand": save it, or ask.
    function offer(combo) {
        const t = KeybindService.conflict(combo, root.row.id)
        if (t === null) {
            KeybindService.setKeys(root.row.id, combo, null)
            root.close()
        } else {
            root.wanted = combo
            root.taken = t
            root.open("conflict")
        }
    }

    // Escape ended the pause (the submap's own bind): that is a cancel.
    Connections {
        target: KeybindService
        function onPausedChanged() {
            if (!KeybindService.paused && root.mode === "record" && root.visible)
                root.close()
        }
    }

    Keys.onPressed: event => {
        event.accepted = true
        if (root.mode !== "record") {
            if (event.key === Qt.Key_Escape)
                root.close()
            return
        }
        // Escape reaches us only if the pause did not take; it still cancels.
        if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
            root.close()
            return
        }
        const combo = KB.comboFromKeyEvent(event.key, event.modifiers, event.nativeScanCode)
        if (combo.key === "") {
            root.heldMods = combo.mods
            return
        }
        if (KB.needsModifier(combo)) {
            root.refusal = KB.showCombo(combo) + " on its own would stop it typing. Hold a modifier with it."
            refusalTimer.restart()
            return
        }
        root.heldMods = 0
        root.offer(combo)
    }

    Keys.onReleased: event => {
        event.accepted = true
        if (root.mode === "record")
            root.heldMods = KB.comboFromKeyEvent(0, event.modifiers, 0).mods & ~KB.modOfKey(event.key)
    }

    Timer {
        id: refusalTimer
        interval: 3200
        onTriggered: root.refusal = ""
    }

    // ===== the box =====
    Rectangle {
        id: shadow
        x: Theme.quickFlat ? 0 : 5
        y: 4
        width: box.width
        height: box.height
        radius: 22
        color: Theme.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: box
        width: root.inner
        height: column.implicitHeight + 8
        radius: 22
        color: Theme.pSurface
        border.width: 4
        border.color: Theme.pLine
        antialiasing: true
        clip: true

        Column {
            id: column
            x: 4
            y: 4
            width: parent.width - 8

            // ----- header: gradient strip -----
            Rectangle {
                width: parent.width
                height: 56
                radius: 18
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.accentCyan }
                    GradientStop { position: 1; color: Theme.accentMint }
                }
                border.width: 5
                border.color: Theme.pRingWhite

                Row {
                    x: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.mode === "conflict" ? "warning" : root.mode === "byhand" ? "tune" : "keyboard"
                        size: 22
                        color: Theme.colBorder
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.row ? root.row.name : ""
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 19
                        font.weight: Font.Black
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.mode === "conflict" ? "These keys are taken"
                            : root.mode === "byhand" ? "Set it by hand" : "Press the new keys"
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.ExtraBold
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.row && root.row.combos.length > 0
                        ? "Now on " + root.row.combos.map(KB.showCombo).join(" or ") : "No key yet"
                    color: Theme.colBorder
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.ExtraBold
                }
            }

            // ----- record -----
            Column {
                visible: root.mode === "record"
                width: parent.width
                topPadding: 30
                bottomPadding: 22
                spacing: 18

                KeyCaps {
                    anchors.horizontalCenter: parent.horizontalCenter
                    large: true
                    held: true
                    combos: root.heldMods !== 0 ? [{ mods: root.heldMods, key: "" }] : []
                    waiting: root.heldMods !== 0 ? "then a key" : "Press the keys"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 48
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.refusal !== "" ? root.refusal
                        : "Hold Super, Ctrl, Alt or Shift, then press a key. It's saved the moment you do."
                    color: root.refusal !== "" ? Theme.pInk : Theme.pInkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
            }

            // ----- by hand -----
            Column {
                visible: root.mode === "byhand"
                width: parent.width
                leftPadding: 26
                rightPadding: 26
                topPadding: 24
                bottomPadding: 24
                spacing: 18

                Row {
                    spacing: 16
                    KeyEditorLabel { text: "Hold" }
                    Repeater {
                        model: [["Super", KB.SUPER], ["Ctrl", KB.CTRL], ["Alt", KB.ALT], ["Shift", KB.SHIFT]]
                        delegate: SettingChip {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            label: modelData[0]
                            selected: (root.handMods & modelData[1]) !== 0
                            onClicked: root.handMods = root.handMods ^ modelData[1]
                        }
                    }
                }

                Row {
                    spacing: 16
                    KeyEditorLabel { text: "Key" }

                    // the key field
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 210
                        height: 54

                        Rectangle {
                            y: 4
                            width: parent.width
                            height: 50
                            radius: 16
                            color: Theme.pLineShadow
                        }
                        Rectangle {
                            width: parent.width
                            height: 50
                            radius: 16
                            color: Theme.pSurface
                            border.width: 3
                            border.color: Theme.pLine

                            TextInput {
                                id: keyField
                                x: 16
                                width: parent.width - 32
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.pInk
                                font.family: Theme.fontFamily
                                font.pixelSize: 19
                                font.weight: Font.Black
                                clip: true
                                onTextEdited: root.handKey = KB.keyFromText(text)
                                Keys.onEscapePressed: root.close()
                                Keys.onReturnPressed: if (root.handKey !== "") root.offer(root.handCombo)

                                Text {
                                    visible: keyField.text === ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "A, Tab, F5…"
                                    color: Theme.pInkSub
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }

                    Repeater {
                        model: [["Space", "space"], ["Tab", "Tab"], ["Return", "Return"], ["Print", "Print"]]
                        delegate: SettingChip {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            capH: 36
                            fontSize: 15
                            label: modelData[0]
                            selected: root.handKey === modelData[1]
                            onClicked: {
                                root.handKey = modelData[1]
                                keyField.text = modelData[0]
                            }
                        }
                    }
                    SettingChip {
                        anchors.verticalCenter: parent.verticalCenter
                        capH: 36
                        fontSize: 15
                        label: "F1 to F12"
                        icon: root.fKeysOpen ? "expand_less" : "expand_more"
                        selected: /^F([1-9]|1[0-2])$/.test(root.handKey)
                        onClicked: root.fKeysOpen = !root.fKeysOpen
                    }
                }

                Flow {
                    visible: root.fKeysOpen
                    x: 96 + 16
                    width: parent.width - 52 - x
                    spacing: 8
                    Repeater {
                        model: 12
                        delegate: SettingChip {
                            required property int index
                            capH: 36
                            fontSize: 15
                            label: "F" + (index + 1)
                            selected: root.handKey === label
                            onClicked: {
                                root.handKey = label
                                keyField.text = label
                                root.fKeysOpen = false
                            }
                        }
                    }
                }

                Row {
                    spacing: 16
                    KeyEditorLabel { text: "Gives" }

                    KeyCaps {
                        anchors.verticalCenter: parent.verticalCenter
                        combos: [root.handCombo]
                        waiting: root.handKey === "" ? "a key" : ""
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: root.handKey === "" ? "info" : root.handTaken === null ? "check_circle" : "warning"
                            size: 20
                            color: Theme.pInk
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.handKey === "" ? "Pick a key"
                                : KB.needsModifier(root.handCombo) ? "Hold a modifier with it, or it stops typing"
                                : root.handTaken === null ? "Free, nothing else uses it"
                                : "Taken by " + root.handTaken.name
                            color: Theme.pInk
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.ExtraBold
                        }
                    }
                }
            }

            // ----- conflict -----
            Row {
                visible: root.mode === "conflict" && root.wanted !== null && root.taken !== null
                width: parent.width
                leftPadding: 26
                rightPadding: 26
                topPadding: 24
                bottomPadding: 24
                spacing: 28

                KeyCaps {
                    id: wantedCaps
                    anchors.verticalCenter: parent.verticalCenter
                    large: true
                    combos: root.wanted ? [root.wanted] : []
                }

                // the warning, on the third card colour
                Rectangle {
                    width: parent.width - 52 - wantedCaps.width - 28
                    height: warnCol.implicitHeight + 32
                    radius: 18
                    color: Theme.attributeColors[2]
                    border.width: 3
                    border.color: Theme.pLine
                    antialiasing: true

                    MaterialIcon {
                        x: 20
                        y: 17
                        name: "warning"
                        size: 26
                        color: Theme.colBorder
                    }

                    Column {
                        id: warnCol
                        x: 60
                        y: 16
                        width: parent.width - 80
                        spacing: 4

                        readonly property bool isAction: root.taken !== null && root.taken.kind === "action"
                        readonly property string keys: root.wanted ? KB.showCombo(root.wanted) : ""
                        readonly property string other: root.taken ? root.taken.name : ""
                        readonly property string group: {
                            if (!warnCol.isAction)
                                return ""
                            const r = KeybindService.row(root.taken.id)
                            return r ? r.group : ""
                        }

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            textFormat: Text.StyledText
                            text: warnCol.isAction
                                ? "<b>" + warnCol.keys + "</b> is already on <b>" + warnCol.other + "</b>, in " + warnCol.group + "."
                                : "<b>" + warnCol.keys + "</b> is Hyprland's <b>" + warnCol.other + "</b> bind, from your "
                                  + (KeybindService.mode === "lua" ? "keybinds.lua" : "Hyprland config") + "."
                            color: Theme.colBorder
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            lineHeight: 1.2
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: warnCol.isAction
                                ? "Take it over and " + warnCol.other + " is left without a key. You can give it a new one any time."
                                : "Take it over and that bind is switched off while " + (root.row ? root.row.name : "")
                                  + " uses these keys. Reset " + (root.row ? root.row.name : "") + " and " + warnCol.other + " gets them back."
                            color: Theme.colBorder
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            lineHeight: 1.2
                        }

                        // what happens to the other one
                        Rectangle {
                            width: parent.width
                            height: 2
                            color: Qt.rgba(0, 0, 0, 0.18)
                        }
                        Row {
                            topPadding: 8
                            spacing: 10
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: warnCol.other
                                color: Theme.colBorder
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.ExtraBold
                            }
                            KeyCaps {
                                anchors.verticalCenter: parent.verticalCenter
                                onColour: true
                                combos: root.taken ? [root.taken.combo] : []
                            }
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "arrow_forward"
                                size: 20
                                color: Theme.colBorder
                            }
                            KeyCaps {
                                anchors.verticalCenter: parent.verticalCenter
                                onColour: true
                                combos: []
                                noneText: warnCol.isAction ? "No key" : "Off"
                            }
                        }
                    }
                }
            }

            // ----- footer -----
            Rectangle {
                width: parent.width
                height: 2.5
                color: Theme.pSurfaceDivider
            }

            Item {
                width: parent.width
                height: 68

                Row {
                    x: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    // Esc cancels (record, conflict) / Record instead (by hand)
                    KeyCaps {
                        visible: root.mode !== "byhand"
                        anchors.verticalCenter: parent.verticalCenter
                        combos: [{ mods: 0, key: "Escape" }]
                    }
                    Text {
                        visible: root.mode !== "byhand"
                        anchors.verticalCenter: parent.verticalCenter
                        text: "cancels"
                        color: Theme.pInkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                    SettingChip {
                        visible: root.mode === "byhand"
                        anchors.verticalCenter: parent.verticalCenter
                        capH: 36
                        fontSize: 15
                        icon: "keyboard"
                        label: "Record instead"
                        onClicked: root.open("record")
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    // record
                    SettingChip {
                        visible: root.mode === "record"
                        anchors.verticalCenter: parent.verticalCenter
                        capH: 36
                        fontSize: 15
                        icon: "block"
                        label: "Leave without a key"
                        onClicked: {
                            KeybindService.setKeys(root.row.id, null, null)
                            root.close()
                        }
                    }
                    Text {
                        visible: root.mode === "record"
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Keys not coming through?"
                        color: Theme.pInkSub
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                    SettingChip {
                        visible: root.mode === "record"
                        anchors.verticalCenter: parent.verticalCenter
                        capH: 36
                        fontSize: 15
                        icon: "tune"
                        label: "Set it by hand"
                        onClicked: root.open("byhand")
                    }

                    // by hand
                    SettingChip {
                        visible: root.mode === "byhand"
                        anchors.verticalCenter: parent.verticalCenter
                        capH: 36
                        fontSize: 15
                        label: "Cancel"
                        onClicked: root.close()
                    }
                    SettingChip {
                        visible: root.mode === "byhand"
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Save"
                        selected: true
                        enabled: root.handKey !== "" && !KB.needsModifier(root.handCombo)
                        opacity: enabled ? 1 : 0.5
                        onClicked: root.offer(root.handCombo)
                    }

                    // conflict
                    SettingChip {
                        visible: root.mode === "conflict"
                        anchors.verticalCenter: parent.verticalCenter
                        capH: 36
                        fontSize: 15
                        label: "Try other keys"
                        onClicked: root.open("record")
                    }
                    SettingChip {
                        visible: root.mode === "conflict"
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Take it over"
                        selected: true
                        onClicked: {
                            KeybindService.setKeys(root.row.id, root.wanted, root.taken)
                            root.close()
                        }
                    }
                }
            }
        }
    }
}
