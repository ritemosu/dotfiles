#!/usr/bin/env python3
"""Merge dotfiles/windows-terminal/settings.json into Windows Terminal's settings.

usage: python3 apply.py PATH_TO_WINDOWS_TERMINAL_SETTINGS_JSON

- adds / replaces the color scheme
- sets profile defaults (scheme, transparency, font size, padding)
- makes the Ubuntu (WSL) profile the default
- adds the Alt key bindings, removing existing bindings on the same keys
A backup is written next to the file first. Comments in the file are not kept.
"""
import json
import shutil
import sys
import time
from pathlib import Path


def strip_jsonc(text: str) -> str:
    """Remove // and /* */ comments and trailing commas (outside strings)."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\":
                out.append(text[i + 1])
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            out.append(c)
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            i = text.index("*/", i) + 2
            continue
        else:
            out.append(c)
        i += 1
    s = "".join(out)
    # trailing commas
    res, in_str, i = [], False, 0
    while i < len(s):
        c = s[i]
        if in_str:
            res.append(c)
            if c == "\\":
                res.append(s[i + 1])
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            res.append(c)
        elif c == ",":
            j = i + 1
            while j < len(s) and s[j] in " \t\r\n":
                j += 1
            if j < len(s) and s[j] in "]}":
                i += 1
                continue
            res.append(c)
        else:
            res.append(c)
        i += 1
    return "".join(res)


def main() -> int:
    target = Path(sys.argv[1])
    ours = json.loads((Path(__file__).parent / "settings.json").read_text(encoding="utf-8"))
    cfg = json.loads(strip_jsonc(target.read_text(encoding="utf-8-sig")))

    # color scheme
    names = {s["name"] for s in ours["schemes"]}
    cfg["schemes"] = [s for s in cfg.get("schemes", []) if s.get("name") not in names] + ours["schemes"]

    # profile defaults
    profiles = cfg.setdefault("profiles", {})
    if isinstance(profiles, list):  # very old format
        profiles = cfg["profiles"] = {"list": profiles}
    profiles.setdefault("defaults", {}).update(ours["profileDefaults"])

    # Ubuntu as the default profile
    for p in profiles.get("list", []):
        if p.get("name", "").lower().startswith("ubuntu") and not p.get("hidden"):
            cfg["defaultProfile"] = p["guid"]
            break

    # key bindings
    keys = {a["keys"] for a in ours["actions"]}
    cfg["actions"] = [a for a in cfg.get("actions", []) if a.get("keys") not in keys] + ours["actions"]
    if "keybindings" in cfg:  # newer format keeps keys here
        cfg["keybindings"] = [k for k in cfg["keybindings"] if k.get("keys") not in keys]

    shutil.copy2(target, target.with_name(f"settings.json.bak-{int(time.time())}"))
    target.write_text(json.dumps(cfg, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"windows-terminal: settings updated ({target})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
