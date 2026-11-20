# Changelog

All notable changes to FlipForever. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [Semantic Versioning](https://semver.org/).

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
