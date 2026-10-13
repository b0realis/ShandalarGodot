# Repository check — 2026-10-13

The owner, after 0.50.21: *"Ok check all Repo for any problems, obvious
bugs. Documentation inconsistencies and commit and push all work."*

Four read-only checks ran over the whole repository at 0.50.21 (4f9c979):

- **Player-facing and top-level docs** against the code: README,
  CONTRIBUTING, DEVELOPMENT, AGENTS, ARCHITECTURE, the handheld, player
  files, setup, release-build and LAN guides, the release notes and the
  in-game Help (53 findings, 10 MED).
- **Developer docs and code comments** against the code: CODE_MAP, ROADMAP,
  mechanics, duel-todo, the glossary, ai-difficulty, simplified-cards, the
  card and pack recipes, and every `[method …]`-style reference in a code
  comment, checked mechanically (33 findings, 9 MED).
- **The code changed since 0.50.16** that the robustness campaign's own
  fixers had not reviewed — 0.50.21's three features above all — with
  probes and twelve AI-vs-AI duels over clause cards and damage effects
  under three rule settings (4 findings, 1 HIGH).
- **Hygiene** of everything tracked: an export from a clean copy, the
  Godot import and boot, every scene and `res://` path, the shell and Python
  tools, CI, versions, stray files (34 findings, 1 HIGH).

Then four fixers on disjoint files fixed them; every behaviour fix has its
own test (`docs/CODE_MAP.md`, "The repository check (2026-10-13)").

## What mattered

- **Every package carried `branding/`** — the logo master and the two
  README screenshots, which show the imported 1997 look and card art —
  because no export preset left the folder out. Nothing in the game loads
  it. All nine presets now exclude it (pinned by
  `tools/test_c3_fx_scripts_export_filter.py`); a Linux pack is about 4 MB
  smaller.
- **At an SGManalink table the duel goes on under the mini help**, and a
  question for the seat arriving under it took the clicks aimed at the
  help's Close — answering the question. A question now closes the help and
  comes to the front, and for a moment ignores clicks. The same check found
  the PAUSE window had the same hole (a question added after it took its
  clicks): it now stays on top, the question waiting behind it; that one
  Escape there both opened and closed the pause; and that keys under the
  tournament Master Panel reached the hidden table.
- **A rule chosen on a brand-new profile was changed once at the next
  start**: the rules-revision marker was never written for a file that had
  no rule yet, so the first saved rule was migrated as an older build's.
- **Shell and CI:** a Quest build without the editor settings or the SDK
  stopped silently; `shandalar.sh --help` failed from another folder;
  Ctrl-C did not reach the soak; a long `find | head` could end a build
  silently; a home path inside the skin zip went unchecked; CI moved to the
  Node 24 upload action and a pinned Ubuntu 24.04 runner.
- **Docs:** the setup notes in every package ran the art tools from the
  wrong folder (they ship in `tools/`); handhelds.md put card packs in
  `skin/`; the LAN guide's deck sizes, protocol history and button names
  were stale; ROADMAP kept five finished items open and a month-old numbers
  table; CODE_MAP and mechanics.md described the damage walk from before
  CR 616.1 ordering; twelve code comments pointed at functions that no
  longer exist. Counts that keep going stale were replaced by text without
  counts where nobody needs the number.

## Left as it is

- **Shell:** fixed log paths shared by two builds at once (not a workflow
  here), Ctrl-C at the remaining short time-capped `timeout` calls, and
  `--out` writing beside its folder (by design, documented).
- **A fresh clone's first import** prints GUT's own warnings about images
  whose `.import` files are ignored (harmless; the boot is clean).
- **Hunter probes that fail by design:** the mini-help probe expects the
  help to stay up when a question arrives (it now closes).
- **For the owner:** the two README screenshots show the 1997 look and card
  art in the public repository (on purpose since 2026-09-14); the early
  commits of 2026-09-05…12 carry a personal address as author (changing it
  would rewrite history); the desk's own `export_presets.cfg` has no Web
  Threaded preset.

## Verification

- Gate: `SHARDS=4 SUITE_TIMEOUT=3600 ./run_tests.sh` — **867 scripts,
  13,403 tests, 581,265 asserts**, exit 0; the log's WARNING lines went from
  131 to 28 (each a refusal a test asks for).
- Python: `python3 -m unittest discover -s tools -p 'test_*.py'` — 698
  tests, OK (15 skipped), with no ResourceWarning or UserWarning lines.
- Boot smoke clean; `./duel_soak.sh` with the default, fifth and modern
  rules — 6 duels each, no ERROR, WARNING or STALL.
