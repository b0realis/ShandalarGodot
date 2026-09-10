# Deck Lab — headless deck testing

```
   ___  ___  ___ _  __   _      _   ___
  |   \| __|/ __| |/ /  | |    /_\ | _ )   Shandalar, 1997 - decks measured,
  | |) | _|| (__| ' <   | |__ / _ \| _ \   not argued over: AI vs AI, headless
  |___/|___|\___|_|\_\  |____/_/ \_\___/   W U B R G
```

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
accumulate ACROSS runs. In the built game the path is beside the
executable — `decks/` is made on the first rated run, every deck starting
at 1500, and the file is read from disk from then on (2026-09-08: before
that the pack's own copy of this checkout's ledger shadowed it and
nothing accumulated):

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
| `--profile-a NAME:knob=value,...` | the same preset with knobs overridden — `wizard:pays_sacrifices=off`, `wizard:minds_pain=off,counter_threshold=4`. Booleans read on/off (true/false, 1/0), numbers as the knob's own type; an unknown knob is refused at parse time. How one AI capability is measured against its own null: the candidate on seat A, the knob off on seat B, same seeds | — |
| `--sweep KNOB=V1,V2,...` | the three-pair measurement of one AI knob in ONE run over one seed set: per value the CANDIDATE pair (deck A with the knob at that value vs deck B at the null), once the NULL pair (both seats at the null), and per value the CONTROL pair (below), which must replay its own null run game for game. One report with a row per value: win rate, interval, delta vs null, and the control's PASS/FAIL. Needs `--deck-a`/`--deck-b` or `--gauntlet` plus both control decks; never writes the Elo ledger; refuses `--matrix`, `random`, and a knob also set in `--profile-a/-b`. An unknown knob or a value the knob cannot read is exit 2 (see [the sweep](#the-sweep--one-knob-three-pairs-one-run-2026-09-06)) | — |
| `--null VALUE` | the sweep's null | `off` for a boolean knob, the seat-A preset's own value for a number |
| `--control-deck-a DECK` / `--control-deck-b DECK` | the sweep's control pair — two decks the knob cannot fire on. Required with `--sweep`, meaningless without it | — |
| `--out DIR` | output directory, created and NAMED BEFORE the run starts (one inside the project gets a `.gdignore`, so the editor never imports the run's `matchups.csv` as a translation table) | `DeckLab/results/run_<stamp>` |
| `--no-svg` | skip chart files | off |
| `--quiet` | no banner and no progress bar; errors only | off |
| `--no-banner` | keep the progress bar, drop the artwork (or export `DECK_LAB_NO_BANNER=1`) | off |
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
| `--mulligan on\|off` | offer the mulligan before turn 1 — since 2026-09-08 the PARIS one (any hand, one card fewer each redraw, until the seat keeps), each seat judged by its pilot (`AiProfile.mulligans`; the plain rule when that knob is off) | **off** — see below |
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

### The sweep — one knob, three pairs, one run (2026-09-06)

Every AI capability this project has measured was measured the same way,
by hand, in three runs: the CANDIDATE pair (deck A piloted with the knob
on, deck B with it off, same seeds), the NULL pair (both seats off), and a
CONTROL pair — two decks the knob cannot fire on — which had to come out
byte-identical to its own null, or the "delta" was the seeding, not the
knob. Three commands, three reports, a spreadsheet, and the control was
checked by eye. `--sweep` is those three runs as one command and one
report:

```
DeckLab/deck_lab.sh --deck-a decks/1997/ancients/dracur.deck --deck-b big_green.deck \
    --sweep pays_sacrifices=on,off \
    --control-deck-a big_green.deck --control-deck-b white_knights.deck \
    --seed 11 --games 1000
```

`KNOB` is any `AiProfile` knob (`pays_sacrifices`, `casts_timed_spells`, `counts_cards`, `levels_boards`,
`paces_draws`, `holds_duplicates`, `animates_to_attack`, `times_sweeps`, `trusts_abyss`, `pumps_to_attack`, `spends_counters`, `ranks_counters`, `tutors_for_the_turn`, `reads_gaze`, `reads_manlands`, `reads_pumps`, `counters_by_shape`, `reads_lethal_x`, `minds_pain`, `fits_auras`, `feeds_worst`, `spares_own`, `prices_liabilities`, `counter_threshold=4,5,6`, `holds_x_burn=0,3,5`, `aggression=0.3,0.7`, `w_hand=1.5,2.0,2.5`, ...); the values read as
the knob's own type, so `pays_sacrifices=maybe` and `counter_threshold=x`
are refused with exit 2, as is a knob that does not exist. The null is
`off` for a boolean and the seat-A preset's own value for a number unless
`--null` says otherwise. Mind what a knob actually fires on when you pick
its control pair: `pumps_to_attack` grew on 2026-09-09 to cover the BLOCK
declaration as well as the attack (and to read Dragon Whelp's and Nalathni
Dragon's card-local breath), and again the same day to make the breaths
the pilot BUYS match the ones the declaration was priced with — the
trampler's overflow and the one pool split among several bodies — and a
fourth time, when the recovery learned to ask the GANG's question (do
these bodies TOGETHER kill it) and an unblocked attacker's breath began
booking the held instant as well as its own second main phase. So its
control must hold no activated self-pump on EITHER side of the table —
Big Green vs White Knights still replays its null game for game, 1,000 of
1,000, in every arm of six runs, and of ten more on 2026-09-09 (five
pairs on the candidate tree and the same five on its baseline). And a
FOURTH time later the same day, to answer a BURN SPELL ON THE STACK with
the victim's own breath. So its control must hold no activated self-pump
on EITHER side of the table AND nothing that points damage at a creature
— Big Green vs White Knights holds neither, still replays its null game
for game (1,000 of 1,000, in every arm of ten runs). And a FIFTH time on
2026-09-10, when the breaths a block was DECLARED on began to be bought
before the pilot's own pre-emptive regeneration shield could spend them —
so its control must ALSO hold no regenerator beside a firebreather, which
Big Green vs White Knights again does not: 2150-1850 byte-identical to
its own null in every arm of six more runs (525-475 at 1,000). The live
pair for that reading is Vampire Lord vs Big Green at seed 11 — two
firebreathers and a Will-o'-the-Wisp reaching for the same Swamps — and
on the merged tree it reads **20.3% null / 23.4% `on`** at 4,000 games
per arm, **19.7% / 23.3%** at 1,000. (The 19.8% / 23.9% the fourth pass
printed for the same pair is one game and six away from that; it is the
same on both trees of the fifth pass's A/B and the control replays
525-475 exactly, so it is a stale pre-merge number rather than a moved
null. The reading is invariant in `--jobs`, checked at 4 and at all
cores.)
`spends_counters` (2026-09-09) fires wherever a permanent's ability costs
"remove N counters from this permanent" and the counters are on it, so its
control must hold no Osai Vultures, Scavenging Ghoul, Necropolis of Azar,
Triskelion, Rasputin Dreamweaver or Life Matrix — Big Green vs White
Knights holds none of the six, and no counter at all. `prices_liabilities` (2026-09-09) fires
on a permanent of the pilot's OWN that is worth less than nothing to it,
so its control must hold no Lich, no Mana Vault, no permanent that stops
untapping (a Paralyze, a Meekstone, an Arena of the Ancients) and no
creature whose printed upkeep line names a mana price it might not
reach — Big Green vs White Knights again, byte-identical to its own null
in every arm of eight runs. It GREW twice on 2026-09-10 and the control
pair holds against both: the dead-weight reading now follows the untap
price printed on an ATTACHMENT (Paralyze's {4}, the pool's one such aura
— Holy Strength grants and takes nothing back), and the sting a punisher
deals its target's controller is priced on the ENEMY side as well as our
own, so the control must also hold no Detonate. Neither deck does; Big
Green vs White Knights is 525-475 byte-identical to its own null in every
arm of five more runs at 1,000 games and one at 2,000.
`ranks_counters` (2026-09-10) fires only where a COUNTERSPELL is cast, so
its control must hold none on either side of the table — Big Green vs
Mountain Artillery holds none in either main deck (Mountain Artillery's
Red Elemental Blasts are sideboard cards, so keep `--sideboard` off or
pick another pair). Mind also that the knob does nothing in a deck whose
counters are all the same card: with two Counterspells and nothing else,
there is no order to get wrong. `holds_x_burn` (2026-09-10) is a NUMBER
and fires only where a spell whose X IS its damage is pointed at a
creature (`EffectIntent.damage_uses_x` — Fireball, Disintegrate, Drain
Life), so its control must hold none of them: Blue Skies vs White Knights
holds no X burn at all (Psionic Blast's four is printed and Braingeyser's
X is cards, not damage). Its null is 0 and NOT the seat's own preset
value, so a sweep of it wants `--null 0` written out — a wizard seat's
own value is 5, and a sweep that lets the default stand is measuring 3
and 0 against 5 rather than against the shipped tree before the knob
existed.
`reads_gaze` (2026-09-10) fires on three printed shapes and its control
must hold none of them: a trigger that destroys what it blocks
(Cockatrice, Thicket Basilisk), a printed rampage (all seven are Legends
cards — Craw Giant, Frost Giant, Wolverine Pack, Marhault Elsdragon,
Aerathi Berserker, Hunding Gjornersen, Chromium — and NO deck in
`decks/` holds one, which is why the rampage half is pinned by
`tests/ai/` and not measured here), and an activated ability that
destroys a TAPPED creature (Royal Assassin, Tetsuo Umezawa). Big Green
vs White Knights holds none of the three. `reads_manlands` (the same
day) fires wherever a permanent can animate ITSELF — the pool's two are
Mishra's Factory and Jade Statue — on EITHER side of the table, because
the knob is one fact read twice: theirs is a blocker our attack has to
price and ours is a blocker we buy once their attackers are declared.
Its control must hold neither, and Big Green vs White Knights again
does not.
`reads_pumps` (2026-09-10) fires wherever a creature on the side
OPPOSITE the seat being swept carries an activated self-pump with no tap
cost — seventeen cards in this pool, the same shape `pumps_to_attack`
reads on its own side (Frozen Shade, Carrion Ants, Killer Bees, Shivan
Dragon, Granite Gargoyle, Vampire Bats, Fire Drake, the three Walls, and
so on; Atog, Fallen Angel and Osai Vultures pay in a BOARD rather than
in mana and are refused). Its control must hold none of them: Big Green
vs White Knights holds none, and is 1075-925 byte-identical to its own
null in every arm of six runs at 2,000 games and 525-475 in all eleven
at 1,000. **Mind what the pool actually holds when you pick the live
pair.** Of the five shipped starters only Mountain Artillery (3 Granite
Gargoyle, 1 Shivan Dragon) and Black-Red Raiders (1 Shivan Dragon) hold
one at all, so fourteen of the twenty starter matchups measure **exactly
0 games different**; the decks that put the question are the 1997
enemies — `decks/1997/originals/vampire_lord.deck` (4 Carrion Ants, 4
Vampire Bats, 22 Swamps), `ape_lord.deck`, and
`decks/1997/ancients/crag_hydra.deck` (Great Hydra: 4 Granite Gargoyle,
4 Wall of Fire, and 4 Lightning Bolt and 4 Mana Flare beside them, which
is the "pumps AND instants" pair the design note asks for). The
community Necropotence list the note names CANNOT be played: six
proxies, exit 2.
`counters_by_shape` (2026-09-10) is read inside `_try_counter`, which no
seat without a counterspell in hand ever reaches, so its control must
hold none on either side of the table — Big Green vs White Knights holds
none, and is 525-475 byte-identical to its own null in every arm of six
runs at 1,000 games. **Mind what the pool holds when you pick the live
pair, twice over.** The knob needs a counter deck in seat A AND an
opponent that casts one of the shapes it reads, and the shapes are the
ones a printed worth gets wrong: a sweeper, an X burn or a player-hitting
Earthquake, a deck-out draw, an extra turn, a wheel. **Coral Reef vs
White Knights measures exactly 0 games different** — White Knights' one
Wrath of God already clears a Wizard's 5.0 bar, the deck holds no X burn
and no extra turn, and Coral Reef's only creature answer is a Boomerang
that costs the same as its Counterspell — which is a pool fact and not a
null result. The pairs that put the question are The Deck (playable) vs
**Mountain Artillery** (2 Fireball, 1 Earthquake, 4 Lightning Bolt:
40.2% → 51.6%) and vs **Black-Red Raiders** (42.7% → 49.9%). Of the five
shipped starters only Blue Skies holds a counterspell at all, and only
two of them, so the starter matrix moves by at most six games in a
thousand.
`reads_lethal_x` (the same day) fires only where a LIFE-FOR-MANA spell is
in the deck, which in this pool is **Channel and nothing else**, so its
control must hold none — Big Green vs White Knights again, 1075-925
byte-identical to its own null in both arms at 2,000 games. Ten decks
name Channel and **only three of them can be played**: the 1997
`summoner.deck` (originals and duels) and `sargent_2009_summoner.deck`.
The other seven are proxy-blocked — `wc1994_lestree` and
`fork_recursion_chalice_1995`, which `docs/forge/casting.md` P6 names for
its own measurement, are BOTH of them (Chaos Orb), as are
`wc1994_symens`, `wc1994_defoucaud` (Chaos Orb), `wc1995_stern` (12
proxies) and `wc1995_justice` (10); `explosion_wright_1994` loads but its
list holds no Channel, only the archetype's name in a comment. Channel is
restricted, so a deck plays exactly one, and the knob's answer differs in
about one game in five (409 of 2,000 against White Knights, 420 of 2,000
against Big Green).
**Mind also that all five default ON at Sorcerer and Wizard**, so a
sweep of some OTHER knob taken against a published number must pin them
off on both seats
(`--profile-a wizard:reads_gaze=off,reads_manlands=off,reads_pumps=off,`
`counters_by_shape=off,reads_lethal_x=off`
and the same for `--profile-b`) or it is measuring several changes; that
is how the null was proved for both passes — the `pays_sacrifices` sweep
of the manual, Dracur (Spells of the Ancients) vs Big Green at seed 11,
1,000 games an arm, run on the tree before the first two landed and on
the tree after with both pinned off, is **identical game for game in all
6,000 games**, 24.9% null either way and the control 525-475 replayed to
the game; and run again on 2026-09-10 on HEAD's own files and on the
`reads_pumps` tree with all three pinned off, the two `games.csv` files
are byte for byte the same 6,000 games (22.6% null on both, which is
what the same pair reads under the day's other knobs).
`tutors_for_the_turn` (2026-09-10) fires wherever a card ask offers cards
out of the SEAT'S OWN LIBRARY, which in this pool is a Demonic Tutor, an
Untamed Wilds, a Land Tax, a Transmute Artifact or an Aladdin's Lamp —
so its control must hold none of the five, and Big Green vs White Knights
does not (Big Green's Regrowth is a GRAVEYARD ask and goes through a
different reader). It is 525-475 byte-identical to its own null in every
arm of four runs at 1,000 games and two at 4,000. Mind the pool when you
pick the live pair: every deck in this repository that plays Demonic
Tutor plays exactly ONE (it is restricted), so the search resolves in
about one game in three and the ANSWER differs in about one in eight —
not enough for any single pair to move a win rate past its own interval.
The census in `docs/ai-difficulty.md` §4 is what the reading is read by.
`levels_boards` (2026-09-07) GREW on 2026-09-10 to cover the LAND SWEEP —
a sweeper whose every kill is a land — so its control must hold no
Balance AND no Armageddon, Flashfires, Tsunami or Acid Rain. Big Green vs
Mountain Artillery holds none of them in the MAIN deck, which is what a
free-play sweep plays: Mountain Artillery's three Flashfires are
sideboard cards and `--sideboard` is off unless you ask for it. It is
549-451 byte-identical to its own null in every arm of eight runs at
1,000 games and 2177-1823 in all seven at 4,000. Every other switch keeps its meaning: `--games`
is per arm and per pair, the seeds are the ones a plain `--deck-a`/
`--deck-b` run deals (the null arm is `--profile-a wizard:KNOB=null
--profile-b wizard:KNOB=null`, game for game), and `--gauntlet` sweeps
every matchup. The run above is 3 arms x 2 pairs x
1000 games, and its report is:

```
Dracur (Spells of the Ancients) vs Big Green: Dracur (Spells of the Ancients)'s win rate with pays_sacrifices at each value on seat A, off on seat B
  value           games  win rate                     delta vs null
  null (off)       1000   24.6%  CI [22.0%..27.4%]        --
  on               1000   27.0%  CI [24.3%..29.8%]      +2.4 +-3.8
  off              1000   24.6%  CI [22.0%..27.4%]      +0.0 +-3.8

control Big Green vs White Knights: the knob cannot fire here, so every arm must replay the null game for game
  value           games  record     verdict
  null (off)       1000  527-473    the baseline
  on               1000  527-473    PASS  byte-identical to the null, 1000 of 1000 games
  off              1000  527-473    PASS  byte-identical to the null, 1000 of 1000 games

control: PASS -- every arm replays the null game for game; the deltas above are the knob's own.
```

— which is the ROADMAP's own table for `pays_sacrifices` (25.3% / 27.2%
on 2,000 games), read by one command. Mind the deck: there are three
Dracurs under `decks/1997/` and only the Ancients list carries the
sacrifice cards; the originals' reads 10.4% / 10.8% here, and the report
names which one it played by the deck's own title.

The control is read from the games, never assumed: every game is
fingerprinted with the md5 of the engine's own log (`MtgGame.log_lines`,
which under a seed is the whole game, move for move), and a control arm
PASSES only when every one of its games carries the fingerprint of the
null arm's game with the same seed. A FAIL names the first game that
moved and what moved (`game 0 (seed 4242): the game log, a_won false vs
true, turns 12 vs 13`) and the run ends with **exit 4** — the report is
still written, because a moved control is itself a finding (the knob
fired where it cannot, or something in the run is not seeded), but the
deltas above it are not a measurement and a script must not read them as
one. The delta's interval is the two Wilson half-widths in quadrature, so
at 1,000 games per arm a delta under 4.4 points is invisible, and the
reading block at the foot of the report says how many games a `+-3` or
`+-1` delta would need.

`w_hand` (2026-09-10) is the first number here that is not a difficulty
knob at all: `Evaluator.W_HAND`, the weight `position_score` puts on a
card-in-hand lead, exposed on `AiProfile` precisely so the Lab can put
it on a seat. It cannot have a proper control pair — every game is
scored — but it very nearly does: raising it from 1.5 to 2.5 changes 12
games of 2 000 on Big Green vs Mountain Artillery, so the run reports a
control FAIL at 2.0 and 2.5 and a PASS at 1.5, and the PASS at the
shipped value is the determinism check that matters. Read the FAIL lines'
counts, not just the verdict, when the swept number is one every game
touches.

A sweep writes `report.txt`, `sweep.json` (everything, including the
control verdict and each arm's profiles), `sweep.csv` (one row per arm
and pair) and `games.csv` (every game's seat, result, turns and
fingerprint, which is what the verdict was read from and what a later run
can be diffed against). It never touches the Elo ledger: a candidate
pilot is not the shipped one, and its games are not rating games.

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

**Since 2026-09-08 the rule is the Paris mulligan** (the owner's ruling,
`docs/duel-todo.md` §1.5): any hand may go back, one card fewer each
time, and the pilot judges by `AiMulligan` — no mana, all land, a mana
count outside the keep range for the hand's size, or mana that casts
none of the spells. That is a wider filter than the 1997 one, so the
table above is the old rule's; the default stays **off** for the same
reason as before (the baseline), and the judgement itself is measured in
`docs/ROADMAP.md`, "THE OPENING HAND (2026-09-08)": `--sweep
mulligans=on --mulligan on`, with two all-land decks as the control —
both rules throw an all-land hand back down to the same floor, so the
control replays the null byte for byte.

**And since 2026-09-10 the band's floor counts MANA, not lands** — the
lands plus every card in hand that costs `{0}` and prints a mana ability
(five Moxen, Black Lotus, Mana Crypt in this pool). It matters to the
Lab's numbers only for a deck that owns one of those seven: the five
shipped decks own none and throw back exactly the share of their sevens
they always did (16.6 / 11.6 / 9.8 / 13.7 / 14.3%, 4 000 hands each,
unchanged to the tenth), while The Deck's lists roughly halve theirs
(20.2 → 8.3%, 22.6 → 9.8%, 36.2 → 16.6%), nineteen 1997 enemy decks do
the same (Dracur 33.6 → 22.2%, Prismat 30.5 → 17.9%) — 69 of the 217
loadable decks hold one of the seven cards — and `twist_of_fire_merritt_1993`
— forty cards, no land at all, twenty-one Black Lotuses — stops
mulliganing to the four-card floor in every game of every run
(100 → 3.1%). **So a recorded baseline that involved `--mulligan on` and
a Power deck is not comparable across that date**; one with `--mulligan
off`, or with none of those seven cards in either list, is.

Deck paths are tried as given, then under `decks/`. **A deck argument is a
PATH, not a deck's name** — `--deck-a decks/big_green.deck`, never
`--deck-a "Big Green"` — and getting that wrong is the single most common
mistake this tool sees, so a path that matches no file is refused with the
deck files it looked most like (matched on the file name, with spaces,
dashes, underscores and case all treated alike, and reaching into the
subfolders), plus what to type instead and what a FOLDER does:

```
deck_lab: deck file not found: 'Big Green'
  looked for: Big Green, decks/Big Green, res://decks/Big Green
  did you mean:
      decks/big_green.deck
  deck arguments are PATHS to a deck file, not deck names:
      --deck-a decks/big_green.deck      yes
      --deck-a "Big Green"               no
  `ls decks/` lists the 5 decks in the folder itself; 312 more are in
  its subfolders, reached with --group (see --help).
```

## What a run produces

Printed to stdout AND written to `--out`:

- **report.txt** — per-matchup: win rate with **Wilson 95% CI**, the raw
  win-loss record, stalled-game count, on-the-play vs on-the-draw split,
  average and median game length. Then, since 2026-09-05, the **reading**
  of those rows: a matrix run's **standings** (every deck's record across
  the whole round robin, best first), a gauntlet run's **aggregate** for
  the deck under test, and a closing paragraph that says how wide the
  interval is at this sample size, how many matchups are DECIDED (their
  interval clear of 50%) and how many are still even. That paragraph
  exists because a percentage gets quoted and an interval gets skipped:
  `44.0%` over 200 games has three times been read as "worse deck" when
  50% sat inside `[37.3%, 50.9%]` all along.
- **results.json** — everything machine-readable, for scripts.
- **matchups.csv** — one row per matchup, for spreadsheets.
- **winrates.svg** — win-rate bars with CI whiskers and a 50% reference
  line (opens in any browser; no plotting software involved anywhere).
- **turns.svg** — game-length histograms per matchup on a shared axis.

`results.json`, `matchups.csv` and the SVGs are read by other tooling and
their shape does not move; the reading paragraphs above are report.txt
and stdout only. A `--sweep` writes its own set instead — `report.txt`,
`sweep.json`, `sweep.csv`, `games.csv` — described under
[the sweep](#the-sweep--one-knob-three-pairs-one-run-2026-09-06).

## Two channels: the instrument and the human

**stdout is the instrument** — the report, byte for byte the text that
lands in `report.txt`, and nothing else. **stderr is the human** — the
banner, the progress bar, warnings, the "did you mean" behind an error —
and it is decorated only when **stderr is a terminal**. GDScript cannot
ask whether a stream is a tty, so `deck_lab.sh` asks (`[ -t 2 ]`) and
passes the answer (and the terminal's width) in the environment.

The consequence is the one that matters:

```
DeckLab/deck_lab.sh ... > run.log         # banner on screen, clean log
DeckLab/deck_lab.sh ... > run.log 2>&1    # no artwork at all, anywhere
```

so a log a script or a measuring agent parses never contains decoration
and nobody has to remember a flag. `--quiet` and `--no-banner` turn it off
deliberately, `DECK_LAB_NO_BANNER=1` turns the artwork off for good, and
`NO_COLOR` (the convention) drops colour while keeping the words.

A run longer than two seconds draws a **progress bar** with a rate and an
ETA, rewritten in place on a terminal and reduced to one heartbeat line a
minute when stderr is a log — because a tool that prints a header and then
nothing for forty minutes is indistinguishable from a hung one, and this
project has lost hours to exactly that ambiguity.

**Exit codes**: 0 a finished run with every file written; 1 the run broke
(a worker thread stopped, a file could not be written); 2 the command line
was wrong (bad flag, missing or illegal deck, a `--sweep` knob or value the
profile cannot read); 3 no Godot binary (`deck_lab.sh`; set
`GODOT=/path/to/godot`); 4 a `--sweep` ran to the end and wrote its files,
but its control pair did not replay the null game for game — the report
names the first game that moved.

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

Games fan out over Godot's WorkerThreadPool.

**MORE THREADS IS NOT FASTER, AND PAST FOUR IT IS MUCH SLOWER.** Measured
on an idle 22-core machine, the same 60-game duel:

| `--jobs` | 1 | 2 | 3 | **4** | 5 | 6 | 8 | 22 |
|---|---|---|---|---|---|---|---|---|
| games/s | 12.1 | 18.1 | 18.1 | **18.1** | 15.7 | 12.5 | 8.9 | 4.4 |

Twenty-two threads runs at **a third of the speed of one**. The default
used to be every core, so every long measurement this project has made
was paying that; it is `min(4, cores)` now. `--jobs 0` still means every
core, and `--jobs N` still caps threads on a shared machine.

The curve is identical on the pre-2026-09-05 script, so the cause is the
engine or the pool oversubscribing rather than anything in the fan-out —
it is not yet understood, and the numbers above are a measurement, not an
explanation. **Results do not depend on it**: `matchups.csv` is
byte-identical at every job count, which is what made the default safe to
move.

Memory: each worker holds one game (~a few MB); 10k games stream through a
preallocated results array — RAM stays flat.

## Files

| File | Role |
|---|---|
| `deck_lab.sh` | entry point (wraps the headless Godot invocation) |
| `deck_convert.sh` / `tools/deck_convert.gd` | format converter (.deck/.dec ↔ .dck) |
| `DeckLab/simulate.gd` | the tool: CLI parsing, thread fan-out, reporting |
| `DeckLab/sim_stats.gd` | Wilson intervals, matchup summaries (unit-tested) |
| `DeckLab/svg_charts.gd` | dependency-free SVG charts (bars, histograms, matrix heatmap) |
| `DeckLab/lab_console.gd` | the terminal side: banner, progress bar, colour, "did you mean" |
| `DeckLab/elo_ledger.gd` | the persistent Elo ledger |
| `engine/deck_list.gd` | multi-format deck parser/validator (strict & lenient modes) |
| `cards/data/dck_ids.txt` | authentic MicroProse card-id table (harvested) |
| `decks/*.deck` | the shipped five-style gauntlet |
| `decks/ratings.txt` | the default Elo ledger (created on first rated run) |
| `tests/tools/test_deck_lab.gd` | component tests |
| `tests/tools/test_deck_lab_sweep.gd` | the sweep: its flags, the three arms, the control verdict read from the games, a small run end to end (exit 0 and exit 4) |
