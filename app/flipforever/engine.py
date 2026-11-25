"""The brain: imports game data, models the market, learns from your own trades,
and turns all of it into a shopping list + sell list for the in-game addon."""
from __future__ import annotations

import hashlib
import json
import math
import shutil
import statistics
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from pathlib import Path

from . import luaio
from .store import ADDON_SRC, DATA_DIR, Settings, get_param, set_param

DAY = 86400
HISTORY_DAYS = 14
HALF_LIFE = 3 * DAY
FULL_SOURCES = ("full", "full-browse")


def money(copper, short=False) -> str:
    copper = int(round(copper or 0))
    sign = "-" if copper < 0 else ""
    copper = abs(copper)
    g, s, c = copper // 10000, (copper // 100) % 100, copper % 100
    if g:
        return f"{sign}{g:,}g {s}s" if short or g >= 100 else f"{sign}{g}g {s}s {c}c"
    if s:
        return f"{sign}{s}s {c}c"
    return f"{sign}{c}c"


def _as_list(v):
    if v is None:
        return []
    if isinstance(v, list):
        return v
    if isinstance(v, dict):
        return [v[k] for k in sorted(v, key=lambda k: (not isinstance(k, int), k))]
    return []


# ============================================================== import
def import_savedvars(con, path: Path) -> dict:
    data = luaio.load_savedvariables(path)
    db = data.get("FlipForeverDB") or {}
    summary = {"scans": 0, "events": 0, "realms": []}
    for realm, r in (db.get("realms") or {}).items():
        if not isinstance(r, dict):
            continue
        if str(realm).startswith(" - "):
            # held by the addon while the game had no realm name yet; it moves to the real realm at the
            # next login, so importing it here would show a nameless realm and count it twice later
            continue
        summary["realms"].append(realm)
        names = r.get("names") or {}
        if isinstance(names, list):
            names = {i + 1: v for i, v in enumerate(names)}
        con.executemany("INSERT OR REPLACE INTO items VALUES (?,?,?)",
                        [(realm, int(k), str(v)) for k, v in names.items()])
        by_name = {str(v): int(k) for k, v in names.items()}
        chars = r.get("chars")
        if isinstance(chars, dict) and chars:
            known = get_param(con, realm, "chars", {})
            for cname, info in chars.items():
                if isinstance(info, dict):
                    known[str(cname)] = {k: info.get(k) for k in ("money", "level", "class", "race", "t", "build", "advisor")}
                    cds = info.get("cooldowns")
                    if isinstance(cds, (dict, list)):
                        vals = cds.values() if isinstance(cds, dict) else cds
                        known[str(cname)]["cooldowns"] = [
                            {"name": str(e.get("name")), "ready": int(e.get("ready") or 0)}
                            for e in vals if isinstance(e, dict) and e.get("name") and e.get("ready")]
            set_param(con, realm, "chars", known)
        for sc in _as_list(r.get("scans")):
            try:
                t, src = int(sc["t"]), str(sc.get("src", "full"))
            except (KeyError, TypeError, ValueError):
                continue
            cur = con.execute("INSERT OR IGNORE INTO scans VALUES (?,?,?,?)", (realm, t, src, int(sc.get("n") or 0)))
            if cur.rowcount == 0:
                continue
            full = 1 if src in FULL_SOURCES else 0
            rows = []
            for part in str(sc.get("d") or "").split(";"):
                f = part.split(":")
                if len(f) >= 5:
                    try:
                        rows.append((realm, t, int(f[0]), int(f[1]), int(f[2]), int(f[3]), int(f[4]), full))
                    except ValueError:
                        pass
            con.executemany("INSERT INTO prices VALUES (?,?,?,?,?,?,?,?)", rows)
            summary["scans"] += 1
        for ev in _as_list(r.get("log")):
            if not isinstance(ev, dict) or "e" not in ev:
                continue
            uniq = hashlib.sha1((realm + json.dumps(ev, sort_keys=True, default=str)).encode()).hexdigest()
            item_id = ev.get("id") or by_name.get(str(ev.get("name") or ""))
            cur = con.execute(
                "INSERT OR IGNORE INTO events VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (uniq, realm, int(ev.get("t") or 0), str(ev["e"]), item_id, ev.get("name"),
                 ev.get("q"), ev.get("p"), ev.get("dep"), ev.get("gross"), ev.get("cut"), ev.get("exp"),
                 ev.get("char")))
            summary["events"] += cur.rowcount
    # The combat helper's learning (anonymous: class/build/band keys and spell orders only) and
    # whether the player lets the app share it (Settings, Features in game)
    learn = db.get("combatLearn")
    summary["combat"] = learn if isinstance(learn, dict) else {}
    settings_in_game = db.get("settings") if isinstance(db.get("settings"), dict) else {}
    summary["combat_share"] = settings_in_game.get("combatShare") is not False
    # bug reports and suggestions typed in game (/ff bug, /ff suggest); the app sends them (community.py)
    reports = db.get("reports")
    summary["reports"] = list(reports.values()) if isinstance(reports, dict) else (reports or [])
    # Gathering (the merged Ore Farmer module): stored next to FlipForever's data now;
    # before the merge it lived in its own OreFarmer.lua file.
    gather = data.get("OreFarmerDB")
    if not isinstance(gather, dict):
        legacy = Path(path).with_name("OreFarmer.lua")
        if legacy.exists():
            try:
                gather = luaio.load_savedvariables(legacy).get("OreFarmerDB")
            except (OSError, luaio.LuaError):
                gather = None
    if isinstance(gather, dict):
        set_param(con, ACCOUNT, "gathering", {
            "zoneStats": {str(k): v for k, v in (gather.get("zoneStats") or {}).items() if isinstance(v, dict)},
            "yield": {str(k): v for k, v in (gather.get("yield") or {}).items() if isinstance(v, dict)},
            "nodes": {str(k): len(v) if isinstance(v, (list, dict)) else 0 for k, v in (gather.get("nodes") or {}).items()},
            "speed": gather.get("speed"),
            "mapNames": {str(k): v for k, v in (db.get("mapNames") or {}).items()},
        })
        summary["gathering"] = True
    con.commit()
    return summary


ACCOUNT = "_account"


def gathering(con, model: dict) -> dict:
    """Gathering stats per zone and per resource, valued with FlipForever's own prices."""
    g = get_param(con, ACCOUNT, "gathering", None)
    if not g:
        return {"zones": [], "resources": []}
    names = g.get("mapNames", {})
    zones = []
    for mid, z in g.get("zoneStats", {}).items():
        active, value, nodes = float(z.get("active") or 0), float(z.get("value") or 0), int(z.get("nodes") or 0)
        rate = value / active * 3600 if active >= 600 and nodes >= 10 else None
        zones.append({"zone": names.get(mid, f"map {mid}"), "minutes": active / 60, "value": value, "nodes": nodes,
                      "rate": rate, "spots": g.get("nodes", {}).get(mid, 0)})
    for mid, count in g.get("nodes", {}).items():
        if mid not in g.get("zoneStats", {}):
            zones.append({"zone": names.get(mid, f"map {mid}"), "minutes": 0, "value": 0, "nodes": 0, "rate": None, "spots": count})
    zones.sort(key=lambda z: -(z["rate"] or 0))
    resources = []
    for key, y in g.get("yield", {}).items():
        visits = int(y.get("visits") or 0)
        items = y.get("items") or {}
        per_visit = 0.0
        priced = True
        for iid, count in items.items():
            m = model.get(int(iid))
            if m:
                per_visit += (count / max(1, visits)) * m.market
            else:
                priced = False
        label = key.split(":", 1)[-1].replace("x:", "")
        resources.append({"resource": label.title(), "visits": visits, "per_visit": per_visit, "priced": priced,
                          "items": sum(int(c) for c in items.values())})
    resources.sort(key=lambda r: -r["per_visit"])
    return {"zones": zones, "resources": resources}


def realms(con) -> list[str]:
    # a new realm shows as soon as a character logged in there, before its first scan or trade
    rows = con.execute("SELECT realm FROM scans UNION SELECT realm FROM events").fetchall()
    found = {r[0] for r in rows}
    try:
        found |= {r[0] for r in con.execute("SELECT DISTINCT realm FROM params WHERE key='chars'")}
    except Exception:
        pass
    return sorted(r for r in found if r and not str(r).startswith(" - "))


def characters(con, realm) -> dict[str, dict]:
    """Characters seen on this realm: {name: {money, level, class, t}}."""
    chars = dict(get_param(con, realm, "chars", {}))
    for (c,) in con.execute("SELECT DISTINCT char FROM events WHERE realm=? AND char IS NOT NULL", (realm,)):
        chars.setdefault(c, {})
    return chars


def last_played(con) -> tuple[str, str, int] | None:
    """The character the game saved most recently, over all realms: (realm, name, time) or None.
    The addon stamps each character with the time it was last seen in game."""
    best = None
    for realm in realms(con):
        for name, info in get_param(con, realm, "chars", {}).items():
            try:
                t = int((info or {}).get("t") or 0)
            except (TypeError, ValueError):
                continue
            if t > 0 and (best is None or t > best[2]):
                best = (realm, str(name), t)
    return best


def char_key(name: str, realm: str) -> str:
    return f"{name} @ {realm}"


def item_names(con, realm) -> dict[int, str]:
    return {r[0]: r[1] for r in con.execute("SELECT id, name FROM items WHERE realm=?", (realm,))}


# ============================================================== market model
@dataclass
class Market:
    id: int
    market: float          # fair price per unit (robust, recency-weighted)
    cur_min: int           # lowest unit price in the latest snapshot
    cur_p25: int
    cur_qty: int
    cur_t: int
    nscans: int
    days_seen: int
    volatility: float      # median abs deviation / median of minimum prices
    vol_day: float | None  # estimated units sold per day (from listing drops between full scans)
    trend: float           # last-3-day median vs 14-day median (-0.1 = 10% cheaper lately)
    usual_qty: float | None = None  # median amount listed before the latest snapshot (4+ snapshots)

    @property
    def flooded(self) -> bool:
        """Far more listed than usual: prices tend to drop while the extra stock clears."""
        return self.usual_qty is not None and self.cur_qty >= 3 * self.usual_qty and self.cur_qty - self.usual_qty >= 20


def _weighted_median(values, weights):
    pairs = sorted(zip(values, weights))
    total = sum(weights)
    acc = 0.0
    for v, w in pairs:
        acc += w
        if acc >= total / 2:
            return v
    return pairs[-1][0]


def market_model(con, realm, now=None) -> dict[int, Market]:
    now = now or int(time.time())
    since = now - HISTORY_DAYS * DAY
    rows = con.execute(
        "SELECT id, t, min, p25, qty, full FROM prices WHERE realm=? AND t>=? ORDER BY id, t",
        (realm, since)).fetchall()
    hist = defaultdict(list)
    for r in rows:
        hist[r[0]].append(r)
    out = {}
    for iid, pts in hist.items():
        p25s = [p[3] for p in pts]
        weights = [0.5 ** ((now - p[1]) / HALF_LIFE) for p in pts]
        market = _weighted_median(p25s, weights)
        mins = [p[2] for p in pts]
        med = statistics.median(mins)
        vol = statistics.median(abs(m - med) for m in mins) / med if med > 0 else 1.0
        recent = [p[3] for p in pts if now - p[1] < 3 * DAY]
        trend = (statistics.median(recent) / statistics.median(p25s) - 1) if recent and statistics.median(p25s) else 0.0
        fulls = [p for p in pts if p[5]]
        drops, span = 0.0, 0.0
        for a, b in zip(fulls, fulls[1:]):
            dt = b[1] - a[1]
            if 0 < dt <= 36 * 3600:
                drops += max(0, a[4] - b[4])
                span += dt
        # listings vanish when they sell OR get cancelled/expire; count ~70% as real sales
        vol_day = 0.7 * drops / (span / DAY) if span >= 6 * 3600 else None
        last = pts[-1]
        usual = statistics.median(p[4] for p in pts[:-1]) if len(pts) >= 5 else None
        out[iid] = Market(iid, market, last[2], last[3], last[4], last[1], len(pts),
                          len({p[1] // DAY for p in pts}), vol, vol_day, trend, usual)
    return out


def last_scan(con, realm):
    row = con.execute("SELECT t, src, nitems FROM scans WHERE realm=? ORDER BY t DESC LIMIT 1", (realm,)).fetchone()
    return dict(row) if row else None


def price_history(con, realm, iid, days=HISTORY_DAYS):
    since = int(time.time()) - days * DAY
    return [tuple(r) for r in con.execute(
        "SELECT t, min, p25, qty FROM prices WHERE realm=? AND id=? AND t>=? ORDER BY t", (realm, iid, since))]


def price_trend(hist, now=None, days=7):
    """How the cheapest listing moved: the newest scan against the median of the last `days` days.

    hist: rows (t, min, p25, qty) as price_history returns them. Returns a fraction (+0.12 = 12% dearer
    than usual), or None with fewer than 3 scans in that window."""
    if not hist:
        return None
    now = now or hist[-1][0]
    window = [r[1] for r in hist if r[0] >= now - days * DAY and r[1]]
    if len(window) < 3:
        return None
    base = statistics.median(window[:-1])
    if not base:
        return None
    return window[-1] / base - 1


def price_trends(con, realm, days=7):
    """price_trend for every item scanned in the last `days` days, in one query: {id: fraction}."""
    since = int(time.time()) - days * DAY
    rows = defaultdict(list)
    for iid, t, mn, p25, qty in con.execute(
            "SELECT id, t, min, p25, qty FROM prices WHERE realm=? AND t>=? ORDER BY id, t", (realm, since)):
        rows[iid].append((t, mn, p25, qty))
    out = {}
    for iid, hist in rows.items():
        tr = price_trend(hist, days=days)
        if tr is not None:
            out[iid] = tr
    return out


def trend_text(tr):
    """+12% / -8% / steady; "" when unknown."""
    if tr is None:
        return ""
    if abs(tr) < 0.03:
        return "steady"
    return f"{tr:+.0%}"


# ============================================================== ledger (what actually happened)
@dataclass
class ItemLedger:
    id: int
    name: str = ""
    inventory: deque = field(default_factory=deque)   # [qty, unit_cost, exp, t]
    open_posts: deque = field(default_factory=deque)  # [qty, unit, dep, t]
    bought_units: int = 0
    spent: int = 0
    sold_units: int = 0
    sold_lots: int = 0
    expired_lots: int = 0
    revenue: int = 0
    cost_sold: int = 0
    deposits_lost: int = 0
    posted_units: int = 0
    deposits_paid: int = 0
    profit: int = 0
    other_income: int = 0     # sales with no known buy price (loot, stock from before tracking)
    ratios: list = field(default_factory=list)        # realized unit price / expected
    days_to_sell: list = field(default_factory=list)
    flip_outcomes: list = field(default_factory=list)  # (t, profit, cost) for flipped units
    last_expired_streak: int = 0

    @property
    def held(self):
        return sum(l[0] for l in self.inventory)

    @property
    def held_cost(self):
        return sum(l[0] * l[1] for l in self.inventory)


@dataclass
class Ledger:
    items: dict
    timeline: list        # (t, profit_delta, label)
    trades: list          # rows for the history table


def build_ledger(con, realm, char: str | None = None) -> Ledger:
    """What happened. char=None: all characters together (used for learning);
    char=name: just that character's stock, sales and profit."""
    names = item_names(con, realm)
    name_to_id = {v: k for k, v in names.items()}
    items: dict[int, ItemLedger] = {}
    timeline, trades = [], []

    def get(iid, name=None):
        if iid is None and name in name_to_id:
            iid = name_to_id[name]
        key = iid if iid is not None else ("name", name)
        led = items.get(key)
        if led is None:
            led = items[key] = ItemLedger(iid if iid is not None else -1, name or names.get(iid, f"item {iid}"))
        return led

    # what each item cost on average across all characters: for sales of stock that was bought on
    # another character (and mailed over), so its price isn't counted as pure profit
    avg_cost = {}
    for iid_, spent_, units_ in con.execute(
            "SELECT id, SUM(q * p), SUM(q) FROM events WHERE realm=? AND e='buy' AND id IS NOT NULL GROUP BY id", (realm,)):
        if units_:
            avg_cost[iid_] = spent_ / units_

    if char:
        rows = con.execute("SELECT * FROM events WHERE realm=? AND char=? ORDER BY t", (realm, char)).fetchall()
    else:
        rows = con.execute("SELECT * FROM events WHERE realm=? ORDER BY t", (realm,)).fetchall()
    for ev in rows:
        e, t, iid = ev["e"], ev["t"], ev["id"]
        name = ev["name"] or names.get(iid) or f"item {iid}"
        led = get(iid, name)
        q = int(ev["q"] or 0)
        if e == "buy":
            p = int(ev["p"] or 0)
            led.inventory.append([q, p, ev["exp"], t])
            led.bought_units += q
            led.spent += q * p
            trades.append((t, "Bought", name, q, p, None, ev["char"]))
        elif e == "post":
            p, dep = int(ev["p"] or 0), int(ev["dep"] or 0)
            led.open_posts.append([q, p, dep, t])
            led.posted_units += q
            led.deposits_paid += dep
            trades.append((t, "Posted", name, q, p, -dep if dep else None, ev["char"]))
        elif e == "invoice":
            gross, cut = int(ev["gross"] or 0), int(ev["cut"] or 0)
            q = max(q, 1)
            net = gross - cut
            unit_gross = gross / q
            # match the auction(s) that sold -> time to sell
            remaining = q
            while remaining > 0 and led.open_posts:
                lot = led.open_posts[0]
                take = min(lot[0], remaining)
                led.days_to_sell.append((t - lot[3]) / DAY)
                lot[0] -= take
                remaining -= take
                if lot[0] <= 0:
                    led.open_posts.popleft()
            # cost basis FIFO from inventory
            remaining, cost, flipped = q, 0, 0
            while remaining > 0 and led.inventory:
                lot = led.inventory[0]
                take = min(lot[0], remaining)
                cost += take * lot[1]
                flipped += take
                if lot[2]:
                    led.ratios.append(unit_gross / lot[2])
                lot[0] -= take
                remaining -= take
                if lot[0] <= 0:
                    led.inventory.popleft()
            # units sold without a buy on this character: bought elsewhere (average cost), or never
            # bought at all (loot, stock from before tracking) -> income, not flip profit
            if remaining and iid in avg_cost:
                cost += round(remaining * avg_cost[iid])
                flipped += remaining
                remaining = 0
            net_flip = round(net * flipped / q)
            other = net - net_flip
            profit = net_flip - cost
            led.sold_units += q
            led.sold_lots += 1
            led.revenue += net
            led.cost_sold += cost
            led.profit += profit
            led.other_income += other
            led.last_expired_streak = 0
            if flipped:
                led.flip_outcomes.append((t, profit, cost))
                timeline.append((t, profit, f"Sold {q}x {name}"))
            trades.append((t, "Sold", name, q, int(unit_gross), profit if flipped else None, ev["char"]))
        elif e == "expired":
            lot = led.open_posts.popleft() if led.open_posts else None
            dep = lot[2] if lot else 0
            led.expired_lots += 1
            led.last_expired_streak += 1
            led.deposits_lost += dep
            led.profit -= dep
            if dep:
                timeline.append((t, -dep, f"Expired {name}"))
            if led.inventory:
                led.flip_outcomes.append((t, -dep, 0))
            trades.append((t, "Expired", name, lot[0] if lot else None, lot[1] if lot else None, -dep if dep else None, ev["char"]))
    trades.reverse()
    return Ledger(items, timeline, trades)


# ============================================================== learning
@dataclass
class Learned:
    margin_factor: float
    global_calib: float
    item_calib: dict
    item_sell: dict        # id -> (posterior sell-through, observations)
    item_margin_adj: dict
    paused: dict           # id -> reason
    notes: list


def _beta_mean(success, fail, prior_mean, strength=4.0):
    return (success + prior_mean * strength) / (success + fail + strength)


def learn(con, realm, settings: Settings, ledger: Ledger, model: dict, commit_tuning=True) -> Learned:
    notes = []
    all_ratios = [r for led in ledger.items.values() for r in led.ratios]
    global_calib = 1.0
    if all_ratios:
        n = len(all_ratios)
        global_calib = (statistics.median(all_ratios) * n + 1.0 * 5) / (n + 5)
        global_calib = min(1.3, max(0.6, global_calib))
    item_calib, item_sell, item_adj, paused = {}, {}, {}, {}
    now = time.time()
    for led in ledger.items.values():
        iid = led.id
        if iid is None or iid == -1:
            continue
        if led.ratios:
            k = 3.0
            c = (sum(led.ratios) + k * global_calib) / (len(led.ratios) + k)
            item_calib[iid] = min(1.5, max(0.5, c))
        m = model.get(iid)
        prior = _liquidity_prior(m)
        obs = led.sold_lots + led.expired_lots
        item_sell[iid] = (_beta_mean(led.sold_lots, led.expired_lots, prior), obs)
        adj = 0.0
        flips = led.flip_outcomes
        if flips:
            losses = sum(1 for _, p, _ in flips if p < 0)
            wins = len(flips) - losses
            if losses >= 2 and losses > wins:
                adj += 0.10
            elif wins >= 3 and losses == 0:
                adj -= 0.04
        if led.last_expired_streak >= 4 and led.sold_lots == 0:
            paused[iid] = f"expired {led.last_expired_streak}x without a sale"
        elif obs >= 4 and led.sold_lots / obs < 0.4:
            paused[iid] = f"rarely sells for you ({led.sold_lots} of {obs} auctions sold)"
        item_adj[iid] = adj

    factor = float(get_param(con, realm, "margin_factor", 1.0))
    if settings.autotune:
        window = now - 30 * DAY
        outcomes = [(t, p, c) for led in ledger.items.values() for (t, p, c) in led.flip_outcomes if t >= window]
        last_t = get_param(con, realm, "tuned_until", 0)
        newest = max((t for t, _, _ in outcomes), default=0)
        if len(outcomes) >= 5 and newest > last_t:
            losses = sum(1 for _, p, _ in outcomes if p < 0)
            loss_rate = losses / len(outcomes)
            cost = sum(c for _, _, c in outcomes)
            roi = sum(p for _, p, _ in outcomes) / cost if cost else 0.0
            sold = sum(l.sold_lots for l in ledger.items.values())
            expired = sum(l.expired_lots for l in ledger.items.values())
            st = sold / (sold + expired) if sold + expired else 0.0
            old = factor
            if loss_rate > 0.30 or roi < settings.min_margin * 0.5:
                factor *= 1.10
                note = "tightened: too many losing flips"
            elif loss_rate < 0.12 and st > 0.6 and roi > settings.min_margin:
                factor *= 0.95
                note = "loosened: flips are winning, going for more volume"
            else:
                note = "kept: results on target"
            factor = min(2.5, max(0.6, factor))
            if commit_tuning:
                set_param(con, realm, "margin_factor", factor)
                set_param(con, realm, "tuned_until", newest)
                con.execute("INSERT INTO tuning VALUES (?,?,?,?,?,?,?)",
                            (realm, int(now), settings.min_margin * factor, loss_rate, st, roi, note))
                con.commit()
            notes.append(f"Margin {settings.min_margin * old:.0%} -> {settings.min_margin * factor:.0%} ({note})")
    return Learned(factor, global_calib, item_calib, item_sell, item_adj, paused, notes)


def _liquidity_prior(m: Market | None) -> float:
    if m is None:
        return 0.35
    vol = m.vol_day if m.vol_day is not None else min(m.cur_qty, 20) * 0.25
    p = 0.25 + 0.6 * (1 - math.exp(-vol / 10.0))
    if m.days_seen < 2:
        p *= 0.8
    return min(0.85, max(0.15, p))


# ============================================================== recommendations
@dataclass
class Deal:
    id: int
    name: str
    cur: int
    market: int
    expected_sale: int
    max_buy: int
    profit_unit: int
    roi: float
    p_sell: float
    vol_day: float | None
    qty_cap: int
    confidence: float
    score: float
    is_deal: bool
    held: int
    reason: str = ""
    fast: bool = False          # passes the "sells decently fast" rules
    est_days: float | None = None  # expected days until what we'd buy is sold
    own_days: float | None = None  # your real average time to sell this item
    starter: bool = False          # no history yet: the addon judges the price live
    flood: bool = False            # far more listed than usual: not bought until it clears


def _starter(settings: Settings, m: Market, learned: Learned, ledger: Ledger, names: dict) -> Deal | None:
    """First-scan candidate: a deep market (lots listed = lots traded). No max price from
    history; in game the addon reads the full listing ladder and only buys stacks far below
    where most of the stock sits."""
    if not settings.starter_mode or m.cur_qty < settings.starter_min_listed:
        return None
    if m.market < settings.min_value_copper:
        return None
    led = ledger.items.get(m.id)
    if learned.item_sell.get(m.id, (1, 0))[1] >= 4 and learned.item_sell[m.id][0] < settings.min_sell_chance:
        return None
    score = math.log10(m.cur_qty) * math.sqrt(m.market)
    return Deal(m.id, names.get(m.id, f"item {m.id}"), m.cur_min, int(m.market), int(m.market), 0, 0, 0.0,
                _liquidity_prior(m), None, settings.max_units_per_item, 0.3, score, False, led.held if led else 0,
                f"first-scan pick: {m.cur_qty:,} listed, price checked live in game", True, None, None, True)


def recommend(settings: Settings, model: dict, learned: Learned, ledger: Ledger, names: dict, now=None,
              holder: Ledger | None = None):
    """ledger = all characters (speed/deposit knowledge); holder = the character who will
    buy (what they already hold). Defaults to the same ledger."""
    now = now or time.time()
    holder = holder or ledger
    margin_base = settings.min_margin * learned.margin_factor
    cut = settings.ah_cut
    deals = []
    black = {int(x) for x in settings.blacklist if str(x).isdigit()}
    for iid, m in model.items():
        if iid in black or iid in learned.paused:
            continue
        if m.nscans < settings.min_scans or m.vol_day is None:
            s = _starter(settings, m, learned, holder, names)
            if s:
                deals.append(s)
            continue
        if m.market < settings.min_value_copper:
            continue
        led = ledger.items.get(iid)
        calib = learned.item_calib.get(iid, learned.global_calib)
        expected = m.market * calib
        if m.trend < -0.05:                       # falling market: expect the lower recent price
            expected *= (1 + m.trend)
        p, _obs = learned.item_sell.get(iid, (_liquidity_prior(m), 0))
        p_ev = 1 - (1 - p) ** 3                  # sells within 3 postings
        cycles = p_ev / p if p > 0 else 3
        dep_unit = (led.deposits_paid / led.posted_units) if led and led.posted_units else expected * settings.deposit_pct
        # the deposit comes back when the item sells: only postings that expire lose it
        net = p_ev * expected * (1 - cut) - (cycles - p_ev) * dep_unit
        margin = margin_base + min(0.25, m.volatility * 0.5) + learned.item_margin_adj.get(iid, 0.0)
        max_buy = int(net / (1 + margin))
        if max_buy <= 0:
            continue
        mine = holder.items.get(iid)
        held = mine.held if mine else 0
        # ---- speed: how fast does this actually sell?
        own_days = None
        if led and len(led.days_to_sell) >= 2:
            own_days = statistics.median(led.days_to_sell)
        vol = m.vol_day if m.vol_day is not None else 0.0
        # we share buyers with other sellers: assume we get about half of the sales
        our_rate = vol * 0.5
        qty_cap = int(min(settings.max_units_per_item, math.floor(our_rate * settings.hold_days)) - held)
        est_days = ((held + max(1, qty_cap)) / our_rate) if our_rate > 0 else None
        if own_days is not None:
            est_days = max(est_days or 0, own_days)
        slow_reason = ""
        if m.vol_day is None:
            slow_reason = "need more scans to judge sell speed"
        elif m.vol_day < settings.min_sales_per_day:
            slow_reason = f"sells too slowly ({m.vol_day:.1f}/day)"
        elif p < settings.min_sell_chance:
            slow_reason = f"low sell chance ({p:.0%})"
        elif own_days is not None and own_days > settings.hold_days:
            slow_reason = f"slow for you (avg {own_days:.1f} days)"
        fast = not slow_reason
        stale = now - m.cur_t > 8 * 3600
        flood = bool(getattr(settings, "flood_warning", True) and m.flooded)
        is_deal = fast and (not stale) and (not flood) and m.cur_min <= max_buy and qty_cap > 0
        profit_unit = int(net - m.cur_min)
        roi = profit_unit / m.cur_min if m.cur_min else 0.0
        data_conf = min(1.0, m.nscans / 10) * min(1.0, m.days_seen / 3)
        confidence = max(0.05, data_conf * (1 - min(0.8, m.volatility * 1.5)) * (0.5 + p / 2))
        reason = ""
        if slow_reason:
            reason = slow_reason
        elif stale:
            reason = "price data is old - rescan"
        elif flood:
            reason = f"market flooded: {m.cur_qty:,} listed, usually ~{int(m.usual_qty):,} - wait until it clears"
        elif m.cur_min > max_buy:
            reason = "no deal right now (watching)"
        elif qty_cap <= 0:
            reason = "you already hold enough"
        # rank by profit per day of waiting: fast sellers beat slightly bigger but slower flips
        speed = 1.0 / max(0.25, est_days or settings.hold_days)
        if is_deal:
            score = max(0, profit_unit) * max(1, qty_cap) * confidence * speed
        else:
            score = max(0, net - max_buy) * vol * confidence * speed * 0.1
        deals.append(Deal(iid, names.get(iid, f"item {iid}"), m.cur_min, int(m.market), int(expected), max_buy,
                          profit_unit, roi, p, m.vol_day, max(0, qty_cap), confidence, score, is_deal, held, reason,
                          fast, est_days, own_days, False, flood))
    deals.sort(key=lambda d: (not d.is_deal, not d.fast, d.starter, -d.score, d.id))
    return deals


def filter_deals(deals: list[Deal], only_deals=False, fast_only=False, min_profit=0, text="") -> list[Deal]:
    """The Deals page filters. First-scan picks are judged live in game, so only the text search hides them."""
    text = (text or "").lower().strip()
    out = []
    for d in deals:
        if text and text not in d.name.lower():
            continue
        if not d.starter:
            if only_deals and not d.is_deal:
                continue
            if fast_only and not d.fast:
                continue
            if min_profit > 0 and d.profit_unit < min_profit:
                continue
        out.append(d)
    return out


PLANNER_SETTINGS = ("min_margin", "ah_cut", "deposit_pct", "hold_days", "min_sales_per_day", "min_sell_chance",
                    "starter_mode", "starter_min_listed", "max_units_per_item", "max_plan_items",
                    "min_value_copper", "min_scans", "duration", "sell_farmed", "flood_warning")


def planner_context(settings: Settings, learned: Learned, ledger: Ledger, holder: Ledger,
                    budget_gold: float | None = None) -> dict:
    """What the in-game planner (Planner.lua) needs to rebuild this character's list from a
    fresh scan exactly like recommend() + build_plan() would: the settings, everything
    learned, and the few ledger facts (deposits, own sell times, what this character holds)."""
    s = {k: getattr(settings, k) for k in PLANNER_SETTINGS}
    s["budget"] = settings.budget_gold if budget_gold is None else budget_gold
    s["blacklist"] = [int(x) for x in settings.blacklist if str(x).isdigit()]
    dep, own, held = {}, {}, {}
    for iid, led in ledger.items.items():
        if not isinstance(iid, int) or iid < 0:
            continue
        if led.posted_units:
            dep[iid] = led.deposits_paid / led.posted_units
        if len(led.days_to_sell) >= 2:
            own[iid] = statistics.median(led.days_to_sell)
    for iid, led in holder.items.items():
        if isinstance(iid, int) and iid >= 0 and led.held > 0:
            held[iid] = led.held
    return {
        "s": s,
        "mf": learned.margin_factor,
        "gc": learned.global_calib,
        "ic": dict(learned.item_calib),
        "ps": {k: [v[0], v[1]] for k, v in learned.item_sell.items()},
        "adj": {k: v for k, v in learned.item_margin_adj.items() if v},
        "paused": {k: True for k in learned.paused},
        "dep": dep,
        "own": own,
        "held": held,
    }


def build_plan(settings: Settings, deals: list[Deal], model: dict, learned: Learned, ledger: Ledger, names: dict,
               realm: str, budget_gold: float | None = None):
    """ledger = the character's own ledger (their stock goes on the sell list)."""
    # keep ~15% back for posting deposits, and never put more than 40% of the budget
    # into one item, so a single bad flip can't wipe out a small bankroll
    gold = settings.budget_gold if budget_gold is None else budget_gold
    budget = int(gold * 10000 * 0.85)
    per_item = max(1, int(budget * 0.40))
    margin_base = settings.min_margin * learned.margin_factor
    buys = []
    spent = 0
    starters = 0
    for d in deals:
        if len(buys) >= settings.max_plan_items:
            break
        if d.qty_cap <= 0 or not d.fast or d.flood:   # never buy anything that doesn't sell fast
            continue
        if d.starter:
            if starters >= settings.max_plan_items // 2:
                continue
            m = model[d.id]
            # never more than 40% of the budget, nor more than 5% of what's listed
            qty = int(min(d.qty_cap, per_item // max(1, m.cur_min), max(1, m.cur_qty // 20)))
            # small budgets: only items you can buy a real stack of (5+ units)
            if qty < 5:
                continue
            starters += 1
            buys.append({"id": d.id, "name": d.name, "gap": round(margin_base + 0.05, 3), "qty": qty,
                         "max": int(max(m.cur_p25, m.market) * 1.5), "vol": round(m.vol_day, 1) if m.vol_day else None})
            continue
        if d.is_deal:
            qty = int(min(d.qty_cap, (budget - spent) // max(1, d.cur), per_item // max(1, d.max_buy)))
            if qty <= 0:
                continue
            spent += qty * d.cur
        else:
            # watch item: the live search may find it cheaper than the last scan
            if d.confidence < 0.4 or len(buys) >= settings.max_plan_items * 0.75:
                continue
            qty = int(min(max(1, d.qty_cap // 2), per_item // max(1, d.max_buy)))
            if qty <= 0:
                continue
        buys.append({"id": d.id, "name": d.name, "max": d.max_buy, "qty": qty, "exp": d.expected_sale,
                     "vol": round(d.vol_day, 1) if d.vol_day else None})

    # sell list: everything you're holding from flips + (optionally) anything else with a market
    sells = []
    seen = set()
    for iid, led in ledger.items.items():
        if not isinstance(iid, int) or iid < 0 or led.held <= 0:
            continue
        m = model.get(iid)
        unit_cost = led.held_cost / led.held
        calib = learned.item_calib.get(iid, learned.global_calib)
        normal = int((m.market if m else unit_cost * 1.3) * calib)
        floor = unit_cost * (1 + 0.02) / (1 - settings.ah_cut)
        expiries = led.last_expired_streak
        age_days = (time.time() - led.inventory[0][3]) / DAY if led.inventory else 0
        overdue = max(0.0, age_days - settings.hold_days * 2)
        if expiries or overdue:
            # learn to let go of slow stock: cheaper with every expiry and every overdue day
            floor *= (0.95 ** expiries) * (0.95 ** overdue)
            floor = max(floor, unit_cost * 0.85)
        normal = max(normal, int(floor * 1.05))
        sells.append({"id": iid, "name": led.name, "floor": int(floor), "normal": normal,
                      "ceil": int(max(normal * 1.6, floor * 1.3)), "held": True})
        seen.add(iid)
    if settings.sell_farmed:
        # selling needs less history than buying: the addon re-checks live prices before every post
        # only items with a real market: several units listed (or measured sales), so one
        # silly overpriced listing can't become your "fair value"
        def liquidity(m):
            return m.vol_day if m.vol_day is not None else m.cur_qty / 10
        farmed = [m for iid, m in model.items()
                  if iid not in seen and m.market >= settings.min_value_copper
                  and (m.cur_qty >= 10 or (m.vol_day or 0) >= 1)]
        farmed.sort(key=lambda m: (-(liquidity(m) * math.sqrt(m.market)), m.id))
        for m in farmed[:600]:
            iid = m.id
            normal = int(m.market * learned.item_calib.get(iid, learned.global_calib))
            sells.append({"id": iid, "name": names.get(iid, f"item {iid}"), "floor": int(normal * 0.75),
                          "normal": normal, "ceil": int(normal * 1.6)})
    return {
        "generated": int(time.time()),
        "realm": realm,
        "duration": settings.duration,
        "budget": budget,
        "cut": settings.ah_cut,
        "buy": buys,
        "sell": sells,
    }, spent


PLANS_PATH = DATA_DIR / "plans.json"


def write_plan(settings: Settings, key: str, plan: dict) -> Path:
    """Store this character's plan and write every character's plan into the addon,
    so each character finds its own list when logged in."""
    target = settings.addon_path()
    if not target or not target.exists():
        raise FileNotFoundError("The FlipForever addon isn't installed yet (Settings -> Install addon).")
    try:
        plans = json.loads(PLANS_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        plans = {}
    plans[key] = plan
    # drop lists older than 3 days: prices have moved on
    plans = {k: v for k, v in plans.items() if time.time() - v.get("generated", 0) < 3 * DAY}
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    PLANS_PATH.write_text(json.dumps(plans), encoding="utf-8")
    text = ("-- Written by the FlipForever app (one list per character). Type /reload in game to load it.\n"
            "FlipForever_Plans = " + luaio.to_lua(plans) + "\n")
    out = target / "ShoppingList.lua"
    out.write_text(text, encoding="utf-8")
    return out


def plan_for(key: str) -> dict | None:
    try:
        return json.loads(PLANS_PATH.read_text(encoding="utf-8")).get(key)
    except (OSError, ValueError):
        return None


def install_addon(settings: Settings) -> Path:
    target = settings.addon_path()
    if not target:
        raise FileNotFoundError("Set your WoW: Forever folder in Settings first.")
    target.parent.mkdir(parents=True, exist_ok=True)
    keep = None
    plan_file = target / "ShoppingList.lua"
    if plan_file.exists():
        keep = plan_file.read_text(encoding="utf-8")
    shutil.copytree(ADDON_SRC, target, dirs_exist_ok=True)
    if keep and ("FlipForever_Plan = {" in keep or "FlipForever_Plans = {" in keep):
        plan_file.write_text(keep, encoding="utf-8")
    return target


def _scrub(text: str) -> str:
    """Remove the Windows user name from paths before text leaves the computer."""
    import os
    import re
    home = os.path.expanduser("~")
    if home and home != "~":
        text = text.replace(home, "<home>").replace(home.replace("\\", "/"), "<home>")
    return re.sub(r"(?i)([a-z]:[\\/]+users[\\/]+)[^\\/\s]+", r"\1<user>", text)


def bug_report_text(settings: Settings, app_version: str, now: float | None = None) -> str:
    """Everything a bug report needs, ready to paste: versions, setup and the addon's last errors.
    No character names, account names or user paths."""
    import platform
    now = now or time.time()
    lines = ["FlipForever bug report info", f"App version: {app_version}"]
    addon_version = "not installed"
    addon_dir = settings.addon_path()
    toc = addon_dir / "FlipForever.toc" if addon_dir else None
    if toc and toc.exists():
        for line in toc.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("## Version:"):
                addon_version = line.split(":", 1)[1].strip()
    lines.append(f"Addon version: {addon_version}")
    lines.append(f"Windows: {platform.release()} ({platform.version()})")
    lines.append(f"Language: {settings.language or 'game language'}")
    lines.append(f"WoW folder set: {'yes' if settings.wow_path else 'no'}"
                 f"  ·  account folder found: {'yes' if settings.account else 'no'}")
    errors = []
    sv = settings.savedvars_path()
    if sv and sv.exists():
        try:
            db = luaio.load_savedvariables(sv).get("FlipForeverDB") or {}
            errors = [e for e in _as_list(db.get("errors")) if isinstance(e, dict)]
        except Exception as exc:  # a broken file is itself worth reporting
            lines.append(f"SavedVariables could not be read: {exc}")
    if errors:
        lines.append(f"Last addon errors ({len(errors)}, newest first):")
        for e in reversed(errors[-10:]):
            when = time.strftime("%Y-%m-%d %H:%M", time.localtime(int(e.get("t") or 0)))
            lines.append(f"  {when}  v{e.get('v', '?')}  {e.get('where', '?')}: {e.get('msg', '')}")
    else:
        lines.append("Last addon errors: none recorded")
    lines.append(f"Created: {time.strftime('%Y-%m-%d %H:%M', time.localtime(now))}")
    return _scrub("\n".join(lines))


def profit_by_char(con, realm) -> list[dict]:
    """Per character on this realm: realized profit, last 7 days, stock at cost, sales and buys."""
    now = time.time()
    out = []
    for (char,) in con.execute("SELECT DISTINCT char FROM events WHERE realm=? AND char IS NOT NULL ORDER BY char", (realm,)):
        led = build_ledger(con, realm, char)
        out.append({
            "char": char,
            "realized": sum(l.profit for l in led.items.values()),
            "week": sum(p for t, p, _ in led.timeline if now - t < 7 * DAY),
            "held_cost": sum(l.held_cost for l in led.items.values()),
            "sold": sum(l.sold_lots for l in led.items.values()),
            "bought": sum(l.bought_units for l in led.items.values()),
        })
    out.sort(key=lambda r: -r["realized"])
    return out


def realm_overview(con) -> list[dict]:
    """Every realm side by side: characters, their gold, realized profit, last 7 days, stock at
    cost and the last scan. Each realm's numbers come only from that realm's own data."""
    out = []
    for realm in realms(con):
        chars = characters(con, realm)
        gold = 0
        for info in chars.values():
            try:
                gold += int((info or {}).get("money") or 0)
            except (TypeError, ValueError):
                pass
        rows = profit_by_char(con, realm)
        scan = last_scan(con, realm)
        out.append({
            "realm": realm, "chars": len(chars), "gold": gold,
            "realized": sum(r["realized"] for r in rows), "week": sum(r["week"] for r in rows),
            "held_cost": sum(r["held_cost"] for r in rows), "last_scan": scan["t"] if scan else None,
        })
    return out


def profession_cooldowns(con) -> list[dict]:
    """Profession cooldowns (transmutes, Mooncloth...) of every character on every realm, soonest
    first, as the addon read them when a profession window was open."""
    out = []
    for realm in realms(con):
        for cname, info in get_param(con, realm, "chars", {}).items():
            for e in (info or {}).get("cooldowns") or []:
                out.append({"realm": realm, "char": cname, "name": e["name"], "ready": int(e["ready"])})
    out.sort(key=lambda e: (e["ready"], e["char"], e["name"]))
    return out


def aging_stock(ledger, model, now=None, days=7.0, ah_cut=0.05):
    """Items held longer than `days` (oldest lot): today's price against what you paid.
    Returns (rows, totals). rows: dicts with id, name, held, age, paid (per unit), now (fair
    price per unit, 0 if unknown), change (now after the cut vs paid, per unit). Oldest first."""
    now = now or time.time()
    rows = []
    for iid, led in ledger.items.items():
        if led.held <= 0 or not led.inventory:
            continue
        age = (now - led.inventory[0][3]) / 86400
        if age <= days:
            continue
        paid = led.held_cost / led.held
        m = model.get(iid) if model else None
        price = m.market if m else 0
        change = price * (1 - ah_cut) - paid if price else 0
        rows.append({"id": iid, "name": led.name, "held": led.held, "age": age, "paid": paid,
                     "now": price, "change": change})
    rows.sort(key=lambda r: -r["age"])
    totals = {"items": len(rows), "units": sum(r["held"] for r in rows),
              "paid": sum(r["paid"] * r["held"] for r in rows),
              "worth": sum(r["now"] * (1 - ah_cut) * r["held"] for r in rows if r["now"]),
              "unknown": sum(1 for r in rows if not r["now"])}
    return rows, totals

def weekly_report(ledger: Ledger, learned: Learned | None = None, now=None, n=3) -> dict:
    """The last 7 days of flips: best and worst items by profit (sales minus cost and lost deposits),
    what sold fastest (median time from posting to sale) and what to stop buying (losing this week,
    expiring again and again, or paused by the learner)."""
    now = now or time.time()
    since = now - 7 * DAY
    week = []
    for led in ledger.items.values():
        outs = [o for o in led.flip_outcomes if o[0] >= since]
        if not outs:
            continue
        sales = sum(1 for o in outs if o[2] > 0)
        week.append({"id": led.id, "name": led.name, "profit": sum(o[1] for o in outs), "sales": sales,
                     "expired": sum(1 for o in outs if o[2] == 0 and o[1] < 0),
                     "streak": led.last_expired_streak, "days": led.days_to_sell[-10:]})
    best = sorted((w for w in week if w["profit"] > 0), key=lambda w: -w["profit"])[:n]
    worst = sorted((w for w in week if w["profit"] < 0), key=lambda w: w["profit"])[:n]
    fast = []
    for w in week:
        if w["sales"] and w["days"]:
            fast.append(dict(w, median_days=statistics.median(w["days"])))
    fast.sort(key=lambda w: w["median_days"])
    stop, seen = [], set()
    for w in sorted(week, key=lambda w: w["profit"]):
        why = None
        if w["streak"] >= 2:
            why = f"expired {w['streak']} times in a row"
        elif w["profit"] < 0 and w["expired"] >= max(1, w["sales"]):
            why = f"lost {money(-w['profit'], True)} this week, expires more than it sells"
        if why:
            stop.append({"id": w["id"], "name": w["name"], "profit": w["profit"], "why": why})
            seen.add(w["id"])
    paused = (learned.paused if learned else {}) or {}
    names = {led.id: led.name for led in ledger.items.values()}
    for iid, reason in paused.items():
        if iid not in seen and iid in names:
            stop.append({"id": iid, "name": names[iid], "profit": 0, "why": f"paused: {reason}"})
    return {"profit": sum(w["profit"] for w in week), "sales": sum(w["sales"] for w in week),
            "items": len(week), "best": best, "worst": worst, "fastest": fast[:n], "stop": stop[:n]}


# ============================================================== dashboard numbers
def goal_text(today: int, week: int, day_gold: int, week_gold: int) -> str:
    """Gold goals (settings goal_day_gold / goal_week_gold, 0 = off): progress as one line, empty when none set."""
    parts = []
    for label, val, goal in (("today", today, day_gold), ("this week", week, week_gold)):
        if goal and goal > 0:
            pct = max(0, val) / (goal * 10000)
            parts.append(f"{label} {pct:.0%} of {goal:,}g" + (" (reached)" if pct >= 1 else ""))
    return ("Goal: " + ", ".join(parts)) if parts else ""


def summary(con, realm, ledger: Ledger, model: dict) -> dict:
    now = time.time()
    realized = sum(l.profit for l in ledger.items.values())
    week = sum(p for t, p, _ in ledger.timeline if now - t < 7 * DAY)
    lt = time.localtime(now)
    midnight = time.mktime((lt.tm_year, lt.tm_mon, lt.tm_mday, 0, 0, 0, 0, 0, -1))
    today = sum(p for t, p, _ in ledger.timeline if t >= midnight)
    held_cost = sum(l.held_cost for l in ledger.items.values())
    held_value = 0
    for iid, l in ledger.items.items():
        if l.held and isinstance(iid, int) and iid in model:
            held_value += l.held * model[iid].market
    sold = sum(l.sold_lots for l in ledger.items.values())
    expired = sum(l.expired_lots for l in ledger.items.values())
    ls = last_scan(con, realm)
    return {
        "realized": realized, "week": week, "today": today, "held_cost": held_cost, "held_value": held_value,
        "other_income": sum(l.other_income for l in ledger.items.values()),
        "sell_through": (sold / (sold + expired)) if sold + expired else None,
        "tracked": len(model), "last_scan": ls,
        "spent": sum(l.spent for l in ledger.items.values()),
    }


def tuning_history(con, realm):
    return [tuple(r) for r in con.execute(
        "SELECT t, margin, loss_rate, sell_through, roi, note FROM tuning WHERE realm=? ORDER BY t DESC", (realm,))]
