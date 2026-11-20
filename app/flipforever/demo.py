"""Synthetic market so you can explore the app before you have real scans."""
from __future__ import annotations

import hashlib
import random
import time

DEMO_REALM = "Demo Realm - Horde"

ITEMS = [
    (2589, "Linen Cloth", 45, 60), (2592, "Wool Cloth", 110, 45), (4306, "Silk Cloth", 380, 40),
    (4338, "Mageweave Cloth", 520, 35), (14047, "Runecloth", 900, 50), (2770, "Copper Ore", 70, 55),
    (2771, "Tin Ore", 160, 30), (2772, "Iron Ore", 750, 25), (3858, "Mithril Ore", 1100, 25),
    (10620, "Thorium Ore", 1900, 20), (2840, "Copper Bar", 95, 30), (3575, "Iron Bar", 820, 15),
    (765, "Silverleaf", 60, 40), (2447, "Peacebloom", 50, 40), (785, "Mageroyal", 180, 25),
    (2452, "Swiftthistle", 260, 20), (3820, "Stranglekelp", 240, 20), (3355, "Wild Steelbloom", 420, 18),
    (8831, "Purple Lotus", 950, 15), (13464, "Golden Sansam", 1600, 12), (13463, "Dreamfoil", 1400, 12),
    (2318, "Light Leather", 55, 40), (2319, "Medium Leather", 140, 30), (4234, "Heavy Leather", 330, 30),
    (4304, "Thick Leather", 600, 30), (8170, "Rugged Leather", 900, 25), (10940, "Strange Dust", 300, 25),
    (11083, "Soul Dust", 900, 15), (11137, "Vision Dust", 1500, 12), (16204, "Illusion Dust", 3200, 12),
    (6370, "Blackmouth Oil", 450, 10), (8846, "Gromsblood", 1300, 10), (7078, "Essence of Fire", 22000, 4),
    (7076, "Essence of Earth", 18000, 4), (12808, "Essence of Undeath", 26000, 3),
    (12363, "Arcane Crystal", 380000, 1), (7910, "Star Ruby", 9000, 3), (12361, "Blue Sapphire", 42000, 2),
    (4625, "Firebloom", 1100, 10), (3356, "Kingsblood", 700, 15),
]


def create_demo(con, days=10):
    rng = random.Random(42)
    now = int(time.time())
    realm = DEMO_REALM
    clear_demo(con)
    con.executemany("INSERT OR REPLACE INTO items VALUES (?,?,?)", [(realm, i, n) for i, n, _, _ in ITEMS])
    start = now - days * 86400
    state = {i: {"price": base, "qty": vol * 6} for i, _, base, vol in ITEMS}
    t = start
    while t <= now:
        con.execute("INSERT OR IGNORE INTO scans VALUES (?,?,?,?)", (realm, t, "full", len(ITEMS)))
        rows = []
        for iid, _name, base, vol in ITEMS:
            s = state[iid]
            s["price"] = max(base * 0.6, min(base * 1.6, s["price"] * (1 + rng.gauss(0, 0.04)) + (base - s["price"]) * 0.08))
            sold = max(0, int(rng.gauss(vol / 6, vol / 12)))
            new = max(0, int(rng.gauss(vol / 6, vol / 10)))
            s["qty"] = max(1, s["qty"] - sold + new)
            p25 = int(s["price"])
            mn = int(p25 * rng.uniform(0.9, 1.0))
            if rng.random() < 0.08:               # someone dumps cheap -> a flip opportunity
                mn = int(p25 * rng.uniform(0.45, 0.7))
            rows.append((realm, t, iid, mn, p25, s["qty"], max(1, s["qty"] // 5), 1))
        con.executemany("INSERT INTO prices VALUES (?,?,?,?,?,?,?,?)", rows)
        t += 4 * 3600
    # a week of trades
    events = []
    for k in range(28):
        iid, name, base, _ = rng.choice(ITEMS[:30])
        bt = start + rng.randint(0, (days - 2) * 86400)
        q = rng.choice([1, 5, 10, 20])
        cost = int(base * rng.uniform(0.55, 0.8))
        events.append((bt, "buy", iid, name, q, cost, None, None, None, base))
        pt = bt + 3600
        price = int(base * rng.uniform(0.95, 1.1))
        dep = int(price * q * 0.015)
        events.append((pt, "post", iid, name, q, price, dep, None, None, None))
        if rng.random() < 0.78:
            events.append((pt + rng.randint(2, 30) * 3600, "invoice", iid, name, q, None, dep, price * q, int(price * q * 0.05), None))
        else:
            events.append((pt + 24 * 3600, "expired", iid, name, None, None, None, None, None, None))
    for ev in events:
        uniq = hashlib.sha1(("demo" + repr(ev)).encode()).hexdigest()
        t, e, iid, name, q, p, dep, gross, cut, exp = ev
        con.execute("INSERT OR IGNORE INTO events VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    (uniq, realm, t, e, iid, name, q, p, dep, gross, cut, exp, "Demochar"))
    con.commit()
    return realm


def clear_demo(con):
    for table in ("items", "scans", "prices", "events", "params", "tuning"):
        con.execute(f"DELETE FROM {table} WHERE realm=?", (DEMO_REALM,))
    con.commit()
