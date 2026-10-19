import QtQuick
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.phone

// A big key for the Wallpapers viewer: "Set as Desktop" and "Set as Lockscreen".
// A SekaiKey with an icon and a label that lights up under the mouse, presses
// into its shadow, and flashes "Applied" (`done`) for a moment after it was used.
//
// For a Wallhaven picture (WallhavenService) it also shows a download: `progress` 0..1
// fills the key with the accent gradient from the left (-1 = none), and `available: false`
// greys it out (the other key, while one is downloading). The label shrinks to fit the key
// rather than run past it ("Downloading \u00b7 1.3 of 2.8 MB" is long).
//
// Pure UI: whoever places it turns clicked(all) into an action.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string doneLabel: "Applied"
    // Shows the check and `doneLabel` (the viewer sets it for a moment).
    property bool done: false
    property real capW: 422
    property real capH: 76
    property real progress: -1
    property bool available: true

    // `all`: Shift was held (every monitor, with One wallpaper per monitor on).
    signal clicked(bool all)

    implicitWidth: capW + 8
    implicitHeight: capH + 6
    opacity: root.available ? 1 : 0.5

    SekaiKey {
        id: key

        capW: root.capW
        capH: root.capH
        radius: 26
        lit: root.done || (area.containsMouse && root.available)
        hovered: area.containsMouse
        pressed: area.pressed
        ringExtra: 6

        readonly property color ink: Qt.tint(Theme.pInk, Qt.rgba(Theme.colBorder.r, Theme.colBorder.g, Theme.colBorder.b, litP))

        // the download, filling the key from the left
        ClippingRectangle {
            visible: root.progress >= 0
            anchors.fill: parent
            anchors.margins: 6
            radius: 20
            color: "transparent"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.progress))
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.accentCyan }
                    GradientStop { position: 1.0; color: Theme.accentMint }
                }
                Behavior on width { NumberAnimation { duration: 250 } }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 14

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: 32
                name: root.done ? "check" : root.icon
                color: key.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // never wider than the key leaves: it shrinks instead
                width: Math.min(implicitWidth, root.capW - 48 - 32 - 14)
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 14
                text: root.done ? root.doneLabel : root.label
                color: key.ink
                font.family: Theme.fontFamily
                font.pixelSize: 25
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked((mouse.modifiers & Qt.ShiftModifier) !== 0)
    }
}
