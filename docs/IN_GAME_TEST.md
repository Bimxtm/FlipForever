# In-game test checklist

Use this list to confirm everything works on a live client. For anything that fails, note the step number and what you saw. Each step takes a minute or two.

## Auction house
1. Open the auction house: the FlipForever panel appears next to it, and nothing else looks broken (Auctionator and Auctioneer still work).
2. Click **Full scan**. Within ~10 minutes it finishes with a sound, and the status line shows how many items it saw. (Tests the full-scan API, timing, shared cooldown.)
3. After the scan: the message **"Shopping list updated from the new scan"** appears, and autopilot doesn't pause.
4. Press the big button (or your key) for a buy: the purchase confirms, and gold goes down by about what the panel said. (Tests commodity prices, hardware-click buying.)
5. Hover an item in your bags: the tooltip shows its typical price and how many sell per day.
6. Click **Reload**, then open the app: the scan imports, and the app builds a list and beeps.

## Selling
7. With something bought, press the button at the AH to post it: the price is above the "never below" floor in its tooltip.
8. Open your mailbox after a sale: one summary line in chat, and a **Collect auction gold** button beside the mailbox that takes the gold from the sale mails only.
9. With your own auctions up, open the auction house after a scan: if someone listed cheaper, one chat line names the biggest undercut, and the Overview shows "Your auctions: N up". (Tests the owned-auctions API and its unit prices.)

## Combat helper
10. Show the combat helper (FlipForever window), set a key, and fight a mob: each press casts and the icon moves on. (Tests the secure step button in combat.)
11. With no target, press the key: it picks the nearest enemy.
12b. Controller: in Key Bindings, FlipForever, bind "Combat helper: next spell" and "Arrow: next Advisor pin or quest spot" to gamepad buttons (or use Set key and press a pad button). Pressing them casts and points the arrow; the window shows the button's name, not PAD1.
12. Type `/ff spells`: it should say that all spell IDs match their names. Any line it lists is a spell the combat helper can't find on clients in other languages.

## Advisor and professions
13. Open the **Advisor**: your class and race are right, and talents show (not empty). (Tests the talent API shape.)
14. Open a profession window: the planner appears beside it with colours and costs.

## Gathering
15. Mine or pick something: the gathering tracker counts it, and the zone shows by name, not "map 1411".
