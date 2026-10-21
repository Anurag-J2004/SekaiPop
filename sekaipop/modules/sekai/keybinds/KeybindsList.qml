import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.settings
import "../../common/functions/KeyBinds.js" as KB
import "KeybindsLayout.js" as KL

// The List view: the groups down the left as tall keys, the actions of the chosen group in a
// card on the right (all groups at once while something is searched for). A row is the
// action's name, its keys, a "changed" mark and a reset button; click it to choose it, then
// use the strip's Press keys. SekaiPop's own actions only: window and workspace keys are
// Hyprland's. "Open apps" is the modifier tap (Super by default); it can be moved to an Alt
// or Ctrl tap or cleared like any other.
Item {
    id: root

    required property var panel

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    readonly property bool searching: root.panel.query.trim() !== ""
    readonly property var shownRows: KL.listRows(KeybindService.rows, root.panel.group, root.panel.query)
    readonly property var listModel: root.shownRows
    readonly property real railW: 200
    readonly property real cardR: 30

    implicitHeight: 476

    // ===== the groups =====
    Column {
        id: rail
        width: root.railW
        spacing: 18
        opacity: root.searching ? 0.45 : 1

        Repeater {
            model: KB.GROUPS

            delegate: SlabKey {
                required property string modelData

                width: rail.width - 14
                keyHeight: 46
                label: modelData
                labelSize: 16
                fill: KL.colorOf(modelData)
                selected: !root.searching && root.panel.group === modelData
                onClicked: {
                    root.panel.query = ""
                    root.panel.clearSearchField()
                    root.panel.group = modelData
                }
            }
        }
    }

    // ===== the card =====
    Item {
        id: card
        x: root.railW + 16
        width: root.width - x
        height: root.height - root.mt.shadowOffset - 2

        Rectangle {
            y: root.mt.shadowOffset
            width: parent.width
            height: parent.height
            radius: root.cardR
            color: root.mt.pLineShadow
        }

        Rectangle {
            id: face
            anchors.fill: parent
            radius: root.cardR
            color: root.mt.pSurface
            border.width: 4
            border.color: root.mt.pLine

            Text {
                x: 32
                y: 14
                text: "ACTION"
                color: root.mt.pInkSub
                font.family: root.mt.fontFamily
                font.pixelSize: 12
                font.weight: Font.Black
                font.letterSpacing: 1.5
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 40
                y: 14
                text: "KEYS"
                color: root.mt.pInkSub
                font.family: root.mt.fontFamily
                font.pixelSize: 12
                font.weight: Font.Black
                font.letterSpacing: 1.5
            }

            ListView {
                id: list
                x: 14
                y: 40
                width: face.width - 28
                height: face.height - 40 - 14
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.listModel

                delegate: Item {
                    id: row
                    required property var modelData

                    readonly property bool sel: modelData.id === root.panel.selectedId
                    readonly property bool changed: modelData.changed === true

                    width: list.width - 14
                    height: 52

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 20
                        color: row.sel ? Qt.tint(root.mt.pSurface, Qt.rgba(root.mt.accentCyan.r, root.mt.accentCyan.g, root.mt.accentCyan.b, 0.22))
                             : rowArea.containsMouse ? root.mt.pSurfaceHover : "transparent"
                        border.width: row.sel ? 3 : 0
                        border.color: root.mt.accentCyan
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        x: 18
                        width: parent.width - 36
                        height: 2
                        color: root.mt.pSurfaceDivider
                        opacity: row.sel ? 0 : 1
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.panel.select(row.modelData.id)
                    }

                    Rectangle {
                        id: bar
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 28
                        radius: 7
                        color: KL.colorOf(row.modelData.group)
                        border.width: 3
                        border.color: root.mt.pLine
                        antialiasing: true
                    }

                    Column {
                        anchors.left: bar.right
                        anchors.leftMargin: 14
                        anchors.right: rightRow.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.modelData.name
                            color: root.mt.pInk
                            font.family: root.mt.fontFamily
                            font.pixelSize: 18
                            font.weight: Font.ExtraBold
                        }
                        Text {
                            visible: root.searching
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.modelData.group
                            color: root.mt.pInkSub
                            font.family: root.mt.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }

                    Row {
                        id: rightRow
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Rectangle {
                            visible: row.changed
                            anchors.verticalCenter: parent.verticalCenter
                            width: changedText.implicitWidth + 20
                            height: 22
                            radius: 11
                            color: root.mt.accentMint
                            Text {
                                id: changedText
                                anchors.centerIn: parent
                                text: "changed"
                                color: root.mt.colBorder
                                font.family: root.mt.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.ExtraBold
                            }
                        }

                        KeyCaps {
                            anchors.verticalCenter: parent.verticalCenter
                            combos: row.modelData.combos
                        }

                        KeyRoundButton {
                            visible: row.changed
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "restart_alt"
                            tip: row.modelData.before && row.modelData.before.length > 0
                                 ? "Back to " + KB.showCombo(row.modelData.before[0]) : "Back to no key"
                            onClicked: KeybindService.reset(row.modelData.id)
                        }
                    }
                }

                SekaiScrollBar {}
            }

            Text {
                visible: root.listModel.length === 0
                anchors.centerIn: parent
                text: "No action or key matches \u201c" + root.panel.query.trim() + "\u201d."
                color: root.mt.pInkSub
                font.family: root.mt.fontFamily
                font.pixelSize: 17
                font.weight: Font.Bold
            }
        }
    }
}
