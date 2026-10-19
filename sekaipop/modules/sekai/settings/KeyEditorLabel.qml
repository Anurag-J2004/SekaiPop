import QtQuick
import qs.modules.common

// The small upper-case label at the start of each "Set it by hand" line (Hold,
// Key, Gives), 96 wide so the controls after it line up.
Text {
    width: 96
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    color: Theme.pInkSub
    font.family: Theme.fontFamily
    font.pixelSize: 14
    font.weight: Font.Black
    font.letterSpacing: 1.4
    font.capitalization: Font.AllUppercase
}
