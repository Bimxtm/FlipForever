"""Read and post in the FlipForever Discord server through the developer's bot ("Bob").

The bot token stays on the developer's PC, outside the repository:
    %LOCALAPPDATA%\\Programs\\FlipForever\\data\\discord_bot.json   {"token": "..."}
It is never printed. Only the Discord REST API is used (no extra packages).

Usage:
    python tools/discord_bot.py channels                  list the text channels the bot can see
    python tools/discord_bot.py read <channel> [--all]    new messages since the last read (--all: last 50)
    python tools/discord_bot.py check                     new messages in #bug-reports, #beta-testing,
                                                          #suggestions and #combat-data; #combat-data is
                                                          also saved to tools/combat_inbox/<date>.txt
    python tools/discord_bot.py suggestions               new messages in #suggestions only
    python tools/discord_bot.py post <channel> <file>     post the text of <file> (- = stdin)
    python tools/discord_bot.py react <channel> <message id> [emoji]   add a check mark (or emoji)

Channels are given by name without "#". The last message read per channel is kept in
discord_state.json next to the token file, so "read" and "check" only show what is new.
"""
from __future__ import annotations

import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = pathlib.Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "FlipForever" / "data"
TOKEN_FILE = DATA / "discord_bot.json"
STATE_FILE = DATA / "discord_state.json"
INBOX = ROOT / "tools" / "combat_inbox"
API = "https://discord.com/api/v10"
UA = "DiscordBot (https://github.com/Bimxtm/FlipForever, 1.0)"
CHECK = ["bug-reports", "beta-testing", "suggestions", "combat-data"]
MAX_LEN = 2000


def token() -> str:
    try:
        t = json.loads(TOKEN_FILE.read_text(encoding="utf-8")).get("token", "").strip()
    except (OSError, ValueError):
        t = ""
    if not t:
        sys.exit(f"No bot token: put {{\"token\": \"...\"}} into {TOKEN_FILE}")
    return t


def call(method: str, path: str, body: dict | None = None):
    data = json.dumps(body).encode() if body is not None else None
    for _ in range(5):
        req = urllib.request.Request(API + path, data=data, method=method, headers={
            "Authorization": "Bot " + token(), "User-Agent": UA, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                raw = r.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            if e.code == 429:
                try:
                    wait = float(json.loads(e.read()).get("retry_after", 1))
                except ValueError:
                    wait = 1.0
                time.sleep(min(wait, 10) + 0.2)
                continue
            msg = e.read().decode("utf-8", "replace")[:200]
            sys.exit(f"Discord {method} {path.split('?')[0]}: HTTP {e.code} {msg}")
    sys.exit("Discord: rate limited, try again later")


def state() -> dict:
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def save_state(s: dict) -> None:
    DATA.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(s, indent=1), encoding="utf-8")


def channels() -> dict[str, str]:
    """name -> id of the text channels in every server the bot is in."""
    s = state()
    cached = s.get("channels")
    if cached and time.time() - s.get("channels_at", 0) < 86400:
        return cached
    out = {}
    for g in call("GET", "/users/@me/guilds") or []:
        for c in call("GET", f"/guilds/{g['id']}/channels") or []:
            if c.get("type") in (0, 5):  # text and announcement channels
                out[c["name"]] = c["id"]
    s["channels"], s["channels_at"] = out, time.time()
    save_state(s)
    return out


def channel_id(name: str) -> str:
    name = name.lstrip("#")
    ids = channels()
    if name not in ids:
        sys.exit(f"No channel #{name} (seen: {', '.join(sorted(ids))})")
    return ids[name]


def fmt(m: dict) -> str:
    who = (m.get("author") or {}).get("global_name") or (m.get("author") or {}).get("username", "?")
    text = m.get("content", "")
    for e in m.get("embeds") or []:
        text += "\n" + "\n".join(x for x in (e.get("title"), e.get("description")) if x)
    for a in m.get("attachments") or []:
        text += f"\n[attachment {a.get('filename')}]"
    return f"[{m['id']}] {m.get('timestamp', '')[:16]} {who}: {text.strip()}"


def read(name: str, all_: bool = False) -> list[dict]:
    cid = channel_id(name)
    s = state()
    last = None if all_ else s.get("last", {}).get(name)
    msgs: list[dict] = []
    if last:
        after = last
        while True:
            batch = call("GET", f"/channels/{cid}/messages?limit=100&after={after}") or []
            if not batch:
                break
            batch.sort(key=lambda m: int(m["id"]))
            msgs += batch
            after = batch[-1]["id"]
            if len(batch) < 100:
                break
    else:
        msgs = sorted(call("GET", f"/channels/{cid}/messages?limit=50") or [], key=lambda m: int(m["id"]))
    if msgs:
        s = state()
        s.setdefault("last", {})[name] = msgs[-1]["id"]
        save_state(s)
    return msgs


def show(name: str, msgs: list[dict]) -> None:
    print(f"#{name}: {len(msgs)} new")
    for m in msgs:
        print(fmt(m))


def post(name: str, text: str) -> None:
    cid = channel_id(name)
    text = text.strip()
    parts = []
    while text:
        cut = text.rfind("\n", 0, MAX_LEN) if len(text) > MAX_LEN else len(text)
        cut = cut if cut > 0 else MAX_LEN
        parts.append(text[:cut])
        text = text[cut:].lstrip("\n")
    if not parts:
        sys.exit("Nothing to post")
    for p in parts:
        m = call("POST", f"/channels/{cid}/messages",
                 {"content": p, "allowed_mentions": {"parse": ["everyone"] if "@everyone" in p else []}})
    print(f"posted in #{name} ({len(parts)} message(s), last id {m['id']})")


def react(name: str, mid: str, emoji: str = "✅") -> None:
    cid = channel_id(name)
    call("PUT", f"/channels/{cid}/messages/{mid}/reactions/{urllib.parse.quote(emoji)}/@me")
    print(f"reacted {emoji} on {mid} in #{name}")


def main(argv: list[str]) -> None:
    if not argv:
        sys.exit(__doc__)
    cmd, rest = argv[0], argv[1:]
    if cmd == "channels":
        for n, i in sorted(channels().items()):
            print(f"#{n} {i}")
    elif cmd == "read" and rest:
        show(rest[0], read(rest[0], "--all" in rest))
    elif cmd in ("check", "suggestions"):
        for name in (CHECK if cmd == "check" else ["suggestions"]):
            msgs = read(name)
            show(name, msgs)
            if name == "combat-data" and msgs:
                INBOX.mkdir(parents=True, exist_ok=True)
                f = INBOX / (time.strftime("%Y-%m-%d") + ".txt")
                with f.open("a", encoding="utf-8") as out:
                    for m in msgs:
                        out.write(fmt(m) + "\n")
                print(f"saved to {f.relative_to(ROOT)}")
    elif cmd == "post" and len(rest) >= 2:
        text = sys.stdin.read() if rest[1] == "-" else pathlib.Path(rest[1]).read_text(encoding="utf-8")
        post(rest[0], text)
    elif cmd == "react" and len(rest) >= 2:
        react(rest[0], rest[1], rest[2] if len(rest) > 2 else "✅")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    main(sys.argv[1:])
