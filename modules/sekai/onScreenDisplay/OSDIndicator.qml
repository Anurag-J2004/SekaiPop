import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// The content of the OSD (on-screen-display) popup: one pill showing
// whichever of volume / mic / brightness just changed, with an icon, a
// label, the percentage, and a progress track underneath — the same
// track look VolumeSlider.qml already uses in the Quick Panel, just in
// a small standalone card instead of a draggable control (this one
// isn't interactive; drag the real sliders in the Quick Panel for that).
//
//   [ (icon)  Volume            72% ]
//   [ ============------------------ ]
//
// Pure UI: OSDPopup.qml (the window) feeds this `kind`/`value`/`muted`
// and never touches OSDSource.qml itself.
Pill {
    id: root

    property string kind: "volume"   // "volume" | "mic" | "brightness" | "gamma"
    property real value: 0           // 0-100
    property bool muted: false

    readonly property string iconName: {
        if (kind === "brightness")
            return "brightness_6"
        if (kind === "gamma")
            return "contrast"
        if (kind === "mic")
            return muted ? "mic_off" : "mic"
        if (muted)
            return "volume_off"
        return value < 34 ? "volume_down" : "volume_up"
    }

    readonly property string labelText: {
        if (kind === "brightness") return "Brightness"
        if (kind === "gamma") return "Gamma"
        if (kind === "mic") return "Microphone"
        return "Volume"
    }

    // Brightness and gamma have no mute state to show — "muted" only
    // ever applies to volume/mic.
    readonly property bool showsMuted: root.muted && root.kind !== "brightness" && root.kind !== "gamma"

    width: 280
    cornerRadius: 22
    ringWidth: 6
    fillColor: Theme.surface
    borderWidth: Theme.borderWidth
    shadowDx: 4
    shadowDy: 4
    implicitHeight: 86

    Item {
        x: root.ringWidth
        y: root.ringWidth
        width: root.capWidth - root.ringWidth * 2
        height: root.capHeight - root.ringWidth * 2

        Row {
            id: headerRow
            y: 12
            x: 4
            width: parent.width - 8
            spacing: 10

            Rectangle {
                width: 36
                height: 36
                radius: 18
                anchors.verticalCenter: parent.verticalCenter
                color: root.showsMuted ? Theme.surfaceDivider : Theme.accentMint
                border.width: Theme.borderWidth
                border.color: Theme.line
                antialiasing: true

                MaterialIcon {
                    color: root.showsMuted ? Theme.ink : Theme.colBorder
                    anchors.centerIn: parent
                    size: 20
                    name: root.iconName
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - 10 - pctLabel.width - 10
                elide: Text.ElideRight
                text: root.labelText
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Text {
                id: pctLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.showsMuted ? "MUTE" : Math.round(root.value) + "%"
                color: Theme.inkSub
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }

        Rectangle {
            id: track
            x: 4
            y: headerRow.y + headerRow.height + 12
            width: parent.width - 8
            height: 12
            radius: 6
            color: Theme.surfaceDivider
            antialiasing: true

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.value / 100))
                height: parent.height
                radius: 6
                antialiasing: true
                opacity: root.showsMuted ? 0.5 : 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.showsMuted ? Theme.inkSub : Theme.accentMint }
                    GradientStop { position: 1.0; color: root.showsMuted ? Theme.inkSub : Theme.accentCyan }
                }
                Behavior on width {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
