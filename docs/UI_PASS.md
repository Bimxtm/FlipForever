# UI and content pass: plan

Owner suggestion, 21 Nov: rework the windows a little and refresh all content so the parts work better together.
Plan written 22 Nov. Each step is one work session, committed on main and shipped in the next bundled beta.
This pass changes layout and wording only, so there are no new switches. Every switch keeps its key, and
the Hub keeps the same order (the test's switch list).

## 1. One window style
Today each window builds its own backdrop, title, close button and dragging:
- FlipForeverHub (Hub.lua)
- FlipForeverPanel (UI.lua)
- FlipForeverAdvisor (Advisor.lua, 470x470)
- FlipForeverProfPlanner (Professions.lua, 380x430)
- FlipForeverTalentPanel (TalentOverlay.lua)

Plan: one helper `FF:Window(name, width, height, title)` in UI.lua that handles the backdrop, title bar, close
button, dragging, saved position, ESC to close (UISpecialFrames) and clamping to the screen. Each of these
windows switches to it, so they look and behave the same. Test: every window opens, closes with ESC and
keeps its position.

## 2. Settings grouped
The Features list on the Settings tab has 23 switches in one 1256 px column. Plan: headings that split the same
order into groups:
- **Auction house:** undercuts, mail
- **Merchant:** junk, repair, merchant strip
- **Gathering:** node timers, bag value
- **Advisor and quests:** trainer, level info, talents, quest helper, map pins
- **Combat helper:** buffs, threat, learning, tips, guide, written guides, sharing
- **Gear:** tooltip, stat gains

Plus a short line under each switch that is not self-explanatory. Test: the switch list stays the same.

## 3. Windows that work together
- From the Hub Overview, buttons for Advisor, Professions and Talents, so every window can be reached from
  one place.
- Advisor: a marker on pinned steps, a "Pinned on map" count, and "Clear pins".
- Quest pins and Advisor pins share one minimap legend tooltip.

## 4. Content refresh
- `/ff help`: list every command, including bug, suggest, quest, talents and emergencykey.
- Advisor hint texts and guide source dates: drop outdated wording, name the 2.7 sources.
- Hub footer and first-run text: say what FlipForever does in one or two lines.
- In-game texts added since 2.7.0: give them a translation key list, so the next stable release translates them.

## 5. App pages (desktop)
- Same header and spacing on every page in gui.py.
- Community page links to "Report a bug" and "Suggest" from Overview.
- Settings page grouped like the in-game Settings.

Order: 1, 2, 4, 3, 5. Ship in 2.7.1-beta.3 when 1 to 4 are done.
