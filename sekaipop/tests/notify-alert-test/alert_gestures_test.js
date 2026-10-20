// The phone that rises for a notification (QuickPanel.qml, alert mode): what each gesture on
// it does. The handlers are checked as text and the two actions run against a fake source
// (Quickshell can't run here). Run: node alert_gestures_test.js
const fs = require("fs"), assert = require("assert")
const read = f => fs.readFileSync(require("../lib/locate")(f), "utf8")
const src = read("modules/sekai/quickPanel/QuickPanel.qml")

const start = src.indexOf("id: alertTouch")
assert.ok(start > 0, "the alert phone's touch layer")
const layer = src.slice(src.lastIndexOf("Item {", start), src.indexOf("// The Settings phone", start))

// Only while the phone is up for an alert, and never in the way of a normal open one.
assert.ok(/enabled: root\.alertUp && !root\.open/.test(layer))
// A click claims on the release, without taking the press from the button under it.
assert.ok(/acceptedButtons: Qt\.LeftButton\s+gesturePolicy: TapHandler\.DragThreshold\s+onTapped: root\.claim\(\)/.test(layer), "left click: claim on tap")
assert.ok(!/onPressed:[\s\S]{0,80}root\.claim\(\)/.test(src), "nothing claims on the press any more (a swipe could never start)")
// Middle hides, right removes: the corner popup cards' buttons.
assert.ok(/acceptedButtons: Qt\.MiddleButton[\s\S]{0,120}onTapped: alertTouch\.putAway\(\)/.test(layer), "middle click: put away")
assert.ok(/acceptedButtons: Qt\.RightButton[\s\S]{0,120}onTapped: alertTouch\.removeIt\(\)/.test(layer), "right click: remove")
// A swipe down past the line puts it away; sideways does nothing.
assert.ok(/DragHandler \{[\s\S]*?target: null[\s\S]*?xAxis\.enabled: false[\s\S]*?lastY > alertTouch\.swipeAway[\s\S]*?alertTouch\.putAway\(\)/.test(layer), "swipe down")

// The two actions, against a fake notification source.
const grab = name => {
    const i = layer.indexOf("function " + name + "(")
    const body = layer.slice(i, layer.indexOf("\n                    }\n", i) + 22)
    return body
}
const calls = []
const root = { notificationSource: {
    toast: { key: "n1-1" },
    hideToast: () => calls.push("hide"),
    dismiss: k => calls.push("dismiss " + k)
} }
const putAway = new Function("root", "return (" + grab("putAway") + ")")(root)
const removeIt = new Function("root", "return (" + grab("removeIt") + ")")(root)
putAway()
assert.deepStrictEqual(calls, ["hide"], "put away: the card goes, the notification stays in the list")
calls.length = 0
removeIt()
assert.deepStrictEqual(calls, ["dismiss n1-1", "hide"], "remove: that notification is removed, and the card goes")
calls.length = 0
root.notificationSource.toast = null
removeIt()
assert.deepStrictEqual(calls, ["hide"], "no card to remove: just put away")
// Hovering the card opens the phone, but slowly enough to aim at it, and never mid-swipe.
const face = read("modules/sekai/quickPanel/QuickPanelFace.qml")
const hover = face.slice(face.indexOf("id: hoverOpen"), face.indexOf("id: hoverOpen") + 80)
assert.ok(/interval: (\d+)/.test(hover) && Number(hover.match(/interval: (\d+)/)[1]) >= 800, "the card's hover-to-open waits long enough to right-click or swipe it")
assert.ok(/onAlertActivated: \{[\s\S]{0,400}if \(alertTouch\.busy\)\s+return/.test(src), "no hover-open in the middle of a press or a swipe")
assert.ok(/readonly property bool busy: leftTap\.pressed \|\| middleTap\.pressed \|\| rightTap\.pressed \|\| alertSwipe\.active/.test(layer))
console.log("alert_gestures_test: all checks passed")
