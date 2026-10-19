import QtQuick
import Quickshell
import qs.modules.common

// The small heading over a row of EditPickKeys: the word (STYLE, POSITION...),
// then, paler, the name of what is picked, or of what the pointer is over.
Row {
    id: head

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string title: ""
    property string value: ""

    spacing: 8

    Text {
        text: head.title
        color: mt.pInk
        font.family: mt.fontFamily
        font.pixelSize: 12
        font.weight: Font.ExtraBold
        font.styleName: mt.fontStyleBold
        font.letterSpacing: 1.2
    }

    Text {
        text: head.value
        color: mt.pInkSub
        font.family: mt.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }
}
