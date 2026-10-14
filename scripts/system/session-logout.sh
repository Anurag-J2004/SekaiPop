#!/bin/sh

# Used by QuickSource.qml's Log out action: ask every open window's program
# to quit first (SIGTERM, so apps can save), give them a moment, then end
# the Hyprland session.
#
# Reads the pids out of `hyprctl clients -j` with grep, so it needs no jq
# and no particular Hyprland dispatcher syntax. Hyprland reports pid -1 for
# some windows; anything <= 1 is skipped so this can never signal init.
#
#   session-logout.sh [grace-seconds]     (default 1.5)

grace="${1:-1.5}"

for pid in $(hyprctl clients -j 2>/dev/null | grep -o '"pid": *[0-9]*' | grep -o '[0-9]*$' | sort -u); do
    [ "$pid" -gt 1 ] 2>/dev/null && kill "$pid" 2>/dev/null
done

sleep "$grace"
exec hyprctl dispatch exit
