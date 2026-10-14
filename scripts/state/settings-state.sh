#!/bin/sh

# Helper for SettingsService.qml: remembers the Settings Panel's own options
# (which bar modules are shown, 24-hour time, the Quick Panel's hot edge, ...)
# so a shell restart brings them back exactly as you left them.
#
#   settings-state.sh save <json>   replace the remembered state with <json>
#   settings-state.sh load          print the remembered JSON (or nothing at
#                                   all, if nothing has ever been changed)
#
# Lives in ${XDG_STATE_HOME:-~/.local/state}/pjsekai/settings.json — state,
# not data, same convention clock-state.sh / todo-state.sh use. Written to a
# temp file and moved into place, so a crash mid-save can't leave half a file.

mode="$1"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/pjsekai"
file="$dir/settings.json"

case "$mode" in
    save)
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$2" > "$file.tmp" || exit 1
        mv "$file.tmp" "$file"
        ;;
    load)
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    *)
        echo "usage: $0 save <json>|load" >&2
        exit 2
        ;;
esac
