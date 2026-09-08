# Contributing to Shandalar

A GDScript remake of MicroProse's 1997 MTG game on Godot 4.7. Read
`docs/ARCHITECTURE.md` first, `docs/CODE_MAP.md` to locate anything.

## Commands

- Test suite: `./run_tests.sh` (headless GUT; pinned binary `../tools/godot`).
  Single test: `./run_tests.sh -gunit_test_name=<name>`.
  TRUST ITS EXIT CODE, NOT THE PRINTED SUMMARY: GUT silently SKIPS a test
  script it cannot parse and still prints "All tests passed" (verified
  2026-08-31 — one broken file, summary read 1894/1894 passing while a
  whole file never ran). The script therefore greps its own log and fails
  on a parse/compile error or a missing GutTest base, derives success
  from GUT's own tally, AND requires exit 0. Since 2026-09-02 it also
  fails on ANY `ERROR:`/`SCRIPT ERROR:` line (an error in before_each,
  a teardown frame or a deferred call never reaches GUT's tally), on a
  risky/pending test, on the exit-time "ObjectDB instances were leaked"
  line, and it kills a hung run after `SUITE_TIMEOUT` (1800 s) instead
  of waiting forever. A 134 (SIGABRT) at teardown is a real bug, not
  renderer noise: `CardRegistry`'s static card table used to be destroyed
  after the card scripts its Callables point into, corrupting the heap on
  every exit (bisected 2026-09-01). The `Lifecycle` autoload
  (`game/lifecycle.gd`) now drops it first. The rule that follows: NO
  `static var` may hold a `CardData`/`CardInstance` (a second such cache,
  `DeckFilter._facts`, aborted every run that had opened the Deck Builder
  until 2026-09-02) — key caches by name or instance id instead.
  Both this script and the soak run with `XDG_DATA_HOME` pointed at
  `$TMPDIR/shandalar-test-data` (override: `SHANDALAR_TEST_DATA_HOME`), so
  `user://` is NOT the player's real profile — which it was until
  2026-09-04, and which is how a test's half-second write of
  `phase_stoppers` and a stale cached `ConfigFile` between them kept the
  three default Stops from ever reaching the player and deleted their
  chosen portrait (docs/ROADMAP.md, "WHY THE THREE DOTS DID NOT REACH THE
  OWNER"). A suite must not be able to write the file the shipped game
  reads.
- Duel soak: `./duel_soak.sh` — whole duels through the live duel screen
  under Xvfb (AI seats and a fuzzed human seat); passes only on `SOAK
  done` with no ERROR/WARNING/STALL line (exit 2 = a duel stood still or
  never started, 3 = bad argument, 124 = whole-run timeout, 1 = a stray
  line). `--rules fifth|modern` plays every duel under that ruleset
  instead of whatever the (isolated — see above) `user://settings.cfg`
  holds, which with no player file to read is the built-in defaults. Run
  it after touching `game/duel/`; the suite drives one widget at a time
  and cannot see what it catches.
- Boot scene smoke: `../tools/godot --headless --path . --quit-after 3`
- Release build: `./build_release.sh` exports the `Linux 64` preset
  (`export_presets.cfg`, copied from `export_presets.cfg.example`) to
  `../shandalar-build/linux64/` and smoke-boots it; `--skin` links this
  checkout's `assets/` into `user://original_skin` so the exported build
  wears the original graphics. The `.pck` ships scripts, `cards/data/` and
  every `.deck` — never art: `GameSkin` reads art off the filesystem
  (`user://` first), so the original 1997 files stay the player's own
  copy. The export templates here are `4.7.stable` while the pinned engine
  is 4.7.2, so the preset names the release template by path — which is
  why the preset itself is gitignored and only the example is committed.
  `--web` exports the `Web` preset (the `web_nothreads` template: static
  hosting, no COOP/COEP headers) to `../shandalar-build/web/` and checks
  that index.html/.js/.wasm/.pck came out; nothing boots headless there,
  a browser does that (`python3 -m http.server --directory
  ../shandalar-build/web`). `--web --skin` writes the skin zip and its
  catalogue beside the page (`web/skin/`) for the page to fetch, and
  `--web --skin --cardart` the card art too, for a page served on this
  machine only. `--package`, since the owner's ruling of 2026-09-08
  ("Cardart we dont release, only scripts to build it — licence"),
  writes the game zip (`pkg/Shandalar-<ver>-linux64.zip` — the game,
  `skin/SKIN.txt`, `icon.png`, `shortcut.sh`, the tools, NO art), the
  same again with the skin zip in its `skin/`
  (`…-linux64-with-skin.zip`, "so only cards are needed to play"), the
  skin zip beside them (`pkg/original_skin.zip`, a download of its own)
  and the card art zip where nothing is uploaded from
  (`../shandalar-build/local/cardart.zip`, never a release asset); the
  staged folder the game zip was made from is left with both packs in
  its `skin/` as the play copy. `--web --package` zips the web folder
  the same two ways (`…-web.zip`, `…-web-with-skin.zip`: the page's
  files, `skin/SKIN.txt`, the tools under `tools/`, `docs/setup-web.txt`
  as README.txt — never the card art, whatever `--cardart` put beside
  the page). Every stage is grepped for the builder's home path before
  it is zipped and the build fails on a hit (`guard_stage`) — a stale
  README once carried one. A release is the five zips: two Linux, two
  web, the skin. Since 2026-09-08 a built game mounts
  the skin as TWO zips (`SkinPack`, `load_resource_pack`): the 1997
  material and, apart, the card art — a zip's kind is what it holds,
  not its name. A player chooses either in Options → Skin, or drops it
  on the window: a skin zip lands in `user://skins/` (the `skin_zip` key
  names the one worn), a card pack in `user://cardpacks/`, where every
  zip is mounted. The five places a player can fill — and their
  `settings.cfg` keys — live in ONE file, `game/paths.gd` (`GamePaths`);
  read a place through it, never through a literal `user://...`, and
  never write a key as a default. `tools/skin_catalogue.py --check`
  says whether a zip is complete.
  The build is the LOCAL step and the GitHub release is a separate one:
  a local build gets played first, and `gh release create` runs only
  when the owner asks for the release — never as the automatic tail of a
  piece of work.
- Python tool self-tests (no Godot, no network):
  `python3 -m unittest discover -s tools -p 'test_*.py'`
- Screenshots under Xvfb: see **Commands that can hang** below. Do not
  pipe a Godot run into anything. It has already cost 12.7 hours once.

## Commands that can hang — READ BEFORE RUNNING GODOT UNDER Xvfb

**THE RULE: never pipe a process that might hang into a reader, and put
the timeout where it can reach the process that actually blocks.**

**The recipe for any windowed Godot run:**

```bash
LOG="$SCRATCH/shot.log"
xvfb-run -a timeout -k 5 120 ../tools/godot --path . res://tools/X.tscn \
    > "$LOG" 2>&1 </dev/null
tail -6 "$LOG"
```

Three things make it safe, and all three are load-bearing:
`timeout` is INSIDE `xvfb-run` so it signals Godot itself; output goes to a
FILE, so no reader can be left waiting on a pipe; stdin is CLOSED, so
nothing can block asking for input.

**What went wrong on 2026-09-01, and why the obvious guard failed.** A run
was launched with a guard that looked entirely reasonable:

```bash
timeout 100 xvfb-run -a ../tools/godot ... | tail -6      # DO NOT
```

`timeout` killed `xvfb-run` — **not** the Godot process `xvfb-run` had
spawned. Orphaned Godot kept the write end of the pipe open, so `tail`
never saw EOF, and the shell waited on the pipeline. A 100-second guard
became **12.7 hours**; the rest of that day's work took about twenty
minutes between them.

**The generalisation, which matters more than the recipe.** A timeout only
protects you if it can signal the process that is actually blocking. Any
wrapper that spawns a child — `xvfb-run`, `env`, `nohup`, a shell
function, `sh -c` — puts a layer between `timeout` and the thing that
hangs. Assume every Godot invocation can hang, write every long command so
that it can FAIL without wedging you, and prefer a log file to a pipe
whenever the producer is not certain to exit.

**If a command runs longer than a few minutes for a reason you cannot
name, stop and investigate rather than waiting.** Waiting is how a
two-hour job becomes a thirteen-hour one.

## Scratch files: not in `tests/`, not left behind

Benchmarks and probes belong OUTSIDE `tests/`, and get deleted when the
question they answered is answered. A one-off A/B benchmark once sat
inside `tests/ui/`; its four timing functions assert nothing, so GUT
reported them as "risky", and they were mistaken for a pre-existing quirk
of the suite for most of a day. Deleting the file took the suite to
2368/2368 with zero risky — the first genuinely clean reading in a while.

If your `/tmp` is tmpfs it is RAM. Screenshots there are memory. Use ONE
directory, inspect, delete immediately; the screenshot tour writes ~100 MB
per run. A session once accumulated 2.4 GB across 420 directories and was
OOM-killed.

A scratch Godot run that is NOT a test (a screenshot script, a click-through
probe) gets two more flags, and both matter. `--log-file "$SCRATCH/x.log"`:
Godot keeps only the last five files in `user://logs/`, so a scratch run
without it silently pushes the owner's own play logs out of the ring — and
a probe you want to read after the fact is then the one that got rotated.
`XDG_DATA_HOME="$SCRATCH/xdg"` whenever the script touches `Settings`, the
options screen, or Magic Battle's `Go!`: `user://settings.cfg` is the
owner's own file, `Settings.set_value` persists by default, and a run that
ticks Full screen or presses `Go!` from a script would otherwise rewrite
what the owner opens on next time. `run_tests.sh` and `duel_soak.sh`
already isolate it; a hand-written run does not unless you say so. The
same flag keeps a scratch duel out of the owner's running `duel_log.txt`
(`DuelLogFile`): beside the executable in an exported game, under
`user://` whenever the editor binary runs the project — so every duel a
scratch script plays through the live screen is appended there too.

## Hard rules

1. `engine/` and `cards/` stay pure: RefCounted only — never Node, scenes,
   Input, or anything from `game/`. Must run headless.
2. ALL game-state mutation goes through `MtgGame` helpers. Never move cards
   between zone arrays or change life/damage/characteristics anywhere else.
3. Action methods return `""` on success or a human-readable refusal string —
   never assert/throw on player-level mistakes.
4. One card per file in `cards/sets/<set>/`; filename = snake_case card name;
   no `class_name` on card files; header doc comment = name line + exact
   oracle text + implementation notes. Follow `docs/adding-cards.md` and its
   checklist exactly, including the test-first rule.
5. Rules code reads `cur_power`/`cur_toughness`/`cur_keywords` (live values),
   never `data.power` etc. (printed values).
6. Any rules shortcut gets a comment at the site containing the word
   `SIMPLIFIED` in caps (`grep -rlw SIMPLIFIED cards` finds them all; the
   card-scoped form is `SIMPLIFIED (docs/simplified-cards.md, "Name"):`)
   plus a row in `docs/simplified-cards.md` (card-scoped) or
   `docs/ROADMAP.md` (engine-wide). `tests/test_simplified_ledger.gd`
   pins marker and ledger to each other. Lifting one: delete marker +
   row, pin with a test.
   New files/classes get a row in `docs/CODE_MAP.md`.
7. Deterministic engine: randomness only via `MtgGame.rng`.

## Gotchas

- `Color` is a Godot built-in — our enum is `Mtg.ManaColor` (that rename
  already happened once; don't reintroduce). Watch for other reserved names
  when adding enums.
- GDScript treats "variable type inferred from a Variant value" as an
  ERROR here. `var x := weakref(g)` and `var y := node.get_ref()` both
  fail to parse; write `var x: WeakRef = weakref(g)`. A single
  unparseable card file drops the pool from 897 to 708 and produces
  hundreds of failures, so run the boot smoke after touching any card.
- Test-only state surgery belongs in `tests/game_test.gd` helpers, which may
  reach into `g._instances` etc.; real tests act through the public API.
- A `-s` script (`duel_soak.gd`, the benches, any scratch SceneTree
  script) is COMPILED BEFORE THE AUTOLOADS EXIST. Naming an autoload —
  `ShellMusic.stop()` — in a script the tool depends on (a typed
  `DuelScreen` variable pulls in `duel_screen.gd`) is "Identifier not
  found" for the whole chain and the soak never starts a duel, while
  the suite, which runs as a scene, is green. A screen that a tool may
  depend on reaches an autoload through the tree at call time
  (`get_node_or_null(^"/root/ShellMusic")`), and a scratch `-s` script
  keeps its screen variables untyped (`var duel = load(...).instantiate()`).
  The soak is the gate that catches it: run it after touching a screen.
- Cite CR (Comprehensive Rules) numbers in comments for rules behavior —
  existing code shows the style.
- Reference implementations for tricky cards/rules: the mage-go clone
  (search its `cards/` by card name) and s30 for UI/adventure design.
  Forge (`../forge`, GPL-3.0) for AI reads and card decompositions —
  read through `docs/forge/`, whose notes pin every pointer to one
  commit; a ported mechanism carries a `[forge]` marker at the site
  naming file, lines and commit, never a card name or a random roll.
- `docs/player-files.md` is the player-facing map of every path the
  BUILT game reads or writes — decks, portraits, the imported skin, card
  art, settings, logs — and the search order when a name exists twice.
  Update it when a new one appears.
- `Provenance.md` (repo root) is the register of every source, which one
  outranks which, and the rules for reading them — including the ones
  that have already cost this project time: `Program/UIStrings.txt` is
  latin-1 so `grep` needs `-a` or it prints NOTHING; always the
  `Program/` copies of the string tables; a `.bmp` in a Manalink install
  is never a 1997 file. Read it before citing a source.
