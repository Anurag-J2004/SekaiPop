import QtQuick
import qs.modules.common
import "../../common/functions/KeyBinds.js" as KB

// The keys of a shortcut, as keycaps: modifiers on a tinted cap, the key on a
// plain one, several combinations side by side with "or" between them. An action
// with no key shows a dashed "No key" (`noneText`).
//
//   KeyCaps { combos: row.combos }                       // the list
//   KeyCaps { combos: [combo]; large: true }             // recording, conflicts
//   KeyCaps { combos: [{ mods: 64, key: "" }]; large: true; waiting: "then a key"; held: true }
Row {
    id: root

    property var combos: []
    property bool large: false
    // Recording: the modifiers being held are lit and pressed in, and an empty key
    // slot blinks with `waiting`.
    property bool held: false
    property string waiting: ""
    property string noneText: "No key"
    // A plain variant for the coloured conflict box: white caps, outlined in the
    // theme's border colour.
    property bool onColour: false

    spacing: large ? 12 : 6

    // Keycap colours follow the theme: white caps in Light, the surface lifted in
    // Dark and Darker; the modifiers a shade off the plain keys.
    readonly property color capColor: onColour ? "#ffffff"
        : Theme.dark ? Qt.lighter(Theme.pSurface, 1.7) : "#ffffff"
    readonly property color modColor: onColour ? "#ffffff"
        : Theme.dark ? Qt.lighter(Theme.pSurface, 2.4)
                     : Qt.tint("#ffffff", Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, 0.10))
    readonly property color capInk: onColour ? Theme.colBorder : Theme.dark ? Theme.pInk : Theme.colBorder
    readonly property color capLine: onColour ? Theme.colBorder : Theme.pLine
    readonly property color capShadow: onColour ? Theme.colBorder : Theme.pLineShadow

    // [{ k, mod }] per combination, plus the separators.
    readonly property var items: {
        const out = []
        const list = root.combos || []
        for (let i = 0; i < list.length; i++) {
            if (i > 0)
                out.push({ k: "or", sep: true })
            const caps = KB.caps(list[i])
            for (const c of caps)
                out.push({ k: c.k, mod: c.mod })
            if (list[i].key === "" && root.waiting !== "")
                out.push({ k: root.waiting, wait: true })
        }
        if (out.length === 0)
            out.push(root.waiting !== "" ? { k: root.waiting, wait: true } : { k: root.noneText, none: true })
        return out
    }

    Repeater {
        model: root.items

        delegate: Item {
            id: cap
            required property var modelData

            readonly property bool sep: modelData.sep === true
            readonly property bool none: modelData.none === true || modelData.wait === true
            readonly property bool lit: root.held && modelData.mod === true
            readonly property real h: root.large ? 58 : 32
            readonly property real border: root.large ? 3 : 2.5
            readonly property real drop: root.large ? 5 : 3

            width: sep ? sepText.implicitWidth : Math.max(root.large ? 66 : 34, label.implicitWidth + (root.large ? 44 : 20))
            height: h + drop
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: sepText
                visible: cap.sep
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -cap.drop / 2
                text: "or"
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: root.large ? 17 : 13
                font.weight: Font.Bold
            }

            // hard shadow under the cap (none for a dashed or pressed-in one)
            Rectangle {
                visible: !cap.sep && !cap.none && !cap.lit
                y: cap.drop
                width: parent.width
                height: cap.h
                radius: root.large ? 14 : 9
                color: root.capShadow
                antialiasing: true
            }

            Rectangle {
                id: face
                y: cap.lit ? cap.drop - 1 : 0
                width: parent.width
                height: cap.h
                radius: root.large ? 14 : 9
                color: cap.none ? "transparent" : cap.modelData.mod ? root.modColor : root.capColor
                border.width: cap.border
                border.color: root.capLine
                antialiasing: true
                // a dashed outline for "No key" / the key still to come
                visible: !cap.sep && !cap.none
            }

            // The pressed-in gradient of a held modifier, inside a white ring.
            Rectangle {
                visible: cap.lit
                x: 4
                y: face.y + 4
                width: parent.width - 8
                height: cap.h - 8
                radius: (root.large ? 14 : 9) - 4
                antialiasing: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.accentCyan }
                    GradientStop { position: 1; color: Theme.accentMint }
                }
            }

            Canvas {
                id: dashed
                visible: cap.none
                width: parent.width
                height: cap.h
                property color lineColor: root.capLine
                onLineColorChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d")
                    g.reset()
                    g.strokeStyle = lineColor
                    g.lineWidth = cap.border
                    g.setLineDash([4, 3])
                    const r = root.large ? 14 : 9, b = cap.border / 2
                    g.beginPath()
                    g.roundedRect(b, b, width - cap.border, height - cap.border, r, r)
                    g.stroke()
                }
            }

            Text {
                id: label
                visible: !cap.sep
                anchors.horizontalCenter: parent.horizontalCenter
                y: face.y + (cap.h - implicitHeight) / 2
                text: cap.modelData.k
                color: cap.lit ? Theme.colBorder : cap.none ? Theme.pInkSub : root.capInk
                font.family: Theme.fontFamily
                font.pixelSize: cap.modelData.wait ? (root.large ? 18 : 14)
                              : root.large ? 22 : 14
                font.weight: cap.none ? Font.ExtraBold : Font.Black
                font.letterSpacing: cap.none ? 0 : (root.large ? 0.6 : 0.4)

                // the key still to come blinks
                SequentialAnimation on opacity {
                    running: cap.modelData.wait === true
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 550; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 550; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
