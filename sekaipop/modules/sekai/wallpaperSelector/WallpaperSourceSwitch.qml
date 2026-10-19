import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Where the gallery's pictures come from: My folder | Wallhaven (WallhavenService.qml).
// In the header, beside the "Wallpapers" title; Ctrl+Tab flips it too (WallpaperFace.qml).
//
// The same pill as WallpaperTargetSwitch (outline, hard shadow, a thumb that slides and
// overshoots a little), but each half is as wide as the wider label needs, so nothing
// is cut whatever the font.
//
// Pure UI: it only says picked("folder") / picked("wallhaven").
Item {
    id: root

    property string current: "folder"      // "folder" | "wallhaven"
    signal picked(string id)

    readonly property var choices: [
        { id: "folder", label: "My folder", icon: "folder" },
        { id: "wallhaven", label: "Wallhaven", icon: "travel_explore" }
    ]
    readonly property int currentIndex: root.current === "wallhaven" ? 1 : 0

    // icon 20 + gap 7 + the label, 16 each side
    readonly property real slot: Math.ceil(Math.max(m0.width, m1.width) + 20 + 7 + 32)

    width: 2 * root.slot + 6
    height: 40

    TextMetrics {
        id: m0
        text: root.choices[0].label
        font.family: Theme.fontFamily
        font.styleName: Theme.fontStyleBold
        font.weight: Font.ExtraBold
        font.pixelSize: 14
    }
    TextMetrics {
        id: m1
        text: root.choices[1].label
        font: m0.font
    }

    // hard shadow
    Rectangle {
        x: Theme.shadowOffset - 1
        y: Theme.shadowOffset - 1
        width: root.width
        height: root.height
        radius: height / 2
        color: Theme.lineShadow
        antialiasing: true
    }

    // the pill
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "#ffffff"
        border.width: Theme.borderWidth
        border.color: Theme.line
        antialiasing: true
    }

    // the thumb
    Rectangle {
        y: 3
        height: root.height - 6
        width: root.slot
        x: 3 + root.currentIndex * root.slot
        radius: height / 2
        antialiasing: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.accentCyan }
            GradientStop { position: 1.0; color: Theme.accentMint }
        }

        Behavior on x {
            NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
    }

    Repeater {
        model: root.choices

        delegate: Item {
            id: seg
            required property var modelData
            required property int index
            readonly property bool on: seg.index === root.currentIndex

            x: 3 + seg.index * root.slot
            width: root.slot
            height: root.height

            Row {
                anchors.centerIn: parent
                spacing: 7

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: seg.modelData.icon
                    size: 20
                    weight: 600
                    color: seg.on ? Theme.colBorder : Theme.colSubText
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: seg.modelData.label
                    color: seg.on ? Theme.colBorder : Theme.colSubText
                    font: m0.font
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(seg.modelData.id)
            }
        }
    }
}
