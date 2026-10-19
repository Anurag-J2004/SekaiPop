import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// The sort control in the wallpaper board's header: a pill with a sort
// icon, the current order's short name ("Newest", "A–Z", ...) and a
// chevron that flips while the menu (GallerySortCard) is open. It only
// says "clicked"; the gallery owns the menu.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string label: ""
    property bool active: false

    signal clicked()

    // 152 at least (the folder's orders all fit in that), wider when the label needs it
    // (Wallhaven's "Top \u00b7 6 months"): the label is never cut.
    width: Math.max(152, Math.ceil(labelMetrics.advanceWidth) + 44 + 36 + 4)
    height: 40

    TextMetrics {
        id: labelMetrics
        text: root.label
        font.family: mt.fontFamily
        font.styleName: mt.fontStyleBold
        font.weight: Font.ExtraBold
        font.pixelSize: 14
    }

    readonly property bool hot: area.containsMouse
    readonly property real press: area.pressed ? 2 : 0

    // hard shadow
    Rectangle {
        x: mt.shadowOffset - 1 - root.press
        y: mt.shadowOffset - 1 - root.press
        width: root.width
        height: root.height
        radius: height / 2
        color: mt.lineShadow
        antialiasing: true
    }

    Rectangle {
        x: root.press
        y: root.press
        width: root.width
        height: root.height
        radius: height / 2
        color: root.hot && !root.active ? mt.colHoverTint : "#ffffff"
        border.width: mt.borderWidth
        border.color: mt.line
        antialiasing: true

        Behavior on color { ColorAnimation { duration: 100 } }

        // "open" fill
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: height / 2
            visible: root.active
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: mt.accentCyan }
                GradientStop { position: 1.0; color: mt.accentMint }
            }
        }

        MaterialIcon {
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            name: "sort"
            size: 22
            weight: 550
            color: mt.colBorder
        }

        Text {
            x: 44
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 44 - 36
            elide: Text.ElideRight
            text: root.label
            color: mt.colBorder
            font.family: mt.fontFamily
            font.styleName: mt.fontStyleBold
            font.weight: Font.ExtraBold
            font.pixelSize: 14
        }

        MaterialIcon {
            x: parent.width - width - 10
            anchors.verticalCenter: parent.verticalCenter
            name: "expand_more"
            size: 22
            weight: 600
            color: mt.colBorder
            rotation: root.active ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
