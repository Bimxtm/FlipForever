"""Sharing what the combat helper learned, so every release starts from what worked for all players.

Only an anonymous summary is sent: class:build:level-band keys, the spell orders compared and their
fight counts, kills, fight time, deaths and health lost. No character, realm or account names, no
chat, nothing else. A random install ID (not linked to anything) lets the merge keep only the newest
summary per install. Sending happens at most once a day, only when something changed, and only while
both switches are on: the app's Settings and the addon's Settings, Features
("Share anonymous combat data").

The summaries go as text messages to a private channel on the FlipForever Discord. When a release is
built, tools/merge_combat_learning.py merges them into the addon (Advisor/CombatShared.lua).
"""
from __future__ import annotations

import hashlib
import json
import time
import urllib.request
import uuid

# Where the summaries go: the private #combat-data channel on the FlipForever Discord. The address
# is kept out of the repository: it lives in _webhook.py next to this file (ignored by git) and is
# built into the app. Without it, nothing is sent.
try:
    from ._webhook import WEBHOOK
except ImportError:
    WEBHOOK = ""
FORMAT = 1
MAX_MESSAGE = 1900       # Discord allows 2000 characters per message
MAX_MESSAGES = 12        # per send
MIN_GAP = 20 * 3600      # at most about once a day

WARNING = ("FlipForever collects anonymous combat data to make the combat helper better for everyone: "
           "your class, build and level band, the spell orders the helper compared, and how long its fights "
           "took. No names, no chat, nothing else.\n\nYou can switch this off any time: in the app under "
           "Settings (\"Share anonymous combat data\"), or in game under Settings, Features.")

FIELDS = ("n", "kills", "time", "deaths", "hp")


def _num(v):
    try:
        f = float(v)
    except (TypeError, ValueError):
        return 0
    return int(f) if f == int(f) else round(f, 1)


def summarize(learn: dict) -> dict:
    """{key: {base order: {variant: {n, kills, time, deaths, hp}}}} from the addon's combatLearn."""
    out = {}
    for key, store in (learn or {}).items():
        if not isinstance(store, dict) or not isinstance(key, str) or key.count(":") != 2:
            continue
        for sig, b in (store.get("bases") or {}).items():
            variants = (b or {}).get("variants") if isinstance(b, dict) else None
            if not isinstance(variants, dict):
                continue
            vs = {}
            for name, v in variants.items():
                if isinstance(v, dict) and _num(v.get("n")) > 0:
                    vs[str(name)] = {f: _num(v.get(f)) for f in FIELDS}
            if vs:
                out.setdefault(key, {})[str(sig)] = vs
    return out


def messages(summary: dict, install: str) -> list[str]:
    """One message per class/build/band key (split further when an entry is too long)."""
    out = []
    for key in sorted(summary):
        for sig, vs in sorted(summary[key].items()):
            body = json.dumps({"f": FORMAT, "i": install, "k": key, "s": sig, "v": vs},
                              separators=(",", ":"), sort_keys=True)
            if len(body) + 12 <= MAX_MESSAGE:
                out.append("```json\n" + body + "\n```")
    return out[:MAX_MESSAGES]


def due(settings, summary: dict, now: float | None = None) -> bool:
    if not summary:
        return False
    now = now or time.time()
    digest = hashlib.sha1(json.dumps(summary, sort_keys=True).encode()).hexdigest()
    if digest == settings.share_digest:
        return False
    return now - (settings.share_last or 0) >= MIN_GAP


def install_id(settings) -> str:
    if not settings.share_id:
        settings.share_id = uuid.uuid4().hex[:12]
        settings.save()
    return settings.share_id


def post(text: str, url: str | None = None, timeout: float = 10) -> bool:
    url = url or WEBHOOK
    if not url:
        return False
    data = json.dumps({"content": text, "username": "FlipForever combat data",
                       "allowed_mentions": {"parse": []}}).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json",
                                                         "User-Agent": "FlipForever"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return 200 <= r.status < 300


def send(settings, learn: dict, allowed_in_game: bool, poster=post, now: float | None = None) -> int:
    """Send the summary if both switches allow it and it is due. Returns how many messages went out."""
    if not settings.share_combat or not allowed_in_game:
        return 0
    summary = summarize(learn)
    if not due(settings, summary, now):
        return 0
    sent = 0
    for msg in messages(summary, install_id(settings)):
        try:
            if poster(msg):
                sent += 1
        except Exception:  # noqa: BLE001  - no network: try again another day
            break
        time.sleep(0 if poster is not post else 1.2)   # stay well under Discord's rate limit
    if sent:
        settings.share_last = now or time.time()
        settings.share_digest = hashlib.sha1(json.dumps(summary, sort_keys=True).encode()).hexdigest()
        settings.save()
    return sent
