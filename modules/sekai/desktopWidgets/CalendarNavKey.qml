import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// One page key on the calendar card's plate (CalendarCardWidget.qml): the same
// round-cornered chip the weather card's view / refresh keys are, with one icon.
//
//   CalendarNavKey { icon: "chevron_left"; onClicked: ... }
Item {
    id: key

    property string icon: ""
    signal clicked()

    width: 34
    height: 28

    Pill {
        anchors.fill: parent
        shadowDy: 3
        cornerRadius: 11
        ringWidth: 3
        fillColor: Theme.chipFill
        pressed: keyArea.pressed

        MaterialIcon {
            anchors.centerIn: parent
            name: key.icon
            fill: 0
            size: 19
            weight: 700
            color: Theme.chipInk
        }
    }

    MouseArea {
        id: keyArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: key.clicked()
    }
}
