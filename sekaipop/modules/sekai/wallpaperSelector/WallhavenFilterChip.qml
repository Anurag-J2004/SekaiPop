import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The Filters key in the gallery's toolbar while it is on Wallhaven: the same pill as the
// Sort chip (SortChip.qml), with how many filters are changed from the defaults in a round
// badge (lit when there are any). Lit itself while the Filters card is open. Its width comes
// from its words, so nothing is cut. Only says "clicked"; the gallery owns the card.
Item {
    id: root

    property int count: 0
    property bool active: false

    signal clicked()

    readonly property bool hot: area.containsMouse
    readonly property real press: area.pressed ? 2 : 0

    width: 13 + 22 + 8 + Math.ceil(label.implicitWidth) + 8 + 24 + 10
    height: 40

    // hard shadow
    Rectangle {
        x: Theme.shadowOffset - 1 - root.press
        y: Theme.shadowOffset - 1 - root.press
        width: root.width
        height: root.height
        radius: height / 2
        color: Theme.lineShadow
        antialiasing: true
    }

    Rectangle {
        x: root.press
        y: root.press
        width: root.width
        height: root.height
        radius: height / 2
        color: root.hot && !root.active ? Theme.colHoverTint : "#ffffff"
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true

        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: height / 2
            visible: root.active
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentCyan }
                GradientStop { position: 1.0; color: Theme.accentMint }
            }
        }

        MaterialIcon {
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            name: "tune"
            size: 22
            weight: 550
            color: Theme.colBorder
        }

        Text {
            id: label
            x: 13 + 22 + 8
            anchors.verticalCenter: parent.verticalCenter
            text: "Filters"
            color: Theme.colBorder
            font.family: Theme.fontFamily
            font.styleName: Theme.fontStyleBold
            font.weight: Font.ExtraBold
            font.pixelSize: 14
        }

        // how many are changed
        Rectangle {
            x: label.x + label.implicitWidth + 8
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: 12
            color: root.count > 0 ? Theme.accentMint : Theme.pSurfaceHover
            border.width: 2
            border.color: Theme.colBorder

            Text {
                anchors.centerIn: parent
                text: String(root.count)
                color: Theme.colBorder
                font.family: Theme.fontFamily
                font.styleName: Theme.fontStyleBold
                font.weight: Font.Black
                font.pixelSize: 12
            }
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
