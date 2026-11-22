# FlipForever 2.7.0 Beta 2

**Quest spots on the minimap.** The quest helper now also shows its known quest spots on the minimap. Spots further away sit faded on the minimap's edge, so you can see which way to go.

# FlipForever 2.7.0 Beta 1

**Quest helper (first test version).** FlipForever now learns where your quests happen: where you took them, where you made progress, and where you handed them in, shared by all your characters. Type `/ff quest` and the waypoint arrow points to the next spot of a quest; type it again for the next quest. Known spots also show as quest pins on the world map, and a chat line tells you when a quest is ready to hand in. It gets better the more you play. You can switch it off under Settings, Features. This beta also has the talent overlay and everything from the 2.5.2 betas up to Beta 12.

# FlipForever 2.6.0 Beta 6

**Your points by level.** The panel beside the Talents window now shows where your points should stand at levels 20, 30, 40, 50 and 60 for builds with a full talent order, with the band you are in marked. If you are behind the order for your level, it tells you by how many points. This beta also has everything from the 2.5.2 betas up to Beta 12.

# FlipForever 2.6.0 Beta 5

**Off-build points flagged.** If you have talent points in a tree your build leaves empty, the panel beside the Talents window now says so, with how many and where. This beta also has everything from the 2.5.2 betas up to Beta 11.

# FlipForever 2.6.0 Beta 4

**Talent details on hover.** Hover a talent in the panel beside the Talents window to read what it does, which tree it is in and where it comes in the build. Talents marked on the Talents window show their pick number and target rank in their tooltip too.

# FlipForever 2.6.0 Beta 3

**Click a talent to open its tree.** Each line in the panel beside the Talents window now takes you to that talent's tree. Builds whose guide names only the key talents get an order too: lower tiers first, so the next point is always one you can take. If a key talent needs more points in its tree first, the panel tells you how many.

# FlipForever 2.6.0 Beta 2

**More of your build beside the Talents window.** The panel now shows which tree each talent is in, the build's role, how to play it, and how many talent points you have left to spend. Type `/ff talents` to open the Talents window.

Also in this beta: the paladin fixes from 2.5.2 Beta 1. The combat helper casts your seal again after every Judgement and no longer causes "Interface action failed because of an AddOn" when you click its icon in a fight.

# FlipForever 2.6.0 Beta 1

**Your build on the Talents window.** Open the game's Talents window and your chosen Advisor build is right there: every talent of the build shows its place in the order, finished ones are marked green and the next point is marked gold. A panel beside the window lists the whole order with your ranks and which tree the next point goes into. Switch builds with its arrows, or turn it off under Settings.

# FlipForever 2.5.3 Beta 1

**Waypoint arrow fix.** Changing zones while a pin is set on the world map no longer shows the error "Arrow.lua:50: attempt to call a nil value". The arrow points to your map pin again.

# FlipForever 2.5.2

Everything from the 2.5.2 test versions, now in every game language:

- **Merchants:** sell all grey items with one click and repair, or let it happen on its own.
- **Mailbox:** *Open all mail* takes the gold and items from every mail.
- **Overview:** XP per hour, time to your next level and rested XP; what your bags are worth and which items are worth posting.
- **Advisor:** a reminder when new spells wait at your class trainer.
- **Combat helper:** casts your missing buffs before a fight, warns you about high threat, and for paladins follows the seal and Judgement. The seal is cast again after every Judgement, and clicking the icon in a fight no longer causes "Interface action failed because of an AddOn".
- **Gathering:** your loop skips spots you gathered in the last 15 minutes.
- **App:** a 7-day price trend on the Deals page, and a price history for the items you hold. The app also restarts cleanly after an update.
- **Settings:** every feature has its own switch under Settings, Features.

# FlipForever 2.5.2 Beta 12

**Combat helper: buffs and a paladin fix.** Before a fight, the combat helper now casts your missing buffs first, such as your blessing and aura, Power Word: Fortitude, Arcane Intellect or Mark of the Wild. For paladins, the big icon now moves on after each cast and shows whether the seal or Judgement comes next. You can switch the buffs off under Settings, Features.

# FlipForever 2.5.2 Beta 11

**Node timers for gathering.** Your farming loop now skips spots you gathered in the last 15 minutes, and the gathering tracker shows how many spots are ready and when the next one should be back. You can switch it off under Settings, Features.

# FlipForever 2.5.2 Beta 10

**Price trends in the app.** The Deals page has a new *7-day trend* column that shows whether an item is dearer or cheaper than usual right now. On the Inventory & selling page, double-click an item to see its price history with your cost and floor marked.

# FlipForever 2.5.2 Beta 9

**What your bags are worth.** The Overview now shows what your bags would fetch at a merchant and selling each item the better way, plus how many items are worth posting at the auction house. Hover the line to see them, biggest gain first. You can switch it off under Settings, Features.

# FlipForever 2.5.2 Beta 8

**Open all mail.** At the mailbox, a new button under *Collect auction gold* takes the gold and items from all your mail in one click. Mail with cash on delivery is left alone, and it stops when your bags are full. You can switch the button off under Settings, Features.

# FlipForever 2.5.2 Beta 7

**Threat warning.** The combat helper now warns you under its icons when you are close to pulling aggro, when your target turns on you, or, as a tank, when you lose aggro. You can switch it off under Settings, Features.

# FlipForever 2.5.2 Beta 6

**Time to level.** The Overview now shows your XP per hour this session, how long until your next level at that pace, and your rested XP. You can switch it off under Settings, Features.

# FlipForever 2.5.2 Beta 5

**No more "Failed to load Python DLL" after updating.** The app sometimes showed this error when it restarted itself after an update. The update was installed fine; only the restart failed. From this version on, it restarts cleanly. If you see the message one more time while updating to this version, click OK and start FlipForever again.

# FlipForever 2.5.2 Beta 4

**Trainer reminder.** Visit your class trainer once and FlipForever remembers what you can learn later. When you reach the level, the Advisor tells you how many new spells are waiting and what they cost. You can switch it off under Settings, Features.

# FlipForever 2.5.2 Beta 3

**Switch any feature on or off.** The Settings tab now scrolls and ends with a *Features* section: the sell junk strip, always selling junk, always repairing, the undercut check, the mailbox gold button and the gear line in tooltips each have their own switch, next to the ones that were already there.

# FlipForever 2.5.2 Beta 2

**Sell junk and repair in one go.** Open a merchant and you'll find a small strip under the window: *Sell junk* sells every grey item in your bags. Tick *Always sell junk* or *Always repair* and FlipForever does it on every visit. Both are off until you tick them, and repairs always use your own gold.

# FlipForever 2.5.2 Beta 1

**Combat helper fixes for paladins.** Your seal is cast again after every Judgement, so it is always up. Consecration and other cooldowns are used while Judgement recharges, then Holy Strike. Clicking the big icon during a fight no longer shows "Interface action failed because of an AddOn". If the game ever blocks an action again, `/ff errors` and *Copy bug report info* now say which one.

# FlipForever 2.5.1

**Updates in one click.** The app checks for a new version when it starts and asks you. Click Yes and it updates itself and the WoW addon. Nothing else to install. The first time it starts, it also offers to put FlipForever on your desktop and in the Start menu.

## Also in 2.5

**In your language.** The FlipForever window, the Advisor, the profession planner, chat messages and the whole app now come in all 11 game languages. Pick yours under Settings, or leave it on the game's language.

**Auction house**
- A shopping list of items that are cheap right now and sell fast, rebuilt in game after every scan, with the expected profit per item.
- Smarter selling: just under the cheapest competitor, never below your floor, 12-hour auctions for fast sellers to keep deposits small.
- Vendor flips, an undercut check for your own auctions, and *Collect auction gold* at the mailbox.
- Prices, sell speed and gear upgrades in item tooltips. The Overview shows how old your last scan is and this week's profit.
- The autopilot is turned off for now while it gets more work. The big button at the auction house does the buying and posting, one key press each.

**Your character**
- The Advisor has 9 builds per class from the current guides and tells you what to do next. Open it with the new button at the top of the FlipForever window, by clicking the next step on the Overview, with a key (Key Bindings, FlipForever), with `/ff guide` or by right-clicking the minimap coin.
- The Advisor now remembers your build choice between logins, and the app's Advisor page shows your characters again.
- Gear finder: affordable upgrades on the auction house and in your bags. Hover an item in the Gear tab to see it next to what you wear. Random-stat gear ("of the Bear") is judged version by version.
- Combat helper for levels 1-60 on the + key: cooldowns first, then one step per press. Druids get the right skills in Bear Form, Cat Form and caster form.
- Class quest locations and a waypoint arrow.

**Professions and gathering**
- Crafting profit finder and exact skill-up chances in the profession planner.

**When something goes wrong**
- `/ff errors` lists the last errors in game, and *Copy bug report info* in the app (About & updates) collects everything a bug report needs.
