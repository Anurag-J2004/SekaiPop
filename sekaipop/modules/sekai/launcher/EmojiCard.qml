import QtQuick
import "Emoji.js" as Emoji
import qs.modules.common
import qs.modules.common.widgets

// The usual emoji picker: a row of category tabs (Recent first, once you've
// picked something), a grid, and the name of whatever is under the cursor at
// the bottom. Typing after "emoji " (or ":") searches every category by
// name and keywords -- ":fire", "emoji red heart".
//
//   click / Enter        copies it and closes
//   Shift+click / Shift+Enter   copies it, closes, and types it into the
//                        window you were in (needs `wtype`)
//   arrows               move around the grid
//
// Pure UI; ExtrasSource.qml does the copying and remembers the recents.
ExtraFrame {
    id: root

    property string arg: ""
    property var recent: []           // characters, newest first

    signal picked(string emoji, bool typeIt)

    readonly property int cols: 9
    readonly property real cell: 52
    readonly property bool searching: arg.trim() !== ""

    // -1 = Recent, 0.. = Emoji.groups
    property int tab: recent.length > 0 ? -1 : 0
    property int current: 0

    width: cols * cell + 32
    height: 432

    readonly property var items: {
        if (root.searching)
            return Emoji.search(root.arg, 300)
        if (root.tab === -1)
            return root.recent.map(ch => Emoji.find(ch))
        return Emoji.inGroup(root.tab)
    }

    onItemsChanged: current = 0
    onRecentChanged: if (tab === -1 && recent.length === 0) tab = 0

    readonly property var currentItem: (current >= 0 && current < items.length) ? items[current] : null

    function nav(dx, dy) {
        if (items.length === 0)
            return
        current = Math.max(0, Math.min(items.length - 1, current + dx + dy * cols))
        grid.positionViewAtIndex(current, GridView.Contain)
    }

    function activate(typeIt) {
        if (currentItem)
            picked(currentItem[0], typeIt === true)
    }

    // ===== category tabs =====
    Row {
        id: tabs
        x: 16
        y: 14
        spacing: 3
        opacity: root.searching ? 0.35 : 1

        Repeater {
            model: {
                const t = []
                if (root.recent.length > 0)
                    t.push({ id: -1, icon: "history", name: "Recent" })
                for (let i = 0; i < Emoji.groups.length; i++)
                    t.push({ id: i, icon: Emoji.groups[i].icon, name: Emoji.groups[i].name })
                return t
            }
            delegate: Item {
                id: tabItem
                required property var modelData
                readonly property bool on: !root.searching && root.tab === modelData.id

                width: root.cell - 10
                height: 36

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: tabItem.on ? Theme.accentCyan : (tabArea.containsMouse ? "#ece6d4" : "transparent")
                    border.width: tabItem.on ? 2.5 : 0
                    border.color: Theme.line
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    name: tabItem.modelData.icon
                    size: 22
                    weight: 550
                    color: tabItem.on ? Theme.colBorder : ScrapbookTheme.inkSoft
                }

                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.tab = tabItem.modelData.id
                        root.current = 0
                    }
                }
            }
        }
    }

    // ===== the grid =====
    Rectangle {
        id: tray
        x: 12
        y: tabs.y + tabs.height + 10
        width: parent.width - 24
        height: parent.height - y - 62
        radius: 16
        color: ScrapbookTheme.boardBg
        border.width: 2
        border.color: Theme.colDivider
        clip: true

        WheelScroll { scroller: grid }
        GridView {
            id: grid
            anchors.fill: parent
            anchors.margins: 6
            cellWidth: root.cell
            cellHeight: root.cell
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.items
            currentIndex: root.current
            visible: root.items.length > 0

            delegate: Item {
                id: cellItem
                required property var modelData
                required property int index
                width: root.cell
                height: root.cell
                readonly property bool sel: index === root.current

                Rectangle {
                    anchors.centerIn: parent
                    width: root.cell - 6
                    height: root.cell - 6
                    radius: 12
                    color: cellItem.sel ? Qt.rgba(0.016, 0.996, 0.933, 0.35) : (cellArea.containsMouse ? "#ffffff" : "transparent")
                    border.width: cellItem.sel ? 2.5 : 0
                    border.color: Theme.line
                }

                Text {
                    anchors.centerIn: parent
                    text: cellItem.modelData[0]
                    font.pixelSize: 28
                }

                MouseArea {
                    id: cellArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // position, not enter: keyboard scrolling moves cells under a
                    // resting mouse, which must not steal the highlight
                    onPositionChanged: root.current = cellItem.index
                    onClicked: mouse => root.picked(cellItem.modelData[0], (mouse.modifiers & Qt.ShiftModifier) !== 0)
                }
            }

            SekaiScrollBar {}
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.items.length === 0
            text: root.searching ? "No emoji match \u201c" + root.arg.trim() + "\u201d." : "Nothing here yet."
            color: ScrapbookTheme.inkSoft
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }
    }

    // ===== footer: the name =====
    Item {
        x: 16
        y: tray.y + tray.height + 10
        width: parent.width - 32
        height: 38

        Text {
            id: bigGlyph
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentItem ? root.currentItem[0] : ""
            font.pixelSize: 26
        }

        Text {
            anchors.left: bigGlyph.right
            anchors.leftMargin: 10
            anchors.right: hint.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.currentItem ? root.currentItem[1] : (root.searching ? "" : "Pick one")
            color: Theme.colBorder
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            id: hint
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Enter copies \u00b7 Shift types"
            color: ScrapbookTheme.inkSoft
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }
}
