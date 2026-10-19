import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The badge that says an accent of the Matugen theme is pinned (matugen.pinA / pinB): a pin,
// then each pinned accent's letter and colour. On the Matugen tile's top-left corner and on
// the Back block of its controls (EditThemeBoard.qml, EditMatugenControls.qml). Hidden while
// nothing is pinned.
Rectangle {
    id: root

    readonly property var pins: [
        { k: "A", c: ThemeService.matugenPinA },
        { k: "B", c: ThemeService.matugenPinB }
    ].filter(p => p.c !== "")

    visible: root.pins.length > 0
    width: row.width + 4 + 6
    height: 24
    radius: 12
    color: Theme.pSurface
    border.width: 2
    border.color: Theme.pLine
    antialiasing: true

    Row {
        id: row
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "push_pin"
            size: 13
            weight: 700
            color: Theme.pInk
        }

        Repeater {
            model: root.pins

            delegate: Row {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.k
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Black
                    font.styleName: Theme.fontStyleBold
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: 6
                    color: modelData.c
                    border.width: 1.5
                    border.color: Theme.pLine
                }
            }
        }
    }
}
