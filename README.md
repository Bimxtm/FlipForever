# FlipForever

by Alix

**A companion for World of Warcraft: Forever** (client 1.60.1, interface 16001): auction house flipping, gathering routes, a class and build advisor, and a combat helper. It consists of a desktop app and an in-game addon.

> What's new: see [NEWS.md](NEWS.md) and [CHANGELOG.md](CHANGELOG.md).

## Install
1. Download the latest `FlipForever-vX.Y.Z.zip` from [Releases](../../releases) and unzip it anywhere.
2. Run `FlipForever.exe`, then go to *Settings → Install / update the addon*.
3. Restart WoW once, and click the gold coin on the minimap.

## Sharing with other players
Everyone runs their own copy: unzip, start `FlipForever.exe`, and the first-run setup finds the WoW: Forever folder and account. All data stays in that copy's `data\` folder: prices, trades, settings and each character's budget. Any character on any account works; pick one at the top of the app.

## Update
The app checks GitHub on start (*About & updates*). While the repository is private, each user needs a read-only GitHub token with access to it, stored encrypted with Windows data protection. **Install update** downloads the new version, verifies its SHA-256 checksum, swaps the files in, keeps your `data\` folder, and updates the WoW addon too.

## Fair play
Every purchase, post and spell cast happens on your own key press or click, because that's what Blizzard allows addons to do. FlipForever searches, calculates and suggests; it never plays for you.

## Files
* `FlipForever.exe` (or the **FlipForever** shortcut on the Desktop): opens the desktop app. No Python needed. Keep the .exe in this folder, because it stores its data in `data\` and installs the addon from `addon\`.
* `Start FlipForever.bat`: the same app run from source (needs Python 3.10 or newer).
* `addon/FlipForever`: the in-game addon. The app's *Settings → Install / update the addon* copies it into `_forever_\Interface\AddOns`.

## How the loop works
1. In game, open the auction house and click **Full scan** on the FlipForever panel. The server allows one full scan every 15 minutes.
2. When the scan finishes, the addon builds your shopping list right away. With autopilot on, it keeps checking the list every minute and rescans every 30 minutes.
3. Press the big button, or bind a key in the FlipForever window. The addon searches each item and stops on deals. One press buys; bulk "commodity" items take a second press to confirm the final price.
4. Click **Post my items**. It undercuts the cheapest real competitor by 1c (tiny dumped lots are ignored) and never goes below the item's floor price.
5. Click **Reload** now and then. The app imports your scans and sales, learns from them, and passes what it learned back with the next list.

Blizzard requires a real key press for every purchase and every post. Fully automatic bots break the Terms of Service and get accounts banned.

## How it improves itself
* **Price accuracy:** each sale is compared to the price the app predicted, and later predictions are corrected for each item.
* **Sell chance:** starts as a guess from how busy the market is (listings disappearing between scans), then becomes your real sold/expired record.
* **Margin for each item:** items that lose money need a bigger margin. Reliable winners get a small discount.
* **Global margin auto-tune:** it tightens after a run of losing flips and loosens when flips win and stock moves (see the *What it learned* tab).
* **Auto-pause:** items that expire 4 times in a row without a sale stop being bought.
* **Floor decay:** stock that keeps expiring has its floor lowered step by step, but never below 85% of what you paid.

## Also built in (since 2.0)
* **Gathering** (`/ore` or `/ff gather`): the former Ore Farmer addon, merged in. It maps your ore, herb, fishing and treasure spots, reads GatherLite's 35,000+ spots, plans a farming loop and estimates gold per hour using FlipForever's own prices. Your old Ore Farmer data was moved over, and the old addon is switched off. If it's ever switched back on, FlipForever's copy stays quiet so nothing runs twice.
* **Advisor** (`/ff guide`): detects your race and class, lets you pick a build (< > buttons), and re-checks after every level-up, quest, gear change, talent point, skill-up and zone change. It covers talents, class quests, gear to hunt (and which dungeon has it), zones, dungeons, professions, bags, and gold to save for the mount (40, 100g), dual spec (40, 50g) and riding at 60 (1,000g). Sources: Method guides (updated 14-19 Nov 2026), Warcraft Tavern (beta-era, marked as such), Conquest Capped, FoReverDB and Warcraft Wiki.
* **Combat helper** (`/ff combat`, key: `/ff combatkey <KEY>`): an icon bar near the top of the screen. Each click casts the big icon, then the next one appears. It follows your build and known spells, and adapts to the target you select before a fight: immunities (no bleeds on elementals or mechanicals, no fire on fire elementals, and so on), extras (Exorcism vs undead and demons), plus a danger/CC line. `/ff combatmode` uses Blizzard's own one-button assistant instead, if the client has it. Shift + right-drag moves the bar.

Slash commands: `/ff guide | combat | combatkey <KEY> | combatmode | gather | scan | buy | sell | stop | auto | key <KEY> | reset`
