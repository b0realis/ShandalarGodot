# Contributing to Shandalar

The development and contribution guide for ShandalarGodot, a GPL-3.0 remake
of MicroProse's 1997 *Magic: The Gathering*. Checked against **0.60.12** on
**2 November 2026**. The version in `project.godot` is authoritative;
published downloads can lag behind `main`.

Start here for setup, tests and contribution rules. Use the
[architecture](docs/ARCHITECTURE.md) for design, the
[code map](docs/CODE_MAP.md) to locate a file or class, and
[provenance](README.md#provenance) before drawing conclusions from reference games.

- [Get it running](#get-it-running)
- [Source layout](#source-layout)
- [Hard rules](#hard-rules)
- [Making and measuring a change](#making-and-measuring-a-change)
- [Commands and tests](#commands)
- [Safe Godot runs](#commands-that-can-hang)
- [Skins, card art and paths](#skins-card-art-and-paths)
- [Gotchas](#gotchas)
- [Publication](#publication)
- [Current scope and further reading](#current-scope-and-further-reading)

## Get it running

Use **Godot 4.7.2**, Bash and GNU `timeout` (`gtimeout` also works; on macOS,
`brew install coreutils`). Packaging tools require **Python 3.10+**. Most
Python tools use the standard library; skin upscaling additionally needs
Pillow and a Real-ESRGAN runtime. Browser tests need Node, Playwright and a
browser. Read each tool's help for its own dependencies.

Run commands from the directory containing `project.godot`.
The root keeps three entry points: `shandalar.sh` for the tool dispatcher,
`build_release.sh` for builds and `run_tests.sh` for the test gate. Supporting
scripts and the agent play guide live in `tools/`; Deck Lab's own launchers
stay with its implementation in `DeckLab/`.
`tools/runtime.sh` provides common runtime discovery:

- Linux prefers the sibling `../tools/godot`, then `godot` on `PATH`.
- macOS prefers `../tools/Godot.app/Contents/MacOS/Godot`, then `godot` on
  `PATH`, then the sibling binary if no command is available. Check that
  the sibling binary is native to the Mac.
- An explicit `GODOT` overrides discovery. A missing explicit binary is an
  error (exit 3), never an invitation to substitute another engine.

The sibling tools directory is outside this repository; it is different
from the tracked `tools/` directory. In a worktree, set the binary explicitly:

```sh
export GODOT=/path/to/Godot
"$GODOT" --version
"$GODOT" --editor --path .
```

Open the project and run it in Godot. An ordinary development run shares
its player profile with the installed game; use the isolation recipe below
for scripted probes. The game runs without imported art or a skin.

For exports, copy `export_presets.cfg.example` to the ignored
`export_presets.cfg` and configure the official export templates and local
paths. Follow [release builds](docs/release-builds.md) for the target matrix,
signing, packaging and verification. Export templates are not needed for
normal editor play or headless engine tests.

Keep shared code portable across Windows, Linux, macOS and Web. Handheld
and Android targets have their own packaging requirements. A successful
cross-export is not a native runtime test; Web must also run in a browser.

## Source layout

| Location | Purpose and boundary |
|---|---|
| `engine/` | Pure, headless MTG rules, card registry and computer players. `MtgGame` is the mutation surface. No dependency on `game/`. |
| `cards/` | Card scripts composed from engine effects and abilities, plus catalogue data. Core sets load by default; numbered-pack implementations activate only with validated, enabled packs. ZIPs never supply executable card scripts. |
| `game/` | Godot scenes and presentation: adventure, duels, deck builder, help, input, skins, LAN play and records. May use the engine and cards. |
| `DeckLab/` | Headless duel simulation and experiments using the rules and card registry. No dependency on game scenes or a renderer. |
| `decks/` | Bundled deck lists grouped by provenance, plus the committed `ratings.txt` ledger. [Deck provenance](docs/decks-1997.md) explains the groups. |
| `tests/` | GUT regressions and shared fixtures. `tests/game_test.gd` supplies the `GameTest` harness. |
| `tools/` | Build, import, packaging and measurement tools. Excluded from the game PCK; approved player tools are copied beside packaged games. |
| `addons/gut/` | Vendored test framework. Keep framework changes separate from game changes. |
| `assets/` | Local imported 1997 material and card art; not tracked. A fresh clone or worktree has none. |
| `docs/` | Design, authoring guides, audits and release records. Use the code map rather than keeping another file census here. |
| `branding/`, `pages/` | Project artwork and screenshots; the public getting-started site. |

## Hard rules

The rule numbers below are stable: source comments cite them.

1. `engine/` and `cards/` stay pure: RefCounted only — never Node, scenes,
   Input, or anything from `game/`. They must run headless.
2. All game-state mutation goes through `MtgGame` helpers. Never move cards
   between zone arrays or change life, damage or characteristics elsewhere.
3. Action methods return `""` on success or a human-readable refusal string.
   Player-level mistakes never assert or throw.
4. One card per file in `cards/sets/<set>/`; filename = snake_case card name;
   no `class_name` on card files. The header gives the name/cost/type, exact
   Oracle text and implementation notes. Follow [adding cards](docs/adding-cards.md),
   including its test-first rule.
5. Rules code reads live characteristics: `cur_power`, `cur_toughness`,
   `cur_keywords`, live types and colors. Printed `data.power` and similar
   fields do not describe a permanent after effects have changed it.
6. Every rules shortcut has a `SIMPLIFIED` comment at the implementation
   and a matching entry in [simplified cards](docs/simplified-cards.md)
   (card-scoped) or [the roadmap](docs/ROADMAP.md) (engine-wide).
   The card-scoped form is `SIMPLIFIED (docs/simplified-cards.md, "Name"):`.
   `tests/test_simplified_ledger.gd` checks the correspondence. When lifting
   a shortcut, remove both marker and entry and add a regression for the
   complete behavior. New files and classes get a row in `docs/CODE_MAP.md`.
7. Duel-engine randomness goes through `MtgGame.rng`. Preserve deterministic
   replay of the same seed and action sequence.
8. Fair information is mandatory at all four standard difficulties.
   Strategy may read its own registered deck and hand, public state, and
   choices or reveals that a rule permits. Never inspect the opponent's
   hidden hand or face-down identities, either library's secret order, or
   RNG state to choose a move. This includes proposal generation,
   evaluation, cache keys, speculative search and card-authored hints.
   Add hidden-state substitution tests and public-change controls; see
   [fair play](docs/fair-play.md) and `tests/ai/test_ai_fair_planning.gd`.
   Only the separately constructed, explicitly opt-in `UnfairPlayer`
   challenge may read the opponent's current hand. It is not an `AiProfile`
   override or a global reveal; other information boundaries still apply.
   Its runs are labeled and excluded from fair sweeps and Elo.

Treat `CardData` and its composed ability/effect objects as shared,
immutable definitions. Mutating an ability in a test changes it for later
users of that registry entry. Replace instance lists with copied abilities
when needed; `ActivatedAbility.shallow_copy()` and `discounted()` support
this pattern.

**No `static var` may hold a `CardData` or `CardInstance`.** Their Callables
can outlive the scripts they reference during shutdown and corrupt the
heap. Cache names or instance IDs instead. The `Lifecycle` autoload settles
`ScreenWarmup` loads and clears the registry before shutdown; preserve that
ordering. `CardRegistry.ensure_loaded()` joins an in-progress registry build.

## Making and measuring a change

### Fidelity and reproduction

Read [provenance](README.md#provenance) first. Original 1997 artifacts outrank the
decompilation, which outranks reimplementations. Label sourced behavior
`[1997]`, deliberate conveniences `[QoL]`, and borrowed mechanisms `[s30]`
or `[forge]` as appropriate. Cite Comprehensive Rules numbers for rules
behavior. Forge citations name the source file, lines and pinned commit;
[the Forge notes](docs/forge/README.md) record the reference revision.
Local code references should use symbols or headings rather than fragile
line numbers.

Older source comments and dated audits cite the former `Provenance.md`.
Its full text is preserved in the [historical source audit](https://github.com/b0realis/ShandalarGodot/blob/04305db4599868acdcc8c84b698982188c9e4030/Provenance.md),
also available locally with `git show 04305db4:Provenance.md`. Keep new
source citations at the implementation site and in the relevant design or
asset inventory; the README holds only the short overview.

Reproduce a reported defect before changing behavior. Use a focused test,
a seeded simulation or a bounded live probe, and record the decisive output
with its setup. If it does not reproduce, say so and record what was tried;
do not add a speculative mechanism just to close the report.

For a card change, read [adding cards](docs/adding-cards.md), write its
regression first, then implement with existing effects. Cover targeting,
timing, resolution and relevant interactions. A missing reusable mechanic
belongs in `engine/` with its own tests. Setup helpers in
`tests/game_test.gd` may construct otherwise unreachable states; the action
under test uses the public API and checks its refusal or success.

Update the code map when adding or moving files/classes, the
[mechanics catalogue](docs/mechanics.md) for new mechanics, and
[player files](docs/player-files.md) when adding a persistent path. For a
numbered pack, use [adding card packs](docs/adding-card-packs.md).

### Computer-player changes

Read [AI difficulty](docs/ai-difficulty.md), [fair play](docs/fair-play.md)
and [Deck Lab](DeckLab/README.md) before changing decisions. New strategy
capabilities get named `AiProfile` fields, so experiments can disable them
exactly. Difficulty progression must remain monotone; do not introduce a
second hidden difficulty system. Basic correctness applies at every rung.

Measure a capability with a seeded Lab sweep: candidate, null and an
unaffected control pair. The control must reproduce its own null game for
game; `--sweep` exits 4 if it does not. The new off arm must also reproduce
the pre-change null. Choose control decks on which the capability cannot
fire, and follow the worked sweep examples in the Lab manual.

Report the commit, seed, decks, rules, profiles, enabled packs, game count
and command with every result. Jobs must not change the games simulated.
Use the Lab's Wilson intervals, play/draw split and paired outcomes; a
percentage without its seed cannot establish an improvement.

A statistical wash can justify a switchable fix for a visible malfunction;
state that claim separately from strength. A constant with no null needs
stronger evidence. Read previous measurements before revisiting a refused
idea. A measured rejection is a valid outcome, not unfinished work;
[the closed AI plan](docs/AI-next-wave.md) contains examples.

**Experiments must use `--no-elo` or a scratch `--elo-file`.** A normal Lab
run updates the tracked `decks/ratings.txt`, so replaying the same seed can
count the same games twice. Sweeps disable Elo themselves. Use the
[tool interface contract](AGENTS.md) for machine-readable output, exit
codes, resume behavior and the MCP interface.

## Commands

### Test scope

During development, run focused tests for the changed behavior and its
immediate interactions. Reserve the full suite for release preparation or
an explicit request. Use visual checks for presentation changes and a
bounded duel soak when live duel flow needs coverage; cosmetic edits do
not automatically require a soak. Report exactly what was checked.

**Never edit source files or `run_tests.sh` while a suite is running.**
Bash reads the script as it runs, and Godot workers must see one source tree.

```sh
./run_tests.sh -gselect=test_simplified_ledger.gd
./run_tests.sh -gselect=test_simplified_ledger.gd -gunit_test_name=TEST_NAME
./run_tests.sh -gdir=res://tests/cards
python3 tools/test_tracked_tree.py
```

Replace `TEST_NAME` with an actual test method. A `-gdir` or `-gtest`
selects only that scope, rather than adding the entire suite. Scratch
`tests/_hunt/` probes are excluded from whole runs and must be selected
explicitly. Permanent assertion-free benchmarks do not belong in `tests/`.

For release preparation:

```sh
./run_tests.sh
python3 -m unittest discover -s tools -p 'test_*.py'
```

`SHARDS=N ./run_tests.sh` distributes a whole run over processes. Linux
uses half the cores, clamped to 1–6, by default. macOS defaults to one
because processes share the integration-test profile; keep its runs
sequential. Targeted selections run in one process. `SHARDS=N SHARD=i`
selects one CI shard. The runner checks the expected script counts as well
as individual results. Current CI configuration is in
[gate.yml](.github/workflows/gate.yml): pushes to `main`, pull requests and
manual runs use four Linux GUT shards, Python tests, boot and offline-Web
checks. Local test-scope policy does not reduce CI coverage.

**Trust the runner's exit status, not GUT's printed summary.** GUT can skip
an unparseable script and still print success. The wrapper also rejects
parse/compile errors, missing test bases, `ERROR:`/`SCRIPT ERROR:` output,
risky or pending tests, leaked objects and nonzero engine exits. A shutdown
SIGABRT is a failure, not renderer noise. `SUITE_TIMEOUT` defaults to 1800
seconds; CI can override it.

Tests requiring the imported 1997 skin must carry
`## Needs the imported 1997 skin` on their first doc line. Without that
skin, the runner excludes those scripts by name and reports the exclusions.
A green art-free run does not verify them. Do not copy historical test
counts or timings into a current guarantee.

### Live and browser checks

`./tools/duel_soak.sh` drives complete duels through the real screen, under Xvfb
on Linux or a native Mac window. Select relevant seeds, modes and rules;
`--rules fifth|modern` forces the corresponding rules answers rather than
reading player settings. This `modern` mode is not the fresh-install
preset: it disables mana burn and enables waiting sacrifice clauses.

A soak needs `SOAK done` and no `ERROR`/`WARNING`/`STALL` line. Exit 2 means
a stalled or unstarted duel; 3 a bad argument; 124 timeout (137 after a
forced kill); 130 interruption; 1 other rejected output. See its help for
run limits and selection options.

After changing offline-Web code or packaging, run:

```sh
node tools/test_web_offline.cjs
```

It needs Node, Playwright and Chrome; `--channel chromium` selects
Playwright's Chromium. Before publishing, also test a cold offline start of
the actual package as described in [release builds](docs/release-builds.md).
A service-worker test alone does not prove that the game starts a duel.

### Profile isolation

The suite and soak call `shandalar_test_profile` from `tools/runtime.sh`.
On Linux it redirects `XDG_DATA_HOME` to
`${SHANDALAR_TEST_DATA_HOME:-${TMPDIR:-/tmp}/shandalar-test-data}`. It also
sets the `shandalar_test` feature. **macOS ignores XDG:** that feature selects
`~/Library/Application Support/Godot/app_userdata/Shandalar Integration Tests/`
before autoloads start. A different scratch directory alone does not create
a different Mac profile. Run settings-dependent suite/soak work sequentially.

Manual probes must opt in too. Use a subshell so the test feature cannot
leak into later export commands. This bounded boot smoke checks project
loading after card changes; inspect its log as well as its status:

```sh
(
  set -e
  . tools/runtime.sh
  shandalar_find_godot
  shandalar_find_timeout
  shandalar_test_profile
  SCRATCH=$(mktemp -d)
  "$SHANDALAR_TIMEOUT" -k 5 120 "$GODOT" --headless --path . \
    --quit-after 3 --log-file "$SCRATCH/engine.log" \
    > "$SCRATCH/boot.log" 2>&1 </dev/null
  cat "$SCRATCH/boot.log"
)
```

Keep the logs needed for diagnosis, then remove the scratch directory.
Never export with the test-profile feature enabled.
Some tool help, including `duel_soak.sh --help`, starts Godot to print its
usage. Apply the same profile, timeout and logging safeguards to it.

## Commands that can hang

Put the timeout directly around Godot, **inside** a wrapper such as
`xvfb-run`. Write output to a file, close stdin and never pipe a potentially
hanging Godot process into a reader:

```sh
# Linux: replace the headless command inside the isolated subshell above.
xvfb-run -a "$SHANDALAR_TIMEOUT" -k 5 120 "$GODOT" --path . \
  --quit-after 120 --log-file "$SCRATCH/engine.log" \
  > "$SCRATCH/window.log" 2>&1 </dev/null
tail -6 "$SCRATCH/window.log"
```

Use this within the same subshell, where its runtime and scratch variables
are defined. On macOS, omit `xvfb-run` and keep the timeout, log and closed stdin.
A timeout outside a spawning wrapper can kill the wrapper while its child
keeps a pipe open indefinitely. If a command takes unexpectedly long,
investigate rather than waiting without a reason.

## Scratch files

Put disposable probes and benchmarks outside `tests/`; remove them once
their question is answered. Keep useful failures as proper regressions.
Use one bounded scratch directory. On tmpfs, accumulated screenshots
consume RAM, not spare disk.

Every manual Godot probe needs an explicit `--log-file` and an isolated
profile. Otherwise it can rotate real play logs, change persisted settings
or append a scratch duel to the player's `duel_log.txt`. The suite and soak
provide these guards; a hand-written command does not.

## Skins, card art and paths

Imported 1997 material and card pictures stay out of Git.
Public packages contain no card art or generated numbered packs: they
include the tools for players to build them. Plain game packages have no
skin; `-with-skin` packages include the release's `original_skin.zip`.
The 2x skin is a separate download. See [card art and packs](docs/card-art-and-packs.md)
and [the skin catalogue](docs/skin-catalogue.txt).

Use `GamePaths` (`game/paths.gd`) for configurable folders and their
settings keys, not literal `user://` paths. Reading a default must not
persist it as a user choice. Update [player files](docs/player-files.md)
when storage or lookup order changes.

Only one skin ZIP is active at a time; its choice applies after restart.
Loose skin folders are fallbacks only when no ZIP is worn. Card packs are
separate and may be mounted together. Detect ZIP kind from its contents,
not its name. `tools/skin_catalogue.py --check` validates completeness.
The released skin comes from the 1997 game; a Manalink-derived skin marked
`from_manalink.txt` is rejected by the release builders and packager.

A high-resolution skin keeps the same filenames and logical geometry.
`GameSkin.picture` exposes the slot's original size, even when pixels are
larger. Code that cuts or examines pixels must use `GameSkin.cut`,
`texture_of`, `scale_of` and `original`, with `lift_alpha` for masks;
never call `get_image().get_region()` using unscaled 1997 coordinates.
New color-keyed cutters must also be handled by the upscaler's preservation
logic. Keep `GameSkin.SIZES` consistent with `docs/skin-catalogue.csv`;
`tools/test_skin_catalogue.py` checks this contract. Preserve `docs/.gdignore`:
otherwise Godot treats that CSV catalogue as a translation table.

## Gotchas

- GDScript inference from a Variant is an error here. For example, use
  `var x: WeakRef = weakref(g)`, not `var x := weakref(g)`. One card parse
  failure can remove much of the registered pool; run a boot smoke after
  card changes. `Color` is a Godot built-in; our enum is `Mtg.ManaColor`.
- A `-s` SceneTree script compiles before autoloads exist. Screens used by
  such tools should resolve autoloads from the tree at call time, for
  example `get_node_or_null(^"/root/ShellMusic")`. Keep scratch screen
  variables untyped if their type would pull in autoload-dependent scripts.
  `tools/test_script_entry_points.py` follows every `--script` entry
  point's `class_name`/`preload` references: a model-side script must not
  name a screen class (keep it an untyped `Node`, or `load()` it at run time).
- The duel screen coalesces engine changes into a refresh once per frame.
  UI tests must wait a frame or call `_refresh()` before inspecting it;
  drive screen AI through `_ai_step()`, not `_ais[pid].act()`.
- Fresh clones/worktrees lack ignored assets. Import or link the intended
  local assets and rerun a bounded Godot import before art-dependent
  checks. Set `GODOT` explicitly when the sibling tools path does not exist.
- Some bundled historic decks use cards outside the enabled pool. The
  proxy gate refuses unknown card names before dealing; this is not by
  itself a regression. Check the enabled packs and the Lab's proxy report
  before changing a historic list.
- Desktop exports deliberately use debug templates because optimized
  templates produced popup signal-disconnection errors with the pinned
  engine. Preserve embedded popups and do not hide engine errors with a
  GDScript workaround. `LINUX_TEMPLATE=release` is the explicit Linux
  override; changing the default needs a verified export-level fix. Web
  uses release templates. See [release builds](docs/release-builds.md).
- Reference tables can be Latin-1: use `rg --text` when searching
  `Program/UIStrings.txt`. Check it against the original tables preserved
  in `s30/assets/text/`; `Program/Text.res` contains later Manalink changes.
  A BMP in a later installation does not establish the 1997 appearance;
  genuine 1997 `Statwin/` bitmaps are an exception. The historical source
  audit linked above records the evidence and other import pitfalls.

## Publication

Every pushed change increments the **last numeric component** of
`project.godot`'s `config/version`, unless the owner explicitly directs a
different version. Group a coherent change and its verification before
pushing. Commit subjects stay short and descriptive. Use a pseudonymous
author and committer with a GitHub noreply address.

Keep personal home paths, private email addresses and local tooling
metadata out of tracked files. Machine-local tooling belongs in
`.git/info/exclude`, not shared ignore rules. Run
`python3 tools/test_tracked_tree.py`: it checks the code map and scans
published files, including binary metadata, for personal paths, addresses
and disallowed tooling references. The release packager separately guards
staged files and ZIP members with `tools/package_release.py --guard`.

The SGManalink handshake hashes the printed catalogue, protocol version,
release version and `SgCompatibility.RULES_REVISION`. A version bump already
separates builds. If engine/card behavior changes between local builds of
the same version, bump `RULES_REVISION`. This is compatibility detection,
not identity authentication or proof that an executable is trusted.

New command-line tools answer `-h`/`--help` and `--version`. The shared helper
reads `project.godot`; packaged MCP also reads the generated `VERSION.txt`.
Never maintain a separate version constant. When the version is unavailable,
report it as unknown and identify the searched location. Shared banners write only to
terminal stderr, never machine-readable stdout. Respect
`SHANDALAR_NO_BANNER=1` and `NO_COLOR=1`; Deck Lab also supports
`DECK_LAB_NO_BANNER`. See `tools/test_tool_banner.py`.

Building locally and publishing a release are separate actions. Do not
create or replace releases unless requested. Follow
[release builds](docs/release-builds.md) for the full matrix, shared skin,
checksums, privacy guard, signing and native/browser checks. Keep local
verification logs outside downloadable packages and state which targets
were only cross-exported.

## Current scope and further reading

Adventure is implemented and playable through the ending; work now includes
playtesting, fidelity and robustness. Campaign card selection offers every
installed pack from Pack 2 to Pack 10 (Pack 1 never); the rules a pack's cards
follow there are in
[the card economy audit](docs/adventure-card-economy-audit.md#card-packs-and-the-main-game).
All ten optional packs are implemented for ordinary duels.
Do not describe source-only additions as already published.

Duel rules forks live in `engine/rules_options.gd`. A fresh player profile
uses **Modern rules, mana burn on**. All presets keep
`sacrifice_clauses_wait` off; enabling it is a custom mix. Bare engine
defaults and the soak's `--rules modern` are different contexts, so tests
must choose their rules explicitly. Campaign card-acquisition rules are a
separate setting; see the [card-economy audit](docs/adventure-card-economy-audit.md).

General CR 613.8 dependency analysis remains incomplete. The current
implementation orders land-type writers before readers, then orders readers
by their dependencies, breaking cycles by timestamp. It does not detect
all dependencies between arbitrary continuous effects. See
`ContinuousEffects._ordered_readers` and the `SIMPLIFIED` entry in
`engine/continuous.gd` before extending this machinery.

Use these references for the detail rather than duplicating it here:

| Working on | Read |
|---|---|
| Rules or a card | [Mechanics](docs/mechanics.md), [adding cards](docs/adding-cards.md), [simplifications](docs/simplified-cards.md) |
| Card packs | [Pack authoring](docs/adding-card-packs.md), [LAN pack integration](docs/packs-sgmanalink-integration.md) |
| Adventure | [Implementation record](docs/adventure-implementation-notes.md), [world-building research](docs/world-builder-adventure-notes.md) |
| Computer play and experiments | [Fair play](docs/fair-play.md), [difficulty](docs/ai-difficulty.md), [Deck Lab](DeckLab/README.md) |
| Tools or MCP | [Programmatic interfaces](AGENTS.md) |
| Duel presentation | [Duel-screen design](docs/duel-screen-design.md), [card states](docs/card-states.md) |
| Platform builds | [Release procedure](docs/release-builds.md), [handhelds](docs/handhelds.md), [Android](docs/android-experimental.md), [Web](docs/setup-web.txt) |
| Historical decisions | [Roadmap](docs/ROADMAP.md), searched by topic/date; dated audits record measurements, not current guarantees |
