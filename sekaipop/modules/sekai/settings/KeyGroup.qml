import QtQuick
import Quickshell
import qs.modules.common

// The rows of one group card on the Keys page (Shell, Utilities, Media, Session),
// two to a line. Editing one opens the page's modal (SettingsPageKeys.qml).
//
// Shell has three parts: its actions, "+N more" (the extras the cheat sheet also
// keeps back), and "Ready, no key yet" (actions that ship without a key).
Column {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property var rows: []               // KeyBinds.rows() entries of this group (already searched)
    property bool showApps: false       // the fixed Super tap leads the Shell card

    signal edit(string id, string mode)
    signal resetRequested(string id)

    property bool moreOpen: false

    readonly property var main: rows.filter(r => !r.more && !r.bare)
    readonly property var extra: rows.filter(r => r.more)
    readonly property var bare: rows.filter(r => r.bare)

    readonly property real colWidth: Math.floor((width - 16) / 2)

    // Lines of two: [{ pair: [row, row] } | { more } | { header }]
    function lines(list, lead) {
        const out = []
        let pair = lead ? [{ fixed: true }] : []
        for (const r of list) {
            pair.push(r)
            if (pair.length === 2) {
                out.push({ pair: pair })
                pair = []
            }
        }
        if (pair.length > 0)
            out.push({ pair: pair })
        return out
    }

    readonly property var model: {
        let out = root.lines(root.moreOpen ? root.main.concat(root.extra) : root.main, root.showApps)
        if (root.extra.length > 0 && !root.moreOpen)
            out.push({ more: root.extra })
        if (root.bare.length > 0) {
            out.push({ header: true })
            out = out.concat(root.lines(root.bare, false))
        }
        return out
    }

    spacing: 2

    Repeater {
        model: root.model

        delegate: Loader {
            id: line
            required property var modelData
            width: root.width
            sourceComponent: modelData.more ? moreLine
                : modelData.header ? headerLine : pairLine
        }
    }

    Component {
        id: pairLine
        Row {
            spacing: 16
            Repeater {
                model: parent ? parent.parent.modelData.pair : []
                delegate: KeyRow {
                    required property var modelData
                    width: root.colWidth
                    fixed: modelData.fixed === true
                    row: modelData.fixed === true ? null : modelData
                    onRecord: root.edit(modelData.id, "record")
                    onByHand: root.edit(modelData.id, "byhand")
                    onResetRequested: root.resetRequested(modelData.id)
                }
            }
        }
    }

    Component {
        id: moreLine
        Item {
            implicitHeight: 52
            SettingChip {
                x: 14
                y: 8
                capH: 36
                fontSize: 15
                label: "+" + parent.parent.modelData.more.length + " more: "
                       + parent.parent.modelData.more.map(r => r.name).join(", ")
                onClicked: root.moreOpen = true
            }
        }
    }

    Component {
        id: headerLine
        Column {
            topPadding: 12
            Canvas {
                id: dash
                width: parent.width
                height: 3
                property color c: mt.pSurfaceDivider
                onCChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d")
                    g.reset()
                    g.strokeStyle = c
                    g.lineWidth = 2.5
                    g.setLineDash([5, 4])
                    g.beginPath()
                    g.moveTo(0, 1.5)
                    g.lineTo(width, 1.5)
                    g.stroke()
                }
            }
            Row {
                leftPadding: 14
                topPadding: 18
                bottomPadding: 8
                spacing: 14
                Text {
                    anchors.baseline: sub.baseline
                    text: "Ready, no key yet"
                    color: mt.pInk
                    font.family: mt.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Black
                    font.letterSpacing: 1.4
                    font.capitalization: Font.AllUppercase
                }
                Text {
                    id: sub
                    text: "These come with the shell but ship without a key. Give them one."
                    color: mt.pInkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
            }
        }
    }
}
