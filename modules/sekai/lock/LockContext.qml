import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.services

// The password side of the lockscreen: what's been typed, and asking
// PAM whether it's right. Shared by every monitor's LockSurface (the
// keyboard only reaches one of them, but the dots show on all), so it
// lives here rather than in the surface — the same split as
// QuickPanel.qml / QuickSource.qml.
//
// Pure logic, no pixels. Same PamContext idea as the Quickshell
// lockscreen example: PAM asks for the password, we answer with what's
// typed, and it reports back success or failure.
Scope {
    id: root

    // The PAM service to check the password against. "login" is
    // Quickshell's own default and what most setups want (it's the one
    // that also honours faillock). If a correct password is refused with
    // "PAM error", check /etc/pam.d/ for what your distro calls it —
    // e.g. "system-auth" — and change this one line.
    property string pamService: "login"

    property string currentText: ""
    property bool unlockInProgress: false

    // "" = nothing to say, otherwise the message under the field.
    property string failureText: ""
    // Bumped on every failed attempt, so the surface can shake even when
    // two failures in a row leave failureText unchanged.
    property int failureCount: 0

    signal unlocked()
    // Asks the surface(s) to grab keyboard focus again (see Lockscreen.qml).
    signal focusRequested()

    // Ctrl+A: the whole password is "selected" (the dots light up). The next
    // key typed replaces it, Backspace / Delete wipes it. Any change to the
    // text, or an empty field, drops the selection.
    property bool allSelected: false
    function selectAll() {
        if (unlockInProgress || currentText.length === 0)
            return
        allSelected = true
    }

    function typeText(t) {
        if (unlockInProgress)
            return
        if (allSelected)
            currentText = t
        else
            currentText += t
    }

    function backspace() {
        if (unlockInProgress)
            return
        if (allSelected)
            currentText = ""
        else
            currentText = currentText.slice(0, -1)
    }

    function clearText() {
        currentText = ""
    }

    // Also called when the lock engages, so a half-typed password from
    // the last session (or a failure message) is never shown.
    function reset() {
        pam.abort()
        currentText = ""
        failureText = ""
        unlockInProgress = false
    }

    function tryUnlock() {
        // Only once the session lock is really engaged: the lockscreen
        // picture also exists earlier, inside LockRing.qml's overlay, but
        // nothing may unlock before the lock does.
        if (!LockState.locked || unlockInProgress || currentText.length === 0)
            return
        failureText = ""
        unlockInProgress = true
        pam.start()
    }

    onCurrentTextChanged: {
        allSelected = false
        if (currentText.length > 0)
            failureText = ""
        idleClear.restart()
    }

    // Walked away mid-password: don't leave it sitting on the screen.
    Timer {
        id: idleClear
        interval: 15000
        onTriggered: {
            if (!root.unlockInProgress)
                root.clearText()
        }
    }

    PamContext {
        id: pam
        config: root.pamService

        // The password prompt: answer it with what was typed.
        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.currentText)
        }

        onCompleted: result => {
            root.unlockInProgress = false
            if (result === PamResult.Success) {
                root.currentText = ""
                root.failureText = ""
                root.unlocked()
                return
            }
            root.currentText = ""
            root.failureCount++
            if (result === PamResult.Error)
                root.failureText = "Couldn't check the password (PAM error)"
            else if (result === PamResult.MaxTries)
                root.failureText = "Too many tries — wait a moment"
            else
                root.failureText = "Wrong password"
        }
    }
}
