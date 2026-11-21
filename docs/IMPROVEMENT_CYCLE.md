# Improvement cycle (every 12 hours)

What happens in each cycle, and the rules it follows.

## Rules
- **Stable releases happen only at the 12-hour cycle.** Work done in between (including features the owner asks for directly) is published **right away as a beta** (see below) once it's tested. The next cycle turns all betas since the last stable into one stable release. The only exception: when close to the usage limit, push and release what's finished and tested early, so nothing is lost.
- **Betas between cycles are fine,** for testing: version `X.Y.Z-beta.N`, title "FlipForever X.Y.Z Beta N", published as a GitHub **pre-release** (`gh release create --prerelease`). Only apps with "Get beta versions" ticked see them. The next cycle turns the betas into the stable release.
- **Small improvements ship on their own:** fixes, polish, better defaults, more guide data, UI conveniences, and small features that fit an existing module.
- **Never stop to wait for approval (owner, 20 Nov).** Keep working; the owner says when they're available. Major ideas are built anyway on their own branch (`feature/<name>`), not merged, released or installed until approved, and listed under "Ready for approval" in ROADMAP.md. Hard-to-reverse or outward-facing steps (making the repository public, deleting releases, touching other addons) still wait.
- **Major ideas need the owner's OK before release.** That covers new modules, anything that changes how the app or addon behaves by default, new dependencies, anything that touches other addons' files or the game folder beyond `Interface\AddOns\FlipForever`, and anything that makes the repository public. They go into [ROADMAP.md](ROADMAP.md) under "Proposed", get built on a branch, and are presented when the owner is back.
- **Inspiration comes from the installed addons, lightly:** look at what they do and where their features live in the UI. Never copy their code.
- **Every feature can be switched off (owner, 21 Nov):** each new feature gets its own switch in the in-game Settings tab (the *Features* section, or its module's section), and its code checks that setting.
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
- [x] Shopping list view in game: sort by status and show the expected profit per item
- [x] Quest locations branch: add warlock, rogue and the missing warrior/paladin quest starts (research), keep on the branch
- [x] Mailbox: a "Collect auction gold" button that takes the gold from all sale invoices in one click (no item mail touched)
- [x] Combat helper: cooldown seconds on the small cooldown icons
- [x] Gear finder: alert (sound + chat line) when a new affordable upgrade appears after a scan
- [x] App Deals page: filters for "fast sellers only" and a minimum profit
- [x] Overview tab in game: this week's profit next to today's
- [x] Language-independent spells: rank-1 spell IDs for the combat helper and advisor, names looked up in the client's language (last: can't be checked without a non-English client)
- [x] Stable 2.5.0 at the 07:11 cycle (all 2.4 and 2.5 betas); translate new texts first (chat messages, auction panel status lines, app pages)
  - Prepared on branch release/2.5.0-translations (chat messages, status lines, newer window texts, shared plural helper): merge it into main first (app pages are translated there too: labels, buttons, table headings, settings); the How to use text stays English. After merging, translate texts added in betas after the branch (beta 21 texts are already on the branch; beta 22 is on the branch; beta 23 merged and re-keyed too; later betas: check for new FF:T texts); run scratchpad-style check: every FF:T literal must be in i18n
- [x] Discord #bug-reports (21 Nov): LDH "Budget not updating" (fixed in beta 27; LDH likely has beta 24 from Drive), LDH "Advisor not working" (same as the /ff guide report below), Alix "Combat helper does not switch between druid forms - it keeps human attacks in bear form".
- [x] Discord #suggestions (21 Nov): LDH Gear tab - hover the item name for its stats, show the full item name without overlapping others. Alix: disable the AH autopilot for now (needs more work). Alix: talent builds as an overlay on the Talents window, builds more fleshed out (bigger: feature branch, 2.6.0).
- [x] Discord #bug-reports (21 Nov 10:48-11:00, Alix): "Interface action failed because of an AddOn" after setting the combat helper key; paladin combat helper "only uses one spell ... just keeps using consecration", no seal/buffs. Shipped 2.5.2-beta.1: paladin seal/Judgement cast sequence, bar move guarded in combat, blocked actions logged to /ff errors. Check mark once confirmed in a stable; ask in game for /ff errors output if the blocked message comes back.
- [x] Discord #suggestions (21 Nov 08:06-10:32, Alix): app auto-switches to the logged-in character; gear finder compares stat gains, not just armor; Advisor steps pinnable on the map like the quest tracker; general UI/content pass. Queued in ROADMAP.md.
- [x] Talent overlay beta 2 (shipped 21 Nov afternoon as 2.6.0-beta.2: tree per talent, role, how to play, points to spend, /ff talents; planned ranks come from the guide data already)
- [x] Talent overlay beta 3 (2.6.0-beta.3): key-talent-only builds ordered by tier with a reachable next point and "spend N more points" note; click a panel line to open its tree.
- [x] Talent overlay beta 4 (2.6.0-beta.4): panel line tooltips (game's talent description, tree, pick, target rank) and the build line in marked talent buttons' tooltips. The guides give no per-talent reasons, so none were added.
- [x] Planning (owner request, 21 Nov afternoon; done: 8 small ideas under "Ideas from popular addons" and 3 big ones under Proposed in ROADMAP.md, #planned-features updated): plan new features from the most downloaded and most loved Classic / WoW: Forever addons (CurseForge, Wago, WoWInterface top lists, and the addons installed in the game folder). Note what players love and whether it fits FlipForever; pick the 8-12 best. Small ones go under Smaller improvements in ROADMAP.md and get built one by one as betas; big ones go under Proposed and are only built on feature/<name> branches until approved. Mirror the list in Discord #planned-features (edit the existing message). Ideas only: never copy another addon's code, art, data files or texts.
- [ ] Build the small ideas from ROADMAP.md "Ideas from popular addons" one by one as betas on main (2.5.2-beta.N): sell junk and repair (done, 2.5.2-beta.2), trainer reminder (done, 2.5.2-beta.4), time to level (done, 2.5.2-beta.6), then threat warning, mailbox open all, bag value, price history in the app, node timers. Alternate with the talent overlay betas.
- [ ] Big modules from ROADMAP.md Proposed (owner, 21 Nov afternoon: replicating popular addon features our own way is approved as a direction): build each on its own branch and release betas from it so the owner and testers can try them; merge into main once the owner has seen them. Order: quest helper (feature/quest-helper), leveling route guide (feature/leveling-route), disenchant profits (feature/disenchant). Own code, frames, names and data; no dependencies.
- [ ] Talent overlay beta 5 (branch feature/talent-overlay): the build's planned split per level band (where the points should stand at 20/30/40/50/60) in the panel, and a warning when your spent points drift from the build (points in a tree the build leaves empty).
- [x] Owner report (21 Nov, about 04:30): "/ff guide also doesnt work in the app". Find out what fails: the /ff guide command in game (Advisor window not opening, an error, slash command wiring) and the app's Advisor page (empty, or not showing what /ff guide shows). Fix, test, ship as the first beta after the 2.5.0 stable.

Version note (21 Nov): 2.5.1 is the current stable. Small fixes now ship as 2.5.2-beta.N; the talent overlay (owner request) is built on branch feature/talent-overlay as 2.6.0-beta.N and is shown to the owner before it reaches main.

## Fresh session after every usage reset (owner, 21 Nov)
- Long conversations make every step expensive, so the work never continues in the same session after a 5-hour window reset.
- When a session pauses for the limit, its one-shot after the reset does this: start a new session (fresh context, same project folder, with a short brief pointing to this file, ROADMAP.md, WEEKLY_BOARD.md and the current branch/version state), let the new session create the 10-minute and 12-hour jobs, and delete every scheduled job in the old session.

## Discord check after every usage reset (owner, 21 Nov)
- The first session after each 5-hour window reset reads #bug-reports and #suggestions in the private Discord server (built-in browser, the owner is signed in; channel list under the FlipForever server).
- New bug reports go to the top of the Night queue (quote the report, note who sent it by Discord name only in this file, never in shipped text). New suggestions go to ROADMAP.md: small ones under Smaller improvements, big ones under Proposed for the owner's OK.
- Once a report or suggestion is fixed and released, react to that message with a check mark (white_check_mark), so it's clear next time what is done (owner, 21 Nov). Don't reply in text unless the owner asks. Messages without a check mark are still open. Mention what was found in the session report.
- After a release, post a short plain update in #announcements (owner, 21 Nov) (downloads come from GitHub releases, linked in #downloads; nothing to upload).

## Where release notes go in Discord (owner, 21 Nov)
- Stable releases: a short plain update in #announcements.
- Betas (pre-releases): the update notes go in #beta-updates (private, Testers read only, the owner posts) - never in #announcements.
- #beta-testing is where Testers give feedback on betas; read it in the Discord check like #bug-reports and react with a check mark once a reported item is fixed and released.
- #what-is-flipforever at the top explains the project; update it when the big picture changes.

## Sharing with friends (internal)
- Friends download from the Google Drive folder FlipForever (link in the private Discord server, #downloads). After a stable release, remind the owner to drag the new zip into that folder (the Drive connector cannot upload 12 MB files); offer to post the release in #announcements. For 2.5.0 the owner already said yes (21 Nov): after publishing, post a short plain announcement in #announcements (built-in browser, the owner is signed in) with what is new and that the zip is in #downloads once uploaded. Keep #planned-features in step with ROADMAP.md (offer to update it when the roadmap changes).

## Usage budget (internal)
- Pro plan, extra usage off. Check usage at the start of each cycle; above 95% of the 5-hour window (owner, 21 Nov: use it fully), pause and resume after the reset.
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
