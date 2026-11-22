# Controller support (plan)

Owner suggestion, 22 Nov. Goal: a player on a gamepad can use the combat helper, the emergency key, the Advisor and
the waypoint arrow without a keyboard. One switch: `controller` in Settings, Features (default on; it changes nothing without a gamepad), next to the
combat helper switches in Hub.lua (the Hub order is the test's switch list).

Rules that stay: every press is the player's own button press; secure buttons are only clicked through bindings;
nothing changes bindings during a fight. Gamepad API calls are feature-checked (`C_GamePad`, `EnableGamePadButton`,
CVar `GamePadEnable`) so clients without gamepad support just keep the keyboard behaviour.

## 1. Bindable actions (Bindings.xml, always present)
New entries in the game's Key Bindings menu (FlipForever header). Pad buttons are bound there like keys.
- `CLICK FlipForeverCombatButton:LeftButton` - Combat helper: next spell
- `CLICK FlipForeverEmergencyButton:LeftButton` - Combat helper: emergency
- `FLIPFOREVER_NEXT_SPOT` - Arrow: next Advisor pin or quest spot (cycles `QH:MapSpots()`, like `/ff quest`)
- `FLIPFOREVER_ARROW_CLEAR` - Arrow: clear the point I set
- existing: `FLIPFOREVER_ADVISOR`, `FLIPFOREVER_HUB`
Names in Core.lua (`BINDING_NAME_*`) and Locale.lua. Binding bodies check the feature switches they need and print
the usual "off" line otherwise.

## 2. Pad buttons in the key capture (switch `controller`)
Hub.lua `startCapture`: when the switch is on and the client has gamepad support, the capture frame also takes
`OnGamePadButtonDown` (`EnableGamePadButton(true)`), so "Set key" for the combat helper, emergency and AH keys
accepts PAD1, PADLSHOULDER etc. `SetOverrideBindingClick` already works with pad key names. `FF:KeyConflict`
needs no change (it asks `GetBindingAction`). PADBACK cancels like Escape.

## 3. Readable button names (switch `controller`)
`FF:KeyLabel(key)`: pad keys shown with the client's own text (`GetBindingText(key, "KEY_")`, falls back to the raw
name). Used wherever a key is printed: combat bar hint, emergency tooltip and low-health line, Hub key rows.

## 4. Easier to hit with the gamepad cursor (switch `controller`)
Advisor `<` `>`, Clear pins, Details and the window close buttons get larger hit areas (`SetHitRectInsets`
negative), no layout change.

## 5. Tests, docs, notes
- tests/test_addon.py: Bindings.xml names resolve to existing frames/functions; `controller` in the Hub switch
  list; `FF:KeyLabel("PAD1")` falls back cleanly without the gamepad API; capture accepts a pad button.
- `/ff help` line, docs/IN_GAME_TEST.md steps (bind a pad button, press it in a fight), CHANGELOG/NEWS under
  2.7.1-beta.3, roadmap item in status/community.json moved to done when released.

Build order: 1, 2, 3, 4, 5 in one pass; full tests once at the end.
