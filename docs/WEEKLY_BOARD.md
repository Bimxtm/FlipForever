# Weekly plan: 20-27 November 2026

## Goals
1. **Prove it in the real game.** So far everything has passed automated tests only. Feedback from real play, and fixing what breaks, comes before new features.
2. **Polish what exists.** The advisor, profession planner and tooltips should feel finished, not just work.
3. **One major feature:** the crafting profit finder (approved). In beta since Thursday evening.

## Schedule
| Day | Focus | Release |
|---|---|---|
| Thu 20 | In-game planning after every scan (no reload), scan alerts, one-key combat targeting | 2.3.0 |
| Thu 20 - Fri 21 | GUI overhaul: tabbed in-game window with a shopping-list view, app sidebar and layout, one look for every panel; smarter undercut; best farming zone in the Advisor | 2.4.0 betas |
| Fri 21 | In-game test results: fix what's reported | 2.4.x |
| Sat 22 - Sun 23 | 2.4.0 release; per-item sale speed in the app | 2.4.0 |
| Mon 24 | Language-independent spells (spell IDs); combat sequences for levels 1-10 | 2.4.x |
| Tue 25 - Thu 27 | Crafting profit finder; bug fixes first; weekly review on Thursday | 2.5.0 betas |

## Waiting for approval
- 2.6.0 beta 1 (branch feature/talent-overlay, owner request): the chosen build on the Talents window, next point marked, order panel beside it. Kept off main until the owner has seen it.

## Open issues
| # | Issue | Severity | Plan |
|---|---|---|---|
| P1 | Nothing has run in the real game yet (auction house API, combat helper, profession API, tooltips) | High | In-game test checklist (Development tab); reported problems get fixed first |
| P2 | Unverified game API details: full-scan timing, silver-only commodity prices, talent API shape, the step button in combat | High | Built with fallbacks; confirm in game (P1) |
| P4 | Guide data: 9 builds per class now; some are key talents only (no pick order), some Warcraft Tavern builds are still level 30 beta builds, and Mobalytics/Icy Veins block automated reading | Medium | Refresh when the guides update |
| P5 | Spell IDs are from memory and untested on a non-English client; WoW: Forever-only spells stay English | Low | /ff spells in game (checklist step 11) |
| P8 | Gathering stats show "map 1411" until the addon has run once | Low | Names are saved at login; verify in game |

## Done this week
- 2.5.2 beta 1 (owner report): paladin combat helper keeps the seal up; no blocked action when clicking the combat icon in a fight; blocked actions show in /ff errors.
- 2.5.1: desktop and Start menu shortcut offer; updates from public GitHub releases without a token.
- Repository is public (owner, 21 Nov): the app finds updates without a GitHub token (P3).
- 2.5.0 stable: all betas, every text in 11 languages, Advisor data and realm fixes, druid forms, Gear tab hover compare, autopilot off for now.
- 2.5.0 beta 29 (owner report): combat helper no longer gets stuck on one skill.
- 2.5.0 beta 28 (owner request): Advisor button in the window title bar, clickable next step, key bindings.
- 2.5.0 beta 27 (reported by the owner): budget changes in Settings apply to the selected character.
- 2.5.0 beta 26: /ff errors.
- 2.5.0 beta 25: Copy bug report info in the app; the addon keeps its last errors.
- 2.5.0 beta 24: undercut auctions per character in the app.
- 2.5.0 beta 23: random-stat gear scored and bought version by version (P6).
- 2.5.0 beta 22: undercut check for your own auctions when the auction house opens.
- 2.5.0 beta 21: gear upgrade line in item tooltips, scan age on the Overview, clearer gathering price source.
- 2.5.0 beta 20: spells looked up by spell ID, so the combat helper and Advisor work in every client language (P5); /ff spells check.
- 2.5.0 beta 19: Deals page filters in the app (fast sellers, minimum profit), this week's result on the in-game Overview.
- 2.5.0 beta 18: collect auction gold in one click, gear upgrade alert after scans, cooldown seconds on the combat icons.
- 2.5.0 beta 17: quest locations (approved): start NPCs for every class quest, learned NPC positions, arrow from Advisor steps.
- 2.5.0 beta 16 (your request): combat helper key + by default.
- 2.5.0 beta 15 (your request): combat helper waits for cooldowns - cooldown abilities on ready, the rest as a cast sequence that only advances after a successful cast.
- 2.5.0 beta 14: shopping list sorted by status with expected profit per item.
- 2.5.0 beta 13: profit per character on the app Dashboard.
- 2.5.0 beta 12: gear finder lists upgrades already in your bags, with Equip.
- 2.5.0 beta 11: auction length by sell speed (12 h for fast sellers, smaller deposits).
- Test harness: mock timers now keep delayed callbacks (P9 fixed).
- 2.5.0 beta 10: Advisor steps translated into all 11 languages; test that every translation keeps its placeholders.
- 2.5.0 beta 9: scans parsed once (faster in-game planning); gear upgrades and profitable crafts in the app's Advisor page.
- 2.5.0 beta 8: waypoint arrow (approved 20 Nov): map pin, /ffway, next gathering stop.
- 2.5.0 beta 7: settings, Advisor window and profession planner translated into all 11 languages.
- 2.5.0 beta 6: 9 builds per class from Method, Warcraft Tavern and RankedBoost, with roles, points, rotations, and combat rotations for every new build style.
- 2.5.0 beta 5: combat helper level bands 1-10 / 11-39 / 40-60 for all classes and builds; exact skill-up chances learned from colour changes (P7).
- 2.5.0 beta 4: auction house accuracy from current WoW: Forever guides (deposit refunded on sale, minimum deposit now 1 copper, 5% cut), vendor flips with automatic merchant selling, vendor floor when posting, cheaper items considered.
- 2.5.0 beta 3: language selector with all 11 game languages (app and addon), one shared translation source.
- 2.5.0 beta 2: gear finder (Gear tab, Advisor step), encrypted GitHub token, setup for other players. Next: language selector.
- 2.5.0 beta 1: crafting profit finder (approved feature), ahead of schedule. The next stable release will be 2.5.0 and include the 2.4 betas.
- 2.4.0 betas 1-4: tabbed in-game window with a shopping-list view and Skip; app sidebar, page headers, striped tables and colour-coded cards; Gathering in the common look; best farming zone in the Advisor; smarter undercut; a reason on every Advisor step (beta 5).
- 2.3.0: in-game planning after every scan (P10), scan alert and autopilot pause (P11), one-key targeting and tank mode (P12), app builds the list after import, sell speed in tooltips, in-game test checklist, window position remembered.
- 2.0.0 - 2.2.0: all-in-one addon, tooltips, minimap summary, profession planner.
- Repository, releases, self-updater, beta channel, test suite.

## Definition of done
Tests pass (`tests/test_addon.py`), the app starts, CHANGELOG and NEWS are updated, nothing depends on other addons or conflicts with them. Betas between releases; stable releases on the regular schedule.
