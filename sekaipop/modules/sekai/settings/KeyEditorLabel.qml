import QtQuick
import Quickshell
import qs.modules.common

// The small upper-case label at the start of each "Set it by hand" line (Hold,
// Key, Gives), 96 wide so the controls after it line up.
Text {

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)
    width: 96
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: mt.pInkSub
    font.family: mt.fontFamily
    font.pixelSize: 14
    font.weight: Font.Black
    font.letterSpacing: 1.4
    font.capitalization: Font.AllUppercase
}
