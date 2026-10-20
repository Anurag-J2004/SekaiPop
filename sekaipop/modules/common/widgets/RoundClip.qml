import QtQuick
import QtQuick.Effects

// A box with its own corner radii that clips what is put in it to that shape. (An Item can
// only clip square: `clip` on a rounded Rectangle still lets a picture's corners out.) The
// content is drawn into a layer and masked as that layer's effect, the way the user card's
// MaskedPhoto does it.
//
//   RoundClip {
//       width: 192; height: 77
//       radii: [24, 24, 16, 16]          // top-left, top-right, bottom-left, bottom-right
//       FramedImage { anchors.fill: parent; source: ...; framing: ... }
//   }
Item {
    id: rc

    property var radii: [0, 0, 0, 0]
    default property alias content: inner.data

    Item {
        id: inner
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: rcMask
        }
    }

    Item {
        id: rcMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            color: "black"
            topLeftRadius: rc.radii[0]
            topRightRadius: rc.radii[1]
            bottomLeftRadius: rc.radii[2]
            bottomRightRadius: rc.radii[3]
            antialiasing: true
        }
    }
}
