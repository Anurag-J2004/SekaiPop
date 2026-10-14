pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

// The audio tap for the little end4-style visualizers in the bar (the media pill's dots
// / wave, VisualizerService.pillStyle). Same as end4-pC's cava feed: cava with
// scripts/cava/cava-pc.conf (50 bands, 0..1000) and `points` = the last frame.
// It runs only while the pill's visualizer is on and a media player is playing.
// (The desktop widget keeps its own tap, VisualizerWidget.qml, because that one also
// stops in Edit Desktop and can use the note analyzer.)
Singleton {
    id: root

    property var points: []

    readonly property bool anyPlaying: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing)
                return true
        }
        return false
    }

    // (Not in Game Mode: the media pill is not on the bar then, so nothing reads it.)
    readonly property bool wanted: VisualizerService.loaded && VisualizerService.pillStyle !== "none" && root.anyPlaying
        && !GameModeService.enabled

    readonly property string conf: Directories.script("cava/cava-pc.conf")

    Process {
        id: cava
        running: root.wanted
        command: ["nice", "-n", "5", "cava", "-p", root.conf]

        stdout: SplitParser {
            onRead: data => {
                // Visualizer sensitivity (0.5 .. 2.5) scales the bands; 1000 is cava's top.
                // One pass and one array per frame (cava sends up to 60 a second); the old
                // split / map / filter / map built four. Same numbers out.
                const s = VisualizerService.sensitivity
                const parts = data.split(";")
                const out = []
                for (let i = 0; i < parts.length; i++) {
                    const v = parseFloat(parts[i])
                    if (!isNaN(v))
                        out.push(Math.min(1000, v * s))
                }
                root.points = out
            }
        }

        onRunningChanged: {
            if (!cava.running)
                root.points = []
        }
    }
}
