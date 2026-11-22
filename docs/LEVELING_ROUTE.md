# Leveling route guide (plan)

Approved by the owner on 22 Nov (Developer page). Goal: the Advisor shows one route step at a time for your
faction, start zone and level ("Go to Sentinel Hill in Westfall, take the quests there"), and the waypoint
arrow points to it. Our own data, written from scratch from the zone list we already have (G.ZONES) and
general zone knowledge; no other guide's text or order is copied. Switch: `levelRoute` in Settings, Features
(Advisor group), on by default.

## Data (Advisor/RouteData.lua)
- `ROUTE[start]` for each start area (Elwynn, Dun Morogh, Teldrassil, Durotar, Mulgore, Tirisfal, Zephras Isle),
  then shared faction legs, then `Both` from 30 on. Start area = from race (Skyborne: Zephras Isle).
- Step: `{ from, to, zone, hub, x, y, text }`: level band, zone name, town or camp, its map position (0-100),
  one short plain line (what to do there, which flight path or boat to take next).
- Hub level only, not quest by quest: about 6-10 steps per faction to 30 and 8 shared steps to 60. That keeps
  the data small and correct; the quest helper already covers single quests.
- WoW: Forever's own zones (Zephras Isle, Shen'dralas, the Riverglades, Mount Hyjal): zone-level steps without
  a position until one is learned (below).

## Map positions
- Map IDs are found by zone name at run time (the Advisor already saves map names as you travel), so the
  data needs no IDs and works for the new zones.
- A step without coordinates gets them once you talk to an NPC in its hub (QuestStarts already remembers NPC
  positions; the hub's centre is learned the same way).

## Advisor and arrow
- One Advisor line, priority just above "Level in:", replacing that line while the route switch is on:
  "Route (level 12-14): Sentinel Hill, Westfall - take the quests, then fly to ...". Click: arrow; right-click:
  pin on the map (existing pin code). The Details view lists the next three steps.
- The step moves on by level, and also when you reach the hub's zone with the step's level met.
- Controller: `FLIPFOREVER_NEXT_SPOT` already cycles pins; nothing else needed.

## Tests
Step choice by race/faction/level, the zone-name map lookup with and without a learned map, the switch hides the
line and brings back "Level in:", the Hub switch list.

## Build order
1. RouteData.lua (Alliance and Horde to 30, shared to 60), added to the .toc.
2. Route logic in Advisor.lua (step choice, map lookup, line, details) and the switch.
3. Tests, CHANGELOG, in-game test step, roadmap and feed.
