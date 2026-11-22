"""Turn the bug reports and suggestions sent from the app into tickets.

Reads the channel text copies in tools/combat_inbox/*.txt (the same private channel as the combat
summaries), and:
- adds each new bug report to status/community.json as a ticket (BUG-001, ...) with status "reported";
- puts each new suggestion into the developer's approval list (owner_inbox.json in the app's data
  folder on the developer's PC). Approved ones move into the suggestion list from the app.

Reports are matched by their random report ID, so running it again adds nothing twice.
Usage: python tools/community_inbox.py [--data <app data folder>]
       python tools/community_inbox.py --idea "<text>"   (an idea of our own, waits for approval too)
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
INBOX = ROOT / "tools" / "combat_inbox"
FEED = ROOT / "status" / "community.json"
DEFAULT_DATA = pathlib.Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "FlipForever" / "data"
BLOCK = re.compile(r"\{[^{}]*\"k\"\s*:\s*\"(?:bug|suggestion)\"[^{}]*\}")


def parse(text: str) -> list[dict]:
    out = []
    for m in BLOCK.finditer(text):
        try:
            d = json.loads(m.group(0))
        except ValueError:
            continue
        if isinstance(d.get("r"), str) and isinstance(d.get("t"), str):
            out.append(d)
    return out


def load(path: pathlib.Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def save(path: pathlib.Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


GOLD = re.compile(r"\{[^{}]*\"k\"\s*:\s*\"gold\"[^{}]*\}")
MAX_GOLD = 5_000_000


def sync_scores(feed: dict, text: str) -> int:
    """Gold scoreboard: the latest score per install (r) with its nickname, from "Gold score" lines."""
    scores = feed.setdefault("scores", [])
    by_r = {s.get("r"): s for s in scores}
    changed = 0
    for m in GOLD.finditer(text):
        try:
            d = json.loads(m.group(0))
        except ValueError:
            continue
        if not (isinstance(d.get("r"), str) and isinstance(d.get("g"), int) and 0 <= d["g"] <= MAX_GOLD
                and isinstance(d.get("n"), str) and d["n"].strip()):
            continue
        entry = {"r": d["r"][:16], "nick": d["n"].strip()[:24], "gold": d["g"]}
        old = by_r.get(entry["r"])
        if old is None:
            scores.append(entry)
            by_r[entry["r"]] = entry
            changed += 1
        elif old.get("nick") != entry["nick"] or old.get("gold") != entry["gold"]:
            old.update(entry)
            changed += 1
    return changed


def _public_status(status: str) -> tuple[str, str] | None:
    s = (status or "open").strip().lower()
    if s.startswith("shipped"):
        return "shipped", s.replace("shipped in", "").replace("shipped", "").strip()
    if s == "in progress":
        return "in_progress", ""
    if s == "open":
        return "planned", ""
    return None   # done (internal), declined and anything else stays private


def sync_approved(feed: dict, owner_list: list) -> int:
    """Approved suggestions show on the public Suggestions page with their status. Each item's
    "public" text is used (a clean wording written for players); items marked "hidden" never show."""
    pub = feed.setdefault("suggestions", [])
    by_r = {s.get("r"): s for s in pub if s.get("r")}
    changed = 0
    for item in owner_list:
        rid = item.get("id")
        st = _public_status(item.get("status", ""))
        if not rid or item.get("hidden") or st is None:
            if rid in by_r:
                pub.remove(by_r.pop(rid))
                changed += 1
            continue
        text = (item.get("public") or item.get("text", "")).strip()
        if text.startswith("Idea: "):
            text = text[6:]
        entry = {"r": rid, "text": text[:160], "status": st[0], "version": st[1]}
        if item.get("nick"):
            entry["nick"] = item["nick"]
        old = by_r.get(rid)
        if old is None:
            pub.append(entry)
            by_r[rid] = entry
            changed += 1
        elif any(old.get(k) != v for k, v in entry.items()):
            old.update(entry)
            changed += 1
    return changed


def main(argv=None) -> tuple[int, int]:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=str(DEFAULT_DATA))
    ap.add_argument("--idea", help="add a feature idea of the developer's own to the approval list")
    args = ap.parse_args(argv)
    if args.idea:
        path = pathlib.Path(args.data) / "owner_inbox.json"
        inbox = load(path, [])
        rid = "idea-" + time.strftime("%Y%m%d%H%M%S")
        inbox.append({"id": rid, "r": rid, "kind": "suggestion", "nick": "", "text": "Idea: " + args.idea.strip()})
        save(path, inbox)
        print("idea waiting for approval:", rid)
        return 0, 1
    reports = []
    texts = []
    # channel copies here, and what the developer's app read itself (Developer page, Get new reports)
    for f in sorted(INBOX.glob("*.txt")) + sorted((pathlib.Path(args.data) / "report_inbox").glob("*.txt")):
        texts.append(f.read_text(encoding="utf-8", errors="replace"))
        reports += parse(texts[-1])
    feed = load(FEED, {})
    tickets = feed.setdefault("tickets", [])
    owner_inbox_path = pathlib.Path(args.data) / "owner_inbox.json"
    owner_list = load(pathlib.Path(args.data) / "owner_suggestions.json", [])
    inbox = load(owner_inbox_path, [])
    decisions = load(pathlib.Path(args.data) / "owner_decisions.json", [])
    ticket_rs = {t.get("r") for t in tickets}
    # already in the developer's lists (the app may have put them there itself) or decided
    known = {s.get("r") for s in feed.get("suggestions", [])} | {i.get("r") for i in inbox} \
        | {i.get("r") for i in owner_list} | {d.get("r") for d in decisions}
    known |= set(load(pathlib.Path(args.data) / "declined_reports.json", []))
    bugs = sugg = 0
    for d in reports:
        if d.get("k") == "bug":
            if d["r"] not in ticket_rs:
                ticket_rs.add(d["r"])
                tickets.append({"id": f"BUG-{len(tickets) + 1:03d}", "r": d["r"], "nick": d.get("n", ""),
                                "title": d["t"][:140], "status": "reported", "reported": time.strftime("%Y-%m-%d"),
                                "version": "", "from_version": d.get("v", "")})
                bugs += 1
            if d["r"] not in known:
                # full text and attached info stay private, for the developer only
                inbox.append({"id": d["r"], "r": d["r"], "kind": "bug", "nick": d.get("n", ""),
                              "text": d["t"] + (f"  [{d['x']}]" if d.get("x") else "")})
        elif d["r"] not in known:
            inbox.append({"id": d["r"], "r": d["r"], "kind": "suggestion", "nick": d.get("n", ""), "text": d["t"]})
            sugg += 1
        known.add(d["r"])
    # the developer's choices from the app's Developer page: Confirm / Not reproducible, and set statuses
    changed = bugs
    by_r = {t.get("r"): t for t in tickets}
    for dec in decisions:
        t = by_r.get(dec.get("r"))
        if dec.get("kind") != "bug" or not t:
            continue
        if dec.get("status"):
            new = (dec["status"], dec.get("version", "") if dec["status"] == "fixed" else t.get("version", ""))
            if (t.get("status"), t.get("version", "")) != new:
                t["status"], t["version"] = new
                changed += 1
        elif t.get("status") == "reported":
            t["status"] = "confirmed" if dec.get("approve") else "not_reproducible"
            changed += 1
    changed += sync_approved(feed, owner_list)
    changed += sync_scores(feed, "\n".join(texts))
    if changed:
        feed["updated"] = time.strftime("%Y-%m-%d")
        save(FEED, feed)
    save(owner_inbox_path, inbox)
    print(f"new bug tickets: {bugs}, new suggestions waiting for approval: {sugg}")
    return bugs, sugg


if __name__ == "__main__":
    main()
