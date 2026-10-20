import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// One setting of an open plugin on the Plugins card (PluginEditor.qml): its name on the left
// (and the raw key under it when the manifest gave no label, or its description), the control
// in the middle, and a reset button on the right when it differs from its default. A changed
// setting also wears the accent diamond and says what a reset gives back.
//
// `row` is a PluginForm.row() entry; the control is the shell's own for its kind (text,
// multiline, choice, slider, stepper, toggle). Pure UI: changes come out as edited(value),
// already of the setting's type.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property var row: null

    signal edited(var value)
    signal resetRequested()

    // The design's grid: 300px | the control | 44px, 20px apart.
    readonly property real labelW: 300
    readonly property real resetW: 44
    readonly property real gap: 20
    readonly property real controlW: Math.max(0, width - labelW - resetW - gap * 2)
    readonly property real controlH: control.item ? control.item.height : 0

    implicitHeight: Math.max(74, Math.max(names.implicitHeight, controlH) + 12)

    Column {
        id: names
        width: root.labelW
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Row {
            spacing: 9

            Rectangle {
                visible: root.row !== null && root.row.changed
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                rotation: 45
                radius: 3
                border.width: 2
                border.color: mt.pLine
                antialiasing: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: mt.accentCyan }
                    GradientStop { position: 1; color: mt.accentMint }
                }
            }

            Text {
                width: root.labelW - (root.row && root.row.changed ? 21 : 0)
                text: root.row ? root.row.label : ""
                elide: Text.ElideRight
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 17
                font.weight: Font.Black
            }
        }

        // No label in the manifest: the key it is saved under, as code.
        Text {
            visible: root.row !== null && !root.row.hasLabel
            width: parent.width
            text: root.row ? root.row.key : ""
            elide: Text.ElideRight
            color: mt.pInkSub
            font.family: "monospace"
            font.pixelSize: 13
        }

        Text {
            visible: root.row !== null && root.row.description !== ""
            width: parent.width
            text: root.row ? root.row.description : ""
            wrapMode: Text.WordWrap
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
        }

        Text {
            visible: root.row !== null && root.row.changed
            width: parent.width
            text: root.row ? root.row.defText : ""
            elide: Text.ElideRight
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 13
            font.weight: Font.ExtraBold
        }
    }

    Loader {
        id: control
        x: root.labelW + root.gap
        // No width of its own: a Loader with one would stretch every control to it, and the
        // design caps the field at 520 and the slider at 600.
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: !root.row ? null
            : root.row.kind === "toggle" ? toggleC
            : root.row.kind === "stepper" ? stepperC
            : root.row.kind === "slider" ? sliderC
            : root.row.kind === "choice" ? choiceC
            : root.row.kind === "multiline" ? multilineC
            : textC
    }

    KeyRoundButton {
        visible: root.row !== null && root.row.changed
        x: root.width - width
        anchors.verticalCenter: parent.verticalCenter
        icon: "restart_alt"
        tip: root.row ? "Back to the default" : ""
        onClicked: root.resetRequested()
    }

    Component {
        id: textC

        SettingText {
            width: Math.min(root.controlW, 520)
            labelWidth: 0
            clearable: false
            value: root.row ? String(root.row.value) : ""
            onSubmitted: text => root.edited(text)
        }
    }

    Component {
        id: multilineC

        Pill {
            width: Math.min(root.controlW, 520)
            height: 116 + mt.shadowOffset
            cornerRadius: 16
            ringWidth: 4
            fillColor: mt.pSurface

            MouseArea {
                anchors.fill: parent
                onPressed: edit.forceActiveFocus()
            }

            TextEdit {
                id: edit
                anchors.fill: parent
                anchors.margins: 14
                anchors.bottomMargin: 14 + mt.shadowOffset
                clip: true
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                text: root.row ? String(root.row.value) : ""
                color: mt.pInk
                selectionColor: mt.accentCyan
                selectedTextColor: mt.colBorder
                font.family: mt.fontFamily
                font.pixelSize: 16
                font.weight: Font.DemiBold
                Keys.onEscapePressed: {
                    edit.text = root.row ? String(root.row.value) : ""
                    edit.focus = false
                }
                onActiveFocusChanged: {
                    if (!activeFocus && root.row && edit.text !== String(root.row.value))
                        root.edited(edit.text)
                }
            }
        }
    }

    Component {
        id: choiceC

        SettingChoice {
            width: root.controlW
            labelWidth: 0
            options: root.row ? root.row.choices.map(c => ({ id: c.value, label: c.label })) : []
            current: root.row ? String(root.row.value) : ""
            onPicked: id => root.edited(id)
        }
    }

    Component {
        id: sliderC

        SettingSlider {
            width: Math.min(root.controlW, 600)
            from: root.row ? root.row.min : 0
            to: root.row ? root.row.max : 1
            step: root.row ? root.row.step : 1
            decimals: root.row ? root.row.decimals : 0
            suffix: root.row && root.row.unit !== "" ? " " + root.row.unit : ""
            value: root.row ? root.row.value : 0
            onMoved: v => root.edited(v)
        }
    }

    Component {
        id: stepperC

        SettingStepper {
            tileWidth: 230
            from: -1e9
            to: 1e9
            step: root.row ? root.row.step : 1
            decimals: root.row ? root.row.decimals : 0
            suffix: root.row && root.row.unit !== "" ? " " + root.row.unit : ""
            value: root.row ? root.row.value : 0
            label: valueText
            subtitle: ""
            onMoved: v => root.edited(v)
        }
    }

    Component {
        id: toggleC

        SettingToggle {
            tileWidth: 150
            icon: checked ? "check" : "close"
            // ON / OFF as the tile's name: under an empty name it sits low
            label: checked ? "ON" : "OFF"
            subtitle: ""
            checked: root.row ? root.row.value === true : false
            onToggled: root.edited(!checked)
        }
    }
}
