# Roadmap

## Ready for approval
- **Talent builds on the Talents window (2.6.0 beta 6, branch feature/talent-overlay):** build talents marked in order on the game's Talents window, finished ones green, the next point gold; a panel beside it with the whole order, your ranks, the tree of each talent (click to open it), the point split, points left to spend, the build's role and how to play it; key-talent-only builds ordered by tier; `/ff talents` opens the window; hover a talent for its description and the build's pick. A warning flags points in trees the build leaves empty. The panel also shows where your points should stand at levels 20 to 60 and how far behind the order you are.

## Planned
- **Talent builds on the Talents window (2.6.0, owner request):** the chosen build shown right on the game's Talents window, next point highlighted, and the builds fleshed out further.
- **Autopilot rework:** the auction house autopilot is off until it is reworked.

## Smaller improvements
- Fixes from real play come first (bug reports from players).
- Combat helper and Advisor: names for the WoW Forever-only spells in every game language.
- Advisor: refresh builds when Warcraft Tavern replaces its level 30 beta builds, and add Mobalytics/Icy Veins builds once they can be read.
- App: the How to use page in every language.
- App: switch to the character you are logged in with automatically.
- Gear finder: compare the stat gains of an upgrade, not only armor and item level.
- Advisor: pin a step to the map with the place and the person to talk to, like the game's quest tracker (extends the waypoint arrow).

### Ideas from popular addons (21 Nov, owner request; our own versions, nothing copied)
Players most often name Questie, Details!, Leatrix Plus, Auctionator, Bagnon, WeakAuras, GatherMate/GatherLite, WhatsTraining and threat meters as must-haves for Classic and WoW: Forever. All eight small ideas from that list are built (2.5.2 betas 2-11): sell junk and repair, trainer reminder, time to level, threat warning, open all mail, bag value, price trend in the app, node timers. The big ones are below under Proposed.

## Proposed
- **Quest helper on the map** (Questie, the most downloaded Classic addon): quest objectives and turn-ins as map pins and in the waypoint arrow, built on our quest locations. Big: needs our own quest data. Branch feature/quest-helper.
- **Leveling route guide** (RestedXP-style guides): a step-by-step route per race and level range inside the Advisor, with the waypoint arrow. Big: route data written from scratch. Branch feature/leveling-route.
- **Disenchant and enchanting profits** (Enchantrix): what an item is worth disenchanted against its auction price, and a "buy to disenchant" list. Needs our own disenchant tables. Branch feature/disenchant.
- **UI and content pass:** rework the windows a little and refresh all content so the parts work better together (owner suggestion, 21 Nov). Needs a plan before work starts.

## Done
- 2.5.0 (betas): crafting profit finder in the profession planner; gear finder for affordable auction house upgrades; encrypted token storage; setup for other players; all 11 game languages (menus and buttons so far); vendor flips; deposit-accurate profit math; vendor floor when posting; combat helper for levels 1-60; exact skill-up chances; 9 builds per class from Method, Warcraft Tavern and RankedBoost; waypoint arrow; quest locations; collect auction gold; gear upgrade alert; spells in every client language.
- 2.4.0 (betas): tabbed in-game window with a shopping-list view, app sidebar and layout, Gathering in the common look, best farming zone in the Advisor, smarter undercut, a reason on every Advisor step.
- 2.3.0: in-game planning after each scan, one-key combat targeting with tank mode, scan alerts, lists built automatically after import, sell speed in tooltips, window position remembered, in-game test checklist, beta channel, Development tab.
- 2.2.0: profession planner, buying missing materials at the AH.
- 2.1.0: prices in item tooltips, minimap summary, today's results on the AH panel.
- 2.0.0: all-in-one addon (Gathering, Advisor, Combat helper, FlipForever window, updater).
