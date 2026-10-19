import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/KeyBinds.js" as KB

// One action on the Keys page: its name, the keys it is on, and on hover the
// round "set it by hand" button. A changed action wears the accent diamond, says
// what a reset gives back ("Default: SUPER + N") and shows a reset button.
// The bare Super tap is `fixed`: shown, with a padlock instead of buttons.
Item {
    id: root

    property var row: null              // KeyBinds.rows() entry (null for the fixed Super tap)
    property bool fixed: false
    property string fixedName: "Apps"
    property string fixedNote: "Tap Super on its own · fixed"
    // Another action is being edited: this one steps back.
    property bool dimmed: false

    signal record()
    signal byHand()
    signal resetRequested()

    readonly property bool hovered: area.containsMouse || resetBtn.hovered || handBtn.hovered
    readonly property string note: fixed ? fixedNote
        : row && row.changed ? "Default: " + (row.before.length > 0 ? row.before.map(KB.showCombo).join(" or ") : "no key")
        : ""

    implicitHeight: Math.max(62, content.implicitHeight + 8)
    opacity: dimmed ? 0.36 : 1
    enabled: !dimmed

    Behavior on opacity {
        NumberAnimation { duration: 140 }
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Theme.pSurfaceHover
        opacity: root.hovered && !root.fixed ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 90 }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.fixed ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: if (!root.fixed) root.record()
    }

    Row {
        id: content
        x: 18
        width: parent.width - 18 - 6
        height: parent.height
        spacing: 12

        // the "changed" diamond
        Rectangle {
            visible: root.row !== null && root.row.changed
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            rotation: 45
            radius: 3
            border.width: 2
            border.color: Theme.pLine
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.accentCyan }
                GradientStop { position: 1; color: Theme.accentMint }
            }
        }

        Column {
            id: names
            anchors.verticalCenter: parent.verticalCenter
            width: content.width - (root.row !== null && root.row.changed ? 24 : 0) - caps.width
                   - buttons.width - content.spacing * 2
            spacing: 1

            Text {
                width: parent.width
                text: root.fixed ? root.fixedName : root.row ? root.row.name : ""
                elide: Text.ElideRight
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.ExtraBold
            }

            Text {
                visible: root.note !== ""
                width: parent.width
                text: root.note
                elide: Text.ElideRight
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        // The Super tap: one cap and "TAP".
        Row {
            id: caps
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            KeyCaps {
                anchors.verticalCenter: parent.verticalCenter
                combos: root.fixed ? [{ mods: KB.SUPER, key: "" }] : root.row ? root.row.combos : []
            }

            Text {
                visible: root.fixed
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -1
                text: "TAP"
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Black
                font.letterSpacing: 1
            }
        }

        Row {
            id: buttons
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            KeyRoundButton {
                id: resetBtn
                visible: root.row !== null && root.row.changed
                icon: "restart_alt"
                tip: root.row && root.row.before.length > 0 ? "Back to " + KB.showCombo(root.row.before[0]) : "Back to no key"
                onClicked: root.resetRequested()
            }

            // "set it by hand", shown on hover; the padlock on the fixed row
            KeyRoundButton {
                id: handBtn
                icon: root.fixed ? "lock" : "tune"
                flat: root.fixed
                tip: root.fixed ? "" : "Set the keys by hand"
                opacity: root.fixed || root.hovered ? 1 : 0
                onClicked: if (!root.fixed) root.byHand()
            }
        }
    }
}
