"""Local storage: SQLite database + settings + locating the WoW: Forever install."""
from __future__ import annotations

import json
import os
import sqlite3
import string
from dataclasses import asdict, dataclass, field
from pathlib import Path

import sys
import base64

# Secrets (the GitHub token) are encrypted with Windows' own data protection (DPAPI): only the
# same Windows user on the same PC can decrypt them, so a copied settings.json reveals nothing.
_PREFIX = "dpapi:"


def _dpapi(data: bytes, encrypt: bool) -> bytes | None:
    if os.name != "nt":
        return None
    import ctypes
    from ctypes import wintypes

    class BLOB(ctypes.Structure):
        _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_char))]

    buf = ctypes.create_string_buffer(data, len(data))
    blob_in, blob_out = BLOB(len(data), buf), BLOB()
    entropy_bytes = b"FlipForever settings"
    ebuf = ctypes.create_string_buffer(entropy_bytes, len(entropy_bytes))
    entropy = BLOB(len(entropy_bytes), ebuf)
    crypt32, kernel32 = ctypes.windll.crypt32, ctypes.windll.kernel32
    fn = crypt32.CryptProtectData if encrypt else crypt32.CryptUnprotectData
    ok = fn(ctypes.byref(blob_in), None, ctypes.byref(entropy), None, None, 0x1, ctypes.byref(blob_out))  # 0x1: no UI
    if not ok:
        return None
    try:
        return ctypes.string_at(blob_out.pbData, blob_out.cbData)
    finally:
        kernel32.LocalFree(blob_out.pbData)


def protect(secret: str) -> str:
    if not secret:
        return ""
    enc = _dpapi(secret.encode("utf-8"), True)
    return _PREFIX + base64.b64encode(enc).decode("ascii") if enc else secret


def unprotect(stored: str) -> str:
    if not stored or not stored.startswith(_PREFIX):
        return stored or ""          # older plain-text value: re-saved encrypted on the next save
    dec = _dpapi(base64.b64decode(stored[len(_PREFIX):]), False)
    return dec.decode("utf-8") if dec else ""


if getattr(sys, "frozen", False):
    # running as FlipForever.exe: everything lives next to the .exe
    APP_DIR = Path(sys.executable).resolve().parent
else:
    APP_DIR = Path(__file__).resolve().parent.parent.parent  # .../FlipForever
DATA_DIR = APP_DIR / "data"
ADDON_SRC = APP_DIR / "addon" / "FlipForever"
DB_PATH = DATA_DIR / "flipforever.db"
SETTINGS_PATH = DATA_DIR / "settings.json"
ADDON_NAME = "FlipForever"

SCHEMA = """
CREATE TABLE IF NOT EXISTS items (
    realm TEXT, id INTEGER, name TEXT, PRIMARY KEY (realm, id));
CREATE TABLE IF NOT EXISTS scans (
    realm TEXT, t INTEGER, src TEXT, nitems INTEGER, PRIMARY KEY (realm, t, src));
CREATE TABLE IF NOT EXISTS prices (
    realm TEXT, t INTEGER, id INTEGER, min INTEGER, p25 INTEGER, qty INTEGER, n INTEGER, full INTEGER);
CREATE INDEX IF NOT EXISTS prices_item ON prices (realm, id, t);
CREATE TABLE IF NOT EXISTS events (
    uniq TEXT PRIMARY KEY, realm TEXT, t INTEGER, e TEXT, id INTEGER, name TEXT,
    q INTEGER, p INTEGER, dep INTEGER, gross INTEGER, cut INTEGER, exp INTEGER, char TEXT);
CREATE INDEX IF NOT EXISTS events_realm ON events (realm, t);
CREATE TABLE IF NOT EXISTS params (
    realm TEXT, key TEXT, value TEXT, PRIMARY KEY (realm, key));
CREATE TABLE IF NOT EXISTS tuning (
    realm TEXT, t INTEGER, margin REAL, loss_rate REAL, sell_through REAL, roi REAL, note TEXT);
"""


def connect() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB_PATH, check_same_thread=False)
    con.row_factory = sqlite3.Row
    con.executescript(SCHEMA)
    return con


def get_param(con, realm, key, default=None):
    row = con.execute("SELECT value FROM params WHERE realm=? AND key=?", (realm, key)).fetchone()
    return json.loads(row[0]) if row else default


def set_param(con, realm, key, value):
    con.execute("INSERT OR REPLACE INTO params VALUES (?,?,?)", (realm, key, json.dumps(value)))


# ------------------------------------------------------------------ settings
@dataclass
class Settings:
    wow_path: str = ""            # ...\World of Warcraft\_forever_
    account: str = ""             # folder name under WTF\Account
    realm: str = ""               # "Realm - Faction"
    budget_gold: float = 500.0    # max gold to spend per shopping list
    min_margin: float = 0.20      # required profit margin (the learner adjusts around this)
    ah_cut: float = 0.05
    deposit_pct: float = 0.015    # deposit guess (fraction of value) until real deposits are learned
    hold_days: float = 2.0        # buy at most what you can sell in ~this many days
    min_sales_per_day: float = 3.0  # skip items the market buys fewer of per day
    min_sell_chance: float = 0.55   # skip items whose auctions sell less often than this
    goal_day_gold: int = 0          # gold goals: daily and weekly profit goal in gold (0 = off)
    goal_week_gold: int = 0
    deal_chart: bool = True         # Deals: price and listed amount of the selected item over 14 days
    starter_mode: bool = True       # before there's history: deep markets, price checked live in game
    starter_min_listed: int = 50    # "deep market" = at least this many units listed
    max_units_per_item: int = 200
    max_plan_items: int = 40
    min_value_copper: int = 50    # ignore items worth less than this (deposits are tiny since 17 Nov)
    min_scans: int = 3            # need at least this many price snapshots
    duration: int = 2             # 1=12h 2=24h 3=48h
    sell_farmed: bool = True      # also post items you didn't flip (farmed loot) at fair value
    autotune: bool = True
    auto_import: bool = True
    auto_build: bool = True       # after importing a new scan: build the shopping list and notify
    auto_character: bool = True   # after importing: switch to the character you played last
    auto_char_seen: str = ""      # the last character switched to automatically ("Name @ Realm")
    realm_overview: bool = True   # Dashboard: every realm side by side (with 2+ realms); double-click switches
    aging_stock: bool = True      # Inventory tab: items held over a week, today's price against what you paid
    csv_export: bool = True       # Inventory tab: Export to CSV button (trades, inventory, weekly report)
    flood_warning: bool = True    # Deals + buy list: skip items listed far above their usual amount (market flooded)
    weekly_report: bool = True    # Dashboard: best/worst flips of the week, fastest sellers, what to stop buying
    prof_cooldowns: bool = True   # Dashboard: profession cooldowns (transmutes...) of every character
    share_combat: bool = True     # share the combat helper's anonymous learning (share.py)
    share_warned: bool = False    # the warning about it was shown once
    share_id: str = ""            # random install ID for the shared summaries (not linked to anything)
    share_last: float = 0.0       # when the summary was last sent
    share_digest: str = ""        # what was sent last (nothing is sent twice)
    community: bool = True        # Community page: load updates, roadmap and ticket status from GitHub
    rules_page: bool = True       # Community, Rules: how FlipForever stays inside the game's rules (docs/RULES.md)
    gold_board: bool = False      # Community, Gold scoreboard: share total profit with the nickname (opt-in)
    nickname: str = ""            # optional name for the Top reporters board ("" = anonymous, not listed)
    blacklist: list = field(default_factory=list)
    auto_check_updates: bool = True
    beta_updates: bool = False    # also offer beta versions (pre-releases) for testing
    version_picker: bool = True   # About & updates: choose and install an older version
    addon_match_app: bool = False  # set when going back to an older version: the addon follows it once
    github_token: str = ""        # only needed while the GitHub repository is private (stays on this PC)
    character: str = ""           # selected character ("" = all characters)
    budgets: dict = field(default_factory=dict)   # "Name @ Realm - Faction" -> gold
    language: str = ""            # "" = English; otherwise a WoW language code (deDE, frFR, ...)
    window: str = ""              # last window size/position ("WxH+X+Y"), restored at start
    window_zoomed: bool = False
    shortcut_asked: bool = False  # the program offered a desktop/Start menu shortcut once

    def budget_for(self, key: str) -> float:
        return float(self.budgets.get(key, self.budget_gold))

    @classmethod
    def load(cls) -> "Settings":
        try:
            data = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
            known = {k: v for k, v in data.items() if k in cls.__dataclass_fields__}
            known["github_token"] = unprotect(known.get("github_token", ""))
            return cls(**known)
        except (OSError, ValueError, TypeError):
            return cls()

    def save(self):
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        data = asdict(self)
        data["github_token"] = protect(self.github_token)   # never stored in plain text
        SETTINGS_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")

    # derived paths
    def savedvars_path(self) -> Path | None:
        if not (self.wow_path and self.account):
            return None
        return Path(self.wow_path) / "WTF" / "Account" / self.account / "SavedVariables" / f"{ADDON_NAME}.lua"

    def addon_path(self) -> Path | None:
        return Path(self.wow_path) / "Interface" / "AddOns" / ADDON_NAME if self.wow_path else None


def find_wow_installs() -> list[str]:
    found = []
    bases = []
    for letter in string.ascii_uppercase:
        drive = f"{letter}:\\"
        if os.path.exists(drive):
            bases += [Path(drive) / "Program Files (x86)" / "World of Warcraft",
                      Path(drive) / "Program Files" / "World of Warcraft",
                      Path(drive) / "World of Warcraft",
                      Path(drive) / "Games" / "World of Warcraft"]
    for base in bases:
        try:
            if base.is_dir():
                for sub in base.iterdir():
                    if sub.name.startswith("_") and ((sub / "Interface").exists() or (sub / "WTF").exists()):
                        found.append(str(sub))
        except OSError:
            pass
    # Forever first
    found.sort(key=lambda p: (0 if "forever" in p.lower() else 1, p))
    return found


def find_accounts(wow_path: str) -> list[str]:
    root = Path(wow_path) / "WTF" / "Account"
    try:
        return sorted(p.name for p in root.iterdir() if p.is_dir() and (p / "SavedVariables").is_dir())
    except OSError:
        return []
