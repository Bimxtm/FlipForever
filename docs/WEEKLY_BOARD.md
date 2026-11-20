# Weekly board - week of Thu 20 Nov → Thu 27 Nov 2026

Read at the start of every cycle and updated at the end. Owner: Bimxtm · Builder: Claude.

## 🎯 Goals this week
1. **Prove it in the real game.** Everything so far has only passed mocked tests. Getting real-game feedback and fixing what breaks beats any new feature.
2. **Polish what exists:** the advisor, profession planner and tooltips should feel finished, not just work.
3. **One major feature,** only if you approve one (see "Waiting for your OK").

## ⏱️ Usage budget (Pro plan, extra usage off: nothing costs extra)
- Weekly limit: **26% used** on Thu morning, resets Sat 21 Nov 14:00.
- **Plan:** at most ~10% of the weekly limit per day. Keep **≥15% in reserve** for fixing bugs found in the real game.
- 5-hour windows: pause at **>80%** and resume after the reset (scheduled automatically). Nothing is left half-done; finished work ships first.
- This session's context is ~80% full. The board and docs are the source of truth if the conversation gets compacted.

## 📅 Plan by day
| Day | Focus | Ships as |
|---|---|---|
| Thu 20, 11:07 | **Top priority (your request):** shopping list rebuilt in game after every scan, no /reload: the app passes its learned settings at login, and the addon plans with fresh prices · "Save & sync with app" button (one click instead of /reload) · then, if there's room: exact skill-up chances, "why" tooltips, "sells ~N/day", window size | 2.3.0 Beta 2 |
| Thu 20, ~19:11 | Cycle: everything since 2.2.0 | **2.3.0 stable** |
| Fri 21 | **In-game test checklist** for you · fix whatever you report · zone names for gathering stats on first login | 2.3.x betas → 2.3.1 at a cycle |
| Fri 21 / Sat 22 | **Better GUI (your request):** in game, one consistent FlipForever window with tabs (Overview · Shopping list you can see and edit · Autopilot · Gathering · Advisor · Professions · Settings), a matching look on every panel, and a shopping-list view showing price, max, bought and status · in the app, a cleaner modern layout (cards, clearer tables, colours with meaning) | 2.4.0 betas |
| Sat 22 | Gathering: value per node on our own map-pin tooltips · Advisor: "best farming zone for your skill" step | 2.4.0 beta |
| Sun 23 | Auction: smarter undercut (ignore single dumped units, never undercut your own) · per-item sale-speed learning shown in the app | 2.4.0 stable at a cycle |
| Mon 24 | Language-independent spells (spell IDs) · combat helper: more sequences for low levels (1-10) | 2.5.0 beta |
| Tue 25-Thu 27 | Approved major feature, if any, otherwise polish + bug fixes · weekly review on Thu | 2.5.0 stable |

## 🧱 Waiting for your OK (major)
- Crafting profit finder (recipes that sell for more than their mats, mats added to the shopping list)
- Waypoint arrow (next gathering stop / dungeon / vendor)
- Quest locations for advisor steps (where class quests start, with map pins), built in, no Questie needed

## 🐞 Problems / risks (fix as we go)
| # | Problem | Severity | Plan |
|---|---|---|---|
| P1 | **Nothing has run in the real game yet** (auction house API, combat helper, profession API, tooltips) | 🔴 high | In-game test checklist Fri; fix reports first |
| P2 | Unverified Forever API details: full-scan timing, commodity silver-only prices, talent API shape, secure step-button in combat | 🔴 high | Built with fallbacks; confirm in-game (P1) |
| P3 | Private repo: the app can't see updates until you paste a read-only GitHub token (About & updates) | 🟠 med | Remind you; or make the repo public when you're ready |
| P4 | Guide data gaps: druid talents "not final" (Method), warlock from a beta-era source, rogue/priest/shaman talents only as pictures | 🟠 med | Re-check sources Sat; add when post-launch text builds appear |
| P5 | Spell names are English-only (your client is enUS, so fine for you) | 🟡 low | Spell IDs on Mon |
| P6 | Random-stat gear ("of the Bear") priced together by item | 🟡 low | Buy logic already prefers commodities; revisit if it causes bad buys |
| P7 | Planner skill-up chances are colour averages | 🟡 low | Exact chances in Beta 2 |
| P8 | Gathering stats show "map 1411" until the addon has run once | 🟡 low | Names saved at login (done); verify Fri |
| P10 | **New shopping lists need /reload, and scans only reach the app after /reload or logout** (WoW only reads and writes addon data at load and logout) | 🟠 med | In-game planning after each scan + one-click sync (Beta 2) |
| P11 | **After a scan you don't know when to reload, and autopilot keeps buying from the old list** | 🟠 med | Beta 3: scan-done alert (sound, raid warning, flashing Reload), autopilot pauses until the reload, app auto-builds the list and notifies |
| P12 | **Combat helper: one key should also pick targets, adapting to your role** (top priority, user request) | 🟠 med | Beta 3. Every step gets `/targetenemy [noharm][dead]`, so it picks the nearest enemy when you have none or yours is dead/friendly. Tank builds (Protection, Bear) also target your friendly target's attacker (`[@targettarget,harm]`), get Taunt/Growl steps and an "enemy on <ally>" warning. Blizzard doesn't let addons choose targets by "who is attacking whom" in combat, so this uses the allowed macro targeting only. |
| P9 | Test harness quirk: mock timers can drop delayed callbacks | 🟢 dev | Improve the mock when it next gets in the way |

## ✅ Done this week
- 2.3.0 Beta 3 (Thu 11:00-11:40): one-key targeting + tank mode (P12 ✔), scan-done alert + autopilot pause (P11 ✔), app auto-builds the list after import (P11 ✔). Next: in-game planning (P10) as Beta 4.
- 2.0.0 all-in-one · 2.1.0 tooltips/minimap/today · 2.2.0 profession planner · 2.3.0 Beta 1 (beta channel, crafted mats, gather hint, mailbox summary)
- Repo, releases, self-updater, beta channel, tests in repo, cycle rules

## 📏 Definition of done
Tests pass (`tests/test_addon.py`) · app starts · CHANGELOG + NEWS written · no dependency on other addons · no conflicts with installed addons · shipped as beta between cycles, stable only at a cycle.
