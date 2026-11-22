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
    for f in sorted(INBOX.glob("*.txt")):
        reports += parse(f.read_text(encoding="utf-8", errors="replace"))
    feed = load(FEED, {})
    tickets = feed.setdefault("tickets", [])
    owner_inbox_path = pathlib.Path(args.data) / "owner_inbox.json"
    owner_list = load(pathlib.Path(args.data) / "owner_suggestions.json", [])
    inbox = load(owner_inbox_path, [])
    seen = {t.get("r") for t in tickets} | {s.get("r") for s in feed.get("suggestions", [])} \
        | {i.get("r") for i in inbox} | {i.get("r") for i in owner_list}
    seen |= set(load(pathlib.Path(args.data) / "declined_reports.json", []))
    bugs = sugg = 0
    for d in reports:
        if d["r"] in seen:
            continue
        seen.add(d["r"])
        if d.get("k") == "bug":
            tickets.append({"id": f"BUG-{len(tickets) + 1:03d}", "r": d["r"], "nick": d.get("n", ""),
                            "title": d["t"][:140], "status": "reported", "reported": time.strftime("%Y-%m-%d"),
                            "version": "", "from_version": d.get("v", "")})
            # full text and attached info stay private, for the developer only
            inbox.append({"id": d["r"], "r": d["r"], "kind": "bug", "nick": d.get("n", ""),
                          "text": d["t"] + (f"  [{d['x']}]" if d.get("x") else "")})
            bugs += 1
        else:
            inbox.append({"id": d["r"], "r": d["r"], "kind": "suggestion", "nick": d.get("n", ""), "text": d["t"]})
            sugg += 1
    # the developer's Confirm / Not reproducible choices from the app's Developer page
    changed = bugs
    by_r = {t.get("r"): t for t in tickets}
    for dec in load(pathlib.Path(args.data) / "owner_decisions.json", []):
        t = by_r.get(dec.get("r"))
        if dec.get("kind") == "bug" and t and t.get("status") == "reported":
            t["status"] = "confirmed" if dec.get("approve") else "not_reproducible"
            changed += 1
    if changed:
        feed["updated"] = time.strftime("%Y-%m-%d")
        save(FEED, feed)
    if bugs or sugg:
        save(owner_inbox_path, inbox)
    print(f"new bug tickets: {bugs}, new suggestions waiting for approval: {sugg}")
    return bugs, sugg


if __name__ == "__main__":
    main()
