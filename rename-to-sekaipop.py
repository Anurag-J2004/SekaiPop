#!/usr/bin/env python3
"""
Rename the Quickshell config from `pjsekai` to `sekaipop`.

Run from the repo root (the folder that has install.sh and pjsekai/):

    python3 rename-to-sekaipop.py            # do it
    python3 rename-to-sekaipop.py --dry-run  # only list what would change

What changes (the config NAME, i.e. how the shell is started and found):
  - the folder  pjsekai/  ->  sekaipop/        (git mv, history kept)
  - qs -c pjsekai ...     ->  qs -c sekaipop ...   (installer, hypr config, hypridle, QML, docs)
  - ~/.config/quickshell/pjsekai -> ~/.config/quickshell/sekaipop
  - qsConfig = "pjsekai"  ->  "sekaipop"       (Extras.js, hypr/variables.lua)
  - path mentions of the folder (./pjsekai, $HERE/pjsekai, pjsekai/VERSION, ...)

What is deliberately NOT changed (renaming these would orphan saved settings,
presets and images, or break matching between files):
  - ~/.config/pjsekai, ~/.local/state/pjsekai, ~/.local/share/pjsekai, ~/.cache/pjsekai
  - layer namespaces (pjsekai-dock, pjsekai-quickpanel, ...) and the Hyprland rules for them
  - the "SekaiPop (pjsekai): Hyprland configuration" marker the installer looks for
  - PJSEKAI_* environment variables, pjsekai_overrides.lua, temp-file names
"""
import os, re, subprocess, sys

DRY = "--dry-run" in sys.argv
OLD, NEW = "pjsekai", "sekaipop"

if not (os.path.isdir(OLD) and os.path.isfile("install.sh")):
    sys.exit("Run this from the repo root (the folder with install.sh and pjsekai/).")
if os.path.exists(NEW):
    sys.exit(f"{NEW}/ already exists: nothing to do.")

# (pattern, replacement). Order matters a little; each is idempotent.
RULES = [
    # how the shell is started / called
    (r'((?:qs|quickshell)\s+-c\s+)pjsekai\b', r'\1sekaipop'),
    (r'(-c\[\[:space:\]\]\+)pjsekai\b', r'\1sekaipop'),               # grep -E patterns in the scripts
    (r'("-c",\s*)"pjsekai"', r'\1"sekaipop"'),                          # execDetached([... "-c", "pjsekai" ...])
    (r'(qsConfig\s*=\s*)"pjsekai"', r'\1"sekaipop"'),
    # where the shell lives
    (r'quickshell/pjsekai\b', 'quickshell/sekaipop'),
    # the repo folder
    (r'(\$HERE/(?:\.\./)?)pjsekai\b', r'\1sekaipop'),
    (r'(?<![\w.~/-])\./pjsekai\b', './sekaipop'),
    (r'(?<![\w.~/$-])pjsekai/(?=(?:VERSION|CHANGELOG|scripts|shell\.qml|modules|services|shaders|tests|assets)\b)', 'sekaipop/'),
    (r'(?m)^pjsekai/ (\s+the shell itself)', r'sekaipop/\1'),   # one space less: keeps the README column aligned
    (r'(--rice /path/to/)pjsekai\b', r'\1sekaipop'),
    (r'((?:the |a different copy of the )`?)pjsekai(`? folder)', r'\1sekaipop\2'),
    (r'Could not find the pjsekai folder', 'Could not find the sekaipop folder'),
]

# files that need a hand edit rather than a regex
EXTRA = {
    "pjsekai/modules/common/functions/FocusMath.js": (
        '["quickshell", "org.quickshell", "pjsekai"]',
        '["quickshell", "org.quickshell", "sekaipop", "pjsekai"]'),
}

def tracked():
    out = subprocess.check_output(["git", "ls-files", "-z"]).decode("utf-8", "surrogateescape")
    return [p for p in out.split("\0") if p]

def is_text(path):
    try:
        with open(path, "rb") as f:
            return b"\0" not in f.read(4096)
    except OSError:
        return False

changed = []
for p in tracked():
    if not os.path.isfile(p) or not is_text(p):
        continue
    with open(p, encoding="utf-8", errors="surrogateescape", newline="") as f:
        s = f.read()
    t = s
    for pat, rep in RULES:
        t = re.sub(pat, rep, t)
    if p in EXTRA and EXTRA[p][0] in t:
        t = t.replace(EXTRA[p][0], EXTRA[p][1])
    if t != s:
        changed.append(p)
        if not DRY:
            with open(p, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
                f.write(t)

print(f"{len(changed)} files edited" + (" (dry run, nothing written)" if DRY else ""))
for p in changed[:12]:
    print("  ", p)
if len(changed) > 12:
    print(f"   ... and {len(changed) - 12} more")

if DRY:
    print(f"would: git mv {OLD} {NEW}")
else:
    subprocess.check_call(["git", "mv", OLD, NEW])
    subprocess.check_call(["git", "add", "-A"])
    print(f"moved {OLD}/ -> {NEW}/ and staged everything. Review with: git status")
