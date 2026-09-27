# Driving Shandalar's tools from a program

This is the contract for **running** the headless tools — the Deck Lab,
the AutoDeck CLI, the Lab Query, the deck converter — from a script, a
pipeline or an agent: what each command is for, what it prints where,
what its exit codes mean, what files it leaves and under which keys.
The house rules for **editing** the repository are in `CONTRIBUTING.md`;
the manuals with the reasoning are `DeckLab/README.md` and `docs/`.
Every claim below is pinned by
`tests/tools/test_lab_for_machines_2026_09_27.gd`,
`tests/tools/test_lab_records_and_queries_2026_09_27.gd`,
`tests/tools/test_deck_lab.gd` and `tests/tools/test_auto_deck_cli.gd`.

## The one door — `./shandalar.sh`

```
./shandalar.sh lab ARGS...        the Deck Lab        (DeckLab/deck_lab.sh)
./shandalar.sh autodeck ARGS...   the AutoDeck CLI    (DeckLab/auto_deck_cli.sh)
./shandalar.sh check DECK...      is this deck playable, and why not
./shandalar.sh packs              every card pack: found, on, why not
./shandalar.sh cards NAME...      a card's record     (DeckLab/lab_query.sh)
./shandalar.sh convert IN OUT     .deck <-> .dck      (deck_convert.sh)
./shandalar.sh VERB --help        that tool's own manual
./shandalar.sh -h | --help        the list, on stdout;  -V | --version
```

Each verb `exec`s the tool, so the exit codes, the channels and the
files below are the tool's own. A verb the door does not know is
refused the way every tool refuses — one JSON line on stdout,
`{"error":{"tool":"shandalar","exit":2,"kind":"option",...}}`, exit 2.
A release folder carries the same `shandalar.sh` (`play` runs the game;
`convert` stays in the checkout) beside `deck_lab.sh`, `auto_deck.sh`
and `lab_query.sh`, each a one-liner into the game binary.

## The two channels

- **stdout is the instrument**: the report (byte for byte `report.txt`),
  a `--dry-run` plan, or a refusal envelope — never a banner, never a
  progress bar, never colour.
- **stderr is the human**: banner, progress, warnings, "did you mean",
  decorated only when stderr is a terminal. `2>/dev/null` loses nothing a
  program needs. `--quiet` drops the banner and the bar.
- One process, one run. The Lab fans games out over `--procs` worker
  processes of its own; do not start a second run, a build or the test
  suite against the same checkout while one runs.

## Exit codes (every tool)

| Code | Meaning |
|---|---|
| 0 | done, every file written (a dry run: the plan printed, nothing written) |
| 1 | the run broke — a worker stopped, a file would not write, an output folder that holds files (AutoDeck without `--force`), a pool with nothing in it |
| 2 | the command line was wrong — a flag, a value, a deck or list file that is not there or is not legal |
| 3 | no Godot binary (`GODOT=/path/to/godot`; the shell wrappers answer `-V` without one) |
| 4 | Lab `--sweep` only: the run finished and wrote its files, but the control pair did not replay game for game — the results are suspect |

## The refusal as data

Every refusal **before a game or a deck** — every exit 2, and the exit 1s
a run can hit before it starts — prints ONE line of JSON on stdout, then
exits. Parse stdout when the exit is non-zero; if it holds an `error`
object, that is the reason.

```json
{"error":{"tool":"deck_lab","exit":2,"kind":"deck",
  "message":"deck file not found: 'big_gren.deck'",
  "path":"big_gren.deck",
  "tried":["big_gren.deck","decks/big_gren.deck","res://decks/big_gren.deck"],
  "folder":false,"suggestions":["decks/big_green.deck"]}}
```

| Key | Always | Meaning |
|---|---|---|
| `tool` | yes | `deck_lab`, `auto_deck`, `lab_query` or `shandalar` |
| `exit` | yes | the code the process exits with |
| `kind` | yes | **the thing to branch on** — below |
| `message` | yes | the prose stderr got |
| `flag` | when named | the flag at fault (`--gmes`, `--keep`, `--out`) |
| `suggestions` | when any | the spellings "did you mean" would offer — flags for `option`, deck paths for `deck` |
| `path`, `tried`, `problems`, `format`, `packs_needed` | by kind | the particulars |

Kinds: `option` (a flag or value, a `--sweep` without its control pair),
`deck` (not found, proxied, illegal for `--format`), `packs` (a `--packs`
that cannot be enabled), `pool` (a `--field`/`--matrix` with nothing in
it), `out` (the folder is a file, cannot be made, or holds files),
and the AutoDeck's own `sets`, `list`, `keep`, `vary`. A refusal
*during* a run keeps its exit code and its stderr and prints no envelope
— by then stdout is the report.

## `--dry-run` — the plan, and nothing played

Both tools take `--dry-run`: every check runs (a bad deck still refuses,
with the envelope), then the plan is printed as pretty JSON on stdout,
exit 0, **no folder is made, nothing is written**. `"dry_run": true` is
always in it.

Deck Lab plan keys: `tool`, `mode` (`duel` `gauntlet` `matrix`
`tournament` `random` `sweep`), `decks[]` (`name`, `file`, `cards`,
`sideboard`), `matchups`, `games_per_matchup`, `unit` (`games` or
`matches`), **`total`** (what the run will play), `seed`, `jobs`,
`procs`, `profile_a`, `profile_b`, `packs` (the switch's value, `null`
when the game's setting decides), `packs_on` (the packs actually on),
`rated`, `format`, `rules`, `out`, `estimate` (`seconds`, at a nominal
rate the note says is a guess — the run measures its own). Tournament
adds `field[]`, `gauntlet[]`, `top`; a sweep adds `knob`, `values`,
`null`, `arms[]`, `pairs[]`, `control`, and `total` is arms × pairs ×
games.

AutoDeck plan keys: `tool`, `count`, `combinations`, `seed`,
`seed_rolled` (no `--seed`: the run would roll one), `source`, `sets`,
`packs`, `packs_on`, `wishes{}`, `distinct`, `keep`/`kept_cards`,
`vary{}`, `list`, `out`, `out_exists`, `out_holds` (files already there
— the `--force` question), `force`, `files{decks,manifest,list}`,
`disk_bytes`, `next` (the Lab command that plays the field, as one
string).

## Deck Lab — `DeckLab/deck_lab.sh`

Plays decks against decks headless and measures. Modes by switch:

```
--deck-a A --deck-b B                 duel (rated unless --no-elo)
--deck-a A --gauntlet DIR|LIST         one deck vs a group
--matrix DIR|LIST                      every pair, round robin
--field DIR|LIST --gauntlet DIR|LIST   tournament: field ranked vs gauntlet (never rated)
--deck-a A --deck-b random             a deck vs the field, a fresh draw a game (--deck-pool DIR)
--deck-a A --deck-b B --sweep KNOB=V1,V2 --control-deck-a C --control-deck-b D
                                       one AI knob, test pair and control pair
```

Deck paths resolve as given, then `decks/NAME`, then `res://decks/NAME`.
`--games N` per matchup, `--seed N`, `--jobs N` threads, `--procs N`
worker processes, `--packs 1,3|all|none`, `--profile-a/-b NAME[:knob=v]`,
`--best-of 3 --sideboard on`, `--rules fifth|modern`, `--format
unrestricted|wild|type1|type1.5|highlander`, `--group NAME` (one deck
group of an expanded folder — `tournament` is the good decks), `--top N`,
`--record losses|stalls|all` (`--record-max N`, default 50), `--out DIR`.
`--help` lists every switch; the tables it is read from are the
parser's own, so the help is never behind the code.

Files in `--out` after exit 0: `report.txt` (= stdout), **`results.json`**,
`matchups.csv`, `winrates.svg`, `turns.svg`, **`run.json`**; tournament
adds `standings.csv` and `top.txt`; a sweep writes `report.txt`,
**`sweep.json`**, `sweep.csv`, `games.csv`, `run.json` instead; with
`--record`, a `records/` folder of game logs.

`results.json`: `mode`, `games_per_matchup`, `seed`, `profile_a`,
`profile_b`, `lives`, `ante`, `mulligan`, `rules`, `rule_overrides`,
`format`, `packs`, `elapsed_seconds`, `matchups[]`; each matchup `deck_a`,
`deck_b`, `games`, `a_wins`, `b_wins`, `stalled`, (`draws` when any),
`winrate{low,mid,high}` (Wilson 95%), `winrate_on_play`,
`winrate_on_draw`, `avg_turns`, `median_turns`. Present only when used:
`best_of`/`sideboard`, `field`, `challenge`, and for a tournament
`standings[]`, `gauntlet[]`, `rated:false`.

`sweep.json`: `knob`, `values`, `null`, `games_per_arm`, `seed`,
`matchups[]` and `control{}` each with `arms[]` (`value`, `null`,
`profile_a`, `profile_b`, the matchup stats, `delta{points,margin,clear}`
against the null arm, and on the control pair `verdict{pass,...}`),
**`control_pass`** (false ⇒ exit 4). Read `delta.clear` before quoting
`delta.points`.

Invariants: a `--sweep` needs both `--control-deck-*`; `--no-elo` on any
mined or experimental field (the ledger `decks/ratings.txt` is the
project's own record); one `--seed` replays one run game for game;
tournaments are never rated; `--out` must not be a file.

### `--record` — the games themselves

`--record losses` writes the engine log of every game deck A lost,
`stalls` of every game that hit the turn limit, `all` of every game, to
`OUT/records/`. One file a game, `pairP_seedS[_armA][_duelD]_OUTCOME.log`
(`a_won`, `a_lost`, `drawn`, `stalled`), a `#` header a program reads
before the log:

```
# deck_a: Big Green
# deck_b: White Knights
# pair: 0
# seed: 5
# a_on_play: true
# outcome: a_lost
# turns: 23
# lines: 162
Game set up: SeatZero (40 cards) vs SeatOne (40 cards)
...
```

`--record-max N` caps the files per run (default 50, `0` = no cap; a
thousand logs is a gigabyte) — exact per process, "about N" across
`--procs` workers. `results.json` / `sweep.json` gain
`records{filter,max,written,dir}` only when the switch was used. The
seed in the name replays that game: `--seed S --games 1` on the same
pair.

## `run.json` — after every run

Every run that made its `--out` folder ends by writing `run.json`
there, whatever the exit — the one file to read first:

| Key | Meaning |
|---|---|
| `tool` | `deck_lab` or `auto_deck` |
| `version`, `git` | the project version and the checkout's commit (`""` in a release) |
| `argv[]` | the line as typed, without the program name |
| `mode`, `seed`, `packs`, `packs_on`, `out`, `started` (UTC, `...Z`), `elapsed_seconds` | the run's particulars |
| `exit` | the code the process exits with — `0`, `1`, or the sweep's `4` |
| `files[]` | what was written (the Lab); AutoDeck: `files{decks,manifest,list}` |
| `control_pass` | a sweep: whether the control pair replayed game for game |
| **`next`** | `{why, argv[]}` — the run that would settle what this one left open — or `null` |

`next.argv` is a complete Deck Lab line built from this run's own argv
with the changing flags stripped and re-added: a duel, gauntlet, matrix
or random run whose matchups still straddle even (`winrate.low < 0.5 <
winrate.high`) gets four times the games at `OUT_more`, unrated; a
tournament gets its `top.txt` as the field at five times the games at
`OUT_top`, same gauntlet; a sweep whose candidate deltas are not `clear`
gets four times the games; AutoDeck's is the Lab line that plays the
field. `null` means nothing is open — every matchup decided, every
delta clear — or, on a sweep whose control moved, that more of the
same would not settle it. A program that loops `run.json.next.argv`
until `null` has run the study; it should still cap the loop.

## AutoDeck CLI — `DeckLab/auto_deck_cli.sh`

Builds decks by the thousand from wishes — the field the Lab plays.

```
DeckLab/auto_deck_cli.sh --out DIR --count N [--seed S] [--colors G,WU,random]
    [--sets 4ed,ice] [--source sets|list|sealed] [--packs 1,2] [--size 40|60]
    [--lean spells|balanced|creatures] [--speed fast|medium|slow] [--gold on|off]
    [--variety PCT] [--distinct PCT] [--keep FILE [--vary "2 Card, 1 Other"]] [--force]
```

Every axis takes a comma list of alternatives and the run walks the
cartesian product `--count` times. `--keep` and `--distinct` imply
`--variety 50` when none was spoken. `--out` must be empty or `--force`
(which clears the previous run's `deck_*.deck`, `decks.csv`,
`decklist.txt` and nothing else).

Files in `--out`: `deck_NNNNN_COLORS_sSEED.deck` per deck, **`decks.csv`**
(one row per deck — `file`, `index`, `seed`, `source`, `sets`, `pool`,
`packs`, the wish columns, `colors_built`, the cards; a row rebuilds its
deck), `decklist.txt` (the paths in order, one a line — a `--gauntlet` or
`--field` reads it), and `run.json` (above; `seed_rolled` says the seed
was the run's own draw, `next.argv` the Lab line). The last stderr line
is `next: DeckLab/deck_lab.sh --field DIR ...`, the same line as words;
`--dry-run` gives it as `next`.

## Asking before running — `DeckLab/lab_query.sh`

Three questions, each answered as ONE pretty-printed JSON document on
stdout and nothing else there. Exit 0 is an answer (a deck that cannot
be played is an answer), 2 a line that could not be answered (the
envelope above, `tool: "lab_query"`), 1 an answer that would not write.

```
DeckLab/lab_query.sh check DECK [DECK...] [--packs LIST] [--format NAME]
DeckLab/lab_query.sh packs
DeckLab/lab_query.sh cards NAME [NAME...]
```

**`check`** loads each deck the way the Lab would (as typed, then
`decks/NAME`) and reports instead of refusing: `decks[]` each with
`file`, `path` (where it was found), `name`, `cards`, `sideboard`,
`errors[]` (lines that are not `COUNT Card Name`), `unknown[]` — every
name the card pool does not know, with `count`, `where`
(`main|sideboard|both`), `pack` (the pack that supplies it; `""` for
none: unimplemented or misspelled) and, for those, `near[]` (the
nearest real names) — `packs_needed[]`, `packs_missing[]` (needed and
not on), `format{name,ok,problem}` with `--format`, and **`playable`**
(no errors, no unknown names, the format met: what the Lab would play);
top-level `playable` over every deck, `packs` (the switch), `packs_on`.
A deck file that is not there is the `deck` refusal with `tried` and
`suggestions`.

**`packs`**: `known[]`, `available[]` (found), `enabled[]` (on) and
`packs[]` — per pack `id`, `label`, `available`, `enabled`, `path`,
`rejection` (why a found zip was not accepted), and for a found pack
`sets[]` and `cards`.

**`cards`**: `cards[]` — a known card's `name`, `cost` (`{3}{W}{W}`),
`mana_value`, `colors[]`, `types[]`, `supertypes[]`, `subtypes[]`,
`keywords[]`, `power`/`toughness` (creatures), `text`, `set`, `sets[]`
(the printings in the pool as configured), `rarity`, `pack` (`""` for a
base card); an unknown one `known: false`, `pack` (the pack that would
supply it) and `near[]`.

## Deck convert — `./deck_convert.sh INPUT OUTPUT`

Formats come from the extensions (`.deck`/`.dec` ↔ `.dck`). Exit 0 with
the converted deck's report on stdout; 2 on anything else (a missing
argument, a deck with problems or no cards, an unknown extension, a file
that would not write — the reason on stderr). No JSON envelope here yet.

## The game itself

`godot --path .` (or the released binary) takes `--deck-lab`,
`--auto-deck` and `--lab-query`, each hosting that headless tool inside
the game binary (what a release's `deck_lab.sh`, `auto_deck.sh` and
`lab_query.sh` are), and `--verify-pack-1..5`; the LAN protocol is 24
(`docs/sgmanalink-*.md`). Headless soaks and audits live under
`tools/*.gd` (`./duel_soak.sh --help`). `./run_tests.sh` is the gate:
trust its exit code, not the printed tally.

## A session, in order

```
./shandalar.sh packs                                                         # what is on
./shandalar.sh autodeck --out mined --count 200 --colors random --dry-run    # plan
./shandalar.sh autodeck --out mined --count 200 --colors random              # build
./shandalar.sh check mined/deck_00001_G_s11.deck                             # playable?
./shandalar.sh lab --field mined --gauntlet decks/ --group tournament \
    --games 20 --no-elo --record losses --out mined_run --dry-run            # plan
./shandalar.sh lab --field mined --gauntlet decks/ --group tournament \
    --games 20 --no-elo --record losses --out mined_run 2>/dev/null          # play
jq '.standings[:10]' mined_run/results.json                                  # read
jq -r '.next.argv // empty | @sh' mined_run/run.json                         # what next
```

A non-zero exit: read stdout for `{"error":...}`, branch on `kind`, offer
`suggestions`; never retry the same line. A zero exit: read `run.json`,
and `next.argv` is the line that settles what this run left open.
