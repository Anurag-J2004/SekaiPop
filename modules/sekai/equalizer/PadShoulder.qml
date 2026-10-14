import QtQuick
import "PadMath.js" as PM
import qs.modules.common

// A shoulder key on the top edge (214 x 46 design pixels): pearl plastic, with a
// thick wall, it sinks a little when pressed. Sits BEHIND the shell, so only the
// part above the edge shows.
Item {
    id: key

    property real u: 1
    property real kx: 0.30
    property real ky: 0.34
    property string label: ""
    property real thick: 14
    signal clicked()

    readonly property bool down: area.pressed
    property real sink: key.down ? 4 : 0
    Behavior on sink {
        NumberAnimation { duration: 70 }
    }

    width: 214 * u
    height: 46 * u

    Repeater {
        model: 8
        Rectangle {
            required property int index
            readonly property real hgt: (8 - index) * key.thick / 8
            x: hgt * key.kx * key.u
            y: hgt * key.ky * key.u + key.sink * key.u
            width: key.width
            height: key.height
            radius: height / 2
            color: PM.mix(Qt.color("#b3bcd8"), Qt.color("#6c779c"), 1 - hgt / key.thick)
        }
    }

    Rectangle {
        id: face
        y: key.sink * key.u
        width: key.width
        height: key.height
        radius: height / 2
        border.width: Math.max(1, key.u)
        border.color: Qt.rgba(0.16, 0.2, 0.35, 0.3)
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#ffffff" }
            GradientStop { position: 0.55; color: "#e6ebf8" }
            GradientStop { position: 1.0; color: "#c7d0e8" }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 2 * key.u
            width: parent.width - 2 * parent.radius * 0.55
            height: 2 * key.u
            radius: height / 2
            color: "#ffffff"
            opacity: 0.9
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8 * key.u
            text: key.label
            color: "#2b3560"
            font.family: Theme.fontFamily
            font.pixelSize: 10 * key.u
            font.weight: Font.Bold
            font.letterSpacing: 1.4 * key.u
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "#ffffff"
            opacity: area.containsMouse && !key.down ? 0.2 : 0
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: key.clicked()
    }
}
