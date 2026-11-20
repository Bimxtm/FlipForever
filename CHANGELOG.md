# Changelog

All notable changes to FlipForever. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [Semantic Versioning](https://semver.org/).

## [2.3.0-beta.3] - 2026-11-20 (beta)
### Added
- **Combat helper, one key for everything:** with *Auto-target* on (default), each press first picks the nearest enemy if you have no target, or yours is dead or friendly. **Tank mode** (on automatically for Protection builds, or tick it yourself): click an ally, and the key hits whatever is on them (`/assist`), with Taunt/Growl early in each round. A red line warns "Your target is attacking <ally>!". Only Blizzard-allowed macro targeting is used.
- **Scan finished → alert:** a sound and raid warning ("Scan saved - click Reload"), and the Reload button lights up. **Autopilot pauses** until you reload, so it never buys from an outdated list. It can be switched off in the FlipForever window.
- **App builds the list by itself:** after importing a new scan it builds the selected character's shopping list, plays a sound and pops to the front with "click Reload in game". Switch: Settings → *Auto-build the shopping list after a new scan*.

## [2.3.0-beta.2] - 2026-11-20 (beta)
### Added
- **Reload button** on the auction house panel and in the FlipForever window: one click loads the newest shopping list and saves your scans for the app. It's refused during combat, while a purchase is waiting, and during a scan.
- **Development tab** in the app: this week's board (goals, usage budget, plan by day, problems) and the roadmap, as kept up to date by the improvement cycles.
- Weekly board, problem tracking and usage budget in `docs/`, shipped with the app.

### Changed
- App: tighter tab bar (all tabs fit); "list ready" message points to the Reload button.
- Releases: every finished change goes out as a beta right away; stable versions at the 12-hour cycle.

## [2.3.0-beta.1] - 2026-11-20 (beta)
### Added
- **Beta channel:** a "Get beta versions (for testing)" checkbox in About & updates. Betas are GitHub pre-releases; without the box ticked you only get stable versions.
- **Profession planner:** materials you craft yourself (like Bolt of Linen Cloth) now also list *their* materials, which are added to "Buy missing mats".
- **Profession planner:** "you can gather this" next to ores and herbs you can collect yourself.
- **Mailbox summary:** opening the mail prints one line: how many auctions sold since your last visit and what they made after the AH cut.

### Changed
- Releases: stable versions only at the 12-hour cycle; betas in between.

## [2.2.0] - 2026-11-20
### Added
- **Profession planner,** built in with no other addon needed. Open any profession window and FlipForever reads its recipes (difficulty colour, materials, result) and remembers them per character. It ranks crafts by cost per skill-up, (materials - what the result sells for) / chance, with orange 100%, yellow ~75% and green ~25%, using FlipForever's own auction prices (vendor goods ~4x sell price; things you craft yourself are priced by their own materials). It suggests how many to craft, flags an unlearned recipe when the trainer visit is worth it, and lists missing materials against your bags and bank.
- **Buy missing mats:** one click queues the top craft's materials. At the auction house, **Buy profession mats** works through them, one key press per purchase and never above the price limit (+25% over the typical price).
- The planner opens next to the profession window (can be switched off), from **Professions** in the FlipForever window, and its cheapest next skill-up appears in the Advisor.

### Fixed
- Money display no longer breaks on "no limit" values (it shows "-").

## [2.1.0] - 2026-11-20
### Added
- **Prices in item tooltips:** FlipForever's typical price on every item it has scanned, plus "on your shopping list (max ...)" and "you post at ... (never below ...)" for items on your lists. It can be switched off in the FlipForever window.
- **Minimap button summary:** hovering the gold coin shows your shopping list and budget left, today's trading, autopilot status and the advisor's top step.
- **Today's results** on the auction house panel: sold and bought today, for the character you're playing.

### Changed
- Developer: the test suite now lives in the repository (`tests/`); release builds go to `dist/` and never touch a running FlipForever.exe.

## [2.0.0] - 2026-11-20
### Added
- **All-in-one addon.** Ore Farmer is now built into FlipForever as the **Gathering** module (`/ore`). It maps your ore, herb, fishing and treasure spots, reads GatherLite's 35,000+ spots, plans farming loops and estimates gold per hour using FlipForever's own price scans.
- **Advisor** (`/ff guide`). It detects your race and class, and you pick the build to follow. It re-checks after every level-up, quest turn-in, gear change, talent point, skill-up, zone change and gold change, and shows talents, class quests, gear to hunt (and which dungeon has it), zones, dungeons, professions, bags and gold milestones. It uses post-launch guides (Method, 14-19 Nov 2026); beta-era sources are marked.
- **Combat helper.** An icon bar near the top of the screen: click the big icon, and the next spell appears. It follows your build and the spells you know, and adapts to the target you select before a fight (immunities, Exorcism vs undead and demons, crowd control, a danger warning). It can also use Blizzard's one-button assistant if the client has it.
- **FlipForever window and minimap button.** Every feature and setting is reachable with the mouse, including "press a key" binding with conflict checks.
- **Desktop app:** Advisor and Gathering tabs, and an **About & updates** tab with one-click self-update from GitHub Releases (SHA-256 verified).
- Tools: `fix_addon_conflicts.py` (turns off duplicate addons per character) and `migrate_orefarmer.py` (moves Ore Farmer data into FlipForever). Both refuse to run while WoW is open and keep backups.

### Changed
- The addon now uses one AddOns-menu entry ("FlipForever") instead of several.
- The combat bar's default position sits below the top band used by EllesmereUI, LayerSwap, WhatsTraining, Dungeon Journal and Schmendrick.

### Fixed
- Key binding refuses keys another addon is currently holding (e.g. Schmendrick's fishing key, Auctionator's SPACE).

## [1.5.0] - 2026-11-20
### Added
- `FlipForever.exe` (no Python needed) and a desktop shortcut.

## [1.4.0] - 2026-11-20
### Added
- **Autopilot:** checks the shopping list every minute and runs a full scan every 30 minutes, with a sound, raid warning, flashing panel and taskbar flash when a flip is found.
- Shares the auction house with Auctionator, Auctioneer and Schmendrick: respects the shared 15-minute full-scan cooldown, reuses other addons' scans and steps aside when you or another addon use the auction house.

## [1.3.0] - 2026-11-20
### Added
- Per-character budgets, stock, profit, history and shopping lists; price knowledge stays shared.

## [1.2.0] - 2026-11-20
### Added
- **First-scan mode:** buys right after one scan by reading the live listings for deep markets, never posting below cost.

## [1.1.0] - 2026-11-20
### Added
- Hard budget limit with deposit reserve and a 40% per-item cap.
- Speed rules: only buys items that sell fast (sales per day, sell chance, your own time-to-sell); slow stock gets cheaper until it moves.

## [1.0.0] - 2026-11-20
### Added
- First release: desktop app plus in-game addon for WoW: Forever auction house flipping, with self-learning prices, sell chance and margins.
