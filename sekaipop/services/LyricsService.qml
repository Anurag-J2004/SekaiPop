pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "../modules/common/functions/LyricsMath.js" as LM

// The desktop lyrics widget's state (where it sits, whether it is shown, the sync nudge)
// and the lyrics of the track that is playing. LyricsWidget.qml is the only thing that
// draws them; it tells this singleton which track is on (request()) and reads `lines`.
//
//   import qs.services
//   ...
//   LyricsService.nudge(250)
//
// Where the lyrics come from, in order, stopping at the first that has them:
//   1. the cache (~/.cache/pjsekai/lyrics, what an earlier play found);
//   2. a .lrc file beside the music file (same name, ".lrc"), for tracks that are files;
//   3. LRCLIB (https://lrclib.net, a free, open lyrics database), asked with `curl` like every
//      other network call of the shell (so curl and a network connection are needed): the
//      exact lookup first, then a search by title and artist, then a free-text search, for
//      the track as the player names it and then with the title cleaned up. The artist, the
//      title, the album and the length of the track are sent to it, and nothing else. Only
//      the synced ("[mm:ss.xx] words") lyrics are used. `ipc lyrics refresh` asks again.
// What is found is kept in the cache, so a track is asked for once. A track with no lyrics
// is not asked for again for ten minutes.
//
// Persistence of the widget's place is the same convention as ClockService: a tiny script
// (lyrics-state.sh) run as a Process. Position is saved straight away, the rest is
// debounced.
Singleton {
    id: root

    // ipc lyrics debug: the lyrics tag shows the clock's numbers (not saved).
    property bool debug: false

    // False until the saved state has been read. Nothing is written before then, or a fresh
    // start would overwrite what is on disk with defaults.
    property bool loaded: false

    property bool shown: false       // off until you add it: ipc lyrics toggle / Edit Desktop
    property real posX: -1           // -1 = never placed; the widget picks a spot
    property real posY: -1
    // The shell scale posX / posY were saved at (see ClockService.posScale).
    property real posScale: 0
    // The monitor the widget was last dropped on (see ClockService.screenName).
    property string screenName: ""
    // Lyrics shown this many milliseconds early (+) or late (-) against the player's clock,
    // for a player (or a speaker) that is always a little off. ipc: lyrics nudgeAll <ms>.
    property int syncMs: 0
    // Ask a karaoke source (NetEase) for when each WORD is sung, once the lines are found.
    // Without it the words of a line are spread by their syllables. ipc lyrics words on|off
    property bool wordsOn: true
    // "auto" (the best provider for each song) or one provider's id to use whenever it has the song.
    property string preferred: "auto"
    // The same, for single tracks: a lyrics file is made for one cut of a song, so one track
    // can be off by a different amount than the next. { trackId: ms }, set with the keys that
    // show when you point at the lyrics (or ipc: lyrics nudge <ms>), remembered.
    property var offsets: ({})
    readonly property int trackOffsetMs: (root.trackId !== "" && root.offsets[root.trackId]) ? root.offsets[root.trackId] : 0
    // What the widget applies: the player-wide nudge plus this track's.
    readonly property int syncTotal: root.syncMs + root.trackOffsetMs
    // How much longer (+) or shorter (-) the cut the lyrics were made for is than the track
    // that is playing, in seconds; 0 when either length is not known.
    property real versionDiff: 0

    // ===== the lyrics of the track that is on =====
    // idle (nothing asked) | loading | ready | none (nobody has them) | instrumental | offline
    property string status: "idle"
    // [{ t, text }], sorted; a line with no words is a gap in the singing.
    property var lines: []
    // cache | file | lrclib, for the little tag under the lyrics
    property string source: ""
    property string trackId: ""

    property int serial: 0
    property var misses: ({})

    readonly property string cacheScript: Directories.script("state/lyrics-cache.sh")
    readonly property string base: "https://lrclib.net/api"
    readonly property string wordBase: "https://music.163.com/api"
    readonly property var wordHeaders: ["-H", "Referer: https://music.163.com/", "-H", "User-Agent: Mozilla/5.0"]

    // The widget calls this every time the track may have changed; asking for the same
    // track again does nothing.
    function request(artist, title, album, length, url, force) {
        const a = String(artist || "")
        const t = String(title || "")
        if (t === "") {
            root.clear()
            return
        }
        const len = Number(length) > 0 ? Number(length) : 0
        const id = LM.trackKey(a, t, len)
        if (force !== true && id === root.trackId && root.status !== "idle")
            return
        root.lastArgs = [a, t, album, length, url]
        root.serial += 1
        root.trackId = id
        root.lines = []
        root.versionDiff = 0
        root.source = ""
        root.sourceKind = ""
        root.sourceStates = ({})
        const ctx = {
            serial: root.serial,
            id: id,
            hash: Qt.md5(id),
            artist: a,
            title: t,
            album: String(album || ""),
            length: len,
            url: String(url || ""),
            cands: LM.candidates(a, t),
            answered: false
        }
        const missed = root.misses[id]
        if (force !== true && missed !== undefined && Date.now() - missed < 600000) {
            root.status = "none"
            return
        }
        root.status = "loading"
        // `force` (ipc lyrics refresh) skips what an earlier play kept.
        if (force === true)
            root.fromCache(ctx, "")
        else
            root.runScript(["get", ctx.hash], text => root.fromCache(ctx, text))
    }

    // Look for this track's lyrics again, ignoring the cache and the ten-minute "nobody has
    // them" (ipc lyrics refresh): after a wrong match, or once the network is back.
    property var lastArgs: null

    function refresh() {
        if (!root.lastArgs)
            return
        root.misses = ({})
        const a = root.lastArgs
        root.request(a[0], a[1], a[2], a[3], a[4], true)
    }

    function clear() {
        root.serial += 1
        root.trackId = ""
        root.lines = []
        root.source = ""
        root.sourceKind = ""
        root.sourceStates = ({})
        root.status = "idle"
    }

    // Show THIS track's lyrics `ms` earlier (negative: later). With no track on, the
    // player-wide nudge is changed instead.
    function nudge(ms) {
        const n = Math.round(Number(ms))
        if (!isFinite(n))
            return
        if (root.trackId === "") {
            root.setSync(root.syncMs + n)
            return
        }
        root.setTrackOffset(root.trackOffsetMs + n)
    }

    // The player-wide nudge: every track, for a player or a speaker that is always a little
    // early or late (ipc: lyrics nudgeAll <ms>).
    function nudgeAll(ms) {
        const n = Math.round(Number(ms))
        if (isFinite(n))
            root.setSync(root.syncMs + n)
    }

    function setTrackOffset(ms) {
        if (root.trackId === "")
            return
        const v = Math.max(-10000, Math.min(10000, Math.round(Number(ms) || 0)))
        const o = Object.assign({}, root.offsets)
        if (v === 0) {
            delete o[root.trackId]
        } else {
            o[root.trackId] = v
            // A bounded list: the oldest go first.
            const keys = Object.keys(o)
            for (let i = 0; i < keys.length - 400; i++)
                delete o[keys[i]]
        }
        root.offsets = o
        root.persist()
    }

    // `id`: a provider's, or "auto". Looks for the song again so it shows at once.
    function setPreferred(id) {
        const v = String(id)
        if (v !== "auto" && root.providerIds.indexOf(v) < 0)
            return false
        root.preferred = v
        root.persist()
        root.refresh()
        return true
    }

    function setWords(on) {
        root.wordsOn = on === true
        root.persist()
        if (root.wordsOn)
            root.refresh()
    }
    function setSync(ms) {
        root.syncMs = Math.max(-5000, Math.min(5000, Math.round(Number(ms) || 0)))
        root.persist()
    }

    // ----- where lyrics come from -----
    // Every provider is asked at once (one `curl` after another inside each). The first usable
    // answer is shown at once; when the rest are in (or a word-timed one and a synced one are,
    // or eight seconds after the first) the best is chosen (LM.chooseLyrics): word by word over
    // synced, then the one cut to the track's length, then the one liked best (this order).
    // What was chosen is cached with the provider's name, so later plays do not ask at all.
    readonly property var providers: [
        { id: "lyricsplus", name: "LyricsPlus" },
        { id: "netease", name: "NetEase Cloud Music" },
        { id: "lrclib", name: "LRCLIB" },
        { id: "qq", name: "QQ Music" },
        { id: "kugou", name: "Kugou" }
    ]
    readonly property var providerIds: root.providers.map(p => p.id)

    // Where each stands for the track on now: "loading", "word", "synced", "none", "offline".
    property var sourceStates: ({})

    // "word" or "synced": how the lyrics on screen are timed (known also when they came from
    // the cache, where no provider was asked).
    property string sourceKind: ""

    // ----- the source picker (LyricsSources.qml) -----
    property bool pickerOpen: false
    property string pickerScreen: ""
    property real pickerX: -1       // where to open it, in the widget's design pixels (-1: the screen's middle)
    property real pickerY: -1

    function providerName(id) {
        const p = root.providers.find(x => x.id === id)
        return p ? p.name : String(id)
    }

    function openPicker(screenName, x, y) {
        root.pickerScreen = screenName !== "" ? screenName : root.screenName
        root.pickerX = x === undefined ? -1 : x
        root.pickerY = y === undefined ? -1 : y
        root.pickerOpen = true
    }

    function closePicker() {
        root.pickerOpen = false
    }

    function togglePicker(screenName, x, y) {
        if (root.pickerOpen)
            root.closePicker()
        else
            root.openPicker(screenName, x, y)
    }

    function fromCache(ctx, text) {
        if (ctx.serial !== root.serial)
            return
        const got = root.parseStored(text)
        if (got !== null && root.apply(ctx, got, "cache"))
            return
        if (ctx.url.indexOf("file://") === 0) {
            root.runScript(["local", ctx.url], t => root.fromFile(ctx, t))
            return
        }
        root.gather(ctx)
    }

    function fromFile(ctx, text) {
        if (ctx.serial !== root.serial)
            return
        if (String(text).trim() !== "" && root.apply(ctx, { synced: text }, "file"))
            return
        root.gather(ctx)
    }

    function gather(ctx) {
        ctx.results = []
        ctx.pending = root.providers.length
        ctx.done = false
        ctx.waiting = false
        ctx.shown = ctx.quiet === true
        ctx.shownText = ""
        const states = {}
        for (const p of root.providers)
            states[p.id] = "loading"
        root.sourceStates = states
        for (const p of root.providers) {
            const id = p.id
            root.ask(id, ctx, res => root.arrived(ctx, id, res))
        }
    }

    function ask(id, ctx, cb) {
        if (id === "lrclib")
            root.pLrclib(ctx, cb)
        else if (id === "netease")
            root.pNetease(ctx, cb)
        else if (id === "qq")
            root.pQq(ctx, cb)
        else if (id === "kugou")
            root.pKugou(ctx, cb)
        else if (id === "lyricsplus")
            root.pLyricsplus(ctx, cb)
        else
            cb({ state: "none" })
    }

    function arrived(ctx, id, res) {
        if (ctx.serial !== root.serial)
            return
        const st = Object.assign({}, root.sourceStates)
        let usable = false
        if (res.state === "found") {
            const lines = LM.foldEchoes(LM.parseLrc(res.text || ""))
            if (lines.length > 0) {
                usable = true
                st[id] = res.kind === "word" ? "word" : "synced"
                if (!ctx.done)
                    ctx.results.push({ id: id, kind: res.kind === "word" ? "word" : "synced", text: res.text, lines: lines, duration: res.duration || 0 })
            } else {
                st[id] = "none"
                if (res.instrumental === true)
                    ctx.instrumental = true
            }
        } else {
            st[id] = res.state === "offline" ? "offline" : "none"
        }
        if (res.state !== "offline")
            ctx.answered = true
        root.sourceStates = st
        ctx.pending -= 1
        if (ctx.done)
            return
        root.progress(ctx, usable)
    }

    function choose(ctx) {
        return LM.chooseLyrics(ctx.results, root.providerIds, ctx.length, root.preferred, root.wordsOn)
    }

    function progress(ctx, usable) {
        const hasWord = ctx.results.some(r => r.kind === "word")
        const hasSynced = ctx.results.some(r => r.kind !== "word")
        if (ctx.pending <= 0 || (hasWord && hasSynced && root.preferred === "auto")) {
            root.finalize(ctx)
            return
        }
        if (ctx.results.length === 0)
            return
        if (!ctx.shown) {
            const ch = root.choose(ctx)
            if (ch) {
                ctx.shown = true
                ctx.shownId = ch.id
                ctx.shownText = ch.text
                root.apply(ctx, { synced: ch.text, duration: root.durationOf(ctx, ch.id) }, ch.id, false)
            }
        }
        if (!ctx.waiting) {
            ctx.waiting = true
            root.run(["sleep", "8"], () => root.finalize(ctx))
        }
    }

    function durationOf(ctx, id) {
        const r = ctx.results.find(x => x.id === id)
        return r ? r.duration : 0
    }

    function finalize(ctx) {
        if (ctx.serial !== root.serial || ctx.done)
            return
        ctx.done = true
        const ch = root.choose(ctx)
        const kept = ctx.cached || null
        if (ch === null) {
            if (ctx.quiet === true && kept) {
                root.keep(ctx, kept.synced, kept.duration, "no", kept.provider)
            } else if (ctx.shown !== true) {
                if (ctx.instrumental === true)
                    root.apply(ctx, { instrumental: true }, "lrclib", true)
                else
                    root.finishMiss(ctx)
            }
            return
        }
        const dur = root.durationOf(ctx, ch.id)
        const words = ch.kind === "word" ? "yes" : "no"
        console.log("[lyrics] using " + ch.id + " (" + (ch.kind === "word" ? "word by word" : "synced") + ")")
        if (ctx.quiet === true && ch.kind !== "word" && kept) {
            // nothing better than what is on screen
            root.keep(ctx, kept.synced, kept.duration, "no", kept.provider)
            return
        }
        if (ctx.shown === true && ctx.shownId === ch.id && ctx.shownText === ch.text) {
            root.keep(ctx, ch.text, dur, words, ch.id)
            return
        }
        root.apply(ctx, { synced: ch.text, duration: dur, words: words, provider: ch.id }, ch.id, true)
    }

    function keep(ctx, synced, duration, words, provider) {
        const json = JSON.stringify({ synced: synced, duration: duration || 0, words: words, provider: provider || "" })
        // one argument to a program is 128 kB at most
        if (json.length < 120000)
            root.runScript(["put", ctx.hash, json], () => {})
    }

    function finishMiss(ctx) {
        if (!ctx.answered) {
            // No provider ever answered (no network, or no curl): nothing was learned about
            // the track, so it is asked again the next time it is requested.
            console.log("[lyrics] no answer from any lyrics service (is curl installed and the network up?)")
            root.status = "offline"
            root.trackId = ""
            return
        }
        const m = Object.assign({}, root.misses)
        m[ctx.id] = Date.now()
        root.misses = m
        root.status = "none"
    }

    function fromApi(o) {
        return {
            synced: typeof o.syncedLyrics === "string" ? o.syncedLyrics : "",
            instrumental: o.instrumental === true,
            duration: typeof o.duration === "number" ? o.duration : 0
        }
    }

    // True when the lyrics were usable (and are now on).
    function apply(ctx, got, source, store) {
        if (ctx.serial !== root.serial)
            return true
        if (got.instrumental === true && !got.synced) {
            root.lines = []
            root.status = "instrumental"
            root.source = source
            if (store)
                root.runScript(["put", ctx.hash, JSON.stringify({ instrumental: true })], () => {})
            return true
        }
        const lines = LM.foldEchoes(LM.parseLrc(got.synced || ""))
        if (lines.length === 0)
            return false
        root.lines = lines
        root.versionDiff = (got.duration > 0 && ctx.length > 0) ? got.duration - ctx.length : 0
        root.status = "ready"
        root.source = (source === "cache" && got.provider) ? got.provider : source
        root.sourceKind = lines.some(l => l.marks && l.marks.length > 0) ? "word" : "synced"
        if (store)
            root.keep(ctx, got.synced, got.duration, got.words || "", got.provider || source)
        // Kept from before there were several providers (or before word timing): the lyrics are
        // on, and the others are asked in the background for a better one.
        if (source === "cache" && got.words !== "yes" && got.words !== "no") {
            ctx.quiet = true
            ctx.cached = got
            root.gather(ctx)
        }
        return true
    }

    // ----- LRCLIB -----
    // The exact lookup, then a search by title and artist, then a free-text search; then the
    // next candidate.
    function pLrclib(ctx, cb) {
        const st = { answered: false }
        const next = i => {
            if (ctx.serial !== root.serial)
                return
            if (i >= ctx.cands.length) {
                cb({ state: st.answered ? "none" : "offline" })
                return
            }
            const c = ctx.cands[i]
            const steps = []
            const sig = "artist_name=" + encodeURIComponent(c.artist) + "&track_name=" + encodeURIComponent(c.title)
            // /get wants all four of artist, title, album and length; without them go to search.
            if (i === 0 && ctx.album !== "" && ctx.length > 0)
                steps.push({ kind: "get", url: root.base + "/get?" + sig + "&album_name=" + encodeURIComponent(ctx.album) + "&duration=" + Math.round(ctx.length) })
            steps.push({ kind: "search", url: root.base + "/search?track_name=" + encodeURIComponent(c.title) + (c.artist !== "" ? "&artist_name=" + encodeURIComponent(c.artist) : "") })
            steps.push({ kind: "search", url: root.base + "/search?q=" + encodeURIComponent((c.artist + " " + c.title).trim()) })
            root.lrclibStep(ctx, steps, 0, st, found => found ? cb(found) : next(i + 1))
        }
        next(0)
    }

    function lrclibStep(ctx, steps, k, st, done) {
        if (ctx.serial !== root.serial)
            return
        if (k >= steps.length) {
            done(null)
            return
        }
        const step = steps[k]
        console.log("[lyrics] lrclib " + step.kind + " " + step.url)
        root.http(step.url, (status, body) => {
            if (ctx.serial !== root.serial)
                return
            // 200 and 404 are the service answering; anything else is not.
            if (status === 200 || status === 404)
                st.answered = true
            let best = null
            if (status === 200) {
                const parsed = root.parseJson(body)
                if (step.kind === "get")
                    best = (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : null
                else
                    best = Array.isArray(parsed) ? LM.pickBest(parsed, ctx.length) : null
            }
            if (best) {
                const a = root.fromApi(best)
                if (a.instrumental && !a.synced) {
                    done({ state: "found", instrumental: true, text: "", duration: a.duration })
                    return
                }
                if (a.synced && LM.parseLrc(a.synced).length > 0) {
                    done({ state: "found", kind: "synced", text: a.synced, duration: a.duration })
                    return
                }
            }
            root.lrclibStep(ctx, steps, k + 1, st, done)
        })
    }

    // ----- NetEase Cloud Music: word by word ("yrc") where it has it, else synced -----
    function pNetease(ctx, cb) {
        root.searchSong(ctx, "netease", root.wordBase + "/search/get/web?csrf_token=&hlpretag=&hlposttag=&type=1&offset=0&total=true&limit=8&s=",
                        body => {
                            const o = root.parseJson(body)
                            return o && o.result && Array.isArray(o.result.songs) ? o.result.songs : null
                        }, root.wordHeaders, (id, st, done) => root.neteaseLyric(ctx, id, st, done), cb)
    }

    function neteaseLyric(ctx, id, st, done) {
        const urls = [
            root.wordBase + "/song/lyric/v1?id=" + id + "&lv=-1&kv=-1&tv=-1&rv=-1&yv=-1&ytv=-1&yrv=-1",
            root.wordBase + "/song/lyric/v1?id=" + id + "&lv=1&yv=1&tv=-1"
        ]
        let plain = ""
        const tryUrl = k => {
            if (ctx.serial !== root.serial)
                return
            if (k >= urls.length) {
                done(plain !== "" ? { state: "found", kind: "synced", text: plain, duration: 0 } : null)
                return
            }
            console.log("[lyrics] netease lyric " + urls[k])
            root.http(urls[k], (status, body) => {
                if (ctx.serial !== root.serial)
                    return
                if (status === 200)
                    st.answered = true
                const o = status === 200 ? root.parseJson(body) : null
                const yrc = o && o.yrc && typeof o.yrc.lyric === "string" ? o.yrc.lyric : ""
                const text = yrc !== "" ? LM.yrcToLrc(yrc, 0) : ""
                if (LM.parseLrc(text).length >= 3) {
                    done({ state: "found", kind: "word", text: text, duration: 0 })
                    return
                }
                if (plain === "" && o && o.lrc && typeof o.lrc.lyric === "string" && LM.parseLrc(o.lrc.lyric).length > 0)
                    plain = o.lrc.lyric
                tryUrl(k + 1)
            }, root.wordHeaders)
        }
        tryUrl(0)
    }

    // ----- QQ Music: synced -----
    function pQq(ctx, cb) {
        const heads = ["-H", "Referer: https://y.qq.com/", "-H", "User-Agent: Mozilla/5.0"]
        root.searchSong(ctx, "qq", "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?format=json&new_json=1&p=1&n=8&t=0&aggr=1&cr=1&catZhida=1&lossless=0&flag_qc=0&platform=yqq.json&needNewCode=0&inCharset=utf8&outCharset=utf-8&w=",
                        body => {
                            const o = root.parseJson(body)
                            const list = o && o.data && o.data.song ? o.data.song.list : null
                            if (!Array.isArray(list))
                                return null
                            return list.map(s => ({ id: s.mid, name: s.name || s.songname || s.title || "", artists: s.singer || [], duration: (Number(s.interval) || 0) * 1000 }))
                        }, heads, (mid, st, done) => {
                            const url = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?g_tk=5381&format=json&inCharset=utf8&outCharset=utf-8&nobase64=1&songmid=" + encodeURIComponent(mid)
                            console.log("[lyrics] qq lyric " + url)
                            root.http(url, (status, body) => {
                                if (ctx.serial !== root.serial)
                                    return
                                if (status === 200)
                                    st.answered = true
                                const o = status === 200 ? root.parseJson(body) : null
                                const text = o && typeof o.lyric === "string" ? LM.unescapeEntities(o.lyric) : ""
                                done(LM.parseLrc(text).length > 0 ? { state: "found", kind: "synced", text: text, duration: 0 } : null)
                            }, heads)
                        }, cb)
    }

    // ----- Kugou: synced -----
    function pKugou(ctx, cb) {
        const heads = ["-H", "User-Agent: Mozilla/5.0"]
        root.searchSong(ctx, "kugou", "https://mobileservice.kugou.com/api/v3/search/song?format=json&page=1&pagesize=8&showtype=1&keyword=",
                        body => {
                            const o = root.parseJson(body)
                            const list = o && o.data ? o.data.info : null
                            if (!Array.isArray(list))
                                return null
                            return list.map(s => ({ id: s.hash, name: s.songname || "", artists: [{ name: s.singername || "" }], duration: (Number(s.duration) || 0) * 1000 }))
                        }, heads, (hash, st, done) => {
                            const q = (ctx.cands[0].artist + " " + ctx.cands[0].title).trim()
                            const url = "https://lyrics.kugou.com/search?ver=1&man=yes&client=pc&hash=" + encodeURIComponent(hash)
                                      + "&duration=" + Math.round(ctx.length * 1000) + "&keyword=" + encodeURIComponent(q)
                            console.log("[lyrics] kugou lyric search " + url)
                            root.http(url, (status, body) => {
                                if (ctx.serial !== root.serial)
                                    return
                                if (status === 200)
                                    st.answered = true
                                const o = status === 200 ? root.parseJson(body) : null
                                const c = o && Array.isArray(o.candidates) && o.candidates.length > 0 ? o.candidates[0] : null
                                if (!c || c.id === undefined || !c.accesskey) {
                                    done(null)
                                    return
                                }
                                const dl = "https://lyrics.kugou.com/download?ver=1&client=pc&fmt=lrc&charset=utf8&id=" + encodeURIComponent(c.id) + "&accesskey=" + encodeURIComponent(c.accesskey)
                                root.http(dl, (status2, body2) => {
                                    if (ctx.serial !== root.serial)
                                        return
                                    const d = status2 === 200 ? root.parseJson(body2) : null
                                    if (!d || typeof d.content !== "string" || d.content === "") {
                                        done(null)
                                        return
                                    }
                                    // the lyrics come as base64; decoded by the system (the text is UTF-8)
                                    root.run(["sh", "-c", "printf %s \"$1\" | base64 -d", "sh", d.content], text => {
                                        const t = String(text).replace(/^\ufeff/, "")
                                        done(LM.parseLrc(t).length > 0 ? { state: "found", kind: "synced", text: t, duration: 0 } : null)
                                    })
                                }, heads)
                            }, heads)
                        }, cb)
    }

    // ----- LyricsPlus: word by word (Apple Music, Musixmatch) where it has it -----
    function pLyricsplus(ctx, cb) {
        const st = { answered: false }
        const cs = ctx.cands.slice(0, 2)
        const next = i => {
            if (ctx.serial !== root.serial)
                return
            if (i >= cs.length) {
                cb({ state: st.answered ? "none" : "offline" })
                return
            }
            const url = "https://lyricsplus.prjktla.workers.dev/v2/lyrics/get?title=" + encodeURIComponent(cs[i].title)
                      + "&artist=" + encodeURIComponent(cs[i].artist) + (ctx.album !== "" ? "&album=" + encodeURIComponent(ctx.album) : "")
                      + (ctx.length > 0 ? "&duration=" + Math.round(ctx.length) : "")
                      + "&source=apple%2Clyricsplus%2Cmusixmatch%2Cspotify%2Cmusixmatch-word"
            console.log("[lyrics] lyricsplus " + url)
            root.http(url, (status, body) => {
                if (ctx.serial !== root.serial)
                    return
                if (status === 200 || status === 404)
                    st.answered = true
                const o = status === 200 ? root.parseJson(body) : null
                const got = o ? LM.lyricsplusToLrc(o) : null
                if (got && LM.parseLrc(got.text).length > 0) {
                    cb({ state: "found", kind: got.word ? "word" : "synced", text: got.text, duration: 0 })
                    return
                }
                next(i + 1)
            }, ["-H", "User-Agent: Mozilla/5.0"])
        }
        next(0)
    }

    // The shape of the providers that find a song by search and then fetch its lyric by id:
    // search `base + query`, `pull(body)` the songs out of it, take the one that is this track
    // (LM.pickWordSong), `fetchOne(id, st, done)` its lyric; the next candidate when it has none.
    function searchSong(ctx, name, base, pull, heads, fetchOne, cb) {
        const st = { answered: false }
        const cs = ctx.cands.slice(0, 2)
        const next = i => {
            if (ctx.serial !== root.serial)
                return
            if (i >= cs.length) {
                cb({ state: st.answered ? "none" : "offline" })
                return
            }
            const url = base + encodeURIComponent((cs[i].artist + " " + cs[i].title).trim())
            console.log("[lyrics] " + name + " search " + url)
            root.http(url, (status, body) => {
                if (ctx.serial !== root.serial)
                    return
                if (status === 200)
                    st.answered = true
                const songs = status === 200 ? pull(body) : null
                const id = LM.pickWordSong(songs, cs[i].artist, cs[i].title, ctx.length)
                if (id === null || id === undefined || id === "") {
                    next(i + 1)
                    return
                }
                fetchOne(id, st, res => res ? cb(res) : next(i + 1))
            }, heads)
        }
        next(0)
    }

    // The providers and where each stands, one a line: what `ipc lyrics sources` prints.
    function sourceReport() {
        const words = { loading: "asking...", word: "word by word", synced: "synced", none: "not found", offline: "unreachable" }
        let out = "source: " + root.preferred + "\n"
        for (const p of root.providers) {
            const s = root.sourceStates[p.id]
            out += (root.source === p.id ? "* " : "  ") + p.id + "  " + p.name + "  " + (s ? words[s] : "-") + "\n"
        }
        if (root.source !== "" && root.providerIds.indexOf(root.source) < 0)
            out += "showing: " + root.source + "\n"
        return out
    }

    function parseStored(text) {
        const o = root.parseJson(String(text).trim())
        if (!o || typeof o !== "object")
            return null
        return {
            synced: typeof o.synced === "string" ? o.synced : "",
            instrumental: o.instrumental === true,
            duration: typeof o.duration === "number" ? o.duration : 0,
            words: o.words === "yes" || o.words === "no" ? o.words : "",
            provider: typeof o.provider === "string" ? o.provider : ""
        }
    }

    function parseJson(text) {
        try {
            return JSON.parse(text)
        } catch (e) {
            return null
        }
    }

    // ===== plumbing =====
    // One short-lived Process per call, so two requests never share one. It is given up
    // after 12 seconds whatever happens (a missing program, a hung connection), and the
    // answer is then empty, the same as no network.
    Component {
        id: runner

        QtObject {
            id: job

            property var command: []
            property var done: null
            property bool called: false

            function finish(text) {
                if (job.called)
                    return
                job.called = true
                limit.stop()
                late.stop()
                job.done(text)
                job.destroy()
            }

            property Process proc: Process {
                command: job.command
                stdout: StdioCollector {
                    onStreamFinished: job.finish(text)
                }
                // The output normally arrives first; this is for a program that never
                // started or never printed.
                onExited: late.restart()
            }

            property Timer late: Timer {
                interval: 150
                onTriggered: job.finish("")
            }

            property Timer limit: Timer {
                interval: 12000
                onTriggered: {
                    job.proc.running = false
                    job.finish("")
                }
            }

            Component.onCompleted: {
                job.proc.running = true
                job.limit.start()
            }
        }
    }

    function run(command, cb) {
        runner.createObject(root, { command: command, done: cb })
    }

    function runScript(args, cb) {
        root.run(["sh", root.cacheScript].concat(args), cb)
    }

    // GET `url` with curl: cb(status, body). Status 0 means it never got an answer (no curl,
    // no network, a timeout). `-w` puts the HTTP status on a last line.
    function http(url, cb, extra) {
        const head = extra ? extra : ["-H", "Lrclib-Client: pjsekai-quickshell"]
        root.run(["curl", "-sS", "-m", "10"].concat(head).concat(["-w", "\n%{http_code}", url]), text => {
            const t = String(text)
            const cut = t.lastIndexOf("\n")
            if (cut < 0) {
                cb(0, "")
                return
            }
            const code = Number(t.slice(cut + 1).trim())
            cb(isFinite(code) ? code : 0, t.slice(0, cut))
        })
    }

    // ===== the widget's place =====
    function setPosition(x, y, screen, scale) {
        if (!root.loaded)
            return
        root.posX = x
        root.posY = y
        if (typeof scale === "number" && scale > 0)
            root.posScale = scale
        if (typeof screen === "string" && screen !== "")
            root.screenName = screen
        saveTimer.stop()
        saver.save(root.snapshot())
    }

    function setShown(value) {
        root.shown = value
        root.persist()
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/lyrics-state.sh")

    function snapshot() {
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            screen: root.screenName,
            shown: root.shown,
            syncMs: root.syncMs,
            wordsOn: root.wordsOn,
            source: root.preferred,
            offsets: root.offsets
        })
    }

    function restore(text) {
        try {
            const s = JSON.parse(text)
            if (typeof s.x === "number")
                root.posX = s.x
            if (typeof s.y === "number")
                root.posY = s.y
            if (typeof s.scale === "number" && s.scale > 0)
                root.posScale = s.scale
            if (typeof s.screen === "string")
                root.screenName = s.screen
            // Off until added: a missing `shown` is off, unlike the older cards.
            root.shown = s.shown === true
            if (typeof s.wordsOn === "boolean")
                root.wordsOn = s.wordsOn
            if (typeof s.source === "string" && (s.source === "auto" || root.providerIds.indexOf(s.source) >= 0))
                root.preferred = s.source
            if (typeof s.syncMs === "number")
                root.syncMs = Math.max(-5000, Math.min(5000, Math.round(s.syncMs)))
            if (s.offsets && typeof s.offsets === "object" && !Array.isArray(s.offsets)) {
                const o = {}
                for (const k in s.offsets) {
                    if (typeof s.offsets[k] === "number" && isFinite(s.offsets[k]))
                        o[k] = Math.max(-10000, Math.min(10000, Math.round(s.offsets[k])))
                }
                root.offsets = o
            }
        } catch (e) {
            // No file yet (first run) or an unreadable one: keep the defaults.
        }
        root.loaded = true
    }

    // Runs once, at startup.
    Process {
        running: true
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: root.restore(text)
        }
    }

    function persist() {
        if (root.loaded)
            saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: saver.save(root.snapshot())
    }

    // Fire-and-forget save. Queues at most one pending snapshot behind an in-flight save
    // rather than dropping it, so the *last* state is what ends up on disk.
    Process {
        id: saver

        property var pending: null

        function save(json) {
            if (saver.running) {
                saver.pending = json
                return
            }
            saver.pending = null
            saver.exec(["sh", root.script, "save", json])
        }

        onExited: {
            if (saver.pending !== null) {
                const json = saver.pending
                saver.pending = null
                saver.exec(["sh", root.script, "save", json])
            }
        }
    }
}
