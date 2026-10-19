#!/bin/sh

# Helper for WallhavenService.qml: Wallhaven (wallhaven.cc) as a source for the
# Wallpapers picker. The URLs come from WallhavenMath.js; this only fetches.
#
#   wallhaven.sh search <url>            print Wallhaven's JSON answer
#   wallhaven.sh download <url> <dir> <name>
#                                        save the image as <dir>/<name> and print
#                                        that path (already there: just print it)
#   wallhaven.sh have <dir>              the Wallhaven ids already downloaded in
#                                        <dir>, one per line
#
# Exit codes: 0 done, 2 bad arguments, 3 too many requests (Wallhaven allows 45
# a minute; wait and try again), 4 Wallhaven answered with an error, 5 it could
# not be reached (offline, DNS, timeout), 127 curl is missing.
#
# Only https://wallhaven.cc/api/ (search) and https://w.wallhaven.cc/full/
# (images) are fetched, so a bad URL can't make this download anything else. A
# download is written to <name>.part and moved into place when it is complete,
# so a picture is never half there.

mode="$1"

command -v curl >/dev/null 2>&1 || { echo "wallhaven: curl is not installed" >&2; exit 127; }

# fetch <url> <out>: curl, with the HTTP status turned into the exit codes above.
fetch() {
    code=$(curl -sS -L --max-time 60 --connect-timeout 10 -A "SekaiPop" -o "$2" -w '%{http_code}' -- "$1") || {
        echo "wallhaven: could not reach $1" >&2
        return 5
    }
    case "$code" in
        200) return 0 ;;
        429) echo "wallhaven: too many requests" >&2; return 3 ;;
        *) echo "wallhaven: HTTP $code for $1" >&2; return 4 ;;
    esac
}

case "$mode" in
    search)
        case "$2" in
            https://wallhaven.cc/api/v1/search*) ;;
            *) echo "wallhaven: not a search URL" >&2; exit 2 ;;
        esac
        tmp=$(mktemp) || exit 1
        fetch "$2" "$tmp"
        rc=$?
        [ "$rc" -eq 0 ] && cat "$tmp"
        rm -f "$tmp"
        exit "$rc"
        ;;
    download)
        url="$2"; dir="$3"; name="$4"
        case "$url" in
            https://w.wallhaven.cc/full/*) ;;
            *) echo "wallhaven: not a Wallhaven image URL" >&2; exit 2 ;;
        esac
        case "$name" in
            wallhaven-*.jpg|wallhaven-*.png|wallhaven-*.webp) ;;
            *) echo "wallhaven: bad file name" >&2; exit 2 ;;
        esac
        case "$name" in */*|*..*) exit 2 ;; esac
        [ -n "$dir" ] || exit 2
        if [ -s "$dir/$name" ]; then
            printf '%s\n' "$dir/$name"
            exit 0
        fi
        mkdir -p "$dir" || exit 1
        fetch "$url" "$dir/$name.part"
        rc=$?
        if [ "$rc" -ne 0 ] || [ ! -s "$dir/$name.part" ]; then
            rm -f "$dir/$name.part"
            [ "$rc" -ne 0 ] && exit "$rc"
            exit 4
        fi
        mv -f "$dir/$name.part" "$dir/$name" || exit 1
        printf '%s\n' "$dir/$name"
        ;;
    have)
        [ -d "$2" ] || exit 0
        for f in "$2"/wallhaven-*; do
            [ -f "$f" ] || continue
            b=$(basename "$f")
            id=${b#wallhaven-}
            printf '%s\n' "${id%.*}"
        done
        ;;
    *)
        echo "usage: $0 search <url> | download <url> <dir> <name> | have <dir>" >&2
        exit 2
        ;;
esac
