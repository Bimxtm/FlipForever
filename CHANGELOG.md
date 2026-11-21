# Changelog

All notable changes to FlipForever. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [Semantic Versioning](https://semver.org/).

## [2.6.0-beta.4] - 2026-11-21 (beta)
### Added
- Talents panel: hover a talent for the game's description of it, its tree, the build's pick number, the target rank and whether it is done or next.
- Talents window: the tooltip of a marked talent shows its pick number in the build and your rank against the target.

## [2.6.0-beta.3] - 2026-11-21 (beta)
### Added
- Talents panel: click a talent to open its tree on the Talents window.
- Builds whose guide names only the key talents now get an order: lower tiers first, and the next point is always one you can already take. When a key talent needs more points in its tree first, the panel says how many.

## [2.6.0-beta.2] - 2026-11-21 (beta)
### Added
- Talents panel: the tree of every talent after its name, the build's role, how to play the build (its rotation), and how many points you have left to spend.
- `/ff talents` opens or closes the game's Talents window (from level 10).
- Includes the 2.5.2 Beta 1 fixes: paladin seal and Judgement in the combat helper, no blocked action when clicking the combat icon in a fight, blocked actions in `/ff errors`.

## [2.6.0-beta.1] - 2026-11-21 (beta)
### Added
- Talents window: your chosen Advisor build is shown right on the game's Talents window. Every talent of the build carries its place in the order, talents you have finished are marked green and the next point is marked gold.
- A panel beside the Talents window lists the whole talent order with your ranks, the build's point split next to yours, and which tree the next point goes into. Switch builds with the arrows at its top.
- Settings: *Show my build on the Talents window* (on by default).

## [2.5.2-beta.10] - 2026-11-21 (beta)
### Added
- App, Deals: a *7-day trend* column - the cheapest listing in your newest scan against the usual price of the last 7 days (+12% dearer, -8% cheaper, or steady). The price history window shows it too.
- App, Inventory & selling: double-click an item for its price history, with your cost, the floor and the fair value marked.

## [2.5.2-beta.9] - 2026-11-21 (beta)
### Added
- Overview: bag value line. What your bags fetch at a merchant, what they fetch selling each item the better way (auction price after the 5% cut, or the merchant), and how many items are clearly worth posting. Hover it for the list, biggest gain first. Soulbound and grey items count at the merchant price. Switch: *Overview: value of my bags, items worth posting* in Settings, Features.

## [2.5.2-beta.8] - 2026-11-21 (beta)
### Added
- Mailbox: *Open all mail* under *Collect auction gold* takes the gold and items from every mail, one at a time. Mail with cash on delivery is left alone, and it stops with a message when your bags are full. A chat line shows what was taken. Switch: *Open all mail button at the mailbox* in Settings, Features.

## [2.5.2-beta.7] - 2026-11-21 (beta)
### Added
- Combat helper: threat warning under the icons. Damage and healing: an orange line from 85% of the threat that pulls aggro, a red one when your target attacks you. Tanks: a red line when you lose aggro. Uses the game's own threat numbers. Switch: *Combat helper: warn me about high threat* in Settings, Features.

## [2.5.2-beta.6] - 2026-11-21 (beta)
### Added
- Overview: a leveling line with your XP per hour this session, how long until the next level at that pace, and your rested XP. Hidden at level 60. Switch: *Overview: XP per hour, time to level, rested XP* in Settings, Features.

## [2.5.2-beta.5] - 2026-11-21 (beta)
### Fixed
- App: after an update, the new version sometimes failed to start with "Failed to load Python DLL" (it looked for the old version's temporary files, which were already gone). The new version now always starts cleanly. Updates from this version onward restart without the error; if you saw it once, just start FlipForever again: the update itself was installed.

## [2.5.2-beta.4] - 2026-11-21 (beta)
### Added
- Advisor: trainer reminder. When you open your class trainer, FlipForever notes the spells you can't learn yet, with their level and cost. Once you reach that level, the Advisor shows "New at your class trainer: N spells" with the total cost, and the spell names in the step's reason. Profession trainers are left out. Switch: *Advisor: remind me of new spells at my class trainer* in Settings, Features.

## [2.5.2-beta.3] - 2026-11-21 (beta)
### Added
- Settings: every feature can be switched on and off. A new *Features* section has switches for the sell junk strip at merchants, always selling grey items, always repairing, the undercut check at the auction house, the *Collect auction gold* button at the mailbox, and the gear upgrade line in item tooltips.
### Changed
- The Settings tab scrolls (mouse wheel or the bar on the right), so everything fits.

## [2.5.2-beta.2] - 2026-11-21 (beta)
### Added
- Merchants: a strip under the merchant window with a *Sell junk* button (sells every grey item with a value) and two switches, *Always sell junk* and *Always repair*. Both are off until you tick them. Repairs use your own gold, never the guild bank, and a chat line shows what was earned or spent.

## [2.5.2-beta.1] - 2026-11-21 (beta)
### Fixed
- Combat helper, paladins: the seal is cast again after every Judgement. Seal and Judgement now run as a sequence that only moves on after a successful cast; Consecration and other cooldowns fill the gaps, then Holy Strike. Before, Consecration came first on every press and the seal was left out.
- Combat helper: clicking the big icon in a fight no longer causes "Interface action failed because of an AddOn" (the bar only stops moving when you moved it).
### Added
- Actions the game blocks for FlipForever are kept in `/ff errors` and in *Copy bug report info*, with the function name and whether a fight was on.

## [2.5.1] - 2026-11-21
### Added
- The app offers to put FlipForever on your desktop and in the Start menu the first time it starts, and About & updates has an *Add to desktop and Start menu* button.
### Changed
- Downloads and updates come straight from the public GitHub releases: no GitHub token needed. The app checks at start, asks, then updates itself and the WoW addon. Nothing else needs to be installed.

## [2.5.0] - 2026-11-21
All 2.4 and 2.5 betas in one release (see the beta entries below), plus:
### Added
- All 11 game languages for the FlipForever window, the Advisor, the profession planner, chat messages, the auction house panel, item tooltips and every app page, including How to use.
- Gear tab: hover an item for its full name and stats, shown next to what you wear in that slot. Names no longer run into the next row.
### Changed
- The auction house autopilot is turned off for now while it gets more work.
### Fixed
- The Advisor's data (your chosen build, next steps, upgrades) was wiped at every login, so the build choice didn't stick and the app's Advisor page stayed empty.
- When the game reported an empty realm name, data was saved under " - Horde" instead of your realm; it is moved back on the next login.
- Combat helper: druids get the bear skills in Bear Form, the cat skills in Cat Form and caster spells otherwise, in every press.
- Opening the Advisor window can no longer fail silently: an error is shown and kept for bug reports.

## [2.5.0-beta.29] - 2026-11-21 (beta)
### Fixed
- Combat helper: with *Wait for cooldowns* on, the button could stop on one skill for the rest of the fight (a finisher without combo points, a shout or shield that was already up, not enough rage). It now moves on to the next skill with every press again, and your cooldown abilities still fire first whenever they're ready.

## [2.5.0-beta.28] - 2026-11-21 (beta)
### Added
- The Advisor is easier to reach: an **Advisor** button in the FlipForever window's title bar (on every tab), the next step on the Overview opens it when clicked, and Key Bindings now has a FlipForever section with keys for the Advisor and the FlipForever window. `/ff guide` and right-clicking the minimap coin still work.

## [2.5.0-beta.27] - 2026-11-21 (beta)
### Fixed
- Changing the gold budget in Settings now also changes it for the selected character and in the budget box at the top. Before, a character that already had its own budget kept the old one.
- After a budget change, the app says what to do next: Build shopping list, then Reload in game, so the addon uses the new budget.

## [2.5.0-beta.26] - 2026-11-21 (beta)
### Added
- `/ff errors` lists the addon's last five errors in chat (time, version, where it happened), so you can check or screenshot them for a bug report without leaving the game.

## [2.5.0-beta.25] - 2026-11-21 (beta)
### Added
- **Copy bug report info** (app, About & updates): copies the app and addon versions, your Windows version, language and setup, and the addon's last errors, ready to paste into a bug report. Windows user names in paths are replaced, and no character or account names are included.
- The addon keeps its last 20 errors (time, version, where it happened) for this.

## [2.5.0-beta.24] - 2026-11-21 (beta)
### Added
- App, Advisor page: each character's auctions from the last auction house visit (how many are up, which are undercut, yours against the cheapest price).

## [2.5.0-beta.23] - 2026-11-21 (beta)
### Changed
- **Random-stat gear is judged version by version.** A full scan now keeps the cheapest listing of every version of an item ("of the Bear", "of the Owl", ...), and the gear finder scores each on its own stats and price. Buying an upgrade searches for exactly that version and never buys a different one of the same item.

## [2.5.0-beta.22] - 2026-11-21 (beta)
### Added
- **Undercut check.** When you open the auction house, FlipForever looks at your own listings and compares them with your newest scan. If someone listed cheaper, one chat line names the biggest undercut, and the Overview shows how many of your auctions are up and how many are undercut. Nothing is cancelled or reposted on its own.

## [2.5.0-beta.21] - 2026-11-21 (beta)
### Added
- Item tooltips show **upgrade for you** with the gain and slot when a piece of gear beats what you wear (same stat weights as the Gear tab).
- In-game Overview: how old your newest scan is, in orange after 6 hours with a reminder to scan again.
### Fixed
- Gathering prices page: without a scan it no longer says that no auction addon was found; it says vendor prices are used until you scan.

## [2.5.0-beta.20] - 2026-11-21 (beta)
### Added
- **Spells in every client language.** The combat helper and the Advisor look spells up by their spell ID, so rotations, class quests and the cooldown check work on German, French, Spanish, Russian and the other game languages, not only English. A few WoW: Forever-only spells keep their English name for now.
- `/ff spells` checks the spell list against the game and names any spell whose ID doesn't match (in-game test checklist, step 11).

## [2.5.0-beta.19] - 2026-11-21 (beta)
### Added
- App, Deals page: *Fast sellers only* and a minimum profit per unit (in silver) to narrow the list. First-scan picks stay visible, since the addon judges them live.
- In-game Overview: this week's result (sales after the AH cut minus purchases, today and the six days before) under today's line.

## [2.5.0-beta.18] - 2026-11-21 (beta)
### Added
- **Collect auction gold.** A button next to the mailbox takes the gold from every auction sale mail in one click and shows the total. Mail with items or COD, won auctions, expired items and letters from players are never touched.
- **Gear upgrade alert.** When a scan finds an affordable gear upgrade that wasn't on the list before, you hear a sound and get a chat line with the item, slot and price. It can be turned off in the FlipForever window.
### Changed
- Combat helper: the small cooldown icons show the seconds left (minutes above one minute).

## [2.5.0-beta.17] - 2026-11-20 (beta)
### Added
- **Quest locations.** Class quest steps in the Advisor now say who starts the quest and where, for your race and faction: warrior, paladin, hunter, rogue, shaman, warlock and druid quests, from Warcraft Wiki. Hover a step to see the full chain.
- FlipForever remembers where every NPC you talk to stands. Once it knows where a quest giver is, click the quest step in the Advisor and the waypoint arrow points there.

## [2.5.0-beta.16] - 2026-11-20 (beta)
### Changed
- The combat helper's key is **+** by default (the + key and numpad +). A key you set yourself replaces it; *Clear* removes all keys.

## [2.5.0-beta.15] - 2026-11-20 (beta)
### Changed
- **Combat helper waits for cooldowns (smart mode, on by default).** Each press now uses one macro that the game itself evaluates:
  - abilities with a cooldown (Mortal Strike, Judgement, Mind Blast, Stormstrike, Fire Blast, Bestial Wrath and so on) are cast the moment they're ready
  - the rest of the rotation is a cast sequence that only moves on after a successful cast, so a spell that isn't ready is never skipped
  - the big icon shows what the next press really casts; the small icons are your cooldown abilities, dimmed while they recharge
  - the old one-step-per-press mode is still there: untick *Wait for cooldowns* in the FlipForever window

## [2.5.0-beta.14] - 2026-11-20 (beta)
### Changed
- In-game shopping list: deals come first (best profit first), then items being watched, then done and skipped ones. A new *Profit* column shows the expected profit per unit at today's lowest price, after the AH cut (green when positive).

## [2.5.0-beta.13] - 2026-11-20 (beta)
### Added
- App Dashboard: **profit per character** (realized profit, last 7 days, stock at cost, sales and units bought), best first. It appears when more than one character on the realm trades.

## [2.5.0-beta.12] - 2026-11-20 (beta)
### Added
- **Gear finder checks your bags too.** Gear you carry that beats what you wear is listed first in the Gear tab (marked *in bags*), with an **Equip** button. The Advisor tells you to put it on. It updates when your bags or gear change.

## [2.5.0-beta.11] - 2026-11-20 (beta)
### Changed
- **Auction length by sell speed.** The deposit grows with the auction length, so items that sell 12 or more a day are now posted for 12 hours (smallest deposit). Items selling 3-12 a day get 24 hours and slower ones 48 hours, to find a buyer. Items without sales data use your usual setting. It can be switched off in the FlipForever window (Settings).

## [2.5.0-beta.10] - 2026-11-20 (beta)
### Changed
- The Advisor's steps are translated into all 11 languages: talents, class quests, weak slots, dungeons, zones, professions, profitable crafts, farming zone, bags, gold milestones and power spikes. Item, quest and zone names stay as the guides write them.

## [2.5.0-beta.9] - 2026-11-20 (beta)
### Added
- App, Advisor page: each character's top auction house gear upgrades and most profitable crafts, as found in game (shown after the next Reload or logout).

### Changed
- Faster in-game planning: every saved scan is read only once and then kept. Rebuilding the shopping list after a new scan reads just that one scan, not all of them, so it's much quicker with many scans.

## [2.5.0-beta.8] - 2026-11-20 (beta)
### Added
- **Waypoint arrow.** A movable on-screen arrow with the distance in yards; it turns green when you face the right way. It points to, in this order:
  - a point you set with `/ffway 45.2 60.8` (clear it with `/ffway`)
  - the pin you place on the world map, if the client has map pins
  - the next stop on your Gathering loop
  - It hides when there's nothing to point at and fades when the target is on another map. Switch: FlipForever window, Settings tab.

## [2.5.0-beta.7] - 2026-11-20 (beta)
### Changed
- More of the addon is translated into all 11 languages: every checkbox in the FlipForever window's Settings tab, the Advisor window (Do this next, Build details, Re-check, pop-up option) and the profession planner (headings, view switch and buy buttons).

## [2.5.0-beta.6] - 2026-11-20 (beta)
### Added
- **9 builds for every class**, collected from the current WoW: Forever guides: Method's leveling guides (updated 14-19 Nov), Warcraft Tavern's level 60 class guides (updated 1-11 Nov) and RankedBoost's build list (updated 8 Nov). Every spec is covered, with leveling, dungeon and raid damage, tank, healer and PvP builds.
  - Each build shows its role, point split, the guide's note and rotation, and its talents. Builds whose guide gives no pick order are marked *Key talents*. Warcraft Tavern's older level 30 beta builds are marked as beta.
  - Pick a build in the Advisor with the < > buttons, as before.
- **Combat helper rotations for the new builds:** Fury, Marksmanship, Survival, Assassination, dagger Combat, Subtlety, Shadow, Holy/Discipline (solo damage), Elemental, Fire, Frostfire, Arcane, Wrack Affliction, Demonology (Fire and Shadow), Destruction, bear tanking and Balance.
- Tank mode now turns on for every tank build, not only Protection and Feral.

## [2.5.0-beta.5] - 2026-11-20 (beta)
### Added
- **Combat helper from level 1 to 60.** Every class follows three level bands:
  - Levels 1-10: starter sequences built from the first spells you learn, e.g. Raptor Strike for hunters before their pet, seal and judge for paladins.
  - Levels 11-39: your build's core rotation, as before.
  - Levels 40-60: the full rotation with the later abilities and talents, such as Whirlwind and Sweeping Strikes, Bestial Wrath and Rapid Fire, Blade Flurry and Adrenaline Rush, Vampiric Embrace, Chain Lightning, Presence of Mind, Conflagrate, Insect Swarm and Starfire.
  - Spells you don't know yet are skipped, and reactive abilities are left out so no key press is wasted.
- **Exact skill-up chances.** The profession planner remembers the skill level at which each recipe turns yellow, green or grey. It then uses the real chance, (grey - skill) / (grey - yellow), instead of the colour average. This is shared by all your characters.

## [2.5.0-beta.4] - 2026-11-20 (beta)
### Added
- **Vendor flips.** After every scan, listings priced below what a merchant pays (at least 15% and 5 copper per unit under) go on the shopping list. Items bought this way are sold automatically the next time you open any merchant. It can be switched off in the FlipForever window (Settings).

### Changed
- **More accurate profit math:** the deposit is refunded when an item sells, so only auctions that expire cost it. Max buy prices are about 1-2% higher where that was too cautious. This applies equally in the app and in game.
- **Never sell below vendor price:** posting never goes under what a merchant pays (after the AH cut). Loot the auction house values at under 1.5x its vendor price is skipped, with a hint to vendor it, because an expired auction costs the deposit and time.
- Cheaper items are worth flipping now that the minimum deposit is tiny: the default "ignore items worth less than" drops from 1 silver to 50 copper for new setups.

## [2.5.0-beta.3] - 2026-11-20 (beta)
### Added
- **Languages.** The app and the addon support every language the game does: English, German, French, Spanish (Spain and Mexico), Italian, Brazilian Portuguese, Russian, Korean, and Simplified and Traditional Chinese.
  - In game, the language follows your game client by default. Change it in the FlipForever window under Settings, then Reload.
  - In the app, pick it in Settings; it applies on the next start.
  - Covered so far: window and tab names, menus, buttons and the auction house panel. Other texts stay in English until they're translated.
  - Russian, Korean and Chinese letters need the game client in that language, because it brings the fonts.

## [2.5.0-beta.2] - 2026-11-20 (beta)
### Added
- **Gear finder.** A new *Gear* tab in the FlipForever window lists auction house upgrades for the character you're playing:
  - It covers gear your class can use (your best armor type, mail or plate from level 40, and your weapon types), with a required level from 10 below yours up to yours.
  - Each item is scored with your class's stat weights and compared with what you wear in that slot. Rings, trinkets and two-handers are compared sensibly.
  - It only lists what costs at most a quarter of your gold. *Buy* buys it at the auction house with one key press.
  - It searches by itself after login, after a level-up and after every scan. The best upgrade also appears as an Advisor step.
- Setup for other players: the README explains how a friend sets up their own copy. The download no longer contains maintainer-only tools.

### Security
- The GitHub token is now stored encrypted with Windows data protection (DPAPI). Only your Windows account on your PC can decrypt it, and existing tokens are encrypted on the next save.

## [2.5.0-beta.1] - 2026-11-20 (beta)
### Added
- **Crafting profit finder.** The profession planner has a second view, *Show profitable crafts*. It lists every recipe you know, across all professions you've opened, whose result sells for more than its materials after the 5% AH cut and a deposit allowance. Materials you craft yourself are costed from their own materials.
  - Only results that sell at least 3 a day, so nothing sits in your bags. The suggested amount is what you can sell in about two days (at most 20).
  - **Buy mats for the top craft** queues the missing materials. At the auction house, *Buy profession mats* works through them with the usual price limit.
  - The best profitable craft also appears as an Advisor step.

## [2.4.0-beta.5] - 2026-11-20 (beta)
### Added
- Advisor: hover a step to see its full text and why it's suggested, e.g. your build's talent order and its guide, a gear upgrade for a weak slot, or gold per hour measured from your own gathering.

## [2.4.0-beta.4] - 2026-11-20 (beta)
### Changed
- **Smarter undercut when posting:** if the cheapest listing is a tiny lot (5% or less of what others have up) priced 30%+ below the next one, it's a dump that will sell in minutes. FlipForever now prices against the next real listing instead of chasing it down, and says so in chat. At most the two cheapest lots are ignored like this. Your own auctions, from any character on your account, are still never undercut.

## [2.4.0-beta.3] - 2026-11-20 (beta)
### Added
- **Advisor: your best farming zone.** If you mine or pick herbs, the Advisor names the zone that has made you the most gold per hour so far (after 10+ minutes and 10+ nodes there, at FlipForever's prices). Until then it tells you how to measure one.

### Changed
- **Better GUI, part 3:** the Gathering window and tracker match the rest of FlipForever (green frame, same background, "FlipForever Gathering" title). Map-pin tooltips say "Your gathering spot", and the last messages still naming Ore Farmer now say Gathering.

## [2.4.0-beta.2] - 2026-11-20 (beta)
### Changed
- **Better GUI, part 2 (app):** a sidebar grouped into Trading, Character and App replaces the long tab row. Each page has a title and a one-line explanation.
  - Tables have striped rows, and the stripes stay right after sorting.
  - Dashboard cards have a colour strip: green for profit, gold for stock, blue for market data. Profit numbers turn green when you're up and red when you're down.
  - Tighter top bar: everything fits at the smallest window size.
- Dashboard steps and How to use describe the new flow: the list builds itself in game after a scan, and you reload only now and then to sync with the app.

## [2.4.0-beta.1] - 2026-11-20 (beta)
### Added
- **Better GUI, part 1 (in game):** the FlipForever window now has tabs.
  - **Overview:** your list and budget left, today's trades, autopilot status, the Advisor's next step, and the buttons you use most.
  - **Shopping list:** every item with the lowest price in your last scan (green when it's below your max), your max, how many you bought, and a **Skip** box. Skipped items are never bought on that character until you untick them. Scroll with the mouse wheel.
  - **Settings:** everything that was in the window before.
- The Settings buttons on the auction house panel and in the Advisor open the Settings tab directly.

## [2.3.0] - 2026-11-20
Everything from Betas 1-4, plus:

### Added
- **Item tooltips: "sells on the AH ~N/day"** (fast, ok, slow), estimated from your own scans.
- **In-game test checklist** (`docs/IN_GAME_TEST.md`, also in the app's Development tab): 13 quick checks to confirm everything works in the real game.
- App: remembers its window size and position (and maximised state).

### Included from the betas
- In-game planning after every scan: no reload needed for a new shopping list (Beta 4).
- Combat helper: one key also picks targets, with tank mode (Beta 3).
- Scan-finished alert, and the app builds the list by itself after importing (Beta 3).
- Reload button and the app's Development tab (Beta 2).
- Beta channel, crafted mats list their own mats, "you can gather this", mailbox summary (Beta 1).

## [2.3.0-beta.4] - 2026-11-20 (beta)
### Added
- **No more reload for a new list:** when a scan finishes, the addon rebuilds your shopping list in game straight away, with the same rules and everything the app has learned (margin tuning, price calibration, sell chances, deposits, your own selling times, what you hold). Autopilot keeps going with the new list, and you see and hear "Shopping list updated from the new scan". At login, a scan newer than the app's list is planned the same way.
- The app now hands its learning to the addon with every list it builds. The app's own list still wins whenever it's newer (after your next reload or logout).
- Switch: FlipForever window → *After a scan: rebuild my shopping list in game (no reload)*. With it off, you get Beta 3's alert and pause instead.
- Panels say when a list was "built in game from a scan".

### Developer
- `Planner.lua`, a port of the app's planner. A new test runs both planners on the same demo data and requires the same items, prices and amounts.

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
