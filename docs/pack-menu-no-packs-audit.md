# Main-menu pack layout and no-pack audit

2026-09-16, development version 0.21.0. This is a source/UI repair, not a
release or a change to the rules engine, AI policy or pack contents.

(2026-10-27: a dated record — "five packs" and the 1,608-card inventory
below are the 0.21.0 numbers. There are nine packs now, 3,093 unique cards
with all of them enabled; the grid's five columns (`CardPackBadges.COLUMNS`)
put Packs 6 to 9 on the second row this audit designed for.)

## Layout

Numbered packs now occupy their own left-aligned grid beneath the original
eight-set plaque. Buttons keep their existing artwork, 72×38 size and
enabled/disabled indicators. Five columns with 6 px gaps cap the current
row at 384 px; a sixth button starts another row instead of approaching
the main menu. With no available packs the grid is hidden and consumes no
height or gap. Disabled but installed packs remain visible.

Native rendered source-scene captures verified all five packs at 1280×800
and 800×600, Pack 1 alone, and no packs. At 1280×800 the original plaque is
at (10,709), size 340×39, and the five-pack row at (10,754), size 384×38.
With no packs the plaque returns to (10,753); there is no empty second row.
These captures stage availability in memory and use the original skin;
they do not move ZIPs, edit player preferences, or claim to photograph an
already-running game. Actual absent-file startup was checked separately
in the desktop export below.

## Reproduced defects and repairs

The initial nine-test audit passed only four tests. Evidence is in the
local `pack-menu-audit/repro.log`:

- Five badges extended sideways to x=742 instead of staying in the left
  corner; a sixth did not wrap. The original HBox is now a vertical group
  containing the original plaque and a five-column pack grid.
- A menu created with no available packs never gained its badge row on
  Rescan; its card count also stayed stale. The row remains alive but
  hidden, and both badges and count subscribe to `rescanned`.
- An open Deck Builder retained its 1,608-card inventory after removing
  all packs. It now refreshes on `rescanned` as well as enable/disable.
- Card Packs' Back button targeted nonexistent `game/options.tscn`.
  It now returns to `game/options_screen.tscn`.

A tenth regression then reproduced stale current-deck/sideboard faces,
preview and legality after pack removal (`deck-refresh-repro.log`). Registry
changes now rebind these views too, preserving the name-based deck. The
focused final run passes all 10 tests / 108 assertions; restoration from
proxies to real cards is covered as well as disappearance.

## No-pack behavior

- The catalogue contains the original **897 named cards** and eight sets.
  No new pack-only names or numbered-pack artwork leak into the pool.
- The title reports `897 cards`, with no pack buttons or reserved blank row.
- Options → Card Packs still explains each missing ZIP by filename and
  `not found`; its enable/disable buttons are unavailable.
- Deck Builder starts with the original 897-card inventory. Extras keeps
  the 1997 visibility control usable; each absent pack has On disabled and
  Off selected. Source visibility remains distinct from global enabling.
- Saved enabled preferences may survive a temporarily absent ZIP, but do
  not make that pack effectively enabled or register any of its cards.
  Returning a valid ZIP and rescanning restores the saved selection.
- Loading a deck that requires a missing pack explains the missing file.
  Enable is unavailable; the player can cancel or explicitly load proxies.
  Merely opening this warning cannot replace the current deck. Main-deck
  and sideboard names and required-pack metadata survive the proxy path;
  unresolved proxy decks cannot enter a duel.
- All **157 original 1997 decks** load without missing-card errors.

## Verification and evidence

Persistent regressions live in `tests/ui/test_pack_menu_absence.gd`, alongside
the updated `tests/ui/test_card_pack_badges.gd` layout contract. The isolated
tests replace discovered availability in memory, restore it after every
test, and never move the player's actual ZIPs.

Commands run from the project root:

```sh
./run_tests.sh -gselect=test_pack_menu_absence.gd
./run_tests.sh
python3 -m unittest discover -s tools -p 'test_*.py'
./build_release.sh --macos --out ../shandalar-build/pack-menu-macos
```

Final full regression: **6,867/6,867 GUT tests / 270,667 assertions / 413
scripts**, strict wrapper exit 0 in 316.308 seconds. Python: **256 tests**,
one platform skip, exit 0. The existing suite/framework warnings are not
represented as a warning-free run; the strict error, skipped-test and
exit-time leak gates all passed.

The fresh desktop app was started with a temporary, separately named
`Shandalar No Packs Audit` profile, no explicit pack environment paths,
no numbered ZIPs in its discovery locations, and no imported skin.
A disposable external autoload probe inspected the real exported scenes,
pressed Back, opened Extras, checked registry membership and loaded all
157 original decks. It passed with no error/leak output. The macOS debug
template ignored external `--script`; that marker-less attempt is **not**
counted as a probe pass. The temporary autoload was removed before running
the exported game's ordinary `--deck-lab` entry point.

That same no-pack export completed **12 full stock-deck games**, six per
ruleset: Big Green versus White Knights, Wizard pilots, two workers,
`--no-elo`, Modern seed 61000 and Fifth Edition seed 62000. Both runs had
zero stalls and no error/leak output. This is a base-game smoke check, not
an AI-strength measurement or an exhaustive gameplay campaign. Each run
used this invocation with its ruleset, seed and separate output directory:

```sh
timeout -k 5 120 "$APP/Contents/MacOS/Shandalar" --headless \
  --log-file "$EVIDENCE/duel-engine.log" -- --deck-lab \
  --deck-a big_green.deck --deck-b white_knights.deck \
  --games 6 --jobs 2 --rules modern --seed 61000 --no-elo \
  --out "$EVIDENCE/no-pack-duels-modern"
```

The temporary profile override was then removed; the app passed
`codesign --verify --deep --strict`. The player's real settings file remains
byte-identical to its pre-audit hash. No real pack ZIP was removed, no
ratings were written, and no release was published.

Local evidence is outside Git under `../shandalar-build/pack-menu-audit/`:
`focused-final.log`, `gut-final.log`, `python-tests.log`, `build-macos.log`,
`no-pack-export-autoload.log`, the native `menu-*.png` images and capture
logs, and the no-pack duel reports. No downloaded artwork or generated
pack ZIP is committed or published.
