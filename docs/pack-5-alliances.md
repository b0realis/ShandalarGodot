# Pack 5 — Alliances

`Pack-5-Alliances.zip` completes the June 1996 Alliances set as an optional,
independent expansion. **199 published printing records, 144 distinct names,
144 new rules identities, no reprints of the preceding pool.** The original
1997 pool remains 897 names. Core + Pack 5 is 1,041 names; all five packs
together expose **2,004 named set entries · 1,608 unique cards**.

Only the construction source, reviewed metadata/rules and original UI symbols
are distributed. The generated ZIP and downloaded card pictures remain local.
The first compatible game build is **0.21.0**; this work does not publish a
new release or change the existing 0.20.0 release.

## Construct and install

From the project root, with Python 3, network access and source matching
the game version you will run:

```sh
python3 tools/pack_5_alliances.py fetch-art
python3 tools/pack_5_alliances.py build
python3 tools/pack_5_alliances.py verify
```

`python3 tools/pack_5_alliances.py fetch` is the maintainer's catalogue-refresh
command. It changes trusted source metadata: review any upstream Oracle/data
changes and rebuild the matching game, rather than refreshing that snapshot
under an older installed executable. Ordinary local construction uses the
checked-in snapshot and does not require `fetch`.

The default ZIP is `../shandalar-packs/Pack-5-Alliances.zip`; the resumable art
cache is `../shandalar-packs/cache/pack_5_art/`. Supply a positional output
path and `--art-dir` to change those locations. The builder selects one
representative printing per name, fetching its **art crop and full card scan**:
288 physical image files, stored under 576 namespaced/fallback ZIP entries.
Together with four metadata entries, the ZIP has 580 entries. All 199 printing
records are retained in source metadata, but alternate illustrations are not
all downloaded. Two image forms do not mean two playable copies of a card.

Use **Options → Card Packs → Open Folder**, put the exact-named ZIP there,
then **Rescan** and enable Pack 5. Development runs may instead set
`SHANDALAR_PACK_5` to the absolute ZIP path. No preceding pack is required.
Rescan reports invalid ZIPs rather than treating them as skins. The trusted
loader checks inventory, names, metadata, version and SHA-256 artwork hashes;
the archive cannot supply executable GDScript.

The main menu shows `5-ALL`. Deck Builder **Extras** has independently
switchable 1997, tDotP, Fallen Empires, Ice Age, Homelands and Alliances rows.
Hide the other sources to see precisely 144 Alliances names. These visibility
filters do not unload a globally enabled pack or edit an existing deck.
Decks stay name-based and record required packs; loading while disabled offers
the enable flow. The gold forked-banner card emblem and stone medallions are
original procedural assets matching the existing strip.

## Engine review

Every unique name has a trusted definition in `cards/sets/all/`, with shared
families in `_basic`, `_spells`, `_resources`, `_triggers`, `_combat`, `_worlds`,
`_auras_costs`, `_choices` and `_links`. The catalogue test refuses any pending
rules guard. Important additions and reused mechanisms include:

- Alternative pitch payments, preserving printed mana value and taxes;
  another eligible card is exiled before the spell reaches the stack.
- Library-exile activation costs; independently chosen, disjoint object
  costs; enchanted-creature tap costs; immediate hand mana from Spirit Guide.
- Entry sacrifices before battlefield arrival; cumulative upkeep paid with
  life, library cards or opponent tokens; reflexive upkeep-failure triggers.
- Exact mana-value X removal, X land tapping, extra colored target costs and
  repeatable additional payments. Payment receipts record actual resources.
- Divided counters, cleanup actions, tracked prevention, actual regeneration
  rewards, delayed draws, combat-life-loss substitutions, blocking taxes,
  graveyard order, incarnation-safe links and face-down owner-only inspection.
- Portal's opponent-visible piles and caster-blind selection, Vault's paid
  repeated five-card look, library selection, milling and reanimation.

The bug-fix pass reproduced and corrected Thought Lash's missing unpaid-upkeep
trigger, duplicate tapping rewards from regenerating an already tapped Steam
Beast, a cross-graveyard Bauble target list, exact-X Shaman targeting, unforced
blocking costs under Lure, and AI sacrifice selection that could throw away
Lord of Tresserhorn instead of expendable creatures.

A later full-duel failure exposed a repeatable Gorilla/Gargoyle cycle: the AI
kept tapping its fighter to kill a creature guaranteed to return, while draw
skips and Digger recycling prevented either side from making progress. Public
death-return metadata now discounts that kill outside combat; the policy also
preserves a precombat attacker against low-value targets. The same Fifth
Edition seed, 157079, now completes in 82 turns. This is a tactical fix, not a
turn-limit increase. Cross-pack redirection handling also now ignores player
targets when a creature-only evaluator is examining Martyrdom's broader shape.

### Explicit digital adaptations

Five cards have two documented timing adaptations, also printed on their
digital rules text, in the manifest, Help and [the ledger](simplified-cards.md):

- **Fatal Lore, Library of Lat-Nam, Misfortune:** the opponent selects the
  mode on resolution. Fatal Lore also selects its creatures then, with normal
  targeting restrictions. Players cannot respond knowing that choice in
  advance; the opponent gets later information than under announcement timing.
- ~~**Bounty of the Hunt, Thawing Glaciers:** counters expire / the land returns
  at cleanup, not the end step, but without an additional response window.~~
  LIFTED by Pack 8 (engine package E3): "at the beginning of the next cleanup
  step" is now a delayed trigger on the stack after the discard and the damage
  removal, with priority and a further cleanup step (CR 514.3a/b) —
  `tests/unit/test_pack_8_e3_flash_cleanup.gd`.

## AI review

`_effect_shapes.gd` describes public effect roles. `alliances_tactics.gd`
uses the existing `forecasts_tactics` capability gate and leaves unrelated
roles to their prior readers. Difficulty presets are unchanged.

The policy prices pitched cards and life, saves mana where appropriate,
counters lethal spells while tapped out, allocates divided removal, uses
Bounty and Scars to save creatures/life, sizes Shaman/Dam/Helm activations,
uses Browse and other resource engines, budgets library fuel, handles object
costs, evaluates favorable fights and preserves valuable sacrifice fodder.
Focused tests exercise actual actions, an off/null arm and hidden-information
permutations. Unknown library order and opponent hands are never searched to
predict outcomes. Authorized search/inspection prompts expose only their
offered cards; they are not a planning shortcut.

This is tactical integration, not a claim of perfect play. Random top-card
pumps are treated conservatively, selective Undergrowth is not valued as a
blanket Fog, and complex multi-turn combo/hidden-pile strategy remains limited.
Costly sacrifice/untap mana abilities remain explicit choices rather than
being counted as free mana by the automatic tapper.

## Reproduce the checks

Use the repository's isolated profile, never the player's settings or decks:

```sh
SHANDALAR_TEST_DATA_HOME=../shandalar-build/pack-5-work/test-data ./run_tests.sh
python3 -m unittest discover -s tools -p 'test_*.py'
git diff --check

. tools/runtime.sh
shandalar_find_godot
shandalar_find_timeout
shandalar_test_profile
export SHANDALAR_PACK_5="../shandalar-packs/Pack-5-Alliances.zip"
"$SHANDALAR_TIMEOUT" -k 5 900 "$GODOT" --headless --path . \
  --script res://tools/pack_5_duel_audit.gd -- --rounds 10 --seed 57000
"$SHANDALAR_TIMEOUT" -k 5 900 "$GODOT" --headless --path . \
  --script res://tools/pack_5_ui_soak.gd -- --rules modern --count 3 --mode both --pace 0
# Repeat with --rules fifth; also run the stock tools/duel_soak.gd.
```

The audit uses nine 60-card themed decks and both rulesets, reporting actual
casts/activations rather than equating loading with play. The UI harness runs
the real DuelScreen and its demo/fuzzed-human paths.

The separate `tools/pack_5_deck_lab.gd` wrapper enables only Pack 5 in memory,
requires the isolated test feature, forces `--no-elo --procs 1` and supports
normal threaded `--jobs` and matched candidate/null/control sweeps.

```sh
"$SHANDALAR_TIMEOUT" -k 5 900 "$GODOT" --headless --path . \
  --script res://tools/pack_5_deck_lab.gd -- \
  --deck-a /absolute/path/all-blue.deck --deck-b /absolute/path/all-red.deck \
  --games 200 --jobs 4 --seed 58000 --sweep forecasts_tactics=on,off \
  --control-deck-a big_green.deck --control-deck-b white_knights.deck \
  --no-elo --out /absolute/path/results-blue

./build_release.sh --macos --out ../shandalar-build/pack-5-macos
# With the real ZIP in SHANDALAR_PACK_5 and an isolated profile:
../shandalar-build/pack-5-macos/Shandalar.app/Contents/MacOS/Shandalar \
  --headless -- --verify-pack-5
```

The exported probe checks 144 dormant scripts, all 288 decoded images, three
UI textures, payment modes and AI metadata. A source-scene screenshot does not
replace that exported-binary check. See [adding-card-packs.md](adding-card-packs.md)
for the full future-pack workflow, including negative tests and provenance.

## Acceptance record — 2026-09-16

Final full GUT gate: **6,857/6,857 tests / 270,559 assertions / 412 scripts**,
passing in 316.875 seconds, strict wrapper exit 0 (`gut-final.log`). No parse
errors, skipped scripts, failing tests or leaked-object exit warnings. The
final focused ledger check also passes all ten tests (`ledger-final.log`).

Focused Pack 5 gate: **68 tests / 1,321 assertions / eight scripts**, all
passing in 11.667 seconds. Python: **256 tests**, one platform skip. The final
in-engine campaign completed **180 full duels**, 90 per ruleset, using seeds
57000–57089 and 157000–157089 with no stalls or engine errors. Actual actions
include 52 Force of Will casts, 40 Pyrokinesis casts, 45 Bounty casts, 67 Scars
casts, 51 Browse activations and 37 Gorilla fight activations.

The two matched Wizard studies used 200 games per arm, three arms per pair,
and a stock-deck control pair: **2,400 games total**, with no stalls or draws.
Only seat A's `forecasts_tactics` gate varied; the off candidate repeats the
off/null arm. Both Big Green / White Knights control studies replayed every
game byte-identically, not merely with the same win totals. No Elo was written.

| Study | Seed | Off/null | On | Difference, reported 95% margin |
|---|---:|---:|---:|---:|
| Alliances blue / red | 58000 | 15/200 (7.5%) | 28/200 (14.0%) | +6.5 ± 6.1 percentage points |
| Alliances green / red | 59000 | 60/200 (30.0%) | 63/200 (31.5%) | +1.5 ± 9.0 percentage points |

The blue result narrowly clears zero in this sample; green is inconclusive.
These intentionally narrow study decks are not tournament recommendations,
and the results do not establish a universal strength improvement.

Reconstruct the named 60-card `.deck` fixtures with 24 of the indicated basic
land and four of each of the following nine names (one `count name` per line):

- `all-blue`: Island; Storm Crow, Force of Will, Arcane Denial, Browse,
  Benthic Explorers, Spiny Starfish, Phantasmal Sphere, Lat-Nam's Legacy,
  Phyrexian War Beast.
- `all-red`: Mountain; Gorilla Shaman, Pyrokinesis, Pillage, Balduvian Horde,
  Lightning Bolt, Storm Shaman, Guerrilla Tactics, Gorilla War Cry,
  Phyrexian War Beast.
- `all-green`: Forest; Elvish Spirit Guide, Elvish Ranger, Kaysa, Deadly Insect,
  Giant Growth, Nature's Chosen, Gorilla Chieftain, Bounty of the Hunt,
  Phyrexian War Beast.

An intermediate run with a misspelled ability-property access was rejected
despite Godot continuing to print duel results; it is not counted above. The
final campaign's strict wrapper checks error and leak output as well as the
exit code. The full suite also caught missing per-card simplification markers:
the five adaptations already had shared-handler/player-text and ledger entries,
but their individual card headers needed the same explicit marker. Only these
comments and trailing-blank-line formatting changed after the final campaigns;
no gameplay behavior changed. Evidence is local under
`../shandalar-build/pack-5-work/`:
`focused-final.log`, `python-final.log`, `duels-final.log`, and the `lab-blue/` and
`lab-green/` reports, CSVs and per-game fingerprints.

All **24 real-screen UI soak duels** completed: six pack and six stock games
per ruleset, each split between demo and fuzzed-human play. Seeds were 1000,
1037 and 1074, with zero errors, leaks or stalls. These renderer-free scene
runs are supplemented by native Mac viewport captures of the real menu,
Extras, filtered collection/Force of Will preview, Options and final Help
page at 1280×800. All five packs were enabled only in memory for the captures;
the player's saved pack selection was not changed. A separate 800×600 native
capture confirms all six Extras rows and Close fit without clipping.

A fresh **0.21.0 macOS debug export** at `../shandalar-build/pack-5-macos/`
smoke-booted and passed the real-ZIP probe: **144 dormant scripts, 288 decoded
artwork images, three UI textures**, two Force of Will payment modes, Browse's
public AI metadata and zero pending rules. The same executable also passed
the Homelands real-ZIP probe (115 scripts, 230 images, three textures).
The temporary separate-profile override was removed and the app's ad-hoc
signature passed `codesign --verify --deep --strict`. The pack ZIPs were not
placed in the bundle. This establishes local macOS export support, not a new
release, notarization or Windows/Linux/Web export certification.

The ordinary player's `settings.cfg` stayed byte-identical throughout.
Export evidence: `build-macos.log`, `export-pack5-probe.log` and
`export-pack4-probe.log` under the same local audit directory. Only source,
metadata, tests, documentation and original UI icons are intended for Git;
generated ZIPs, downloaded artwork, captures and logs stay local.
