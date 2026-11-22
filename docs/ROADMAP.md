# Roadmap

## Ready for approval
- Nothing waiting.

## Released in 2.7.0
- **Talent builds on the Talents window** (from the 2.6.0 betas): build marked on the Talents window, next point gold, order panel, level bands, `/ff talents`.
- **Quest helper** (from the 2.7.0 betas): learned quest spots, world map and minimap pins, `/ff quest`. Next: pins from the quest log, and the Advisor's quest steps using the learned spots.

## In the 2.7.1 betas
- **Community page** (beta 1): updates, roadmap, bug tickets, suggestions, Top reporters.
- **Reports from the game** (beta 2): `/ff bug`, `/ff suggest`, Report a bug button; gear finder stat gains; Advisor steps pinned on the map.
- **Beta 3:** the combat helper tests the spell orders from written class guides; UI and content pass (one window style, grouped Settings in game and app, `/ff help`, Talents button, Clear pins, minimap pin tooltips); Rules page in the app's Community; choose an older version; controller support (bindable combat, emergency and arrow actions, gamepad buttons in Set key, readable button names); quest log Pin on map button; Advisor class quests use their learned next spot; leveling route guide (approved suggestion).

## Planned
- **Leveling route guide, next:** positions for the towns in WoW: Forever's own zones (learned as you play), and moving on when you reach the town.
- **Autopilot rework:** the auction house autopilot is off until it is reworked.

## Smaller improvements
- Code protection (owner question 22 Nov): no obfuscation of the addon (Blizzard's addon rules require readable code); the app stays open source.
- Fixes from real play come first (bug reports from players).
- Combat helper and Advisor: names for the WoW Forever-only spells in every game language.
- Advisor: refresh builds when Warcraft Tavern replaces its level 30 beta builds, and add Mobalytics/Icy Veins builds once they can be read.
- App: the How to use page in every language.

### Ideas from popular addons (21 Nov, owner request; our own versions, nothing copied)
Players most often name Questie, Details!, Leatrix Plus, Auctionator, Bagnon, WeakAuras, GatherMate/GatherLite, WhatsTraining and threat meters as must-haves for Classic and WoW: Forever. All eight small ideas from that list are built (2.5.2 betas 2-11): sell junk and repair, trainer reminder, time to level, threat warning, open all mail, bag value, price trend in the app, node timers. The big ones are below under Proposed.

## Proposed
- **(done in 2.7.0) Quest helper on the map** (Questie, the most downloaded Classic addon): quest objectives and turn-ins as map pins and in the waypoint arrow, built on our quest locations. Big: needs our own quest data. Branch feature/quest-helper.
- **Leveling route guide** (RestedXP-style guides): a step-by-step route per race and level range inside the Advisor, with the waypoint arrow. Big: route data written from scratch. Branch feature/leveling-route.
- **Disenchant and enchanting profits** (Enchantrix): what an item is worth disenchanted against its auction price, and a "buy to disenchant" list. Needs our own disenchant tables. Branch feature/disenchant.

## Done
- 2.5.2 (betas): sell junk and repair, open all mail, time to level, bag value, trainer reminder, threat warning, combat helper buffs and paladin fixes, gathering node timers, 7-day price trend in the app, a switch for every feature; all in every game language.
- 2.5.0 (betas): crafting profit finder in the profession planner; gear finder for affordable auction house upgrades; encrypted token storage; setup for other players; all 11 game languages (menus and buttons so far); vendor flips; deposit-accurate profit math; vendor floor when posting; combat helper for levels 1-60; exact skill-up chances; 9 builds per class from Method, Warcraft Tavern and RankedBoost; waypoint arrow; quest locations; collect auction gold; gear upgrade alert; spells in every client language.
- 2.4.0 (betas): tabbed in-game window with a shopping-list view, app sidebar and layout, Gathering in the common look, best farming zone in the Advisor, smarter undercut, a reason on every Advisor step.
- 2.3.0: in-game planning after each scan, one-key combat targeting with tank mode, scan alerts, lists built automatically after import, sell speed in tooltips, window position remembered, in-game test checklist, beta channel, Development tab.
- 2.2.0: profession planner, buying missing materials at the AH.
- 2.1.0: prices in item tooltips, minimap summary, today's results on the AH panel.
- 2.0.0: all-in-one addon (Gathering, Advisor, Combat helper, FlipForever window, updater).
