"""Community page: updates, roadmap, bug tickets, suggestions and the top reporters board.

The public status lives in status/community.json in the GitHub repository and is read from there
(a copy is kept so it works offline). Bug reports and suggestions are sent as text messages to the
private FlipForever channel (same path as share.py) with a random report ID, so each player can see the
status of their own reports. Nothing personal is sent: the text, the app and addon version and, only if
the player set one, a nickname for the Top reporters board.

On the developer's PC (a file data/owner.key exists) the page also shows a private section with the
suggestions waiting for approval and the approved suggestion list the work is planned from.
"""
from __future__ import annotations

import json
import time
import urllib.request
import uuid

from . import share, store
from .version import GITHUB_REPO, VERSION

FEED_URL = f"https://raw.githubusercontent.com/{GITHUB_REPO}/main/status/community.json"
CACHE = store.DATA_DIR / "community_cache.json"
MINE = store.DATA_DIR / "my_reports.json"
OWNER_KEY = store.DATA_DIR / "owner.key"
OWNER_SUGGESTIONS = store.DATA_DIR / "owner_suggestions.json"
OWNER_INBOX = store.DATA_DIR / "owner_inbox.json"
MAX_TEXT = 1500

STATUS = {
    "reported": "Reported",
    "confirmed": "Confirmed",
    "in_progress": "In progress",
    "fixed": "Fixed",
    "not_reproducible": "Not reproducible",
    "wont_fix": "Won't fix",
}
COUNTS = ("confirmed", "in_progress", "fixed")     # what counts on the Top reporters board


def _load(path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def _save(path, data):
    store.DATA_DIR.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=1, ensure_ascii=False), encoding="utf-8")


def fetch(timeout: float = 8) -> dict:
    """The newest status from GitHub, or the last copy when offline."""
    try:
        req = urllib.request.Request(FEED_URL + f"?t={int(time.time() // 300)}", headers={"User-Agent": "FlipForever"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            data = json.loads(r.read().decode("utf-8"))
        if isinstance(data, dict):
            _save(CACHE, data)
            return data
    except Exception:  # noqa: BLE001  - offline or GitHub unreachable
        pass
    return _load(CACHE, {})


def status_label(ticket: dict) -> str:
    label = STATUS.get(ticket.get("status", "reported"), "Reported")
    if ticket.get("status") == "fixed" and ticket.get("version"):
        label += " in " + ticket["version"]
    return label


def leaderboard(feed: dict, limit: int = 10) -> list[tuple[str, int, int]]:
    """(nickname, confirmed bugs, shipped suggestions), best first. Developers are never listed."""
    skip = {n.lower() for n in feed.get("developers", [])} | {"alix"}
    score: dict[str, list[int]] = {}
    for t in feed.get("tickets", []):
        nick = (t.get("nick") or "").strip()
        if nick and nick.lower() not in skip and t.get("status") in COUNTS:
            score.setdefault(nick, [0, 0])[0] += 1
    for s in feed.get("suggestions", []):
        nick = (s.get("nick") or "").strip()
        if nick and nick.lower() not in skip and s.get("status") == "shipped":
            score.setdefault(nick, [0, 0])[1] += 1
    rows = [(n, b, s) for n, (b, s) in score.items()]
    rows.sort(key=lambda r: (-(r[1] * 2 + r[2]), r[0].lower()))
    return rows[:limit]


def my_reports() -> list[dict]:
    return _load(MINE, [])


def submit(kind: str, text: str, nick: str = "", extra: str = "", poster=None) -> str | None:
    """Send a bug report or suggestion. Returns the report ID, or None if it could not be sent."""
    text = (text or "").strip()[:MAX_TEXT]
    if not text or kind not in ("bug", "suggestion"):
        return None
    rid = uuid.uuid4().hex[:8]
    body = {"f": 1, "r": rid, "k": kind, "v": VERSION, "n": (nick or "").strip()[:24], "t": text}
    if extra:
        body["x"] = extra[:400]
    head = "Bug report" if kind == "bug" else "Suggestion"
    msg = head + "\n```json\n" + json.dumps(body, ensure_ascii=False, separators=(",", ":")) + "\n```"
    try:
        ok = (poster or share.post)(msg)
    except Exception:  # noqa: BLE001
        ok = False
    if not ok:
        return None
    mine = my_reports()
    mine.append({"r": rid, "k": kind, "t": text, "time": int(time.time())})
    _save(MINE, mine[-200:])
    return rid


def is_owner() -> bool:
    return OWNER_KEY.exists()


def owner_lists() -> tuple[list, list]:
    """(waiting for approval, approved suggestion list) on the developer's PC."""
    return _load(OWNER_INBOX, []), _load(OWNER_SUGGESTIONS, [])


def owner_add(text: str, source: str = "own") -> None:
    items = _load(OWNER_SUGGESTIONS, [])
    items.append({"id": uuid.uuid4().hex[:8], "text": text.strip(), "source": source,
                  "date": time.strftime("%Y-%m-%d"), "status": "open"})
    _save(OWNER_SUGGESTIONS, items)


def owner_decide(item_id: str, approve: bool) -> None:
    """Approve (moves it into the suggestion list) or decline (drops it) a waiting suggestion."""
    inbox, items = owner_lists()
    keep = []
    for it in inbox:
        if it.get("id") != item_id:
            keep.append(it)
        elif approve:
            items.append({"id": it.get("id"), "r": it.get("r", ""), "nick": it.get("nick", ""),
                          "text": it.get("text", ""), "source": "user", "date": time.strftime("%Y-%m-%d"),
                          "status": "open"})
    _save(OWNER_INBOX, keep)
    _save(OWNER_SUGGESTIONS, items)


def owner_remove(item_id: str) -> None:
    _save(OWNER_SUGGESTIONS, [it for it in _load(OWNER_SUGGESTIONS, []) if it.get("id") != item_id])
