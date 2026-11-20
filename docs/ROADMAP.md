# Roadmap

## Ready for approval (built, not released)
- **Quest locations** (branch `feature/quest-locations`). Class quest steps in the Advisor say who starts them and where, per faction and race (Warcraft Wiki data for all class quests the Advisor lists: warrior, paladin, hunter, rogue, shaman, warlock and druid). The addon remembers where every NPC you talk to stands; when a quest giver's position is known, clicking the step points the waypoint arrow there. Tested; merged and released once approved. Limit: the wiki gives coordinates for few quest givers, so most positions are learned as you play.

## Planned
- **GUI overhaul (2.4.0, in progress).** In game: a tabbed FlipForever window, a common look for every panel, and an editable shopping-list view. In the app: sidebar navigation and a cleaner layout.

## Smaller improvements
- Translate the remaining texts (Advisor steps, chat messages, app pages) into all 11 languages.
- Language-independent spells (spell IDs), so the advisor and combat helper work on any client language.
- Advisor: refresh builds when Warcraft Tavern replaces its level 30 beta builds, and add Mobalytics/Icy Veins builds once they can be read.

## Done
- 2.5.0 (betas): crafting profit finder in the profession planner; gear finder for affordable auction house upgrades; encrypted token storage; setup for other players; all 11 game languages (menus and buttons so far); vendor flips; deposit-accurate profit math; vendor floor when posting; combat helper for levels 1-60; exact skill-up chances; 9 builds per class from Method, Warcraft Tavern and RankedBoost; waypoint arrow.
- 2.4.0 (betas): tabbed in-game window with a shopping-list view, app sidebar and layout, Gathering in the common look, best farming zone in the Advisor, smarter undercut, a reason on every Advisor step.
- 2.3.0: in-game planning after each scan, one-key combat targeting with tank mode, scan alerts, lists built automatically after import, sell speed in tooltips, window position remembered, in-game test checklist, beta channel, Development tab.
- 2.2.0: profession planner, buying missing materials at the AH.
- 2.1.0: prices in item tooltips, minimap summary, today's results on the AH panel.
- 2.0.0: all-in-one addon (Gathering, Advisor, Combat helper, FlipForever window, updater).
