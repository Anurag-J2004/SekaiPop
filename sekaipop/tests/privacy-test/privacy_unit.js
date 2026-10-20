// The privacy badge's sorting of PipeWire streams (services/PrivacyService.qml): the
// functions are cut out of the .qml and run against nodes shaped like real ones (taken from
// pw-dump), and the wiring is checked as text (Quickshell can't run here).
// Run: node privacy_unit.js
// (PipeWire gives booleans, as pw-dump shows; prop() reads them as "true".)
const fs = require("fs"), assert = require("assert")
const read = f => fs.readFileSync(require("../lib/locate")(f), "utf8")
const src = read("services/PrivacyService.qml")
function grab(name) {
    const start = src.indexOf("    function " + name + "(")
    assert(start >= 0, "no function " + name)
    return src.slice(start, src.indexOf("\n    }\n", start) + 7).replace(/^    function /, "function ")
}

const node = (id, props) => ({ id, properties: props })
const headsetOut = node(65, { "media.class": "Audio/Sink", "node.name": "alsa_output.usb-HS80.analog-stereo" })
const headsetMic = node(66, { "media.class": "Audio/Source", "node.name": "alsa_input.usb-HS80.mono-fallback" })
// A VNC / screen-recorder feed: recording the headset's output (what is playing).
const vncAudio = node(111, { "media.class": "Stream/Input/Audio", "application.name": "Lavf63.1.101",
    "application.process.binary": "ffmpeg", "media.name": "record", "stream.capture.sink": true,
    "target.object": "alsa_output.usb-HS80.analog-stereo" })
// The same without PipeWire's mark: its target still says it is an output.
const unmarked = node(112, { "media.class": "Stream/Input/Audio", "application.name": "obs",
    "target.object": "alsa_output.usb-HS80.analog-stereo" })
// A real microphone stream.
const discordMic = node(120, { "media.class": "Stream/Input/Audio", "application.name": "WEBRTC VoiceEngine",
    "target.object": "alsa_input.usb-HS80.mono-fallback" })
// A filter chain's own capture (passive): neither.
const boost = node(36, { "media.class": "Stream/Input/Audio", "media.name": "HS80 Boosted Mic", "node.passive": true,
    "target.object": "alsa_input.usb-HS80.mono-fallback" })

const root = { nodes: [headsetOut, headsetMic, vncAudio, unmarked, discordMic, boost] }
for (const n of ["prop", "mediaClass", "appName", "isMeter", "isDesktopCapture", "isMicStream", "isAudioCapture"])
    root[n] = new Function("root", "return (" + grab(n) + ")")(root)

assert.ok(root.isAudioCapture(vncAudio) && !root.isMicStream(vncAudio), "recording what plays is desktop audio, not the mic")
assert.ok(root.isAudioCapture(unmarked) && !root.isMicStream(unmarked), "...also when only its target says so")
assert.ok(root.isMicStream(discordMic) && !root.isAudioCapture(discordMic), "a real microphone stays the microphone")
assert.ok(!root.isMicStream(boost) && !root.isAudioCapture(boost), "a passive filter capture is neither")
assert.ok(root.isMeter(boost) === true)

// The wiring: a list of its own, not hidden by the mic's mute, through the bar to the badge.
assert.ok(/readonly property var audioApps:/.test(src) && !/audioApps[\s\S]{0,400}micMuted/.test(src.slice(src.indexOf("readonly property var audioApps:"), src.indexOf("readonly property var audioApps:") + 400)),
    "desktop audio is listed on its own, and a muted mic doesn't hide it")
assert.ok(/readonly property bool active: micLive \|\| audioLive \|\| screenLive/.test(src))
const bar = read("modules/sekai/bar/Bar.qml")
assert.ok(/privacyAudio: PrivacyService\.audioLive/.test(bar) && /Desktop audio recorded by: /.test(bar), "the bar passes it and says so on hover")
assert.ok(/audioLive: status_Bar\.privacyAudio/.test(read("modules/sekai/bar/Status_Bar.qml")))
const pill = read("modules/sekai/bar/PrivacyIndicator.qml")
assert.ok(/readonly property bool live: micLive \|\| audioLive \|\| screenLive/.test(pill) && (pill.match(/visible: root\.audioShown/g) || []).length === 2,
    "the pill has the desktop-audio icon, on a flat and on a standing bar")
console.log("privacy_unit: all checks passed")
