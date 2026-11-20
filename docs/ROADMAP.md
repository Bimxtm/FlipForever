# Roadmap

## Waiting for your OK (major ideas)
2. **Crafting profit finder.** It flags recipes you know that sell for more than their mats cost, then adds the mats to the shopping list. *Inspired by Auctionator and TSM-style crafting tabs.*
3. **Waypoint arrow.** One arrow on screen for the next gathering stop, an advisor target (a dungeon or quest hub) or a vendor. *Inspired by Schmendrick's arrow and TomTom.*
4. **Questie link-up.** The advisor reads Questie's quest database, so "class quest" and "gear from quest X" show where to start, with map pins. *Inspired by Questie and GearQuestForever.*

## Small improvements (queue)
- Profession planner: exact skill-up chances from each recipe's colour thresholds (learned in game as your skill moves), instead of averages per colour.
- Profession planner: when the top craft needs something you craft yourself (e.g. bolts), add *its* materials to the mats list too.
- Profession planner: "farm it instead" hint using Gathering's gold/hour for ores and herbs.
- Language-independent spells: use spell IDs instead of English names, so the advisor and combat helper work on any client language.
- Item tooltips: add "sells ~N/day" (needs the app's sales-speed data passed to the addon with the shopping list).
- Gathering: a value-per-node line in GatherLite's node tooltips.
- Mailbox: a sales summary ("you earned Xg since last time") when the mail opens.
- Advisor: a "why" tooltip on each step (which guide said so).
- Advisor: more builds per class as Method/Warcraft Tavern publish post-launch level-60 builds.
- App: dark/light option and window size memory.

## Done
- 2.2.0: profession planner (self-contained), buy missing mats at the AH.
- 2.1.0: prices in item tooltips, minimap summary, today's results on the AH panel.
- 2.0.0: all-in-one (Gathering, Advisor, Combat helper, FlipForever window, updater).
