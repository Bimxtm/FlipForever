# Improvement cycle (every 12 hours)

What happens in each cycle, and the rules it follows.

## Rules
- **Stable releases happen only at the 12-hour cycle.** Work done in between (including features the owner asks for directly) is published **right away as a beta** (see below) once it's tested. The next cycle turns all betas since the last stable into one stable release. The only exception: when close to the usage limit, push and release what's finished and tested early, so nothing is lost.
- **Betas between cycles are fine,** for testing: version `X.Y.Z-beta.N`, title "FlipForever X.Y.Z Beta N", published as a GitHub **pre-release** (`gh release create --prerelease`). Only apps with "Get beta versions" ticked see them. The next cycle turns the betas into the stable release.
- **Small improvements ship on their own:** fixes, polish, better defaults, more guide data, UI conveniences, and small features that fit an existing module.
- **Never stop to wait for approval (owner, 20 Nov).** Keep working; the owner says when they're available. Major ideas are built anyway on their own branch (`feature/<name>`), not merged, released or installed until approved, and listed under "Ready for approval" in ROADMAP.md. Hard-to-reverse or outward-facing steps (making the repository public, deleting releases, touching other addons) still wait.
- **Major ideas need the owner's OK before release.** That covers new modules, anything that changes how the app or addon behaves by default, new dependencies, anything that touches other addons' files or the game folder beyond `Interface\AddOns\FlipForever`, and anything that makes the repository public. They go into [ROADMAP.md](ROADMAP.md) under "Proposed", get built on a branch, and are presented when the owner is back.
- **Inspiration comes from the installed addons, lightly:** look at what they do and where their features live in the UI. Never copy their code.
- **Self-contained:** every feature is built fully into FlipForever and works without any other addon, even when an installed addon already offers something similar. Other addons are inspiration only, never dependencies, and FlipForever's versions use their own frames and names so nothing conflicts.
- **Blizzard's rules stay intact:** every buy, post and cast needs a key press or click. No automation from game state in combat.
- **Hands off while WoW is running:** never edit SavedVariables or AddOns.txt then.
- **Nothing ships without passing tests.**
- **House style for everything users see** (app, addon, NEWS, CHANGELOG, README, release notes, WEEKLY_BOARD, ROADMAP, IN_GAME_TEST, commit messages): plain, professional wording; no emoji or decorative symbols; no mention of how the project is built or of usage limits. Process notes stay in this file, which is not shipped or shown in the app.

## Night queue (internal, until Sat 21 Nov 13:30) - take the first open item, mark it [x] when shipped
Pace: about 3.5% of the weekly limit per hour (55% left at 21:30 Fri, reset Sat 14:00). Work sessions run every 10 minutes; keep going inside a session while there's work, ship each finished item as a beta.
- [x] Performance: in-game market model parses all 60 scans on every rebuild; cache parsed points per scan so a new scan only adds its own rows
- [x] App: show the addon's gear upgrades and profitable crafts in the desktop app (addon saves them; new app page or Advisor section)
- [x] Test harness: make mock timers keep delayed callbacks (board issue P9)
- [x] Quest locations (major, unapproved): research quest giver positions for class quests, build on branch feature/quest-locations, list as ready for approval
- [x] Auction duration by speed: post fast sellers for 12 h (smaller deposit) and slow ones for 24/48 h, using the learned sales per day
- [x] Gear finder: also check your bags for items that beat what you wear ("equip this")
- [x] App Dashboard: profit per character (chart or table) when several characters trade
- [ ] Shopping list view in game: sort by status and show the expected profit per item
- [ ] Quest locations branch: add warlock, rogue and the missing warrior/paladin quest starts (research), keep on the branch
- [ ] Language-independent spells: rank-1 spell IDs for the combat helper and advisor, names looked up in the client's language (last: can't be checked without a non-English client)
- [ ] Stable 2.5.0 at the 07:11 cycle (all 2.4 and 2.5 betas); translate new texts first (chat messages, auction panel status lines, app pages)

## Usage budget (internal)
- Pro plan, extra usage off. Check usage at the start of each cycle; above 80% of the 5-hour window, pause and resume after the reset.
- The owner asked (20 Nov) to use the weekly allowance fully until the reset on Sat 21 Nov 14:00; after that, about 10% of the weekly limit per day, with ~15% kept for real-game bug fixes.

## Steps
1. Read **WEEKLY_BOARD.md** first (goals, schedule, open issues), then ROADMAP.md. High-severity issues come before features. Check usage (see Usage budget).
2. Implement. Add or extend tests in `tests/`.
3. Check:
   - `python tests/test_addon.py` passes (ALL ADDON TESTS PASSED)
   - the app opens (GUI smoke test) and the engine runs on demo data
4. Version (owner's rule, 20 Nov): the **last number** (x.y.Z) for every normal update: fixes, polish, small features (2.4.1, 2.4.2, ...). The **middle number** (x.Y.0) only for a **big update**: an approved major feature or overhaul (2.4.0 Better GUI, 2.5.0 crafting profit finder). Betas preview the version they lead to (`2.4.0-beta.N`, `2.4.1-beta.N`). Bump `app/flipforever/version.py` and `## Version` in `addon/FlipForever/FlipForever.toc`.
5. Add a CHANGELOG.md section, and rewrite NEWS.md for the player.
   Translations (owner's rule, 20 Nov): only right before a **stable** release, never in betas. At the stable cycle, translate the texts added since the last stable into all 11 languages (app/flipforever/i18n.py, then tools/gen_locale.py).
6. `python tools/build_release.py`.
7. Commit, push, and `gh release create vX.Y.Z dist/FlipForever-vX.Y.Z.zip dist/SHA256SUMS.txt --notes-file dist/release-notes.md`.
8. Update WEEKLY_BOARD.md (done items, new issues found) and ROADMAP.md (move done items, add new small ideas, and add major ideas under "Waiting for your OK"). On Thursdays, write a short weekly review and a new board for the next week.
9. Report briefly what shipped, and ask about any new major ideas.
