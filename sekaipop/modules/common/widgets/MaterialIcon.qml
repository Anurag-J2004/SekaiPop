import QtQuick
import qs.modules.common

// One Material Symbols Rounded glyph, drawn as text.
//
//   MaterialIcon { name: "wifi_off"; size: 24 }
//
// `name` is the icon's name from fonts.google.com/icons (Rounded style),
// exactly as it appears there — the font turns the word into the picture
// (ligatures), so there are no files to ship or export. It's a vector
// glyph, so it stays crisp at any size and under the Quick Panel's tilt.
//
// Colour is `color` (the mode's ink by default: navy in light mode, pale in dark), so hover / muted /
// on-a-dark-pill looks are just a colour, not a second asset.
//
// The look of every icon in the shell is set in one place, Theme.qml
// (iconFill / iconWeight); `fill` and `weight` here override it for a
// single icon.
//
// Needs the "Material Symbols Rounded" font installed (the same one
// Illogical Impulse uses) and Qt 6.7+ for `font.variableAxes`.
Text {
    id: root

    property string name: ""
    property real size: 24
    property real fill: Theme.iconFill        // 0 outline .. 1 filled
    property real weight: Theme.iconWeight    // 100 .. 700

    // In the Capsule bar the chips are 21 px tall, so its icons are drawn at most
    // 16 px (the layouts follow the width, so nothing needs to know).
    readonly property real drawSize: Theme.capsuleFor(root) ? Math.min(size, 16) : size

    width: drawSize
    height: drawSize
    text: name
    color: Theme.classicFor(root) ? Theme.pInk : Theme.ink
    clip: true

    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    font.family: Theme.iconFont
    font.pixelSize: drawSize
    font.hintingPreference: Font.PreferFullHinting
    font.variableAxes: ({
        "FILL": root.fill,
        "wght": root.weight,
        // The font's own optical-size axis only runs 20..48
        "opsz": Math.max(20, Math.min(48, root.drawSize)),
        "GRAD": 0
    })
}
