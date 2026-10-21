import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "KeybindsLayout.js" as KL

// The Board view: a 75% keyboard that shows what is on every key while the chosen
// modifiers are held (the Super / Ctrl / Alt / Shift keys, here and in the strip, are the
// layers), and under it the mouse keys and the hardware keys.
//
// Pink / orange / blue / red keys are SekaiPop's own actions (Shell, Utilities, Media,
// Session: the ones this panel can move); yellow, lilac and green ones are Hyprland's, shown
// so you can see which keys are taken but changed in keybinds.lua. Click a pink key to pick
// its action; while "Press keys" is on, click a free key (with the modifiers you want on)
// to put the action there.
Item {
    id: root

    required property var panel

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    readonly property var map: KL.layerMap(KeybindService.binds, KeybindService.rows, root.panel.layer)
    readonly property real colW: root.width / KL.COLS
    readonly property real keyH: 62
    readonly property real pitch: 76
    readonly property real rowsH: KL.ROWS.length * root.pitch
    readonly property real bottomY: root.rowsH + 12
    readonly property color free: mt.pSurface

    implicitHeight: root.bottomY + 24 + 54 + mt.shadowOffset

    // ===== the keyboard =====
    Repeater {
        model: KL.ROWS

        delegate: Item {
            id: rowItem
            required property var modelData
            required property int index

            y: rowItem.index * root.pitch
            width: root.width
            height: root.keyH + root.mt.shadowOffset

            Repeater {
                model: rowItem.modelData

                delegate: SlabKey {
                    id: key
                    required property var modelData

                    readonly property bool isMod: modelData.mod !== 0
                    readonly property bool modOn: isMod && (root.panel.layer & modelData.mod) !== 0
                    readonly property var entry: modelData.bindable ? KL.hit(root.map, modelData) : undefined
                    readonly property bool plain: isMod ? !modOn : entry === undefined

                    x: modelData.x * root.colW + 3
                    width: modelData.w * root.colW - 6
                    keyHeight: root.keyH

                    label: modelData.label
                    labelSize: modelData.label.length > 1 ? 15 : 22
                    sub: entry !== undefined ? entry.short : ""
                    fill: isMod ? (modOn ? root.mt.accentCyan : root.free)
                                : (entry !== undefined ? KL.colorOf(entry.group) : root.free)
                    ink: plain ? root.mt.pInk : root.mt.colBorder
                    active: modOn
                    selected: entry !== undefined && entry.kind === "action" && entry.id === root.panel.selectedId
                    dim: !modelData.bindable && !isMod

                    onClicked: {
                        if (key.isMod)
                            root.panel.toggleMod(modelData.mod)
                        else
                            root.panel.boardKey(modelData, key.entry)
                    }
                }
            }
        }
    }

    // ===== media and mouse =====
    Text {
        x: 6
        y: root.bottomY
        text: "MEDIA \u00b7 ANY LAYER"
        color: root.mt.pInkSub
        font.family: root.mt.fontFamily
        font.pixelSize: 12
        font.weight: Font.Black
        font.letterSpacing: 1.5
    }

    Text {
        x: 28 * root.colW + 6
        y: root.bottomY
        text: "MOUSE \u00b7 WITH THE LAYER"
        color: root.mt.pInkSub
        font.family: root.mt.fontFamily
        font.pixelSize: 12
        font.weight: Font.Black
        font.letterSpacing: 1.5
    }

    Repeater {
        model: KL.MEDIA

        delegate: SlabKey {
            required property var modelData
            required property int index

            x: index * 8 * root.colW + 3
            y: root.bottomY + 24
            width: 8 * root.colW - 6
            keyHeight: 54
            label: modelData.label
            labelSize: 16
            fill: root.free
            ink: root.mt.pInk
        }
    }

    Repeater {
        model: KL.MOUSE

        delegate: SlabKey {
            required property var modelData
            required property int index

            readonly property var entry: KL.hit(root.map, modelData)

            x: (28 + index * 8) * root.colW + 3
            y: root.bottomY + 24
            width: 8 * root.colW - 6
            keyHeight: 54
            label: modelData.label
            labelSize: 16
            sub: entry !== undefined ? entry.short : ""
            fill: entry !== undefined ? KL.colorOf(entry.group) : root.free
            ink: entry !== undefined ? root.mt.colBorder : root.mt.pInk
        }
    }
}
