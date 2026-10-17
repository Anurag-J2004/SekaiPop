#!/bin/sh

# Helper for UpdateService.qml: what version is this shell, and is there a
# newer one?
#
#   update-check.sh info     print  version= / git= / branch= / commit= / remote=
#   update-check.sh check    print  status=current|behind|nosource|error and
#                            behind=<n> (git) or latest=<version> (URL)
#   update-check.sh log      commits that an update would bring, one per line:
#                            <hash>|<subject>|<age>   (git only)
#   update-check.sh apply    git pull --ff-only (git only)
#
# Where it looks, in order:
#   1. The shell's own folder is a git clone with an upstream branch
#      (`git clone ... ~/.config/quickshell/sekaipop`): it compares with
#      that upstream.
#   2. Otherwise a URL to a plain-text VERSION file, from $PJSEKAI_UPDATE_URL
#      or the first line of ~/.config/pjsekai/update-url. It is compared with
#      this folder's VERSION. (Nothing is ever downloaded or installed this
#      way; the panel just tells you a newer version exists.)
#   3. Otherwise: status=nosource.

here=$(cd "$(dirname "$0")/../.." && pwd)
ver=$(head -n 1 "$here/VERSION" 2>/dev/null | tr -d ' \r')
[ -n "$ver" ] || ver=unknown
is_git() { command -v git >/dev/null 2>&1 && git -C "$here" rev-parse --is-inside-work-tree >/dev/null 2>&1 && [ "$(git -C "$here" rev-parse --show-toplevel)" = "$here" ]; }
has_up() { git -C "$here" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; }

url="$PJSEKAI_UPDATE_URL"
[ -n "$url" ] || url=$(head -n 1 "${XDG_CONFIG_HOME:-$HOME/.config}/pjsekai/update-url" 2>/dev/null)

case "$1" in
    info)
        printf 'version=%s\n' "$ver"
        if is_git; then
            printf 'git=yes\nbranch=%s\ncommit=%s\n' "$(git -C "$here" rev-parse --abbrev-ref HEAD)" "$(git -C "$here" rev-parse --short HEAD)"
            printf 'remote=%s\n' "$(git -C "$here" config --get remote.origin.url)"
        else
            printf 'git=no\n'
            [ -n "$url" ] && printf 'remote=%s\n' "$url"
        fi
        ;;
    check)
        if is_git && has_up; then
            git -C "$here" fetch --quiet 2>/dev/null || { echo "status=error"; echo "reason=fetch failed"; exit 0; }
            n=$(git -C "$here" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
            if [ "$n" -gt 0 ]; then echo "status=behind"; else echo "status=current"; fi
            echo "behind=$n"
        elif [ -n "$url" ]; then
            command -v curl >/dev/null 2>&1 || { echo "status=error"; echo "reason=curl not installed"; exit 0; }
            latest=$(curl -fsSL -m 15 "$url" 2>/dev/null | head -n 1 | tr -d ' \r')
            [ -n "$latest" ] || { echo "status=error"; echo "reason=couldn't reach the update URL"; exit 0; }
            echo "latest=$latest"
            if [ "$latest" = "$ver" ]; then echo "status=current"
            elif [ "$(printf '%s\n%s\n' "$ver" "$latest" | sort -V | tail -n 1)" = "$latest" ]; then echo "status=behind"
            else echo "status=current"; fi
        else
            echo "status=nosource"
        fi
        ;;
    log)
        is_git && has_up || exit 0
        git -C "$here" log --pretty=format:'%h|%s|%cr' -n 30 'HEAD..@{u}' 2>/dev/null
        ;;
    apply)
        is_git && has_up || { echo "not a git clone with an upstream" >&2; exit 1; }
        git -C "$here" pull --ff-only
        ;;
    *)
        echo "usage: $0 info|check|log|apply" >&2
        exit 2
        ;;
esac
exit 0
