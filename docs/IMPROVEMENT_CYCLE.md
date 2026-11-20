# Improvement cycle (every 12 hours)

What happens in each cycle, and the rules it follows.

## Rules
- **Small improvements ship on their own:** fixes, polish, better defaults, more guide data, UI conveniences, and small features that fit an existing module.
- **Major ideas wait for the owner's OK.** That covers new modules, anything that changes how the app or addon behaves by default, new dependencies, anything that touches other addons' files or the game folder beyond `Interface\AddOns\FlipForever`, and anything that makes the repository public. They go into [ROADMAP.md](ROADMAP.md) under "Waiting for your OK", and the cycle asks.
- **Inspiration comes from the installed addons, lightly:** look at what they do and where their features live in the UI. Never copy their code.
- **Blizzard's rules stay intact:** every buy, post and cast needs a key press or click. No automation from game state in combat.
- **Hands off while WoW is running:** never edit SavedVariables or AddOns.txt then.
- **Nothing ships without passing tests.**

## Steps
1. Read ROADMAP.md. Pick 1-3 items from "Small improvements" (or approved items).
2. Implement. Add or extend tests in `tests/`.
3. Check:
   - `python tests/test_addon.py` passes (ALL ADDON TESTS PASSED)
   - the app opens (GUI smoke test) and the engine runs on demo data
4. Version: patch (x.y.Z) for fixes, minor (x.Y.0) for features. Bump `app/flipforever/version.py` and `## Version` in `addon/FlipForever/FlipForever.toc`.
5. Add a CHANGELOG.md section, and rewrite NEWS.md for the player.
6. `python tools/build_release.py`.
7. Commit, push, and `gh release create vX.Y.Z dist/FlipForever-vX.Y.Z.zip dist/SHA256SUMS.txt --notes-file dist/release-notes.md`.
8. Update ROADMAP.md (move done items, add new small ideas, and add major ideas under "Waiting for your OK").
9. Report briefly what shipped, and ask about any new major ideas.
