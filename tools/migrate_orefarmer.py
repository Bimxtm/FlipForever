"""Move Ore Farmer's saved data into FlipForever (which now contains Ore Farmer as its
Gathering module) and switch the old stand-alone Ore Farmer addon off on every character.

WoW must be closed (it rewrites these files on exit). Backups are kept next to each file
with the suffix .before-flipforever. Safe to run twice.

Usage: python migrate_orefarmer.py <...\\_forever_\\WTF\\Account\\<account>>
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path


def wow_running() -> bool:
    out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq Wow.exe"], capture_output=True, text=True).stdout
    return "Wow.exe" in out


def backup(p: Path):
    b = p.with_name(p.name + ".before-flipforever")
    if p.exists() and not b.exists():
        shutil.copy2(p, b)


def main():
    account = Path(sys.argv[1])
    if wow_running():
        print("WoW is running - quit the game first.")
        sys.exit(2)
    sv = account / "SavedVariables"
    old, new = sv / "OreFarmer.lua", sv / "FlipForever.lua"

    # 1) data: copy the OreFarmerDB = {...} block into FlipForever's file
    if old.exists():
        text = old.read_bytes().decode("utf-8", errors="surrogateescape")
        # the top-level table ends with a "}" alone on its line; inner tables end with "},"
        m = re.search(r"^OreFarmerDB = \{.*?^\}[ \t]*\r?$", text, re.S | re.M)
        target = new.read_bytes().decode("utf-8", errors="surrogateescape") if new.exists() else ""
        if not m:
            print("OreFarmer.lua has no OreFarmerDB - nothing to move.")
        elif re.search(r"^OreFarmerDB = ", target, re.M):
            print("FlipForever already has the gathering data - left as is.")
        else:
            combined = target.rstrip("\r\n") + "\n" + m.group(0) + "\n"
            # never write a file the game can't read: check it parses and holds both tables
            sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "app"))
            from flipforever import luaio
            parsed = luaio.loads(combined.encode("utf-8", errors="surrogateescape").decode("utf-8", errors="replace"))
            if "OreFarmerDB" not in parsed or (target and "FlipForeverDB" not in parsed):
                print("check failed - nothing written.")
                sys.exit(3)
            backup(new)
            new.write_bytes(combined.encode("utf-8", errors="surrogateescape"))
            print(f"moved Ore Farmer data into FlipForever ({len(m.group(0)):,} characters, checked: file parses).")
    else:
        print("no OreFarmer.lua - nothing to move.")

    # 2) switch the old addon off for every character
    for f in sorted(account.glob("*/*/AddOns.txt")):
        text = f.read_bytes().decode("utf-8")
        nl = "\r\n" if "\r\n" in text else "\n"
        lines = text.splitlines()
        if "OreFarmer: disabled" in lines:
            print(f"{f.parent.name}: Ore Farmer already off")
            continue
        backup(f)
        lines = [l for l in lines if not l.startswith("OreFarmer:")] + ["OreFarmer: disabled"]
        f.write_bytes((nl.join(lines) + nl).encode("utf-8"))
        print(f"{f.parent.name}: Ore Farmer switched off (FlipForever's Gathering takes over)")


if __name__ == "__main__":
    main()
