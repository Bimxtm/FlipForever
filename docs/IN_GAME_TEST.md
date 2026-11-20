# In-game test checklist

Nothing has run in the real game yet (problem P1). Go through this once and tell Claude what didn't work: the step number and what you saw is enough. Each step takes a minute or two.

## Auction house
1. Open the auction house: the FlipForever panel appears next to it, and nothing else looks broken (Auctionator and Auctioneer still work).
2. Click **Full scan**. Within ~10 minutes it finishes with a sound, and the status line shows how many items it saw. (Checks: the full-scan API, timing, shared cooldown.)
3. After the scan: **"Shopping list updated from the new scan"** appears, and autopilot doesn't pause. (Beta 4, in-game planning.)
4. Press the big button (or your key) for a buy: the purchase confirms, and gold goes down by about what the panel said. (Checks: commodity prices, hardware-click buying.)
5. Hover an item in your bags: tooltip lines show the typical price and how many sell per day.
6. Click **Reload**, then open the app: the scan imports, and the app builds a list and beeps.

## Selling
7. With something bought, press the button at the AH to post it: the price is above the "never below" floor in its tooltip.
8. Open your mailbox after a sale: one summary line in chat.

## Combat helper
9. Show the combat helper (FlipForever window), set a key, and fight a mob: each press casts and the icon moves on. (Checks: the secure step button in combat.)
10. With no target, press the key: it picks the nearest enemy.

## Advisor and professions
11. Open the **Advisor**: your class and race are right, and talents show (not empty). (Checks: the talent API shape.)
12. Open a profession window: the planner appears beside it with colours and costs.

## Gathering
13. Mine or pick something: the gathering tracker counts it, and the zone shows by name, not "map 1411".
