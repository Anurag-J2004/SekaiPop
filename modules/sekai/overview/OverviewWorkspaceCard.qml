import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// One workspace's card in the Overview: a "Workspace N" header over a
// to-scale mock of the screen — now a sheet of paper pinned (or taped)
// to the cork board Overview.qml draws behind it. It is only the
// *frame*: the window thumbnails are not children of it. They live in
// Overview.qml's shared `windowSpace` layer, drawn above every card,
// so a tile can be dragged from one card to another without being
// clipped by the card it started on. What this card does own:
//
//   - the drop target (`DropArea`): while a tile is dragged over it,
//     `dragEntered` / `dragExited` tell Overview.qml which workspace
//     it would land on
//   - click to switch to this workspace (`clicked`) — a tile sitting
//     above it takes its own clicks first
//
// Overview.qml sizes and positions each card (it also needs those
// numbers to place the tiles), so nothing here computes a layout.
// That is also why the card itself is never rotated: the tiles sit
// in a different layer and would stop lining up with it. The "messy
// board" feel comes from the tilted sheet *behind* the card, the pin
// or tape on top, and the drop shadow instead.
Item {
    id: root

    required property int workspaceId
    property real areaWidth: 300
    property real areaHeight: 170
    property real cellPad: 10
    property real headerHeight: 28
    property int windowCount: 0

    // True while a tile is being dragged over this card.
    readonly property bool dropHover: dropArea.containsDrag

    // Per-card variety, all derived from the workspace number so it's
    // stable: a tilt for the paper behind, a pin colour, and whether
    // this one is held by a pin (odd) or a strip of tape (even).
    readonly property var tilts: [-2.4, 1.8, -1.3, 2.6, -1.9]
    readonly property var pinColors: [ScrapbookTheme.tapeCoral, ScrapbookTheme.tapeTeal, ScrapbookTheme.tag, ScrapbookTheme.tapeMint, ScrapbookTheme.pinPink]
    readonly property var tapeColors: [ScrapbookTheme.tapeTeal, ScrapbookTheme.tapeCoral, ScrapbookTheme.tapeMint, ScrapbookTheme.tag, ScrapbookTheme.tapeTeal]
    readonly property int slot: (root.workspaceId - 1) % 5
    readonly property bool taped: root.workspaceId % 2 === 0

    signal clicked()
    signal dragEntered()
    signal dragExited()

    // A second sheet of paper, tilted, peeking out from behind.
    Rectangle {
        x: 3
        y: 2
        width: root.width
        height: root.height
        radius: 8
        rotation: root.tilts[root.slot]
        color: Theme.dark ? (root.slot % 2 === 0 ? Theme.paper : Qt.lighter(Theme.paper, 1.12)) : (root.slot % 2 === 0 ? "#f1e4c0" : "#e9efd9")
        border.width: 1.5
        border.color: "#664a4536"
    }

    // Drop shadow of the pinned card onto the cork.
    Rectangle {
        x: 5
        y: 6
        width: root.width
        height: root.height
        radius: 10
        color: ScrapbookTheme.noteShadow
        opacity: 0.38
    }

    Rectangle {
        id: card
        width: root.width
        height: root.height
        radius: 10
        color: ScrapbookTheme.page
        border.width: 2
        border.color: ScrapbookTheme.ink
    }

    Text {
        x: 16
        y: 6
        height: root.headerHeight - 6
        verticalAlignment: Text.AlignVCenter
        text: "Workspace " + root.workspaceId
        color: ScrapbookTheme.ink
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
    }

    // The mock screen the tiles are laid out on.
    Rectangle {
        id: screenArea
        x: root.cellPad
        y: root.headerHeight
        width: root.areaWidth
        height: root.areaHeight
        radius: 6
        color: Theme.dark ? (root.dropHover ? Qt.tint(Theme.surface, Qt.rgba(0.5, 0.9, 0.6, 0.28)) : Theme.surface) : (root.dropHover ? "#e4f3d3" : "#ebe4cf")
        border.width: 1.5
        border.color: "#554a4536"
        Behavior on color { ColorAnimation { duration: 100 } }

        // Big faint workspace number, behind the tiles.
        Text {
            anchors.centerIn: parent
            text: root.workspaceId
            color: "#1a4a4536"
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(screenArea.height * 0.6)
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            anchors.centerIn: parent
            visible: root.windowCount === 0
            text: "Empty"
            color: "#884a4536"
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    // ===== what holds it to the board =====
    Item {
        visible: !root.taped
        x: Math.round(root.width / 2) - 10
        y: -9
        width: 20
        height: 20
        z: 5

        Rectangle { // its little shadow on the paper
            x: 3
            y: 4
            width: 18
            height: 18
            radius: 9
            color: "#55000000"
        }
        Rectangle { // the head
            width: 18
            height: 18
            radius: 9
            color: root.pinColors[root.slot]
            border.width: 1.5
            border.color: Qt.darker(root.pinColors[root.slot], 1.55)
        }
        Rectangle { // shine
            x: 4
            y: 3
            width: 6
            height: 5
            radius: 3
            color: "#99ffffff"
        }
    }

    // ...a strip of washi tape on even ones.
    WashiTape {
        visible: root.taped
        x: Math.round(root.width / 2) - width / 2
        y: -13
        width: 76
        height: 24
        z: 5
        rotation: root.tilts[(root.slot + 2) % 5] * 1.6
        color: root.tapeColors[root.slot]
    }

    // Click anywhere on the card to jump to this workspace. Declared
    // before the DropArea and, as a sibling of the shared tile layer
    // (which sits above), it only ever sees clicks a tile didn't take.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        onEntered: root.dragEntered()
        onExited: root.dragExited()
    }
}
