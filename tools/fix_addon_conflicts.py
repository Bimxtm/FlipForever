"""Turn off duplicate addons that fight over the same job, per character.

Only touches characters that have BOTH addons of a pair switched on, keeps a backup of
every file it changes (AddOns.txt.before-flipforever), and refuses to run while WoW is
open (the game rewrites these files when you log out or quit).

Choices (made by the user):
  bags        keep EllesmereUI Bags      -> off: Bagnon + its modules, BagBrother
  layers      keep LayerSwap             -> off: AutoLayer, Layer Hop for AutoLayer, Forever Layer Hop
  nameplates  keep Threat Plates         -> off: EllesmereUI Nameplates
  meters      keep Details!              -> off: EllesmereUI Damage Meters

Usage: python fix_addon_conflicts.py <...\\_forever_\\WTF\\Account\\<account>> [--apply]
"""
import shutil
import subprocess
import sys
from pathlib import Path

RULES = [
    # (name, keep-if-enabled, turn off these when keep is enabled and they are too)
    ("bags", ["EllesmereUI", "EllesmereUIBags"], ["Bagnon", "Bagnon_Bank", "Bagnon_Config", "Bagnon_GuildBank", "BagBrother"]),
    ("layers", ["LayerSwap"], ["AutoLayer", "LayerHopForAutoLayer", "ForeverLayerHop"]),
    ("nameplates", ["TidyPlates_ThreatPlates"], ["EllesmereUINameplates"]),
    ("meters", ["Details"], ["EllesmereUIDamageMeters"]),
]


def wow_running() -> bool:
    out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq Wow.exe"], capture_output=True, text=True).stdout
    return "Wow.exe" in out


def default_states(addons_dir: Path) -> dict:
    """Addons missing from a character's AddOns.txt load with their default state:
    enabled, unless the .toc says '## DefaultState: disabled'."""
    out = {}
    for d in addons_dir.iterdir():
        if not d.is_dir():
            continue
        state = "enabled"
        for toc in d.glob("*.toc"):
            for line in toc.read_text(encoding="utf-8", errors="ignore").splitlines():
                if line.lower().startswith("## defaultstate:") and "disabled" in line.lower():
                    state = "disabled"
        out[d.name] = state
    return out


def process(path: Path, apply: bool, defaults: dict) -> list[str]:
    raw = path.read_bytes()
    text = raw.decode("utf-8")
    lines = text.splitlines()
    state = {}
    for line in lines:
        if ": " in line:
            name, val = line.rsplit(": ", 1)
            state[name] = val.strip()

    def is_on(name):
        if name in state:
            return state[name] == "enabled"
        return defaults.get(name) == "enabled"   # installed but not listed yet

    changes, added = [], []
    for rule, keep, off in RULES:
        if all(is_on(k) for k in keep):
            for name in off:
                if is_on(name):
                    if name not in state:
                        added.append(name)
                    state[name] = "disabled"
                    changes.append(f"{rule}: {name} -> off")
    if changes and apply:
        backup = path.with_name("AddOns.txt.before-flipforever")
        if not backup.exists():
            shutil.copy2(path, backup)
        out = []
        for line in lines:
            if ": " in line:
                name = line.rsplit(": ", 1)[0]
                out.append(f"{name}: {state[name]}")
            else:
                out.append(line)
        out += [f"{name}: disabled" for name in added]
        nl = "\r\n" if "\r\n" in text else "\n"
        path.write_bytes((nl.join(out) + nl).encode("utf-8"))
    return changes


def main():
    account = Path(sys.argv[1])
    apply = "--apply" in sys.argv
    if apply and wow_running():
        print("WoW is running - quit the game first (it rewrites these files on exit).")
        sys.exit(2)
    defaults = default_states(account.parents[2] / "Interface" / "AddOns")
    for f in sorted(account.glob("*/*/AddOns.txt")):
        char = f.parent.name
        changes = process(f, apply, defaults)
        print(f"{char}: " + ("; ".join(changes) if changes else "no conflicts"))
    print("APPLIED (backups: AddOns.txt.before-flipforever)" if apply else "dry run - nothing changed")


if __name__ == "__main__":
    main()
