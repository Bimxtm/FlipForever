# FlipForever and the game's rules

FlipForever is built to stay inside Blizzard's rules for WoW: Forever and its addon policy. This page explains how.
If you are unsure about anything, read Blizzard's own rules (End User License Agreement, Terms of Use and the UI
Add-On Development Policy). Those rules are what counts, not this page.

## The addon only uses what the game allows
- It runs inside the game's own addon system and only calls the addon API that Blizzard gives every addon.
- Anything the game protects needs your own key press or click. That covers buying, posting and cancelling
  auctions, and casting spells. FlipForever never gets around that, and it does nothing while you are away from
  the keyboard.
- The combat helper is a normal action button. Each press casts at most one spell, like a macro.
  It never moves your character, never plays for you, and never presses keys for you.
- The autopilot only searches the auction house while you have it open, and buying still waits for your
  key press. When you or another addon use the auction house, it steps aside.
- The waypoint arrow, map pins, the Advisor and the talent overlay only show information.

## The desktop app never touches the game
- It reads the files the game saves itself (SavedVariables) after a /reload or logout, and writes the shopping
  list back as an addon file that the game loads on the next /reload.
- It does not read the game's memory, inject anything, send key presses to the game, or log in to your account.
- It never asks for your password.

## Your data
- Anonymous combat data (class, build, spell orders, fight times, no names) is shared only if the switch is on.
  You can turn it off in the app's Settings and in the game's Settings.
- Bug reports and suggestions only leave your PC when you send one.

## Free and readable
- FlipForever is free. The addon code is plain, readable Lua, as Blizzard's addon policy asks, and everything is
  public on GitHub: https://github.com/Bimxtm/FlipForever
