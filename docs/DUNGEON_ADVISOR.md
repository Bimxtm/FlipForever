# Dungeon advisor (plan)

Approved by the owner on 22 Nov. Goal: of the dungeons around your level, the Advisor names the one that holds
the most gear upgrades for your weak slots, says which slots, and points the waypoint arrow at its entrance.
Our own data, written from general dungeon knowledge; no other addon's tables are copied. Switch:
`dungeonAdvisor` in Settings, Features (Advisor group), on by default.

## Data (Advisor/DungeonData.lua)
- `D.LIST`: one entry per dungeon: `{ name, from, to, faction, zone, x, y, drops }`.
  - `from`/`to`: the level range (same bands as G.DUNGEONS); `faction` nil for both.
  - `zone`, `x`, `y`: the zone of the entrance and its map position (0-100). Instance-only cities
    (Ragefire Chasm, The Stockade) use the city map.
  - `drops`: notable blue (and a few green) items as `{ slot, armor, level, name }`, a handful per dungeon.
    `slot` uses the Advisor's slot labels (Head, Chest, Main hand ...), `armor` is Cloth, Leather, Mail, Plate
    or nil (weapons, back, rings, trinkets, neck).
- WoW: Forever's own dungeons (marked "new") get level range and zone only; no drops until we know them, so
  they never win on upgrades but still show in the level list.

## Logic (Advisor.lua)
- Weak slots: the same test as the "Weak slots" line (empty, white from 15, item level 12+ below yours).
- Armor you can wear: from class (Cloth: mage, priest, warlock; Leather: rogue, druid; Mail from 40 for
  hunter and shaman, else Leather; Plate from 40 for warrior and paladin, else Mail). Higher armor classes
  count; lower ones are skipped for armor slots (cloth is not an upgrade for a warrior).
- Score per dungeon in range for your faction: number of weak slots with at least one fitting drop whose
  level is within your level - 5 .. level + 3. Ties: the dungeon whose range centre is closest to your level.
- Line (priority 50, replaces "Dungeons for your level:" while the switch is on and a dungeon scores > 0):
  "Dungeon for upgrades: Wailing Caverns - Chest, Legs, Main hand (entrance: The Barrens)". Hover lists the
  drops per slot. Click: arrow to the entrance (map ID from the zone name, like the route).
- No score (no weak slots, or no data): the old "Dungeons for your level:" line stays. Switch off: old line.

## Tests
Pick by weak slots and armor (a warrior at 20 with an empty chest and a white weapon), faction filter,
the arrow target, the switch bringing back the old line, the Hub switch list.

## Build order
1. DungeonData.lua, added to the .toc after RouteData.lua.
2. Logic and line in Advisor.lua, switch in Hub.lua.
3. Tests, CHANGELOG [2.7.1-beta.4], roadmap, feed.
