# Changelog

All notable changes to FlipForever. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [Semantic Versioning](https://semver.org/).

## [2.7.1-beta.6] - 2026-11-23 (beta, hotfix)
### Fixed
- The Talents button and `/ff talents` said "The Talents window could not be opened" on WoW: Forever, whose Talents window has its own name. They now open it the way the game does (or through the Talents key), and the FlipForever build panel attaches to it.
- On WoW: Forever, the game can keep reporting your first realm's name after you switch realms, so a character on another realm (for example RPPvP) was filed under the first one. FlipForever now checks the realm's short name and keeps each realm apart.
- The app lists a new realm as soon as a character has logged in there, before its first scan or trade.

## [2.7.1-beta.5] - 2026-11-23 (beta)
### Added
- **Talents by level:** for the build you chose, the panel beside the Talents window has a By level button that lists the talent to take at every level from 10 to 60 (your next point in gold, points you have in green; the mouse wheel scrolls). When the next talent sits in a tier that is still locked, the list names the points that open it. The Advisor shows the same plan in short ranges ("L10-14 Improved Frostbolt 5/5"). Change the build with the arrows on the panel. Switch in Settings, Features.

### Changed
- Less clutter: the addon's Settings tab no longer repeats the Advisor, Gathering, Professions and Talents buttons (all four are on the Overview) or the Reload button; the app's sidebar has two pages fewer (How to use is in About & updates, Development is under Community).
- Smaller download: the app leaves out parts of Python it never uses.

### Fixed
- With characters on more than one realm, a moment without a realm name at login could file a character's scans and trades under the realm you played last. The realm is now remembered per character.

## [2.7.1-beta.4] - 2026-11-23 (beta)
### Added
- **Best time to post:** when posting, and in item tooltips, FlipForever shows the 4-hour window of the day in which your own auctions of that item sold most (all your sales together until the item has 5). Switch in Settings, Features.
- **Dungeon advisor:** of the dungeons around your level, the Advisor names the one with the most upgrades for your weak gear slots (for your class's armor), lists the drops when you hover it and points the arrow to the entrance when you click it. Switch in Settings, Features.
- **Price chart in Deals (app):** select an item in the Deals tab to see its cheapest and typical price and the amount listed over the last 14 days below the list. Switch in the app's Settings (Price chart under Deals).
- **Send to alt:** a mailbox button mails your crafting materials and flip stock (up to 12 stacks per click, never soulbound items) to another character of yours on the same realm and faction; right-click picks the character. Switch in Settings, Features.
- **Vendor resale finder:** merchants you visit are remembered with their spot on the map. Their limited items (such as recipes) that sell for clearly more on the auction house are named at the merchant, and `/ff vendors` lists the best ones and pins them on the map. Switch in Settings, Features.
- **Bag space aware buying:** auction buying stops before your bags are full and keeps 2 slots free (profession bags not counted); stacks are sized to the room left. Change it with `/ff bags <slots>`. Switch in Settings, Features.
- **Auction session summary:** when you close the auction house, one chat line sums up what you bought, posted and sold while it was open and how your gold changed. Switch in Settings, Features.
- **Gold goals:** set a daily or weekly profit goal with `/ff goal day <gold>` or `/ff goal week <gold>`; the Overview shows how far you are. In the app, set the goals in Settings and see the progress on the Dashboard under Last 7 days. Switch in Settings, Features.
- **Restock reminders for crafters:** when an item you craft and posted in the last two weeks is gone from the auction house and your bags, the auction house reminds you once a day to craft and post it again. Switch in Settings, Features.
- **Craft button in the profession planner:** crafts the top skill-up or profitable recipe the planned number of times, as many as your materials allow, while that profession's window is open. Switch in Settings, Features.

## [2.7.1-beta.3] - 2026-11-22 (beta)
### Added
- Combat helper: the spell orders from the WoW: Forever leveling guides on Warcraft Tavern are tested next to the helper's own order, and the one that kills faster for you is kept. Switch in Settings, Features.
- `/ff help` lists every command, grouped.
- **Leveling route:** the Advisor shows the next town or camp for your race, faction and level up to 60; click it for the arrow, right-click to pin it. Build details lists the next steps. Switch in Settings, Features.
- **Quest log: Pin on map.** Select a quest and click *Pin on map*: its next spot (objective area or hand-in, learned from your play) is pinned on the map and minimap and the arrow points there. Switch in Settings, Features.
- **Advisor:** class quests already in your quest log point to their next learned spot (objective or hand-in) instead of the quest giver. Switch in Settings, Features.
- **Controller support:** bind the combat helper, the emergency key and the arrow (next Advisor pin or quest spot, clear) in Key Bindings, FlipForever; Set key takes gamepad buttons, and keys show the button's name. Switch in Settings, Features.
- App: Community, Rules shows how FlipForever stays inside the game's rules. Switch in Settings, Community and sharing.
- FlipForever window: Talents button next to Advisor, Gathering and Professions.
- Advisor: pinned steps are marked, and *Clear pins* removes all map pins. Minimap pins show what they are when you hover them.
- A page on the game's rules and how FlipForever stays inside them (docs/RULES.md, linked from the README).
- **Gold reserve when buying:** auction buying keeps 20% of the gold you had when you started (at least 20 gold) and sizes each purchase to what is left, so a character is never drained to a few silver. `/ff reserve <percent> <gold>` changes it. Switch in Settings, Features.
- **Fast flips:** before buying, the addon counts the units other sellers list below your sell price and, with how fast the item sells, skips flips where that queue would take more than twice your hold time to sell through (for example 300 cheaper units ahead of a slow item). Switch in Settings, Features.
- **Disenchant values:** green, blue and purple weapons and armor show in their tooltip what they disenchant for at your scanned prices, and whether that is more than the item sells for. `/ff disenchant` lists items in your last scan listed below their disenchant value and buys them at the auction house. Switch in Settings, Features.
- **Gold scoreboard:** Community, Gold scoreboard lists the players with the most profit from flipping. Opt-in: turn on *Gold scoreboard* in Settings and set a nickname; the app then shares your total profit (whole gold, no character names) once a day.
- App: About & updates can install an older version (Load versions, pick one, Install this version). Going back turns off the update check at start and puts the matching addon in. Switch in Settings: *Choose an older version*.
### Changed
- All FlipForever windows share one look: same frame, Escape closes them, and they remember where you put them.
- Settings, Features: the switches are grouped (Merchant, Auction house and mail, Gathering and bags, Advisor, quests and talents, Combat helper, Gear), some with a short explanation on hover.
- App Settings: grouped into sections.
- Community page: a fuller roadmap.
- Profession planner: wider window, the Materials header no longer overlaps the first material, long lines fit, and clearer wording (cost per skill-up, price each, sales a day).

### Security
- Updates only download files attached to FlipForever's own GitHub releases, a GitHub token is never sent on to the download host, and the check for unsafe paths in the update zip is stricter.
- Bug reports and suggestions: at most 5 an hour from one PC, and report text can't break the report format.

### Fixed
- Realized profit: items sold on a character that bought them on another character now count their buy price, and sales with no buy price at all (loot, stock from before tracking) are shown apart instead of as profit.

## [2.7.1-beta.2] - 2026-11-22 (beta)
### Added
- Report bugs and suggest ideas from the game: `/ff bug <text>`, `/ff suggest <text>` and a *Report a bug* button in the FlipForever window. The report keeps your version, class, level, zone and the last FlipForever errors; the app sends it after the next save and it shows up as a ticket on the Community page.
- Gear finder: each upgrade shows the stat gains against what you wear, in the Gear tab and in item tooltips. Switch in Settings, Features.
- Advisor: right-click a step that has a place (for example a quest giver you've met) to pin it on the world map and minimap. Click the pin to point the arrow there, right-click it to remove it. Switch in Settings, Features.

## [2.7.1-beta.1] - 2026-11-22 (beta)
### Added
- App: new Community page with Updates, Roadmap, Bug reports, Suggestions and Top reporters. The status comes from the FlipForever repository on GitHub (the last copy is kept for offline use).
- Bug reports and suggestions can be sent right from the app. Each report gets a ticket with a status (Reported, Confirmed, In progress, Fixed, Not reproducible, Won't fix), and you can see the status of your own reports. Suggestions are reviewed before they reach the roadmap.
- Top reporters: confirmed bugs and shipped suggestions per nickname. The nickname is optional (Settings); without one your reports stay anonymous.
- Switches in the app's Settings: *Community page* and *Nickname for Top reporters*.

## [2.7.0] - 2026-11-22
All 2.5.3, 2.6.0 and 2.7.0 betas in one release (see the beta entries below), plus:
### Added
- Talent overlay (2.6.0 betas): your chosen build on the Talents window with the next point marked, a panel with the talent order, the key talents and where your points should stand at levels 20 to 60, and `/ff talents`.
- Quest helper (2.7.0 betas): learned quest spots for all your characters, quest pins on the world map and minimap, a chat line when a quest is ready to hand in, and `/ff quest` to point the arrow at the next spot.
- Combat helper: learns the best spell order from your fights, gives advice after a fight, an emergency key, interrupts and cooldowns for elites, and anonymous shared learning that can be switched off.
- Undercut fix: cancel and repost undercut auctions only where it pays after the deposit.
- Advisor: the talent step says where each unspent point goes for your build.
- App: switches to the character you played last after each import; a setting for sharing anonymous combat data.
- Translations of every text added since 2.5.2 into all game languages.
### Fixed
- The waypoint arrow error when changing zones, errors from hidden auras and system chat text, and Locale.lua loading twice.

## [2.7.0-beta.11] - 2026-11-22 (beta, branch feature/quest-helper)
### Added
- From 2.5.3 Beta 9: shared combat learning (anonymous summaries, merged into each release; warning once, can be switched off).

## [2.7.0-beta.10] - 2026-11-22 (beta, branch feature/quest-helper)
### Changed
- From 2.5.3 Beta 8: combat learning counts only the helper's own casts and fights; fix for the "you waited" note.

## [2.7.0-beta.9] - 2026-11-22 (beta, branch feature/quest-helper)
### Added
- From 2.5.3 Beta 7: combat helper rules from the WoW: Forever class guides (cooldowns for elites, emergency key, advice in fights).

## [2.7.0-beta.8] - 2026-11-22 (beta, branch feature/quest-helper)
### Added
- From 2.5.3 Beta 6: the combat helper learns from your fights per class and build, with notes after fights and `/ff combat report`.

## [2.7.0-beta.7] - 2026-11-22 (beta, branch feature/quest-helper)
### Added
- From 2.5.3 Beta 5: the undercut fix (cancel and repost undercut auctions where it pays after the deposit).

## [2.7.0-beta.6] - 2026-11-22 (beta, branch feature/quest-helper)
### Added
- From 2.5.3 Beta 4: the app switches to the character you played last after each import.

## [2.7.0-beta.5] - 2026-11-22 (beta, branch feature/quest-helper)
### Fixed
- The fixes from 2.5.3 Beta 3: hidden auras and system chat text no longer cause errors, and Locale.lua is loaded once.

## [2.7.0-beta.4] - 2026-11-22 (beta, branch feature/quest-helper)
### Changed
- The Advisor's talent step from 2.5.3 Beta 2: where each unspent point goes for the chosen build (talent, points, tree); clicking it opens the Talents window with the talent overlay.

## [2.7.0-beta.3] - 2026-11-22 (beta, branch feature/quest-helper)
### Fixed
- The waypoint arrow fix from 2.5.3 Beta 1: no more "Arrow.lua:50: attempt to call a nil value" when changing zones with a pin on the world map.

## [2.7.0-beta.2] - 2026-11-21 (beta, branch feature/quest-helper)
### Added
- Quest helper: known quest spots on your map also show on the minimap. Spots out of the minimap's range sit faded on its edge, in their direction. Follows a rotating minimap.

## [2.7.0-beta.1] - 2026-11-21 (beta, branch feature/quest-helper)
### Added
- Quest helper. FlipForever learns quest spots from your play and keeps them for all your characters: where you took each quest, where its objectives moved forward, and where you handed it in. The next spot of a quest is the area of its first unfinished objective, or the place to hand it in once it is done (the quest giver until a hand-in has been seen). Where the game client knows the next waypoint itself, that is used too.
- `/ff quest` points the waypoint arrow at the next quest spot, ready-to-hand-in quests first; type it again for the next quest.
- World map: a quest pin on each known spot of the map you are looking at (yellow ? to hand in, ! for objectives), with the quest and what to do there on hover.
- Chat: a line when a quest is ready to hand in and its hand-in spot is known.
- Switch: *Quest helper: learn quest spots, map pins, /ff quest* in Settings, Features.
- Includes the talent overlay (2.6.0 Beta 6) and 2.5.2 Beta 12.

## [2.6.0-beta.6] - 2026-11-21 (beta)
### Added
- Talents panel: where your points should stand at levels 20, 30, 40, 50 and 60, as a point split per tree, for builds with a full talent order. The band you are in now is gold. When you have fewer points in the build's trees than the order asks for at your level (not counting points you still have to spend), an orange note says how many.
- Includes 2.5.2 Beta 12 from the main line: combat helper buffs before a fight, paladin icon follows the seal and Judgement.

## [2.6.0-beta.5] - 2026-11-21 (beta)
### Added
- Talents panel: an orange warning when you have points in a tree your build leaves empty, with how many and in which tree.
- Includes 2.5.2 betas 2-11 from the main line: sell junk and repair, a switch for every feature, trainer reminder, clean restart after updates, time to level, threat warning, open all mail, bag value, price trend in the app, node timers.

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

## [2.5.3-beta.9] - 2026-11-22 (beta)
### Added
- Shared combat learning: what every player's combat helper learns now improves the helper for everyone. The app sends an anonymous summary (class, build and level band, the spell orders compared, fight counts, kills, fight time, deaths and health lost; no character, realm or account names, no chat) at most once a day, only when something changed. Each release starts from what worked across all players; your own fights still decide (the shared results count as at most 20 fights).
- A warning says so the first time (in game and in the app). Switch it off in game under Settings, Features (*Share anonymous combat data*) or in the app's Settings.
- Release builds merge the shared summaries into the addon (tools/merge_combat_learning.py, Advisor/CombatShared.lua).

## [2.5.3-beta.8] - 2026-11-22 (beta)
### Changed
- Combat helper learning now judges only the helper's own choices, not how you play: only casts that come right after a press of the helper's button or key count, and a fight only counts for comparing orders when at least 70% of its casts came from the helper. Spells you cast yourself no longer go into its statistics. `/ff combat report` shows how many fights the helper did itself.
### Fixed
- The note "you waited ... seconds between casts" could raise an error when the time was not a whole number of seconds.

## [2.5.3-beta.7] - 2026-11-22 (beta)
### Added
- Combat helper plays like the WoW: Forever class guides teach (Skill Capped's WoW: Forever class guides, updated 19 Nov 2026; written for PvP, used here mainly against mobs and bosses):
  - Big cooldowns (Recklessness, Adrenaline Rush, Arcane Power, Rapid Fire and so on) are saved for elites, rares, bosses, players and targets 3+ levels above you instead of being used on every normal mob.
  - Emergency key: Shift + your combat key (or `/ff emergencykey KEY`), also a small button left of the big icon. It casts your first ready defensive spell in the guide's order (Shield Wall, Evasion, Divine Shield, Ice Barrier, Barkskin and so on) and uses the best healthstone and healing potion in your bags. The macro is prepared before each fight, as the game requires.
  - During a fight, the line under the icons says when to press it (below 35% health), when to interrupt a cast and with what, when to slow a target that may run, and when to switch to the wand (casters below 12% mana). These thresholds are FlipForever's own starting values; the guides give none.
  - After a death, the note now points to the emergency key.
- Switch: *Combat helper: emergency key, interrupts, cooldowns for elites* in Settings, Features (on).

## [2.5.3-beta.6] - 2026-11-22 (beta)
### Added
- Combat helper learns from your fights, separately for each class, build and level band (shared by all your characters of that class). Every fight is recorded: casts, failed casts and why (out of range or sight, not enough mana/rage/energy, no combo points), time spent waiting between casts, time out of power, health lost, deaths and kills.
- It compares small changes to the guide's order: two neighbouring steps swapped, and a spell that keeps failing for lack of power moved to the end. Each version gets at least 6 fights; then the one with the fastest kills (adjusted for the target's level), the least health lost and no deaths is used, with an occasional re-check so changes in gear and level are noticed. Fights against players are kept out of this.
- After a fight it tells you what to do better when it matters (dying, waiting between casts, spells failing out of range, running out of power, losing most of your health), at most every 5 minutes.
- `/ff combat report` (or `/ff fights`): recent fights, kills, deaths, average fight length, waiting time, spells that often fail, and the orders being compared.
- Switches: *Combat helper: learn the best order from my fights* and *Combat helper: tell me after a fight what to do better* in Settings, Features (both on).

## [2.5.3-beta.5] - 2026-11-22 (beta)
### Added
- Undercut fix at the auction house: when your auctions are undercut, the FlipForever button now checks each one live and offers to cancel it (one key press each, as the game requires) only where reposting pays. An auction is kept when the cheaper listings should sell before it ends (from the item's sales per day), when it ends within the hour, when the new price would be below your floor, or when the repost would bring less than four times the new deposit and any cancel fee. A deposit is lost on a cancel and on an expiry alike, so an auction that no longer sells has already lost it; acting only costs the new deposit.
- Cancelled items come back by mail. Collect them (Open all mail) and press the button at the auction house: they are posted again just under the cheapest real competitor, never below your floor.
- Switch: *Undercut auctions: cancel and repost where it pays* in Settings, Features (on).

## [2.5.3-beta.4] - 2026-11-22 (beta)
### Added
- App: switches to the character you play. After each import (the game saves on /reload and logout), the app picks the realm and character the game saved last. A character you pick yourself stays until you play another one. Switch: Settings, *Switch to the character I play* (on).

## [2.5.3-beta.3] - 2026-11-22 (beta)
### Fixed
- Combat helper buffs: no more "Auras cannot be accessed when secret" errors at the end of a fight. Buffs are read safely, and while the game keeps them hidden the last known list is used.
- No more "Core.lua:282: attempt to index local 'msg' (a secret string value)" from system chat messages the game hides during fights. Auction house error messages are handled the same way.
- The game no longer reports "Duplicate File Load Detected" for Locale.lua at login: the addon's file list named it twice.
### Checked
- The error logs of all installed addons (Swatter and FlipForever's own). Other FlipForever errors in them come from older versions and are already fixed (combat bar moved in a fight up to 2.6.0 Beta 1, waypoint arrow up to 2.7.0 Beta 2). The remaining errors come from other addons' own code and are not caused by FlipForever.

## [2.5.3-beta.2] - 2026-11-22 (beta)
### Changed
- Advisor, talents: the step for unspent talent points now says where each point goes for your chosen build, with the talent, how many points and the tree (up to three in the line, the full list on hover). Builds that only name their key talents are filled lower tiers first, and a talent is only suggested once its tier is open. Points the build does not place yet are named as free. Clicking the step opens the Talents window.

## [2.5.3-beta.1] - 2026-11-22 (beta)
### Fixed
- Waypoint arrow: no more error "Arrow.lua:50: attempt to call a nil value" when changing zones with a pin on the world map. The arrow now reads the map pin the way this game client stores it.

## [2.5.2] - 2026-11-21
All 2.5.2 betas in one release (see the beta entries below), plus:
### Added
- Translations of every text added in the 2.5.2 betas into all game languages: merchant and mailbox buttons, the Overview lines, the trainer reminder, the threat warning, the combat helper's buffs, the new Settings switches and the app's 7-day trend.

## [2.5.2-beta.12] - 2026-11-21 (beta)
### Fixed
- Combat helper, paladins: the big icon now moves on after each cast. It follows the seal and Judgement in the order the game casts them (seal, Judgement, seal again) and starts over on a new target, as the game does. Before, it could keep showing the seal.
### Added
- Combat helper: buffs before a fight. Out of combat, a missing self-buff is cast with the first press: paladin blessing and aura (Righteous Fury for tank builds, Blessing of Wisdom for holy), priest Power Word: Fortitude and Inner Fire, mage Arcane Intellect and armor, druid Mark of the Wild and Thorns, warlock armor, hunter aspect. The big icon shows it with "(before the fight)". Greater blessings count, and a hunter's own choice of aspect is kept. These lines never fire in combat. Switch: *Combat helper: cast my missing buffs before a fight* in Settings, Features.

## [2.5.2-beta.11] - 2026-11-21 (beta)
### Added
- Gathering: node timers. Spots you gathered in the last 15 minutes are skipped by the *Next* stop on your loop (nodes come back after roughly 5-30 minutes), and the tracker shows how many spots are ready and when the next one should be back. If every spot is still waiting, the loop runs in its normal order. Switch: *Gathering: skip spots I gathered in the last 15 min* in Settings, Features.

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
