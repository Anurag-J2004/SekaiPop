import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../../common/functions/ShelfDragMath.js" as SDM

// The widget being dragged off Edit Desktop's shelf (EditTraySlot.qml, EditMode.dragId):
// its picture under the pointer, as big as it will be on the card, so what you drop is what
// you get. It is its own window because the shelf's window is only the strip along the
// bottom edge and cannot draw above it.
//
// A full-screen Overlay window on the edited monitor, mapped only while a drag is on, that
// takes no input at all (an empty mask): the press that started the drag keeps the pointer.
//
// What it says about where it would land:
//   over the card    upright, full colour, a mint outline: let go and it is put there
//   over the shelf   small and faded: let go and it goes back
//   elsewhere        tilted and faded: let go and nothing happens
PanelWindow {
    id: win

    readonly property var mt: Theme.of(screen)

    screen: Quickshell.screens.find(s => s.name === EditMode.screenName) ?? Quickshell.screens[0]

    readonly property real uiScale: ShellScale.forScreen(win.screen)
    readonly property string id_: EditMode.dragId
    readonly property bool on: win.id_ !== ""

    visible: win.on

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "sekaipop-edit-drag"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {}

    readonly property string url: EditMode.previewUrls[win.id_] ?? ""
    readonly property var size: EditMode.previewSizes[win.id_] ?? ({ w: 0, h: 0 })
    readonly property real cardScale: win.screen
        ? EditMode.cardRect(win.screen.width, win.screen.height, win.uiScale).s : 1
    readonly property var real: SDM.ghostSize(win.size.w, win.size.h, win.uiScale, win.cardScale, 96)

    readonly property string over: EditMode.dragOver

    // The icon for a widget with no picture (the Image tile), from the shelf's own list.
    readonly property string icon: {
        for (const w of EditMode.shelfList) {
            if (w.id === win.id_)
                return w.icon
        }
        return "widgets"
    }

    Item {
        id: ghost
        width: win.real.w
        height: win.real.h
        x: EditMode.dragX - width / 2
        y: EditMode.dragY - height / 2

        scale: win.over === "card" ? 1 : (win.over === "shelf" ? 0.55 : 0.85)
        rotation: win.over === "card" ? 0 : -4
        opacity: win.over === "card" ? 0.95 : 0.55
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
        Behavior on rotation {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }

        // A hard shadow, like everything else on the desktop.
        Rectangle {
            x: 6
            y: 8
            width: parent.width
            height: parent.height
            radius: 14
            color: win.mt.pLineShadow
            opacity: 0.5
        }

        Image {
            anchors.fill: parent
            visible: win.url !== ""
            source: win.url
            smooth: true
            mipmap: true
            cache: false
            fillMode: Image.Stretch
        }

        // No picture: a chip with the widget's icon.
        Rectangle {
            anchors.fill: parent
            visible: win.url === ""
            radius: 16
            color: win.mt.pSurface
            border.width: win.mt.borderWidth
            border.color: win.mt.pLine

            MaterialIcon {
                anchors.centerIn: parent
                name: win.icon
                size: Math.min(parent.width, parent.height) * 0.45
                weight: 600
                color: win.mt.accentMint
            }
        }

        // Where it will land.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            visible: win.over === "card"
            radius: 16
            color: "transparent"
            border.width: 3
            border.color: win.mt.accentMint
        }
    }
}
