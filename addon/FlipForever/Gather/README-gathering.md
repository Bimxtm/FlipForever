# Ore Farmer (WoW Forever addon)

Maps the spots where you gather ore, herbs, fish and treasure. It plans the
shortest loop through them and estimates how much gold that loop makes.

## Install / update

Copy the whole `OreFarmer` folder into
`World of Warcraft\_forever_\Interface\AddOns\` (replace the old one), then type
`/reload` in game. Your saved spots are kept.

## The window

Open it with the **minimap button** (copper-ore icon), the AddOns menu, or
`/ore`. **Escape** closes it.

- **Overview:** your zone and skills, this zone's loop and estimate, the next
  stop, and what you've earned this run. It has buttons for a new run, route
  on/off, tracker on/off and opening the map.
- **Resources:** a tab per profession with a box per resource, plus All, None and
  "Only what I can gather".
- **Zones:** every zone with spots, best first: number of spots, loop time,
  estimated and measured gold per hour.
- **Prices:** ore → bar prices with a smelt/sell hint, and herb prices.
- **Settings:** what to show, the estimate settings, detected skills, and
  "forget" buttons (each asks first).

The small **tracker** window shows the next stop and live numbers while you
farm. Right-click the minimap button or use `/ore tracker` to show or hide it.

## Working with GatherLite

If **GatherLite** is installed, Ore Farmer reads its 35,000+ WoW Forever spots
and adds them to yours. Routes and profit estimates then cover whole zones
right away.

- GatherLite draws the spots on the maps. Ore Farmer adds the yellow route and
  highlights the next stop, so nothing shows up twice. (*Settings → Also draw
  spots myself* turns Ore Farmer's own pins back on.)
- Spots you gather yourself still count, and their real loot makes the profit
  numbers more accurate.
- Professions you don't have are left off the route automatically.
- Ore Farmer only reads GatherLite's data and never changes it.

**Tip:** with a whole zone of spots, the loop can be long. In *Resources*, pick
just the ores or herbs worth farming (for example Iron + Silver). The loop and
the gold-per-hour estimate update right away.

## How spots get recorded

WoW Forever hides most object names from addons, so Ore Farmer goes by **what
you loot**:

- ore in the loot → a mining spot for that ore
- a herb → a herb spot
- fishing loot → a "fishing spot" where you stood (or the pool, if the game showed
  its name)
- treasure chests → only when the game shows the chest's name

The spot is placed where you stand when you loot it. A new ore or herb that
isn't in the list is learned automatically from its item. Loot from dead mobs
is ignored.

Turn on `/ore debug` to have it explain each recording in chat. That's useful
if something doesn't show up.

## Map, minimap, route

- Spots appear as coloured squares on the **world map** (zone view and zoomed-out
  views, including MapUtils' big map) and on the **minimap**. Hover one for
  details.
- **Route:** a yellow loop through every spot you can gather and haven't hidden.
  The panel shows the **next stop**, which gets a white border and stays on the
  edge of the minimap. Fishing spots are markers only, not on the route.
- **Show…** (or `/ore show`) has a tab per profession (Mining, Herbalism, Fishing,
  Treasure). Each tab has an on/off box for the whole profession and one per
  resource, plus All/None buttons.

## Profit

Prices come from **Auctionator**, **Auctioneer** or **TSM**, whichever is
installed. A price you set with `/ore price` always wins; otherwise vendor
prices are used.

- *Est.* = loop value ÷ loop time. It uses your average loot per spot, your
  travel speed, about 6 s per spot, and how many spots you expect to have
  something (default 50%). It shows "(rough)" until it has some data.
- *This run* / *Measured here* = what you actually looted, valued at those
  prices, divided by time spent moving and gathering.

## Commands

| Command | What it does |
|---|---|
| `/ore` | Open or close the window |
| `/ore tracker` | Show or hide the small tracker |
| `/ore show` / `zones` / `prices` / `settings` | Open the window on that tab |
| `/ore skill 150` / `/ore skill herbalism 120` / `/ore skill auto` | Set a skill if it isn't detected |
| `/ore avail 50` | % of spots you expect to have something |
| `/ore price 2772 0.45` | Your own price in gold (item link or ID; `0` clears) |
| `/ore debug` | Explain recordings in chat (on/off) |
| `/ore check` | Troubleshooting info |
| `/ore reset zone` / `/ore reset all` | Forget data |

Skinning isn't included, because it comes from mobs, not spots on the map.
