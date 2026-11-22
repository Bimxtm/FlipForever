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
import re
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
OWNER_DECISIONS = store.DATA_DIR / "owner_decisions.json"
DECLINED = store.DATA_DIR / "declined_reports.json"
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


SENT_GAME = store.DATA_DIR / "sent_game_reports.json"


def forward_game_reports(reports: list, nick: str = "", poster=None) -> int:
    """Send the reports typed in game that were not sent yet. Returns how many went out."""
    sent = set(_load(SENT_GAME, []))
    n = 0
    for r in reports or []:
        if not isinstance(r, dict) or r.get("k") not in ("bug", "suggestion"):
            continue
        key = f"{r.get('time', 0)}:{str(r.get('t', ''))[:40]}"
        if key in sent:
            continue
        extra = ""
        if r.get("k") == "bug":
            extra = "addon {v}, {c} {l}, {z}; errors: {e}".format(v=r.get("v", "?"), c=r.get("class", "?"),
                                                                  l=r.get("level", "?"), z=r.get("zone", "?"),
                                                                  e=r.get("errors") or "none")
        if submit(r["k"], str(r.get("t", "")), nick, extra, poster):
            sent.add(key)
            n += 1
        else:
            break                     # no connection: try again after the next import
    if n:
        _save(SENT_GAME, sorted(sent)[-500:])
    return n


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
            continue
        # remembered for the next status update: bugs become Confirmed / Not reproducible, declined
        # suggestions are never offered again
        decisions = _load(OWNER_DECISIONS, [])
        decisions.append({"r": it.get("r", ""), "kind": it.get("kind", "suggestion"), "approve": approve,
                          "date": time.strftime("%Y-%m-%d")})
        _save(OWNER_DECISIONS, decisions[-500:])
        if it.get("kind") == "bug":
            continue
        if not approve:
            _save(DECLINED, (_load(DECLINED, []) + [it.get("r", "")])[-1000:])
        elif approve:
            items.append({"id": it.get("id"), "r": it.get("r", ""), "nick": it.get("nick", ""),
                          "text": it.get("text", ""), "source": "user", "date": time.strftime("%Y-%m-%d"),
                          "status": "open"})
    _save(OWNER_INBOX, keep)
    _save(OWNER_SUGGESTIONS, items)


def owner_remove(item_id: str) -> None:
    _save(OWNER_SUGGESTIONS, [it for it in _load(OWNER_SUGGESTIONS, []) if it.get("id") != item_id])


def owner_move(item_id: str, delta: int) -> None:
    """Move a suggestion up (-1) or down (+1); the list order is the work order."""
    items = _load(OWNER_SUGGESTIONS, [])
    i = next((k for k, it in enumerate(items) if it.get("id") == item_id), None)
    if i is None:
        return
    j = max(0, min(len(items) - 1, i + delta))
    items.insert(j, items.pop(i))
    _save(OWNER_SUGGESTIONS, items)


def owner_focus(item_id: str) -> None:
    """Toggle "focus first" on a suggestion; focused ones move to the top and are worked on first."""
    items = _load(OWNER_SUGGESTIONS, [])
    it = next((x for x in items if x.get("id") == item_id), None)
    if not it:
        return
    it["focus"] = not it.get("focus")
    items.remove(it)
    n = sum(1 for x in items if x.get("focus"))
    items.insert(n if it["focus"] else n, it)
    _save(OWNER_SUGGESTIONS, items)


BUG_FOCUS = store.DATA_DIR / "owner_bug_focus.json"   # report IDs of bugs to fix first, in order


def owner_bug_focus() -> list:
    return _load(BUG_FOCUS, [])


def owner_bug_focus_toggle(r: str) -> None:
    focus = owner_bug_focus()
    if r in focus:
        focus.remove(r)
    elif r:
        focus.append(r)
    _save(BUG_FOCUS, focus)


def owner_set_ticket(r: str, status: str, version: str = "") -> None:
    """A ticket's new status; the next status update publishes it on the Bug reports page."""
    if status not in STATUS or not r:
        return
    decisions = _load(OWNER_DECISIONS, [])
    decisions.append({"r": r, "kind": "bug", "status": status, "version": version.strip()[:20],
                      "date": time.strftime("%Y-%m-%d")})
    _save(OWNER_DECISIONS, decisions[-500:])


# Reports into the Developer page ------------------------------------------------------------------
# Players' reports travel through the private report channel (share.post). The developer's app
# reads them back with the report reader (a bot token in report_reader.json, never in the repo) or
# from pasted text, and puts them straight into "Waiting for approval". The raw text is kept in
# report_inbox\ so the status update turns bugs into public tickets.
READER = store.DATA_DIR / "report_reader.json"        # {"token": "...", "channel": "combat-data"}
READER_STATE = store.DATA_DIR / "report_reader_state.json"
REPORT_INBOX = store.DATA_DIR / "report_inbox"
_BLOCK = re.compile(r"\{[^{}]*\"k\"\s*:\s*\"(?:bug|suggestion)\"[^{}]*\}")


def parse_reports(text: str) -> list[dict]:
    out = []
    for m in _BLOCK.finditer(text or ""):
        try:
            d = json.loads(m.group(0))
        except ValueError:
            continue
        if isinstance(d.get("r"), str) and isinstance(d.get("t"), str):
            out.append(d)
    return out


REPORT_ARCHIVE = store.DATA_DIR / "owner_reports.json"   # every report ever read: r -> details (private)


def owner_archive() -> dict:
    return _load(REPORT_ARCHIVE, {})


def owner_take_reports(text: str) -> tuple[int, int]:
    """New bug reports and suggestions from text -> Waiting for approval. Returns (bugs, suggestions)."""
    reports = parse_reports(text)
    if not reports:
        return 0, 0
    archive = owner_archive()
    for d in reports:
        archive.setdefault(d["r"], {"kind": d.get("k", ""), "nick": d.get("n", ""), "text": d["t"],
                                    "extra": d.get("x", ""), "version": d.get("v", ""), "date": time.strftime("%Y-%m-%d")})
    _save(REPORT_ARCHIVE, archive)
    REPORT_INBOX.mkdir(parents=True, exist_ok=True)
    with open(REPORT_INBOX / (time.strftime("%Y-%m-%d") + ".txt"), "a", encoding="utf-8") as f:
        f.write(text.strip() + "\n")
    inbox, items = owner_lists()
    seen = {i.get("r") for i in inbox} | {i.get("r") for i in items} | set(_load(DECLINED, []))
    seen |= {d.get("r") for d in _load(OWNER_DECISIONS, [])}
    bugs = sugg = 0
    for d in reports:
        if d["r"] in seen:
            continue
        seen.add(d["r"])
        is_bug = d.get("k") == "bug"
        inbox.append({"id": d["r"], "r": d["r"], "kind": "bug" if is_bug else "suggestion", "nick": d.get("n", ""),
                      "text": d["t"] + (f"  [{d['x']}]" if is_bug and d.get("x") else "")
                      + (f"  (v{d['v']})" if d.get("v") else "")})
        bugs += is_bug
        sugg += not is_bug
    _save(OWNER_INBOX, inbox)
    return bugs, sugg


def _reader_cfg() -> dict:
    # its own file, else the token of the Discord bot from docs/DISCORD_BOT.md
    return _load(READER, {}) or _load(store.DATA_DIR / "discord_bot.json", {})


def reader_ready() -> bool:
    return bool(_reader_cfg().get("token"))


def _discord(path: str, token: str):
    req = urllib.request.Request("https://discord.com/api/v10" + path,
                                 headers={"Authorization": "Bot " + token, "User-Agent": "FlipForever"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read().decode("utf-8"))


def owner_fetch_reports(api=None) -> tuple[int, int] | None:
    """Read new messages from the report channel. None when the reader isn't set up or unreachable."""
    cfg = _reader_cfg()
    token = (cfg.get("token") or "").strip()
    if not token:
        return None
    api = api or (lambda p: _discord(p, token))
    st = _load(READER_STATE, {})
    try:
        cid = st.get("channel_id")
        if not cid:
            want = (cfg.get("channel") or "combat-data").lstrip("#")
            for g in api("/users/@me/guilds") or []:
                for c in api(f"/guilds/{g['id']}/channels") or []:
                    if c.get("name") == want and c.get("type") in (0, 5):
                        cid = c["id"]
            if not cid:
                return None
        after = st.get("last")
        msgs = api(f"/channels/{cid}/messages?limit=100" + (f"&after={after}" if after else "")) or []
    except Exception:  # noqa: BLE001  - offline, wrong token, no access
        return None
    parts = []
    for m in msgs:
        parts.append(m.get("content", ""))
        parts += [e.get("description", "") for e in m.get("embeds", []) or []]
    if msgs:
        st["last"] = max((m["id"] for m in msgs), key=int)
    st["channel_id"] = cid
    _save(READER_STATE, st)
    return owner_take_reports("\n".join(parts))
