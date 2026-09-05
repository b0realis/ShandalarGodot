# Deck Lab — headless deck testing

The Deck Lab plays AI-vs-AI duels **headless** (no graphics, text output)
at arbitrary scale — 10,000-game matchups are its designed workload — and
reports statistically honest results with chart output. It exists for the
community: testing a brew against a known deck, or against a whole
gauntlet of styles, on every CPU core the machine has.

```
DeckLab/deck_lab.sh --deck-a my_brew.deck --deck-b black_red_raiders.deck --games 10000
DeckLab/deck_lab.sh --deck-a my_brew.deck --gauntlet decks/ --games 10000 --jobs 8
DeckLab/deck_lab.sh --help
```

`--help` prints the complete switch reference; this page is the long-form
manual behind it.

## Deck formats

Three formats load interchangeably (by extension), and
`./deck_convert.sh IN OUT` translates between them:

**.deck / .dec — the community standard** (The Dojo era's plain-text
lists, standardized by Apprentice and still what Arena/Moxfield exports
descend from):

```
// NAME : My Brew          (.dec header; or our 'name: My Brew')
# or hash comments         (blanks ignored)
4 Lightning Bolt           (count, space, EXACT printed card name)
4x Giant Growth            (Dojo-post style counts work too)
17 Mountain
SB: 3 Shatter              (sideboard — parsed, validated, and SWAPPED by
                            the AI between the duels of a match: see
                            --best-of / --sideboard below)
```

**.dck — the ORIGINAL MicroProse 1997 format**, as shipped in the game's
Decks folder: a header line (`Lord of Fate (Bl/Wh, 4th Edition)`), then
`.<id><TAB><count><TAB><name>` card lines, then per-opponent-color
sideboard sections (`.vNone`, `.vBlack`, ... — the original AI's
color-keyed swaps, folded to max-count-per-name on load). Numeric ids are
ignored on read (names are authoritative); writing `.dck` re-emits
authentic ids from `cards/data/dck_ids.txt` (369 ids harvested from an
original game copy's own deck files — round-trips are byte-faithful on
card lines).

Loading for PLAY validates every line against the card registry and
reports **all** problems at once; only implemented cards are playable.
`deck_convert.sh` is deliberately lenient — historic decks full of
not-yet-implemented cards convert fine. The shipped gauntlet lives in
`decks/` (five 40-card styles) and a CI test keeps every shipped deck
valid as the pool evolves.

## The Elo ledger

Unless `--no-elo`, every run folds its results into a persistent,
human-readable, commit-friendly text ledger (default `decks/ratings.txt`;
`--elo-file` overrides), so each deck's rating and lifetime record
accumulate ACROSS runs:

```
# deck | elo | games | wins | losses | updated
Blue Skies | 1635.2 | 240 | 180 | 60 | 2026-08-30
```

Math: standard Elo, K=8 per game, start 1500, zero-sum, with each
matchup's wins interleaved evenly (order-stable, deterministic). Ratings
converge to the gap the winrate implies (~123 points for a 67% matchup)
rather than growing without bound. **Caveat**: re-running the identical
seed re-counts those games — use `--no-elo` or a scratch `--elo-file` for
experiments and reruns.

## Matchup matrix mode

`DeckLab/deck_lab.sh --matrix decks/ --games 2000` runs the full round robin —
every deck against every other — and adds `matrix.svg`: an n×n win-rate
heatmap (red = losing, parchment = even, green = winning; row deck's
winrate vs column deck). The first full run of the shipped gauntlet
crowned Blue Skies (1635 Elo) and demoted Mountain Artillery (1403) —
flyers rule the starter meta.

## Switches

| Switch | Meaning | Default |
|---|---|---|
| `--deck-a DECK` | the deck under test (required) | — |
| `--deck-b DECK` | single opponent → duel mode | — |
| `--gauntlet LIST\|DIR` | comma list of .deck files, or a directory of them (deck A excluded, whichever flag was typed first) → gauntlet mode | — |
| `--games N` | games **per matchup** | 1000 |
| `--seed N` | base RNG seed — same seed + decks = identical results at ANY `--jobs` | 1 |
| `--jobs N` | worker threads | all cores |
| `--profile-a NAME` / `--profile-b NAME` | pilot skill: `apprentice`, `magician`, `sorcerer`, `wizard` | wizard |
| `--out DIR` | output directory (one inside the project gets a `.gdignore`, so the editor never imports the run's `matchups.csv` as a translation table) | `sim_results/run_<stamp>` |
| `--no-svg` | skip chart files | off |
| `--deck-pool LIST\|DIR` | what `random` draws from (see below) | `decks/` |
| `-h`, `--help` | switch reference | — |

### `random` — measuring a deck against the field

Either deck argument may be the literal word `random` instead of a path.
It is the setup screen's own `<random deck>` row in the CLI, and it is
deliberately the same mechanism rather than a second one: the pick runs
through `SetupScreen.random_deck_path`, which is static and RNG-injected
precisely so both callers can share it.

```
DeckLab/deck_lab.sh --deck-a my_brew.deck --deck-b random --games 2000
DeckLab/deck_lab.sh --deck-a my_brew.deck --deck-b random --deck-pool tier1/ --games 2000
```

A real deck is drawn **per game**, so 2000 games is 2000 draws from the
field and not 2000 games against one opponent. `--deck-pool LIST|DIR` says
what the field is (default `decks/`), and `--group` narrows it exactly as
it narrows `--gauntlet` — and, since 2026-09-02, reaches into the group
subfolders the same way (`--deck-pool decks/ --group ancients` is the
field of *Spells of the Ancients* enemy decks; see the switch table).

Four things are worth knowing about what you get back:

- **The pool is loaded and validated before a single game runs.** A deck
  in the field that does not parse, or that `--format` refuses, fails on
  the command line — not 400 games into a run that has already printed a
  header.
- **No deck under test is ever in its own field**, whichever side it sits
  on. A mirror match is a guaranteed 50% that dilutes the very number you
  are trying to read.
- **The draw is seeded from each game's own seed**, not from one RNG
  walked down the list, so game *i* faces the same opponent however many
  games you ask for: `--games 200` and `--games 2000` share their first
  200 pairings, and the longer run is the shorter one plus more evidence.
- **The report always splits the aggregate by opponent.** This is not
  decoration. With a five-deck field the aggregate is a weighted average
  of a handful of matchups, and it hides which of them did the damage —
  White Knights' first measured `45.0% vs the field` was 75% against
  Black-Red Raiders and **0 for 9** against Blue Skies.

`<random deck>` is a label for a row of the report, never a deck: it takes
no Elo rating and gives none. Each game is recorded in the ledger against
the deck that actually played it, so a run against the field rates every
deck in the field as well as the deck under test.

### Matches — `--best-of` and `--sideboard` (2026-09-02)

Both flags were absent until AI sideboarding existed, and the reason was a
missing capability rather than a design choice: without it the duels of a
best-of-N are independent, so a match result carries no information a game
result did not already carry, and `--sideboard on` would have changed
nothing at all. [AiSideboard](../engine/ai/ai_sideboard.gd) is what made
them worth wiring.

```bash
DeckLab/deck_lab.sh --matrix decks/ --games 60 --seed 4242 \
              --best-of 3 --sideboard on --no-elo
```

With `--best-of N` (1, 3 or 5 — the two lengths the 1997 record sentence
can narrate plus the gauntlet's `Best of &One`, see `MatchState`), **one
unit of work is a MATCH, `--games`
counts matches, and every figure in the report is a match figure** — the
header says `matches/matchup` rather than `games/matchup` so it cannot be
misread. Two things then make a match more than N duels: the **loser of a
duel is on the play** in the next one, and — with `--sideboard on` — each
seat **sideboards between duels** on what it saw the opponent play, never
on the opponent's decklist. How many cards a seat may move is its AI
profile's `sideboard_swaps`, so `--profile-a`/`--profile-b` change this
too and `apprentice` never sideboards at all. `--sideboard` without
`--best-of 3` or `5` is refused — with no match, or with `--best-of 1`,
there is nothing for it to be between.

The one figure that is still per-duel is `avg turns`, which is the mean
duel length inside the match — "a match took 34 turns" is not a number
anybody reads.

**THE FIRST EXPERIMENT, run on 2026-09-02** — the one the design named,
`--best-of 3 --sideboard on` against `off` on the same seed
(`--matrix decks/ --games 60 --seed 4242`, 600 matches a side, ~165s
each). **The delta is emphatically not zero**, so the sideboards are real
answers and the heuristic finds them. Every deck's overall match win rate
across the matrix:

| deck | sideboard off | sideboard on | delta |
|---|---|---|---|
| Black-Red Raiders | 49.0% | 62.2% | **+13.2** |
| Mountain Artillery | 17.2% | 24.2% | **+7.0** |
| White Knights | 60.4% | 60.4% | ±0.0 |
| Big Green | 39.5% | 31.6% | **−7.9** |
| Blue Skies | 83.8% | 70.6% | **−13.1** |

Both sides board, so a delta measures whose sideboard is better. The
biggest single move is Black-Red Raiders vs Blue Skies, **18.3% → 53.3%**:
four Red Elemental Blasts against a mono-blue deck is exactly the card the
heuristic is meant to find, and it finds it. Blue Skies, the best deck in
the field, is the one sideboarding costs most — which is what happens to
the best deck when everybody else gets to bring in answers to it.

### The duel settings

Every setting the battle-setup screen can choose is reachable from here.
That is a rule, not a nicety: a setting only the GUI can set is a setting
that can only ever be exercised by a human clicking, and this is the tool
that runs a thousand games.

| Switch | Meaning | Default |
|---|---|---|
| `--lives A,B` | starting life per seat; one number sets both | `20,20` |
| `--ante N` | stake N cards each before the deal (the original's `&Ante`) | 0 |
| `--names A,B` | seat names in the log | `SeatZero,SeatOne` |
| `--format NAME` | require a deck format: `unrestricted`, `wild`, `type1`, `type1.5`, `highlander`. An illegal deck **fails at parse time**, naming the card. Since 2026-09-01 the check counts the deck's `SB:` SIDEBOARD with its maindeck — which is also what keeps a sideboarded deck legal at duel 2, since a one-for-one swap leaves the union of the two piles alone | none |
| `--group NAME` | when a DIR is expanded, keep only one deck group: `originals`, `ancients`, `planeswalkers`, `coyote_tex`, `kevin_bane`, `other`, `starter`, `tournament`, `community`, `extended_community`, `user` (one per `DeckGroups.ORDER` heading). Since 2026-09-02 a DIR given with `--group` is walked **into its subfolders** — that is how the 312 ported decks under `decks/1997/<group>/`, `decks/tournament/`, `decks/community/` and `decks/extended_community/` ([decks-1997.md](decks-1997.md)) are reached: `--gauntlet decks/ --group originals` is the 55 enemy decks of the 1997 game, `--group community` the 48 proxy-free community decks. Without `--group` a DIR is its own files only, so the default field is still the five starter decks. A DIR deck that holds proxy cards is skipped with a note on stderr (a named file is never skipped; the loader refuses it and says why) | all |
| `--mulligan on\|off` | offer the Shandalar mulligan before turn 1 | **off** — see below |
| `--rules NAME` | `fifth` or `modern`; `fifth` turns every fork to the 1997 answer | `modern` |
| `--rule KEY=on\|off` | override one fork on top of `--rules`; repeatable | — |
| `--best-of N` | play MATCHES of up to N duels (1, 3 or 5) instead of single duels — the original's `&Best of:` | 0 (`&Free play`) |
| `--sideboard on\|off` | let each AI seat swap cards with its own sideboard between the duels of a match; needs `--best-of 3` or `5` | off |

**Every default above is what this tool did before the flag existed.** The
determinism check — same seed, same win/loss split, byte-identical
`matchups.csv` — is how this project proves an engine change was safe, and a
moved default silently invalidates it. A run at the defaults prints no
`settings:` line and writes the same report it always has.

`--rules fifth` is the one worth reaching for on its own: it replays a whole
pool under the ruleset the 1997 game actually played (mana burn on, attacker
selection committed, and the rest of `RulesOptions.FORKS`), which had never
been measurable at scale.

### The AI's skill and its sideboarding — where the switches are

The two things a player or a tester most often wants to set about the AI
are the same two switches in both places:

| | in the game (battle setup screen) | in the Lab |
|---|---|---|
| AI skill | **`AI difficulty:`** picker on each AI seat — Apprentice, Magician, Sorcerer, Wizard (default Wizard); hover it for what each level does | `--profile-a NAME` / `--profile-b NAME` (default `wizard`) |
| sideboarding | **`Sideboard between duels`** checkbox (greyed in `Free play`); governs the human's between-duels dialog AND whether the AI seats swap | `--sideboard on\|off` (default off; needs `--best-of`) |

They are the same [AiProfile](../engine/ai/ai_profile.gd) presets and the
same `sideboard_between_duels` flag on `DuelConfig`/`MatchState`, so what
the Lab measures is what the game plays. How many cards an AI seat may
move is the profile's `sideboard_swaps` (Apprentice 0 — it never
sideboards; Magician 2, Sorcerer 3, Wizard 4), and `--sideboard off` /
the unticked box stops [AiSideboard](../engine/ai/ai_sideboard.gd) from
running at all (`MatchScreen._ai_sideboards`, pinned by
tests/ui/test_match_screen.gd). Every level runs the same decision code;
the lower ones fumble more of it (`mistake_chance`) and the Apprentice
never holds instants open.

### The 2026-09-02 AI capabilities pass — before and after

The AI was rewritten to use what its cards can do (the class doc of
[ai_player.gd](../engine/ai/ai_player.gd) lists what; one test per item
in tests/ai/test_ai_capabilities.gd). Measured on the shipped decks, same
seeds before and after, wizard vs wizard, modern rules, no mulligan:

`--matrix decks/ --games 100 --seed 1` (row deck's win rate):

| pairing | before | after |
|---|---|---|
| Big Green vs Black-Red Raiders | 43.0% | 50.0% |
| Big Green vs Blue Skies | 30.6% | 47.0% |
| Big Green vs Mountain Artillery | 63.6% | 62.0% |
| Big Green vs White Knights | 49.5% | 65.0% |
| Black-Red Raiders vs Blue Skies | 28.0% | 41.0% |
| Black-Red Raiders vs Mountain Artillery | 66.7% | 40.0% |
| Black-Red Raiders vs White Knights | 40.0% | 47.0% |
| Blue Skies vs Mountain Artillery | 82.0% | 64.0% |
| Blue Skies vs White Knights | 64.0% | 59.0% |
| Mountain Artillery vs White Knights | 30.0% | 47.0% |

Both seats changed, so a matrix cell says how the DECKS fare under the
new pilot, not how much better the pilot is. The pilot's own measure was
a scratch A/B harness (new AI vs the old one, 25 pairings including
mirrors, seats alternating, 1000 games, seed 1): the new AI wins **65.5%**
as Wizard (seed 2: 66.3%), 64.0% as Sorcerer, 63.3% as Magician and
55.9% as Apprentice, with 0 stalls and 0 refused actions. The profiles
stay ORDERED — mirror matches, profile P in seat A vs a Wizard in seat B,
`--games 40 --seed 7`, five decks pooled: Apprentice 19.5% (was 25.8%),
Magician 36.5% (37.0%), Sorcerer 43.5% (41.5%), Wizard 45.5% (43.8%).
The cost is CPU: ~6 games/s on the matrix where it was ~9.

### Why `--mulligan` defaults off, and what it costs

Until 2026-09-01 the Lab never mulliganed. `MtgGame.start()` is exactly
`deal_opening_hands()` followed by `start_duel()` — the two openings were
never actually different — but the duel screen runs `OpeningHand` BETWEEN
them, and that is where the Shandalar mulligan is offered. So every Lab
result was measured on unfiltered opening hands while every real duel
filtered the unkeepable ones out.

It is now wired (the AI branch of `OpeningHand.run`, in the same order:
first player first, twice round). It defaults **off** because turning it on
changes every opening hand and therefore invalidates the recorded baseline
wholesale.

Measured, 200 games per pair over the five shipped decks, seed 77 (2000
games each way):

| Deck | mulligan off | on | delta |
|---|---|---|---|
| Blue Skies | 73.5% | 73.8% | +0.3 |
| White Knights | 55.6% | 55.5% | −0.1 |
| Black-Red Raiders | 47.0% | 47.4% | +0.4 |
| Big Green | 45.9% | 45.4% | −0.5 |
| Mountain Artillery | 28.0% | 28.0% | ±0.0 |

No single matchup moved by more than 1.5 points; average game length went
from 17.34 to 17.37 turns. All of that is inside the interval, and the
arithmetic says why: the Shandalar mulligan is a narrow filter — **no land
at all, or nothing but land**, not the modern keep-or-mull decision — and a
40-card deck with 17 lands throws such a hand about 1.4% of the time. So the
answer to "how much has the Lab been lying to us" is: for decks with a sane
mana base, not measurably. It would matter more for a deck with a bad one,
which is the case worth re-measuring if the default ever flips.

Deck paths are tried as given, then under `decks/`.

## What a run produces

Printed to stdout AND written to `--out`:

- **report.txt** — per-matchup: win rate with **Wilson 95% CI**, the raw
  win-loss record, stalled-game count, on-the-play vs on-the-draw split,
  average and median game length.
- **results.json** — everything machine-readable, for scripts.
- **matchups.csv** — one row per matchup, for spreadsheets.
- **winrates.svg** — win-rate bars with CI whiskers and a 50% reference
  line (opens in any browser; no plotting software involved anywhere).
- **turns.svg** — game-length histograms per matchup on a shared axis.

## Methodology (why the numbers can be trusted)

- **Wilson intervals**, not naive ±: correct near 0/100% and at small n.
  Rule of thumb: 1,000 games ≈ ±3%, 10,000 games ≈ ±1% at even win rates.
- **Play/draw alternation**: game i has deck A on the play iff i is even,
  and the split is reported — first-player advantage is real and an
  aggregate would hide it.
- **Determinism**: every game seeds as `base_seed + matchup_offset +
  game_index` and each thread writes only its own result slot, so a run
  reproduces bit-for-bit regardless of `--jobs`. Quote the seed when
  sharing results.
- **Stalls** (the AI driver bailing out — expected zero, and treated as a
  bug if seen) are counted separately, never attributed to either deck.
- **Pilot skill** is a variable, not noise: `wizard` vs `wizard` (default)
  compares DECKS with mistake-free pilots; weaker profiles inject seeded
  mistakes to model human-ish pilots (see engine/ai/ai_profile.gd).
- **Caveat that belongs in every writeup**: results measure decks *as
  piloted by this AI* (a one-ply heuristic — no search). AI strength
  upgrades (docs/ROADMAP.md M4) shift absolute numbers, and the
  2026-09-02 capabilities pass below did: Mountain Artillery, the deck
  whose cards the old AI could not use, moved most. Comparisons between
  decks under the same AI remain meaningful; comparisons across AI
  versions do not.

## Performance

Games fan out over Godot's WorkerThreadPool. Measured on a 22-thread
machine: ~15 games/second wall-clock (~0.3 games/s/thread), so a
10,000-game matchup ≈ 10 minutes and a five-deck gauntlet at 10k ≈ an
hour. `--jobs` caps threads for shared machines. Memory: each worker holds
one game (~a few MB); 10k games stream through a preallocated results
array — RAM stays flat.

## Files

| File | Role |
|---|---|
| `deck_lab.sh` | entry point (wraps the headless Godot invocation) |
| `deck_convert.sh` / `tools/deck_convert.gd` | format converter (.deck/.dec ↔ .dck) |
| `DeckLab/simulate.gd` | the tool: CLI parsing, thread fan-out, reporting |
| `DeckLab/sim_stats.gd` | Wilson intervals, matchup summaries (unit-tested) |
| `DeckLab/svg_charts.gd` | dependency-free SVG charts (bars, histograms, matrix heatmap) |
| `DeckLab/elo_ledger.gd` | the persistent Elo ledger |
| `engine/deck_list.gd` | multi-format deck parser/validator (strict & lenient modes) |
| `cards/data/dck_ids.txt` | authentic MicroProse card-id table (harvested) |
| `decks/*.deck` | the shipped five-style gauntlet |
| `decks/ratings.txt` | the default Elo ledger (created on first rated run) |
| `tests/tools/test_deck_lab.gd` | component tests |
